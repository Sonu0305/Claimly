import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:claimly/features/auth/controllers/auth_controller.dart';
import 'package:claimly/features/admin/claims_review/controllers/admin_claims_controller.dart';
import 'package:claimly/features/admin/claims_review/screens/admin_claims_screen.dart';
import 'package:claimly/features/admin/shell/admin_shell_screen.dart';
import 'package:claimly/features/admin/users/controllers/admin_users_controller.dart';
import 'package:claimly/features/admin/users/models/admin_user_model.dart';
import 'package:claimly/features/admin/users/screens/admin_users_screen.dart';
import 'package:claimly/features/customer/claims/claim_wizard/controllers/wizard_controller.dart';
import 'package:claimly/features/customer/claims/claim_wizard/screens/claim_wizard_screen.dart';
import 'package:claimly/features/customer/claims/controllers/claim_detail_controller.dart';
import 'package:claimly/features/customer/claims/controllers/claims_controller.dart';
import 'package:claimly/features/customer/claims/models/claim_model.dart';
import 'package:claimly/features/customer/claims/repositories/claim_repository.dart';
import 'package:claimly/features/customer/claims/screens/claim_detail_screen.dart';
import 'package:claimly/features/customer/claims/screens/claims_list_screen.dart';
import 'package:claimly/features/customer/notifications/controllers/notifications_controller.dart';
import 'package:claimly/features/customer/products/controllers/products_controller.dart';
import 'package:claimly/features/customer/products/repositories/product_repository.dart';
import 'package:claimly/features/customer/shell/customer_shell_screen.dart';

import '../test_helpers/mocks.dart';
import '../test_helpers/pump_app.dart';
import '../test_helpers/responsive_test_helper.dart';
import '../test_helpers/test_fixtures.dart';

void main() {
  late MockClaimRepository mockClaimRepo;
  late MockProductRepository mockProductRepo;
  late MockSupabaseClient mockSupabase;
  late MockAuthRepository mockAuthRepo;

  final sampleAdminClaimItem = AdminClaimItem(
    id: 'clm-001',
    claimNumber: 'CLM-2026-0001',
    userId: 'usr-customer-001',
    productId: 'prod-001',
    type: 'warranty',
    status: 'submitted',
    title: 'Display flicker and artifacts',
    description: 'Screen randomly glitches with vertical colored lines.',
    priority: 85,
    createdAt: DateTime(2026, 1, 10, 14, 0, 0),
    customerName: 'Sarah Jenkins',
    productName: 'MacBook Pro 16" M3',
    productCategory: 'Electronics',
  );

  final testAdminUser = AdminUserModel(
    id: 'usr-customer-001',
    role: 'customer',
    fullName: 'Sarah Jenkins',
    avatarUrl: null,
    phoneNumber: '+15551234567',
    createdAt: DateTime(2025, 1, 15, 10, 0, 0),
    productCount: 3,
    claimCount: 1,
  );

  setUpAll(() {
    registerCommonFallbackValues();
  });

  setUp(() {
    mockClaimRepo = MockClaimRepository();
    mockProductRepo = MockProductRepository();
    mockSupabase = MockSupabaseClient();
    mockAuthRepo = MockAuthRepository();

    when(() => mockClaimRepo.fetchClaims(
          userId: any(named: 'userId'),
          statusTab: any(named: 'statusTab'),
        )).thenAnswer((_) async => [sampleClaim]);

    when(() => mockClaimRepo.getClaimDetail(any()))
        .thenAnswer((_) async => sampleClaim);

    when(() => mockProductRepo.getProducts(userId: any(named: 'userId')))
        .thenAnswer((_) async => [sampleProduct]);

    when(() => mockProductRepo.getProductById(any()))
        .thenAnswer((_) async => sampleProduct);
  });

  Widget buildClaimsListHarness() {
    return const ClaimsListScreen();
  }

  Widget buildClaimDetailHarness() {
    return ClaimDetailScreen(claimId: sampleClaim.id);
  }

  Widget buildClaimWizardHarness({int initialStep = 0}) {
    return ClaimWizardScreen(initialProductId: sampleProduct.id);
  }

  GoRouter createCustomerClaimsShellRouter(String initialLocation) {
    return GoRouter(
      initialLocation: initialLocation,
      routes: [
        ShellRoute(
          builder: (context, state, child) => CustomerShellScreen(child: child),
          routes: [
            GoRoute(
              path: '/customer/claims',
              builder: (context, state) => const ClaimsListScreen(),
            ),
          ],
        ),
      ],
    );
  }

  GoRouter createAdminClaimsShellRouter(String initialLocation) {
    return GoRouter(
      initialLocation: initialLocation,
      routes: [
        ShellRoute(
          builder: (context, state, child) => AdminShellScreen(child: child),
          routes: [
            GoRoute(
              path: '/admin/claims',
              builder: (context, state) => const AdminClaimsScreen(),
            ),
            GoRoute(
              path: '/admin/users',
              builder: (context, state) => const AdminUsersScreen(),
            ),
          ],
        ),
      ],
    );
  }

  group('Claims and Wizard Screens Responsive Tests', () {
    for (final breakpoint in ResponsiveBreakpoint.values) {
      testWidgets('ClaimsListScreen renders claims without overflow at ${breakpoint.label}', (tester) async {
        await tester.setBreakpoint(breakpoint);

        final secondClaim = ClaimModel(
          id: 'clm-002',
          claimNumber: 'CLM-2026-0002',
          userId: 'usr-customer-001',
          productId: 'prod-001',
          type: 'warranty',
          status: 'pending',
          title: 'Battery drain issue',
          description: 'Battery drains in 2 hours.',
          incidentDate: DateTime(2026, 1, 9),
          priority: 50,
          createdAt: DateTime(2026, 1, 11),
          updatedAt: DateTime(2026, 1, 11),
          product: sampleProduct,
        );

        final claimsController = ClaimsController(mockClaimRepo, 'usr-test');
        claimsController.state = ClaimsState(
          claims: [sampleClaim, secondClaim],
          isLoading: false,
        );

        await tester.pumpApp(
          buildClaimsListHarness(),
          overrides: [
            claimRepositoryProvider.overrideWith((ref) => mockClaimRepo),
            claimsControllerProvider.overrideWith((ref) => claimsController),
          ],
        );
        await tester.pumpAndSettle();

        expectNoRenderFlexOverflow(tester);
        expect(find.byType(ClaimsListScreen), findsOneWidget);
        expect(find.text('CLM-2026-0001'), findsOneWidget);
      });

      testWidgets('ClaimDetailScreen renders details without overflow at ${breakpoint.label}', (tester) async {
        await tester.setBreakpoint(breakpoint);

        await tester.pumpApp(
          buildClaimDetailHarness(),
          overrides: [
            claimRepositoryProvider.overrideWith((ref) => mockClaimRepo),
            claimDetailControllerProvider(sampleClaim.id).overrideWith(
              (ref) => ClaimDetailController(mockClaimRepo, sampleClaim.id),
            ),
          ],
        );
        await tester.pumpAndSettle();

        expectNoRenderFlexOverflow(tester);
        expect(find.byType(ClaimDetailScreen), findsOneWidget);
        expect(find.text('CLM-2026-0001'), findsWidgets);
      });

      testWidgets('ClaimWizardScreen Step 1 renders without overflow at ${breakpoint.label}', (tester) async {
        await tester.setBreakpoint(breakpoint);

        final prodController = ProductsController(mockProductRepo, 'usr-test');
        prodController.state = prodController.state.copyWith(
          products: [sampleProduct],
          isLoading: false,
        );

        await tester.pumpApp(
          buildClaimWizardHarness(),
          overrides: [
            claimRepositoryProvider.overrideWith((ref) => mockClaimRepo),
            productRepositoryProvider.overrideWith((ref) => mockProductRepo),
            productsControllerProvider.overrideWith((ref) => prodController),
          ],
        );
        await tester.pumpAndSettle();

        expectNoRenderFlexOverflow(tester);
        expect(find.byType(ClaimWizardScreen), findsOneWidget);
        expect(find.text('File New Claim (1/5)'), findsOneWidget);
      });
    }

    testWidgets('ClaimWizardScreen advances through steps without overflow at Mobile (390x844)', (tester) async {
      await tester.setBreakpoint(ResponsiveBreakpoint.mobile);

      final prodController = ProductsController(mockProductRepo, 'usr-test');
      prodController.state = prodController.state.copyWith(
        products: [sampleProduct],
        isLoading: false,
      );

      final wizardController = ClaimWizardController(mockClaimRepo, 'usr-test', sampleProduct);
      wizardController.state = wizardController.state.copyWith(
        currentStep: 4, // Review & Submit step
        selectedProduct: sampleProduct,
        claimType: 'warranty',
        issueTitle: 'Display flicker and very long issue title testing responsiveness',
        issueDescription: 'Screen randomly glitches with vertical colored lines and cannot render properly.',
        issueCategory: 'Hardware Defect',
        incidentDate: DateTime(2026, 1, 8),
      );

      await tester.pumpApp(
        ClaimWizardScreen(initialProductId: sampleProduct.id),
        overrides: [
          claimRepositoryProvider.overrideWith((ref) => mockClaimRepo),
          productRepositoryProvider.overrideWith((ref) => mockProductRepo),
          productsControllerProvider.overrideWith((ref) => prodController),
          claimWizardControllerProvider(sampleProduct).overrideWith((ref) => wizardController),
        ],
      );
      await tester.pumpAndSettle();

      expectNoRenderFlexOverflow(tester);
      expect(find.text('File New Claim (5/5)'), findsOneWidget);
      expect(find.text('Review Claim & Triage Assessment'), findsOneWidget);
    });

    testWidgets('Claims screens render cleanly at narrow mobile viewport (360x640) with 0px overflow', (tester) async {
      await tester.setViewport(const Size(360, 640));

      final claimsController = ClaimsController(mockClaimRepo, 'usr-test');
      claimsController.state = ClaimsState(
        claims: [sampleClaim],
        isLoading: false,
      );

      await tester.pumpApp(
        buildClaimsListHarness(),
        overrides: [
          claimRepositoryProvider.overrideWith((ref) => mockClaimRepo),
          claimsControllerProvider.overrideWith((ref) => claimsController),
        ],
      );
      await tester.pumpAndSettle();

      expectNoRenderFlexOverflow(tester);
      expect(find.byType(ClaimsListScreen), findsOneWidget);
    });

    const customerBoundarySizes = [
      ('Narrow Mobile (320x568)', Size(320, 568)),
      ('Mobile 360 (360x640)', Size(360, 640)),
      ('Tablet Boundary 600x800', Size(600, 800)),
      ('Tablet Boundary 600x960', Size(600, 960)),
      ('Desktop Boundary 1024x768', Size(1024, 768)),
      ('Desktop Boundary 1024x800', Size(1024, 800)),
    ];

    for (final (label, size) in customerBoundarySizes) {
      testWidgets('ClaimsListScreen inside CustomerShellScreen renders without overflow at $label', (tester) async {
        await tester.setViewport(size);

        final claimsController = ClaimsController(mockClaimRepo, 'usr-test');
        claimsController.state = ClaimsState(
          claims: [sampleClaim],
          isLoading: false,
        );

        final router = createCustomerClaimsShellRouter('/customer/claims');
        await tester.pumpApp(
          const SizedBox.shrink(),
          router: router,
          overrides: [
            claimRepositoryProvider.overrideWith((ref) => mockClaimRepo),
            claimsControllerProvider.overrideWith((ref) => claimsController),
            unreadNotificationsCountProvider.overrideWith((ref) => 2),
          ],
        );
        await tester.pumpAndSettle();

        expectNoRenderFlexOverflow(tester);
        expect(find.byType(ClaimsListScreen), findsOneWidget);
        expect(find.text('CLM-2026-0001'), findsOneWidget);
      });
    }

    const adminBoundarySizes = [
      ('Tablet Boundary 600x800', Size(600, 800)),
      ('Tablet Boundary 600x960', Size(600, 960)),
      ('Desktop Boundary 1024x768', Size(1024, 768)),
      ('Desktop Boundary 1024x800', Size(1024, 800)),
    ];

    for (final (label, size) in adminBoundarySizes) {
      testWidgets('AdminClaimsScreen inside AdminShellScreen renders without overflow at $label', (tester) async {
        await tester.setViewport(size);

        final router = createAdminClaimsShellRouter('/admin/claims');
        await tester.pumpApp(
          const SizedBox.shrink(),
          router: router,
          overrides: [
            authControllerProvider.overrideWith(
              (ref) => AuthController(mockAuthRepo)..state = AsyncData(sampleAdminProfile),
            ),
            adminClaimsControllerProvider.overrideWith(
              (ref) => AdminClaimsController(mockSupabase)
                ..state = AdminClaimsState(claims: [sampleAdminClaimItem], isLoading: false),
            ),
          ],
        );
        await tester.pumpAndSettle();

        expectNoRenderFlexOverflow(tester);
        expect(find.byType(AdminClaimsScreen), findsOneWidget);
        expect(find.text('CLM-2026-0001'), findsOneWidget);
      });

      testWidgets('AdminUsersScreen inside AdminShellScreen renders without overflow at $label', (tester) async {
        await tester.setViewport(size);

        final router = createAdminClaimsShellRouter('/admin/users');
        await tester.pumpApp(
          const SizedBox.shrink(),
          router: router,
          overrides: [
            authControllerProvider.overrideWith(
              (ref) => AuthController(mockAuthRepo)..state = AsyncData(sampleAdminProfile),
            ),
            adminUsersControllerProvider.overrideWith(
              (ref) => AdminUsersController(mockSupabase)
                ..state = AdminUsersState(users: [testAdminUser], isLoading: false),
            ),
          ],
        );
        await tester.pumpAndSettle();

        expectNoRenderFlexOverflow(tester);
        expect(find.byType(AdminUsersScreen), findsOneWidget);
        expect(find.text('Sarah Jenkins'), findsOneWidget);
      });
    }

    testWidgets('ClaimWizardScreen Step 5 renders without overflow at narrow mobile (320x568)', (tester) async {
      await tester.setViewport(const Size(320, 568));

      final prodController = ProductsController(mockProductRepo, 'usr-test');
      prodController.state = prodController.state.copyWith(
        products: [sampleProduct],
        isLoading: false,
      );

      final wizardController = ClaimWizardController(mockClaimRepo, 'usr-test', sampleProduct);
      wizardController.state = wizardController.state.copyWith(
        currentStep: 4, // Review & Submit step
        selectedProduct: sampleProduct,
        claimType: 'warranty',
        issueTitle: 'Display flicker and very long issue title testing responsiveness',
        issueDescription: 'Screen randomly glitches with vertical colored lines and cannot render properly.',
        issueCategory: 'Hardware Defect',
        incidentDate: DateTime(2026, 1, 8),
      );

      await tester.pumpApp(
        ClaimWizardScreen(initialProductId: sampleProduct.id),
        overrides: [
          claimRepositoryProvider.overrideWith((ref) => mockClaimRepo),
          productRepositoryProvider.overrideWith((ref) => mockProductRepo),
          productsControllerProvider.overrideWith((ref) => prodController),
          claimWizardControllerProvider(sampleProduct).overrideWith((ref) => wizardController),
        ],
      );
      await tester.pumpAndSettle();

      expectNoRenderFlexOverflow(tester);
      expect(find.text('File New Claim (5/5)'), findsOneWidget);
      expect(find.text('Review Claim & Triage Assessment'), findsOneWidget);
    });
  });
}
