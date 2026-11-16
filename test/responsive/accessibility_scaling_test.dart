import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:claimly/features/auth/controllers/auth_controller.dart';
import 'package:claimly/features/auth/models/user_model.dart';
import 'package:claimly/features/customer/claims/claim_wizard/controllers/wizard_controller.dart';
import 'package:claimly/features/customer/claims/claim_wizard/steps/step_review_submit.dart';
import 'package:claimly/features/customer/products/controllers/products_controller.dart';
import 'package:claimly/features/customer/products/models/product_model.dart';
import 'package:claimly/features/customer/products/repositories/product_repository.dart';
import 'package:claimly/features/customer/products/screens/product_detail_screen.dart';
import 'package:claimly/features/customer/products/widgets/warranty_countdown_widget.dart';
import 'package:claimly/features/customer/profile/controllers/profile_controller.dart';
import 'package:claimly/features/customer/profile/screens/profile_screen.dart';
import '../test_helpers/mocks.dart';
import '../test_helpers/pump_app.dart';
import '../test_helpers/responsive_test_helper.dart';

class TestProfileController extends StateNotifier<ProfileState> implements ProfileController {
  TestProfileController(super.state);

  @override
  Future<void> loadProfile() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late MockProductRepository mockProductRepo;
  late MockClaimRepository mockClaimRepo;
  late MockAuthRepository mockAuthRepo;

  final sampleProduct = ProductModel(
    id: 'prod-001',
    userId: 'usr-customer-001',
    name: 'MacBook Pro 16" M3 Max Ultra Edition',
    category: 'Electronics & Computers',
    brand: 'Apple Computer Inc.',
    modelNumber: 'A2991-EXTENDED-SPEC',
    serialNumber: 'SN-9988-7766-LONG-SERIAL-123456789-US',
    purchaseDate: DateTime(2025, 6, 1),
    warrantyPeriodMonths: 24,
    warrantyExpiryDate: DateTime(2027, 6, 1),
    price: 3499.99,
    retailer: 'Authorized Mega Retailer Online Store International',
    notes: 'Extended AppleCare+ plan included with hardware defect protection.',
    createdAt: DateTime(2025, 6, 1),
    updatedAt: DateTime(2025, 6, 1),
  );

  final adminUserProfile = UserProfile(
    id: 'usr-admin-001',
    email: 'administrator.executive@claimly-enterprise.com',
    fullName: 'Alexander Morgan-Vanderbilt',
    role: UserRole.admin,
    createdAt: DateTime(2024, 1, 1),
    updatedAt: DateTime(2024, 1, 1),
  );

  setUpAll(() {
    registerCommonFallbackValues();
  });

  setUp(() {
    mockProductRepo = MockProductRepository();
    mockClaimRepo = MockClaimRepository();
    mockAuthRepo = MockAuthRepository();

    when(() => mockProductRepo.getProductById(sampleProduct.id))
        .thenAnswer((_) async => sampleProduct);
  });

  GoRouter createTestRouter(String initialLocation) {
    return GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: '/customer/products/:id',
          builder: (context, state) => ProductDetailScreen(productId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/customer/profile',
          builder: (context, state) => const CustomerProfileScreen(),
        ),
        GoRoute(
          path: '/admin/dashboard',
          builder: (context, state) => const Scaffold(body: Text('Admin Dashboard Portal')),
        ),
      ],
    );
  }

  const testViewports = [
    ('Narrow Mobile (320x568)', Size(320, 568)),
    ('Mobile 360 (360x640)', Size(360, 640)),
  ];

  const testScales = [
    ('1.5x', 1.5),
    ('2.0x', 2.0),
  ];

  group('Accessibility Text-Scaling RenderFlex Verification (1.5x & 2.0x)', () {
    for (final (vpName, vpSize) in testViewports) {
      for (final (scaleName, scaleValue) in testScales) {
        testWidgets(
          'StepReviewSubmit renders summary rows without overflow at $vpName under $scaleName text scale',
          (tester) async {
            await tester.setViewport(vpSize);

            final wizardController = ClaimWizardController(mockClaimRepo, 'usr-test', sampleProduct);
            wizardController.state = wizardController.state.copyWith(
              currentStep: 4,
              selectedProduct: sampleProduct,
              claimType: 'warranty',
              issueCategory: 'Hardware Component Defect',
              incidentDate: DateTime(2026, 1, 15),
              issueTitle: 'Display Panel Flickering and Vertical Artifacts',
              issueDescription: 'Continuous flickering screen when under heavy GPU load.',
              attachments: [],
            );

            await tester.pumpApp(
              SingleChildScrollView(
                child: StepReviewSubmit(initialProduct: sampleProduct),
              ),
              wrapScaffold: true,
              textScaler: TextScaler.linear(scaleValue),
              overrides: [
                claimWizardControllerProvider(sampleProduct).overrideWith((ref) => wizardController),
              ],
            );
            await tester.pumpAndSettle();

            expectNoRenderFlexOverflow(tester);
            expect(find.text('Review Claim & Triage Assessment'), findsOneWidget);
            expect(find.text('Submit Official Claim'), findsOneWidget);
          },
        );

        testWidgets(
          'WarrantyCountdownWidget renders without overflow at $vpName under $scaleName text scale',
          (tester) async {
            await tester.setViewport(vpSize);

            await tester.pumpApp(
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: WarrantyCountdownWidget(product: sampleProduct),
              ),
              wrapScaffold: true,
              textScaler: TextScaler.linear(scaleValue),
            );
            await tester.pumpAndSettle();

            expectNoRenderFlexOverflow(tester);
            expect(find.textContaining('Days Left'), findsOneWidget);
          },
        );

        testWidgets(
          'ProductDetailScreen overview & specs render without overflow at $vpName under $scaleName text scale',
          (tester) async {
            await tester.setViewport(vpSize);

            await tester.pumpApp(
              ProductDetailScreen(productId: sampleProduct.id),
              router: createTestRouter('/customer/products/${sampleProduct.id}'),
              textScaler: TextScaler.linear(scaleValue),
              overrides: [
                productRepositoryProvider.overrideWithValue(mockProductRepo),
                productsControllerProvider.overrideWith(
                  (ref) => ProductsController(mockProductRepo, 'usr-test'),
                ),
              ],
            );
            await tester.pumpAndSettle();

            expectNoRenderFlexOverflow(tester);
            expect(find.text(sampleProduct.name), findsWidgets);
            expect(find.text('Specifications'), findsOneWidget);
            expect(find.text('File a Claim for this Product'), findsOneWidget);
          },
        );

        testWidgets(
          'CustomerProfileScreen with Administrator Mode renders without overflow at $vpName under $scaleName text scale',
          (tester) async {
            await tester.setViewport(vpSize);

            final authController = AuthController(mockAuthRepo)..state = AsyncData(adminUserProfile);
            final profileState = ProfileState(
              fullName: adminUserProfile.fullName,
              email: adminUserProfile.email,
              role: 'admin',
              totalProducts: 12,
              activeWarranties: 8,
              totalClaims: 3,
            );

            await tester.pumpApp(
              const CustomerProfileScreen(),
              router: createTestRouter('/customer/profile'),
              textScaler: TextScaler.linear(scaleValue),
              overrides: [
                authControllerProvider.overrideWith((ref) => authController),
                profileControllerProvider.overrideWith((ref) => TestProfileController(profileState)),
              ],
            );
            await tester.pumpAndSettle();

            expectNoRenderFlexOverflow(tester);
            expect(find.text('Administrator Mode'), findsOneWidget);
            expect(find.text('Open Portal'), findsOneWidget);
            expect(find.text('Log Out of Account'), findsOneWidget);
          },
        );
      }
    }
  });
}
