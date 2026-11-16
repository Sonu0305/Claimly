import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:claimly/features/auth/controllers/auth_controller.dart';
import 'package:claimly/features/customer/dashboard/controllers/dashboard_controller.dart';
import 'package:claimly/features/customer/dashboard/screens/customer_dashboard_screen.dart';
import 'package:claimly/features/customer/products/controllers/products_controller.dart';
import 'package:claimly/features/customer/products/repositories/product_repository.dart';
import 'package:claimly/features/customer/products/screens/product_detail_screen.dart';
import 'package:claimly/features/customer/products/screens/product_form_screen.dart';
import 'package:claimly/features/customer/products/screens/products_list_screen.dart';
import 'package:claimly/features/customer/profile/controllers/profile_controller.dart';
import 'package:claimly/features/customer/profile/screens/profile_screen.dart';
import 'package:claimly/features/customer/notifications/controllers/notifications_controller.dart';
import 'package:claimly/features/customer/shell/customer_shell_screen.dart';
import '../test_helpers/mocks.dart';
import '../test_helpers/pump_app.dart';
import '../test_helpers/responsive_test_helper.dart';
import '../test_helpers/test_fixtures.dart';

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

  final testProduct = sampleProduct.copyWith(
    serialNumber: 'SN-9988-7766-LONG-SERIAL-123456789-US',
    retailer: 'Authorized Mega Retailer Online Store International',
  );

  setUpAll(() {
    registerCommonFallbackValues();
  });

  setUp(() {
    mockProductRepo = MockProductRepository();
    mockClaimRepo = MockClaimRepository();
    mockAuthRepo = MockAuthRepository();

    when(() => mockProductRepo.getProducts(userId: any(named: 'userId')))
        .thenAnswer((_) async => [testProduct]);
    when(() => mockClaimRepo.fetchClaims(userId: any(named: 'userId')))
        .thenAnswer((_) async => [sampleClaim]);
    when(() => mockProductRepo.getProductById(testProduct.id))
        .thenAnswer((_) async => testProduct);
  });

  GoRouter createRouter(String initialLocation) {
    return GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: '/customer/home',
          builder: (context, state) => const CustomerDashboardScreen(),
        ),
        GoRoute(
          path: '/customer/products',
          builder: (context, state) => const ProductsListScreen(),
        ),
        GoRoute(
          path: '/customer/products/new',
          builder: (context, state) => const ProductFormScreen(),
        ),
        GoRoute(
          path: '/customer/products/:id',
          builder: (context, state) => ProductDetailScreen(productId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/customer/profile',
          builder: (context, state) => const CustomerProfileScreen(),
        ),
      ],
    );
  }

  GoRouter createCustomerShellRouter(String initialLocation) {
    return GoRouter(
      initialLocation: initialLocation,
      routes: [
        ShellRoute(
          builder: (context, state, child) => CustomerShellScreen(child: child),
          routes: [
            GoRoute(
              path: '/customer/home',
              builder: (context, state) => const CustomerDashboardScreen(),
            ),
            GoRoute(
              path: '/customer/products',
              builder: (context, state) => const ProductsListScreen(),
            ),
          ],
        ),
      ],
    );
  }

  group('Customer Dashboard and Product Screens Responsive Tests', () {
    for (final breakpoint in ResponsiveBreakpoint.values) {
      testWidgets('CustomerDashboardScreen renders KPI cards without overflow at ${breakpoint.label}', (tester) async {
        await tester.setBreakpoint(breakpoint);

        await tester.pumpApp(
          const CustomerDashboardScreen(),
          router: createRouter('/customer/home'),
          overrides: [
            dashboardControllerProvider.overrideWith(
              (ref) => DashboardController(mockProductRepo, mockClaimRepo, 'usr-test'),
            ),
            authControllerProvider.overrideWith(
              (ref) => AuthController(mockAuthRepo)..state = AsyncData(sampleUserProfile),
            ),
          ],
        );
        await tester.pumpAndSettle();

        expectNoRenderFlexOverflow(tester);
        expect(find.text('Active Warranties'), findsOneWidget);
        expect(find.text('Pending Claims'), findsOneWidget);
        expect(find.text('Approved Claims'), findsOneWidget);
        expect(find.text('Expiring Soon'), findsOneWidget);
        expect(find.text('+ Add Product'), findsOneWidget);
        expect(find.text('File a Claim'), findsOneWidget);
      });

      testWidgets('ProductsListScreen renders filter chips and product grid/list without overflow at ${breakpoint.label}', (tester) async {
        await tester.setBreakpoint(breakpoint);

        await tester.pumpApp(
          const ProductsListScreen(),
          router: createRouter('/customer/products'),
          overrides: [
            productsControllerProvider.overrideWith(
              (ref) => ProductsController(mockProductRepo, 'usr-test'),
            ),
          ],
        );
        await tester.pumpAndSettle();

        expectNoRenderFlexOverflow(tester);
        expect(find.text('My Products'), findsOneWidget);
        expect(find.byKey(const Key('product_search_input')), findsOneWidget);
        expect(find.byKey(const Key('product_filter_chip')), findsOneWidget);
        expect(find.text(testProduct.name), findsOneWidget);
      });

      testWidgets('ProductDetailScreen renders specifications without overflow at ${breakpoint.label}', (tester) async {
        await tester.setBreakpoint(breakpoint);

        await tester.pumpApp(
          ProductDetailScreen(productId: testProduct.id),
          router: createRouter('/customer/products/${testProduct.id}'),
          overrides: [
            productRepositoryProvider.overrideWithValue(mockProductRepo),
            productsControllerProvider.overrideWith(
              (ref) => ProductsController(mockProductRepo, 'usr-test'),
            ),
          ],
        );
        await tester.pumpAndSettle();

        expectNoRenderFlexOverflow(tester);
        expect(find.text(testProduct.name), findsWidgets);
        expect(find.text('Specifications'), findsOneWidget);
        expect(find.text('File a Claim for this Product'), findsOneWidget);
      });

      testWidgets('ProductFormScreen renders input fields without overflow at ${breakpoint.label}', (tester) async {
        await tester.setBreakpoint(breakpoint);

        await tester.pumpApp(
          const ProductFormScreen(),
          router: createRouter('/customer/products/new'),
          overrides: [
            productsControllerProvider.overrideWith(
              (ref) => ProductsController(mockProductRepo, 'usr-test'),
            ),
          ],
        );
        await tester.pumpAndSettle();

        expectNoRenderFlexOverflow(tester);
        expect(find.byKey(const Key('product_name_input')), findsOneWidget);
        expect(find.byKey(const Key('product_category_dropdown')), findsOneWidget);
        expect(find.byKey(const Key('product_brand_input')), findsOneWidget);
        expect(find.byKey(const Key('product_model_input')), findsOneWidget);
        expect(find.byKey(const Key('product_purchase_date_input')), findsOneWidget);
        expect(find.byKey(const Key('product_warranty_months_input')), findsOneWidget);
        expect(find.byKey(const Key('product_save_btn')), findsOneWidget);
      });

      testWidgets('CustomerProfileScreen renders statistics and details without overflow at ${breakpoint.label}', (tester) async {
        await tester.setBreakpoint(breakpoint);

        await tester.pumpApp(
          const CustomerProfileScreen(),
          router: createRouter('/customer/profile'),
          overrides: [
            profileControllerProvider.overrideWith(
              (ref) => TestProfileController(
                const ProfileState(
                  fullName: 'Dr. Alexander Montgomery-Smith III',
                  email: 'alexander.montgomery.smith@multinational-enterprise-systems.org',
                  phoneNumber: '+1 (555) 019-2834',
                  totalProducts: 42,
                  activeWarranties: 28,
                  totalClaims: 14,
                ),
              ),
            ),
            authControllerProvider.overrideWith(
              (ref) => AuthController(mockAuthRepo)..state = AsyncData(sampleUserProfile),
            ),
          ],
        );
        await tester.pumpAndSettle();

        expectNoRenderFlexOverflow(tester);
        expect(find.text('Total Products'), findsOneWidget);
        expect(find.text('Active Warranties'), findsOneWidget);
        expect(find.text('Total Claims'), findsOneWidget);
        expect(find.text('Log Out of Account'), findsOneWidget);
      });
    }

    testWidgets('CustomerDashboardScreen renders cleanly at narrow mobile viewport (360x640) with 0px overflow', (tester) async {
      await tester.setViewport(const Size(360, 640));

      await tester.pumpApp(
        const CustomerDashboardScreen(),
        router: createRouter('/customer/home'),
        overrides: [
          dashboardControllerProvider.overrideWith(
            (ref) => DashboardController(mockProductRepo, mockClaimRepo, 'usr-test'),
          ),
          authControllerProvider.overrideWith(
            (ref) => AuthController(mockAuthRepo)..state = AsyncData(sampleUserProfile),
          ),
        ],
      );
      await tester.pumpAndSettle();

      expectNoRenderFlexOverflow(tester);
      expect(find.text('Active Warranties'), findsOneWidget);
      expect(find.text('Pending Claims'), findsOneWidget);
    });

    const boundarySizes = [
      ('Narrow Mobile (320x568)', Size(320, 568)),
      ('Mobile 360 (360x640)', Size(360, 640)),
      ('Tablet Boundary 600x800', Size(600, 800)),
      ('Tablet Boundary 600x960', Size(600, 960)),
      ('Desktop Boundary 1024x768', Size(1024, 768)),
      ('Desktop Boundary 1024x800', Size(1024, 800)),
    ];

    for (final (label, size) in boundarySizes) {
      testWidgets('CustomerDashboardScreen inside CustomerShellScreen renders without overflow at $label', (tester) async {
        await tester.setViewport(size);

        final router = createCustomerShellRouter('/customer/home');
        await tester.pumpApp(
          const SizedBox.shrink(),
          router: router,
          overrides: [
            dashboardControllerProvider.overrideWith(
              (ref) => DashboardController(mockProductRepo, mockClaimRepo, 'usr-test'),
            ),
            authControllerProvider.overrideWith(
              (ref) => AuthController(mockAuthRepo)..state = AsyncData(sampleUserProfile),
            ),
            unreadNotificationsCountProvider.overrideWith((ref) => 2),
          ],
        );
        await tester.pumpAndSettle();

        expectNoRenderFlexOverflow(tester);
        expect(find.text('Active Warranties'), findsOneWidget);
      });

      testWidgets('ProductsListScreen inside CustomerShellScreen renders without overflow at $label', (tester) async {
        await tester.setViewport(size);

        final router = createCustomerShellRouter('/customer/products');
        await tester.pumpApp(
          const SizedBox.shrink(),
          router: router,
          overrides: [
            productsControllerProvider.overrideWith(
              (ref) => ProductsController(mockProductRepo, 'usr-test'),
            ),
            unreadNotificationsCountProvider.overrideWith((ref) => 2),
          ],
        );
        await tester.pumpAndSettle();

        expectNoRenderFlexOverflow(tester);
        expect(find.text(testProduct.name), findsOneWidget);
      });
    }

    testWidgets('ProductDetailScreen renders without overflow under 1.5x accessibility text scale at 360x640', (tester) async {
      await tester.setViewport(const Size(360, 640));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            productRepositoryProvider.overrideWithValue(mockProductRepo),
            productsControllerProvider.overrideWith(
              (ref) => ProductsController(mockProductRepo, 'usr-test'),
            ),
          ],
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(1.5),
              ),
              child: child!,
            ),
            home: ProductDetailScreen(productId: testProduct.id),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expectNoRenderFlexOverflow(tester);
      expect(find.text('Specifications'), findsOneWidget);
      expect(find.text('Warranty Expiry'), findsOneWidget);
    });

    testWidgets('ProductFormScreen renders without overflow at narrow 320x568', (tester) async {
      await tester.setViewport(const Size(320, 568));

      await tester.pumpApp(
        const ProductFormScreen(),
        router: createRouter('/customer/products/new'),
        overrides: [
          productsControllerProvider.overrideWith(
            (ref) => ProductsController(mockProductRepo, 'usr-test'),
          ),
        ],
      );
      await tester.pumpAndSettle();

      expectNoRenderFlexOverflow(tester);
      expect(find.byKey(const Key('product_category_dropdown')), findsOneWidget);
    });
  });
}
