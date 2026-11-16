import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:claimly/features/auth/controllers/auth_controller.dart';
import 'package:claimly/features/auth/screens/forgot_password_screen.dart';
import 'package:claimly/features/auth/screens/login_screen.dart';
import 'package:claimly/features/auth/screens/register_screen.dart';
import 'package:claimly/features/auth/screens/splash_screen.dart';
import '../test_helpers/mocks.dart';
import '../test_helpers/pump_app.dart';
import '../test_helpers/responsive_test_helper.dart';

void main() {
  late MockAuthRepository mockAuthRepo;

  setUpAll(() {
    registerCommonFallbackValues();
  });

  setUp(() {
    mockAuthRepo = MockAuthRepository();
  });

  GoRouter createRouter(String initialLocation) {
    return GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: '/splash',
          builder: (context, state) => const SplashScreen(),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/register',
          builder: (context, state) => const RegisterScreen(),
        ),
        GoRoute(
          path: '/forgot-password',
          builder: (context, state) => const ForgotPasswordScreen(),
        ),
        GoRoute(
          path: '/customer/home',
          builder: (context, state) => const Scaffold(body: Text('Customer Home')),
        ),
      ],
    );
  }

  group('Auth Screens Responsive Tests', () {
    for (final breakpoint in ResponsiveBreakpoint.values) {
      testWidgets('SplashScreen renders cleanly without overflow at ${breakpoint.label}', (tester) async {
        await tester.setBreakpoint(breakpoint);

        await tester.pumpApp(
          const SplashScreen(),
          router: createRouter('/splash'),
        );
        await tester.pump(const Duration(milliseconds: 100));

        expectNoRenderFlexOverflow(tester);
        expect(find.text('Claimly'), findsOneWidget);
        expect(find.text('Initializing...'), findsOneWidget);

        // Advance timer past splash delay to prevent pending timer error
        await tester.pump(const Duration(milliseconds: 1600));
        await tester.pump();
      });

      testWidgets('LoginScreen renders form and OAuth buttons without overflow at ${breakpoint.label}', (tester) async {
        await tester.setBreakpoint(breakpoint);

        await tester.pumpApp(
          const LoginScreen(),
          router: createRouter('/login'),
          overrides: [
            authControllerProvider.overrideWith(
              (ref) => AuthController(mockAuthRepo),
            ),
          ],
        );
        await tester.pumpAndSettle();

        expectNoRenderFlexOverflow(tester);
        expect(find.text('Welcome to Claimly'), findsOneWidget);
        expect(find.byKey(const Key('auth_email_input')), findsOneWidget);
        expect(find.byKey(const Key('auth_password_input')), findsOneWidget);
        expect(find.byKey(const Key('auth_login_submit_btn')), findsOneWidget);
      });

      testWidgets('RegisterScreen renders registration inputs without overflow at ${breakpoint.label}', (tester) async {
        await tester.setBreakpoint(breakpoint);

        await tester.pumpApp(
          const RegisterScreen(),
          router: createRouter('/register'),
          overrides: [
            authControllerProvider.overrideWith(
              (ref) => AuthController(mockAuthRepo),
            ),
          ],
        );
        await tester.pumpAndSettle();

        expectNoRenderFlexOverflow(tester);
        expect(find.text('Join Claimly'), findsOneWidget);
        expect(find.byKey(const Key('auth_fullname_input')), findsOneWidget);
        expect(find.byKey(const Key('auth_email_input')), findsOneWidget);
        expect(find.byKey(const Key('auth_password_input')), findsOneWidget);
        expect(find.byKey(const Key('auth_confirm_password_input')), findsOneWidget);
        expect(find.byKey(const Key('auth_register_submit_btn')), findsOneWidget);
      });

      testWidgets('ForgotPasswordScreen renders inputs without overflow at ${breakpoint.label}', (tester) async {
        await tester.setBreakpoint(breakpoint);

        await tester.pumpApp(
          const ForgotPasswordScreen(),
          router: createRouter('/forgot-password'),
          overrides: [
            authControllerProvider.overrideWith(
              (ref) => AuthController(mockAuthRepo),
            ),
          ],
        );
        await tester.pumpAndSettle();

        expectNoRenderFlexOverflow(tester);
        expect(find.text('Reset Password'), findsOneWidget);
        expect(find.byKey(const Key('auth_email_input')), findsOneWidget);
        expect(find.byKey(const Key('auth_reset_password_submit_btn')), findsOneWidget);
      });
    }

    testWidgets('SplashScreen renders without overflow on low-height landscape mobile (640x320)', (tester) async {
      await tester.setViewport(const Size(640, 320));

      await tester.pumpApp(
        const SplashScreen(),
        router: createRouter('/splash'),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expectNoRenderFlexOverflow(tester);
      expect(find.text('Claimly'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pump();
    });
  });
}
