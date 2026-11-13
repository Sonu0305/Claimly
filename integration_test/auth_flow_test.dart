import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:claimly/core/constants/app_constants.dart';
import 'helpers/integration_test_helper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Complete Auth Flow: Boot -> Splash -> Login -> Validation Errors -> Authenticated Session -> Customer Dashboard',
    (tester) async {
      final mockSupabase = MockSupabaseClient();
      final mockAuth = MockGoTrueClient();
      final mockAuthRepo = MockAuthRepository();
      final mockProductRepo = MockProductRepository();
      final mockClaimRepo = MockClaimRepository();
      final mockNotificationRepo = MockNotificationRepository();

      // Start with unauthenticated state
      Session? currentSession;
      final authStreamController = StreamController<AuthState>.broadcast();
      addTearDown(authStreamController.close);

      when(() => mockSupabase.auth).thenReturn(mockAuth);
      when(() => mockAuth.currentSession).thenAnswer((_) => currentSession);
      when(() => mockAuth.currentUser).thenAnswer((_) => currentSession?.user);
      when(() => mockAuth.onAuthStateChange).thenAnswer((_) => authStreamController.stream);

      when(() => mockAuthRepo.getCurrentUserProfile()).thenAnswer((_) async => null);
      when(() => mockProductRepo.getProducts(userId: any(named: 'userId'))).thenAnswer((_) async => []);
      when(() => mockClaimRepo.fetchClaims(
            userId: any(named: 'userId'),
            statusTab: any(named: 'statusTab'),
          )).thenAnswer((_) async => []);
      when(() => mockNotificationRepo.fetchNotifications(unreadOnly: any(named: 'unreadOnly')))
          .thenAnswer((_) async => []);
      when(() => mockNotificationRepo.getUnreadCount(any())).thenAnswer((_) async => 0);

      // 1. Boot app to Splash Screen
      await IntegrationTestHelper.pumpClaimlyApp(
        tester,
        customSupabaseClient: mockSupabase,
        customGoTrueClient: mockAuth,
        customAuthRepo: mockAuthRepo,
        customProductRepo: mockProductRepo,
        customClaimRepo: mockClaimRepo,
        customNotificationRepo: mockNotificationRepo,
      );

      // Verify splash elements
      expect(find.byIcon(Icons.shield_outlined), findsOneWidget);
      expect(find.text(AppConstants.appName), findsOneWidget);
      expect(find.text(AppConstants.appTagline), findsOneWidget);

      // 2. Advance time past splash delay (1500ms) to trigger navigation to /login
      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pumpAndSettle();

      // Verify Login Screen rendered
      expect(find.byKey(const Key('auth_email_input')), findsOneWidget);
      expect(find.byKey(const Key('auth_password_input')), findsOneWidget);
      expect(find.byKey(const Key('auth_login_submit_btn')), findsOneWidget);
      expect(find.byKey(const Key('auth_forgot_password_btn')), findsOneWidget);

      // 3. Test validation errors on empty submission
      await tester.tap(find.byKey(const Key('auth_login_submit_btn')));
      await tester.pumpAndSettle();

      expect(find.text('Email is required'), findsOneWidget);
      expect(find.text('Password is required'), findsOneWidget);

      // 4. Test validation on malformed email and short password
      await tester.enterText(find.byKey(const Key('auth_email_input')), 'bademail');
      await tester.enterText(find.byKey(const Key('auth_password_input')), '123');
      await tester.tap(find.byKey(const Key('auth_login_submit_btn')));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a valid email address'), findsOneWidget);
      expect(find.text('Password must be at least 6 characters'), findsOneWidget);

      // 5. Setup successful login mock
      final mockUser = IntegrationTestHelper.createMockUser(
        id: testCustomerProfile.id,
        role: 'customer',
      );
      final loggedInSession = IntegrationTestHelper.createMockSession(user: mockUser);

      when(() => mockAuthRepo.signInWithEmailAndPassword(
            email: 'sarah.jenkins@claimly.com',
            password: 'SecureP@ss2026!',
          )).thenAnswer((_) async {
        currentSession = loggedInSession;
        authStreamController.add(AuthState(AuthChangeEvent.signedIn, loggedInSession));
        return testCustomerProfile;
      });
      when(() => mockAuthRepo.getCurrentUserProfile()).thenAnswer((_) async => testCustomerProfile);

      // 6. Enter valid credentials and submit
      await tester.enterText(find.byKey(const Key('auth_email_input')), 'sarah.jenkins@claimly.com');
      await tester.enterText(find.byKey(const Key('auth_password_input')), 'SecureP@ss2026!');
      await tester.tap(find.byKey(const Key('auth_login_submit_btn')));
      await tester.pumpAndSettle();

      // 7. Verify navigation to Customer Dashboard
      expect(find.text('Claimly Dashboard'), findsOneWidget);
      expect(find.textContaining('Sarah Jenkins'), findsOneWidget);
      expect(find.text('Active Warranties'), findsOneWidget);
      expect(find.text('Pending Claims'), findsOneWidget);
      expect(find.text('Approved Claims'), findsOneWidget);
      expect(find.text('Expiring Soon'), findsOneWidget);
      expect(find.text('+ Add Product'), findsOneWidget);
      expect(find.text('File a Claim'), findsWidgets);

      // Verify bottom navigation
      expect(find.byKey(const Key('nav_item_home')), findsOneWidget);
      expect(find.byKey(const Key('nav_item_products')), findsOneWidget);
      expect(find.byKey(const Key('nav_item_claims')), findsOneWidget);
      expect(find.byKey(const Key('nav_item_notifications')), findsOneWidget);
      expect(find.byKey(const Key('nav_item_profile')), findsOneWidget);
    },
  );
}
