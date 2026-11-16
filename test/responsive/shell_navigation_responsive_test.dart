import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:claimly/core/router/route_constants.dart';
import 'package:claimly/features/auth/controllers/auth_controller.dart';
import 'package:claimly/features/admin/shell/admin_shell_screen.dart';
import 'package:claimly/features/customer/notifications/controllers/notifications_controller.dart';
import 'package:claimly/features/customer/shell/customer_shell_screen.dart';

import '../test_helpers/mocks.dart';
import '../test_helpers/pump_app.dart';
import '../test_helpers/responsive_test_helper.dart';
import '../test_helpers/test_fixtures.dart';

void main() {
  late MockAuthRepository mockAuthRepo;

  setUpAll(() {
    registerCommonFallbackValues();
  });

  setUp(() {
    mockAuthRepo = MockAuthRepository();
  });
  GoRouter createCustomerShellRouter() {
    return GoRouter(
      initialLocation: RouteConstants.customerHome,
      routes: [
        ShellRoute(
          builder: (context, state, child) => CustomerShellScreen(child: child),
          routes: [
            GoRoute(
              path: RouteConstants.customerHome,
              builder: (context, state) => const Scaffold(body: Text('Home Content')),
            ),
            GoRoute(
              path: RouteConstants.customerProducts,
              builder: (context, state) => const Scaffold(body: Text('Products Content')),
            ),
            GoRoute(
              path: RouteConstants.customerClaims,
              builder: (context, state) => const Scaffold(body: Text('Claims Content')),
            ),
            GoRoute(
              path: RouteConstants.customerNotifications,
              builder: (context, state) => const Scaffold(body: Text('Notifications Content')),
            ),
            GoRoute(
              path: RouteConstants.customerProfile,
              builder: (context, state) => const Scaffold(body: Text('Profile Content')),
            ),
          ],
        ),
      ],
    );
  }

  GoRouter createAdminShellRouter() {
    return GoRouter(
      initialLocation: RouteConstants.adminDashboard,
      routes: [
        ShellRoute(
          builder: (context, state, child) => AdminShellScreen(child: child),
          routes: [
            GoRoute(
              path: RouteConstants.adminDashboard,
              builder: (context, state) => const Scaffold(body: Text('Admin Dashboard Content')),
            ),
            GoRoute(
              path: RouteConstants.adminClaims,
              builder: (context, state) => const Scaffold(body: Text('Admin Claims Content')),
            ),
            GoRoute(
              path: RouteConstants.adminUsers,
              builder: (context, state) => const Scaffold(body: Text('Admin Users Content')),
            ),
          ],
        ),
      ],
    );
  }

  group('CustomerShellScreen Responsive Navigation Tests', () {
    testWidgets('renders bottom NavigationBar with semantic keys at Mobile (390x844)', (tester) async {
      await tester.setBreakpoint(ResponsiveBreakpoint.mobile);

      final router = createCustomerShellRouter();
      await tester.pumpApp(
        const SizedBox.shrink(),
        router: router,
        overrides: [
          unreadNotificationsCountProvider.overrideWith((ref) => 3),
        ],
      );
      await tester.pumpAndSettle();

      expectNoRenderFlexOverflow(tester);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);

      // Verify all navigation keys
      expect(find.byKey(const Key('nav_item_home')), findsOneWidget);
      expect(find.byKey(const Key('nav_item_products')), findsOneWidget);
      expect(find.byKey(const Key('nav_item_claims')), findsOneWidget);
      expect(find.byKey(const Key('nav_item_notifications')), findsOneWidget);
      expect(find.byKey(const Key('nav_unread_badge')), findsOneWidget);
      expect(find.byKey(const Key('nav_item_profile')), findsOneWidget);
      expect(find.text('Home Content'), findsOneWidget);
    });

    testWidgets('renders NavigationRail without bottom bar at Tablet (768x1024)', (tester) async {
      await tester.setBreakpoint(ResponsiveBreakpoint.tablet);

      final router = createCustomerShellRouter();
      await tester.pumpApp(
        const SizedBox.shrink(),
        router: router,
        overrides: [
          unreadNotificationsCountProvider.overrideWith((ref) => 2),
        ],
      );
      await tester.pumpAndSettle();

      expectNoRenderFlexOverflow(tester);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(NavigationRail), findsOneWidget);

      // Semantic keys preserved on rail destinations
      expect(find.byKey(const Key('nav_item_home')), findsOneWidget);
      expect(find.byKey(const Key('nav_item_products')), findsOneWidget);
      expect(find.byKey(const Key('nav_item_claims')), findsOneWidget);
      expect(find.byKey(const Key('nav_item_notifications')), findsOneWidget);
      expect(find.byKey(const Key('nav_unread_badge')), findsOneWidget);
      expect(find.byKey(const Key('nav_item_profile')), findsOneWidget);
    });

    testWidgets('renders extended NavigationRail with brand title at Desktop (1280x800)', (tester) async {
      await tester.setBreakpoint(ResponsiveBreakpoint.desktop);

      final router = createCustomerShellRouter();
      await tester.pumpApp(
        const SizedBox.shrink(),
        router: router,
        overrides: [
          unreadNotificationsCountProvider.overrideWith((ref) => 0),
        ],
      );
      await tester.pumpAndSettle();

      expectNoRenderFlexOverflow(tester);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.text('Claimly'), findsOneWidget);

      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.extended, isTrue);
    });

    testWidgets('navigates to different destinations cleanly across viewports', (tester) async {
      await tester.setBreakpoint(ResponsiveBreakpoint.mobile);

      final router = createCustomerShellRouter();
      await tester.pumpApp(
        const SizedBox.shrink(),
        router: router,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('nav_item_products')));
      await tester.pumpAndSettle();

      expectNoRenderFlexOverflow(tester);
      expect(find.text('Products Content'), findsOneWidget);
    });
  });

  group('AdminShellScreen Responsive Navigation Tests', () {
    testWidgets('renders bottom NavigationBar at Mobile (390x844)', (tester) async {
      await tester.setBreakpoint(ResponsiveBreakpoint.mobile);

      final router = createAdminShellRouter();
      await tester.pumpApp(
        const SizedBox.shrink(),
        router: router,
        overrides: [
          authControllerProvider.overrideWith(
            (ref) => AuthController(mockAuthRepo)..state = AsyncData(sampleAdminProfile),
          ),
        ],
      );
      await tester.pumpAndSettle();

      expectNoRenderFlexOverflow(tester);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.text('Admin Dashboard Content'), findsOneWidget);
    });

    testWidgets('renders NavigationRail at Tablet (768x1024)', (tester) async {
      await tester.setBreakpoint(ResponsiveBreakpoint.tablet);

      final router = createAdminShellRouter();
      await tester.pumpApp(
        const SizedBox.shrink(),
        router: router,
        overrides: [
          authControllerProvider.overrideWith(
            (ref) => AuthController(mockAuthRepo)..state = AsyncData(sampleAdminProfile),
          ),
        ],
      );
      await tester.pumpAndSettle();

      expectNoRenderFlexOverflow(tester);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.text('Admin Dashboard Content'), findsOneWidget);
    });

    testWidgets('renders extended NavigationRail at Desktop (1280x800)', (tester) async {
      await tester.setBreakpoint(ResponsiveBreakpoint.desktop);

      final router = createAdminShellRouter();
      await tester.pumpApp(
        const SizedBox.shrink(),
        router: router,
        overrides: [
          authControllerProvider.overrideWith(
            (ref) => AuthController(mockAuthRepo)..state = AsyncData(sampleAdminProfile),
          ),
        ],
      );
      await tester.pumpAndSettle();

      expectNoRenderFlexOverflow(tester);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(NavigationRail), findsOneWidget);

      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.extended, isTrue);
    });
  });
}
