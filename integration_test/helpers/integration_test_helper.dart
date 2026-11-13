import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:claimly/app.dart';
import 'package:claimly/core/network/supabase_client.dart';
import 'package:claimly/core/theme/theme_provider.dart';
import 'package:claimly/features/auth/models/user_model.dart';
import 'package:claimly/features/auth/repositories/auth_repository.dart';
import 'package:claimly/features/customer/claims/models/claim_model.dart';
import 'package:claimly/features/customer/claims/models/claim_timeline_model.dart';
import 'package:claimly/features/customer/claims/repositories/claim_repository.dart';
import 'package:claimly/features/customer/notifications/models/notification_model.dart';
import 'package:claimly/features/customer/notifications/repositories/notification_repository.dart';
import 'package:claimly/features/customer/products/models/product_model.dart';
import 'package:claimly/features/customer/products/repositories/product_repository.dart';

// Mocks
class MockSupabaseClient extends Mock implements SupabaseClient {}
class MockGoTrueClient extends Mock implements GoTrueClient {}
class MockFunctionsClient extends Mock implements FunctionsClient {}
class MockStorageFileApi extends Mock implements StorageFileApi {}
class MockAuthRepository extends Mock implements AuthRepository {}
class MockProductRepository extends Mock implements ProductRepository {}
class MockClaimRepository extends Mock implements ClaimRepository {}
class MockNotificationRepository extends Mock implements NotificationRepository {}
class MockSession extends Mock implements Session {}
class MockUser extends Mock implements User {}

// Standard Fixtures for Integration Tests
final testCustomerProfile = UserProfile(
  id: 'usr-123-uuid',
  email: 'sarah.jenkins@claimly.com',
  fullName: 'Sarah Jenkins',
  phoneNumber: '+15551234567',
  role: UserRole.customer,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

final testProduct = ProductModel(
  id: 'prod-123-uuid',
  userId: 'usr-123-uuid',
  name: 'MacBook Pro 16" M3',
  category: 'Electronics',
  brand: 'Apple',
  modelNumber: 'A2991',
  serialNumber: 'C02XYZ123ABC',
  purchaseDate: DateTime.now().subtract(const Duration(days: 30)),
  warrantyPeriodMonths: 24,
  warrantyExpiryDate: DateTime.now().add(const Duration(days: 700)),
  retailer: 'Apple Store Fifth Ave',
  createdAt: DateTime.now().subtract(const Duration(days: 30)),
  updatedAt: DateTime.now().subtract(const Duration(days: 30)),
);

final testClaim = ClaimModel(
  id: 'claim-123-uuid',
  claimNumber: 'CLM-2026-0001',
  userId: 'usr-123-uuid',
  productId: 'prod-123-uuid',
  type: 'warranty',
  status: 'submitted',
  title: 'Display flickers violently',
  description: 'Horizontal black lines across screen',
  issueCategory: 'Hardware Defect',
  incidentDate: DateTime.now().subtract(const Duration(days: 2)),
  priority: 85,
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
  product: testProduct,
  timeline: [
    ClaimTimelineModel(
      id: 'tl-1',
      claimId: 'claim-123-uuid',
      toStatus: 'submitted',
      notes: 'Claim submitted by customer',
      createdAt: DateTime.now(),
    ),
  ],
);

final testNotification = NotificationModel(
  id: 'notif-1',
  userId: 'usr-123-uuid',
  title: 'Claim Update',
  message: 'Your claim CLM-2026-0001 has been received.',
  type: 'claim_update',
  isRead: false,
  createdAt: DateTime.now(),
);

class IntegrationTestHelper {
  static MockUser createMockUser({String id = 'usr-123-uuid', String role = 'customer'}) {
    final mockUser = MockUser();
    when(() => mockUser.id).thenReturn(id);
    when(() => mockUser.email).thenReturn('sarah.jenkins@claimly.com');
    when(() => mockUser.appMetadata).thenReturn({'role': role});
    when(() => mockUser.userMetadata).thenReturn({'role': role});
    return mockUser;
  }

  static MockSession createMockSession({MockUser? user}) {
    final mockSession = MockSession();
    final effectiveUser = user ?? createMockUser();
    when(() => mockSession.user).thenReturn(effectiveUser);
    when(() => mockSession.accessToken).thenReturn('fake-jwt-token');
    return mockSession;
  }

  static Future<void> pumpClaimlyApp(
    WidgetTester tester, {
    List<Override> additionalOverrides = const [],
    Session? initialSession,
    UserProfile? initialProfile,
    MockSupabaseClient? customSupabaseClient,
    MockGoTrueClient? customGoTrueClient,
    MockAuthRepository? customAuthRepo,
    MockProductRepository? customProductRepo,
    MockClaimRepository? customClaimRepo,
    MockNotificationRepository? customNotificationRepo,
  }) async {
    tester.view.physicalSize = const Size(1280, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    SharedPreferences.setMockInitialValues({'theme_mode': 'light'});
    final prefs = await SharedPreferences.getInstance();

    final mockSupabase = customSupabaseClient ?? MockSupabaseClient();
    final mockAuth = customGoTrueClient ?? MockGoTrueClient();
    when(() => mockSupabase.auth).thenReturn(mockAuth);

    if (customGoTrueClient == null) {
      final authStreamController = StreamController<AuthState>.broadcast();
      addTearDown(authStreamController.close);

      when(() => mockAuth.currentSession).thenReturn(initialSession);
      when(() => mockAuth.currentUser).thenReturn(initialSession?.user);
      when(() => mockAuth.onAuthStateChange).thenAnswer((_) => authStreamController.stream);
    }

    final authRepo = customAuthRepo ?? MockAuthRepository();
    if (customAuthRepo == null) {
      when(() => authRepo.getCurrentUserProfile()).thenAnswer((_) async => initialProfile);
    }

    final productRepo = customProductRepo ?? MockProductRepository();
    if (customProductRepo == null) {
      when(() => productRepo.getProducts(userId: any(named: 'userId'))).thenAnswer((_) async => []);
    }

    final claimRepo = customClaimRepo ?? MockClaimRepository();
    if (customClaimRepo == null) {
      when(() => claimRepo.fetchClaims(
            userId: any(named: 'userId'),
            statusTab: any(named: 'statusTab'),
          )).thenAnswer((_) async => []);
    }

    final notificationRepo = customNotificationRepo ?? MockNotificationRepository();
    if (customNotificationRepo == null) {
      when(() => notificationRepo.fetchNotifications(unreadOnly: any(named: 'unreadOnly')))
          .thenAnswer((_) async => []);
      when(() => notificationRepo.getUnreadCount(any())).thenAnswer((_) async => 0);
    }

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          supabaseClientProvider.overrideWithValue(mockSupabase),
          authRepositoryProvider.overrideWithValue(authRepo),
          productRepositoryProvider.overrideWithValue(productRepo),
          claimRepositoryProvider.overrideWithValue(claimRepo),
          notificationRepositoryProvider.overrideWithValue(notificationRepo),
          ...additionalOverrides,
        ],
        child: const ClaimlyApp(),
      ),
    );
  }
}
