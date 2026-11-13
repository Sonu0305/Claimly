import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'helpers/integration_test_helper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(testProduct);
    registerFallbackValue(<String, dynamic>{});
  });

  testWidgets(
    'Claim Filing Flow: Dashboard -> File Claim -> 5-Step Claim Wizard Progression -> Summary / Detail Screen',
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
      when(() => mockProductRepo.getProducts(userId: any(named: 'userId')))
          .thenAnswer((_) async => [testProduct]);
      when(() => mockClaimRepo.fetchClaims(
            userId: any(named: 'userId'),
            statusTab: any(named: 'statusTab'),
          )).thenAnswer((_) async => []);
      when(() => mockNotificationRepo.fetchNotifications(unreadOnly: any(named: 'unreadOnly')))
          .thenAnswer((_) async => []);
      when(() => mockNotificationRepo.getUnreadCount(any())).thenAnswer((_) async => 0);

      when(() => mockClaimRepo.validateClaim(any())).thenAnswer((_) async => {
            'priority_score': 85,
            'warranty_valid': true,
            'warranty_status': 'active',
            'score_breakdown': {'base': 40, 'urgency': 25, 'completeness': 20},
          });
      when(() => mockClaimRepo.submitClaim(any())).thenAnswer((_) async => {
            'claim_id': testClaim.id,
            'status': 'submitted',
          });
      when(() => mockClaimRepo.getClaimDetail(testClaim.id)).thenAnswer((_) async => testClaim);

      // 1. Boot app with authenticated user having 1 registered product
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

      // Advance through splash to Customer Dashboard
      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pumpAndSettle();

      // 2. Tap 'File a Claim' quick action button
      await tester.tap(find.text('File a Claim').first);
      await tester.pumpAndSettle();

      // Verify on ClaimWizardScreen (Step 1/5)
      expect(find.byKey(const Key('wizard_cancel_btn')), findsOneWidget);
      expect(find.text('Select Product for Claim'), findsOneWidget);

      // 3. Step 1: Select registered product
      await tester.tap(find.byKey(const Key('wizard_product_selector')));
      await tester.pumpAndSettle();

      // Advance to Step 2
      await tester.tap(find.byKey(const Key('wizard_next_btn')));
      await tester.pumpAndSettle();

      // 4. Step 2: Select Claim Type
      expect(find.text('Select Claim Type'), findsOneWidget);
      await tester.tap(find.byKey(const Key('wizard_claim_type_card_warranty')));
      await tester.pumpAndSettle();

      // Advance to Step 3
      await tester.tap(find.byKey(const Key('wizard_next_btn')));
      await tester.pumpAndSettle();

      // 5. Step 3: Enter Issue Details
      expect(find.byKey(const Key('wizard_issue_title_input')), findsOneWidget);
      await tester.enterText(find.byKey(const Key('wizard_issue_title_input')), 'Display flickers violently');
      await tester.enterText(find.byKey(const Key('wizard_issue_desc_input')), 'Horizontal black lines across screen');
      await tester.pumpAndSettle();

      // Advance to Step 4
      await tester.tap(find.byKey(const Key('wizard_next_btn')));
      await tester.pumpAndSettle();

      // 6. Step 4: Attachments (optional, advance to Step 5)
      expect(find.byKey(const Key('wizard_next_btn')), findsOneWidget);
      await tester.tap(find.byKey(const Key('wizard_next_btn')));
      await tester.pumpAndSettle();

      // 7. Step 5: Review & Submit
      expect(find.text('Review Claim & Triage Assessment'), findsOneWidget);
      expect(find.textContaining('MacBook Pro 16" M3'), findsWidgets);
      expect(find.textContaining('Display flickers violently'), findsWidgets);
      expect(find.byKey(const Key('wizard_submit_btn')), findsOneWidget);

      // Submit Official Claim
      await tester.tap(find.byKey(const Key('wizard_submit_btn')));
      await tester.pumpAndSettle();

      // 8. Verify transition to ClaimDetailScreen
      expect(find.text('CLM-2026-0001'), findsWidgets);
      expect(find.text('Display flickers violently'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('claim_status_badge')),
          matching: find.text('Submitted'),
        ),
        findsOneWidget,
      );
    },
  );
}

