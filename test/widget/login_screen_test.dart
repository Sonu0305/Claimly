import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:claimly/features/auth/controllers/auth_controller.dart';
import 'package:claimly/features/auth/screens/login_screen.dart';
import '../test_helpers/mocks.dart';
import '../test_helpers/pump_app.dart';

void main() {
  late MockAuthRepository mockAuthRepo;
  late GoRouter testRouter;

  setUpAll(() {
    registerCommonFallbackValues();
  });

  setUp(() {
    mockAuthRepo = MockAuthRepository();

    testRouter = GoRouter(
      initialLocation: '/login',
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/forgot-password',
          builder: (context, state) => const Scaffold(body: Text('Forgot Password Screen')),
        ),
        GoRoute(
          path: '/customer/home',
          builder: (context, state) => const Scaffold(body: Text('Customer Home Screen')),
        ),
      ],
    );
  });

  group('LoginScreen Widget Tests', () {
    testWidgets('LoginScreen renders title, email, password inputs, and action buttons', (tester) async {
      await tester.pumpApp(
        const LoginScreen(),
        router: testRouter,
        overrides: [
          authControllerProvider.overrideWith(
            (ref) => AuthController(mockAuthRepo),
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('Welcome to Claimly'), findsOneWidget);
      expect(find.byKey(const Key('auth_email_input')), findsOneWidget);
      expect(find.byKey(const Key('auth_password_input')), findsOneWidget);
      expect(find.byKey(const Key('auth_login_submit_btn')), findsOneWidget);
      expect(find.byKey(const Key('auth_forgot_password_btn')), findsOneWidget);
    });

    testWidgets('LoginScreen displays validation errors when submitted empty', (tester) async {
      await tester.pumpApp(
        const LoginScreen(),
        router: testRouter,
        overrides: [
          authControllerProvider.overrideWith(
            (ref) => AuthController(mockAuthRepo),
          ),
        ],
      );
      await tester.pumpAndSettle();

      // Tap submit with empty fields
      await tester.tap(find.byKey(const Key('auth_login_submit_btn')));
      await tester.pumpAndSettle();

      expect(find.text('Email is required'), findsOneWidget);
      expect(find.text('Password is required'), findsOneWidget);
    });

    testWidgets('LoginScreen displays invalid email error message for bad format', (tester) async {
      await tester.pumpApp(
        const LoginScreen(),
        router: testRouter,
        overrides: [
          authControllerProvider.overrideWith(
            (ref) => AuthController(mockAuthRepo),
          ),
        ],
      );
      await tester.pumpAndSettle();

      // Enter invalid email format
      await tester.enterText(find.byKey(const Key('auth_email_input')), 'not-an-email');
      await tester.pump();

      // Tap submit
      await tester.tap(find.byKey(const Key('auth_login_submit_btn')));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a valid email address'), findsOneWidget);
    });
  });
}
