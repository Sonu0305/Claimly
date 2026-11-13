import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:claimly/features/customer/products/models/product_model.dart';
import 'helpers/integration_test_helper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(testProduct);
  });

  testWidgets(
    'Product CRUD Flow: Dashboard -> Products List -> Add Product Form -> Validation -> Submit -> Product Card Rendered',
    (tester) async {
      final mockSupabase = MockSupabaseClient();
      final mockAuth = MockGoTrueClient();
      final mockAuthRepo = MockAuthRepository();
      final mockProductRepo = MockProductRepository();
      final mockClaimRepo = MockClaimRepository();
      final mockNotificationRepo = MockNotificationRepository();

      final mockUser = IntegrationTestHelper.createMockUser(
        id: testCustomerProfile.id,
        role: 'customer',
      );
      final loggedInSession = IntegrationTestHelper.createMockSession(user: mockUser);
      final authStreamController = StreamController<AuthState>.broadcast();
      addTearDown(authStreamController.close);

      when(() => mockSupabase.auth).thenReturn(mockAuth);
      when(() => mockAuth.currentSession).thenReturn(loggedInSession);
      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockAuth.onAuthStateChange).thenAnswer((_) => authStreamController.stream);

      when(() => mockAuthRepo.getCurrentUserProfile()).thenAnswer((_) async => testCustomerProfile);
      when(() => mockProductRepo.getProducts(userId: any(named: 'userId'))).thenAnswer((_) async => []);
      when(() => mockClaimRepo.fetchClaims(
            userId: any(named: 'userId'),
            statusTab: any(named: 'statusTab'),
          )).thenAnswer((_) async => []);
      when(() => mockNotificationRepo.fetchNotifications(unreadOnly: any(named: 'unreadOnly')))
          .thenAnswer((_) async => []);
      when(() => mockNotificationRepo.getUnreadCount(any())).thenAnswer((_) async => 0);

      when(() => mockProductRepo.createProduct(any())).thenAnswer((invocation) async {
        final p = invocation.positionalArguments.first as ProductModel;
        return ProductModel(
          id: 'prod-new-123',
          userId: p.userId,
          name: p.name,
          category: p.category,
          brand: p.brand,
          modelNumber: p.modelNumber,
          serialNumber: p.serialNumber,
          purchaseDate: p.purchaseDate,
          warrantyPeriodMonths: p.warrantyPeriodMonths,
          warrantyExpiryDate: p.warrantyExpiryDate,
          retailer: p.retailer,
          notes: p.notes,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      });

      // 1. Boot app with authenticated session
      await IntegrationTestHelper.pumpClaimlyApp(
        tester,
        initialSession: loggedInSession,
        initialProfile: testCustomerProfile,
        customSupabaseClient: mockSupabase,
        customGoTrueClient: mockAuth,
        customAuthRepo: mockAuthRepo,
        customProductRepo: mockProductRepo,
        customClaimRepo: mockClaimRepo,
        customNotificationRepo: mockNotificationRepo,
      );

      // Advance through splash to Dashboard
      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pumpAndSettle();

      // Verify on Customer Dashboard
      expect(find.byKey(const Key('nav_item_products')), findsOneWidget);

      // 2. Navigate to Products List screen via Bottom Navigation
      await tester.tap(find.byKey(const Key('nav_item_products')));
      await tester.pumpAndSettle();

      // Verify Products List elements
      expect(find.byKey(const Key('product_search_input')), findsOneWidget);
      expect(find.byKey(const Key('product_add_fab')), findsOneWidget);

      // 3. Tap Add Product FAB to open ProductFormScreen
      await tester.tap(find.byKey(const Key('product_add_fab')));
      await tester.pumpAndSettle();

      // Verify Product Form elements
      expect(find.byKey(const Key('product_name_input')), findsOneWidget);
      expect(find.byKey(const Key('product_save_btn')), findsOneWidget);

      // 4. Test validation: Submit empty form and assert required field error
      await tester.tap(find.byKey(const Key('product_save_btn')));
      await tester.pumpAndSettle();

      expect(find.text('This field is required'), findsOneWidget);

      // 5. Enter complete product details
      await tester.enterText(find.byKey(const Key('product_name_input')), 'MacBook Pro 16" M3');
      await tester.enterText(find.byKey(const Key('product_brand_input')), 'Apple');
      await tester.enterText(find.byKey(const Key('product_model_input')), 'A2991');
      await tester.enterText(find.byKey(const Key('product_serial_input')), 'C02XYZ123ABC');
      await tester.enterText(find.byKey(const Key('product_warranty_months_input')), '24');
      await tester.enterText(find.byKey(const Key('product_retailer_input')), 'Apple Store Fifth Ave');
      await tester.pumpAndSettle();

      // 6. Submit the form
      await tester.tap(find.byKey(const Key('product_save_btn')));
      await tester.pumpAndSettle();

      // 7. Verify navigation back to Products List and presence of the new product card
      expect(find.byKey(const Key('product_search_input')), findsOneWidget);
      expect(find.text('MacBook Pro 16" M3'), findsOneWidget);
      expect(find.textContaining('Apple'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('product_status_badge')),
          matching: find.text('Active'),
        ),
        findsOneWidget,
      );
    },
  );
}

