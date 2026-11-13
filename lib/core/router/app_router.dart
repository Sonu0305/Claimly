import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../network/supabase_client.dart';
import 'route_constants.dart';

// Screen Imports
import 'package:claimly/features/auth/screens/splash_screen.dart';
import 'package:claimly/features/auth/screens/login_screen.dart';
import 'package:claimly/features/auth/screens/register_screen.dart';
import 'package:claimly/features/auth/screens/forgot_password_screen.dart';
import 'package:claimly/features/customer/shell/customer_shell_screen.dart';
import 'package:claimly/features/customer/dashboard/screens/customer_dashboard_screen.dart';
import 'package:claimly/features/customer/products/screens/products_list_screen.dart';
import 'package:claimly/features/customer/products/screens/product_detail_screen.dart';
import 'package:claimly/features/customer/products/screens/product_form_screen.dart';
import 'package:claimly/features/customer/claims/screens/claims_list_screen.dart';
import 'package:claimly/features/customer/claims/screens/claim_detail_screen.dart';
import 'package:claimly/features/customer/claims/claim_wizard/screens/claim_wizard_screen.dart';
import 'package:claimly/features/customer/notifications/screens/notifications_screen.dart';
import 'package:claimly/features/customer/profile/screens/profile_screen.dart';
import 'package:claimly/features/admin/shell/admin_shell_screen.dart';
import 'package:claimly/features/admin/dashboard/screens/admin_dashboard_screen.dart';
import 'package:claimly/features/admin/claims_review/screens/admin_claims_screen.dart';
import 'package:claimly/features/admin/claims_review/screens/admin_claim_detail_screen.dart';
import 'package:claimly/features/admin/users/screens/admin_users_screen.dart';

/// Notifier listening to auth changes to trigger GoRouter re-evaluations reactively.
class GoRouterRefreshStream extends ChangeNotifier {
  late final StreamSubscription<dynamic> _subscription;

  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

/// Riverpod provider supplying the central GoRouter instance.
final appRouterProvider = Provider<GoRouter>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  final refreshStream = GoRouterRefreshStream(supabase.auth.onAuthStateChange);
  ref.onDispose(refreshStream.dispose);

  return GoRouter(
    initialLocation: RouteConstants.splash,
    refreshListenable: refreshStream,
    debugLogDiagnostics: false,
    redirect: (BuildContext context, GoRouterState state) {
      Session? session;
      try {
        session = supabase.auth.currentSession;
      } catch (_) {
        session = null;
      }

      final isAuthenticated = session != null;
      final location = state.matchedLocation;

      final isAuthRoute = location == RouteConstants.login ||
          location == RouteConstants.register ||
          location == RouteConstants.forgotPassword ||
          location == RouteConstants.splash;

      // 1. Unauthenticated users cannot access protected routes
      if (!isAuthenticated && !isAuthRoute) {
        return RouteConstants.login;
      }

      // 2. Authenticated users on auth screens bounce to respective shell
      if (isAuthenticated && isAuthRoute && location != RouteConstants.splash) {
        final role = session.user.appMetadata['role'] as String? ??
            session.user.userMetadata?['role'] as String? ??
            'customer';
        return role == 'admin' ? RouteConstants.adminDashboard : RouteConstants.customerHome;
      }

      // 3. Admin role guard: non-admins cannot access /admin routes
      if (isAuthenticated && location.startsWith('/admin')) {
        final role = session.user.appMetadata['role'] as String? ??
            session.user.userMetadata?['role'] as String? ??
            'customer';
        if (role != 'admin') {
          return RouteConstants.customerHome;
        }
      }

      // 4. Convenience route aliases
      if (location == '/dashboard') return RouteConstants.customerHome;
      if (location == '/products') return RouteConstants.customerProducts;
      if (location == '/claims') return RouteConstants.customerClaims;
      if (location == '/notifications') return RouteConstants.customerNotifications;
      if (location == '/profile') return RouteConstants.customerProfile;

      return null;
    },
    routes: [
      // Top-level Auth Routes
      GoRoute(
        path: RouteConstants.splash,
        name: RouteConstants.splashName,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: RouteConstants.login,
        name: RouteConstants.loginName,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: RouteConstants.register,
        name: RouteConstants.registerName,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: RouteConstants.forgotPassword,
        name: RouteConstants.forgotPasswordName,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),

      // Customer ShellRoute
      ShellRoute(
        builder: (context, state, child) => CustomerShellScreen(child: child),
        routes: [
          GoRoute(
            path: RouteConstants.customerHome,
            name: RouteConstants.customerHomeName,
            builder: (context, state) => const CustomerDashboardScreen(),
          ),
          GoRoute(
            path: RouteConstants.customerProducts,
            name: RouteConstants.customerProductsName,
            builder: (context, state) => const ProductsListScreen(),
            routes: [
              GoRoute(
                path: 'new',
                builder: (context, state) => const ProductFormScreen(),
              ),
              GoRoute(
                path: ':id',
                builder: (context, state) => ProductDetailScreen(
                  productId: state.pathParameters['id']!,
                ),
                routes: [
                  GoRoute(
                    path: 'edit',
                    builder: (context, state) => ProductFormScreen(
                      productId: state.pathParameters['id'],
                    ),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: RouteConstants.customerClaims,
            name: RouteConstants.customerClaimsName,
            builder: (context, state) => const ClaimsListScreen(),
            routes: [
              GoRoute(
                path: 'new',
                name: RouteConstants.claimWizardName,
                builder: (context, state) => ClaimWizardScreen(
                  initialProductId: state.uri.queryParameters['productId'],
                ),
              ),
              GoRoute(
                path: ':id',
                builder: (context, state) => ClaimDetailScreen(
                  claimId: state.pathParameters['id']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: RouteConstants.customerNotifications,
            name: RouteConstants.customerNotificationsName,
            builder: (context, state) => const NotificationsScreen(),
          ),
          GoRoute(
            path: RouteConstants.customerProfile,
            name: RouteConstants.customerProfileName,
            builder: (context, state) => const CustomerProfileScreen(),
          ),
        ],
      ),

      // Admin ShellRoute
      ShellRoute(
        builder: (context, state, child) => AdminShellScreen(child: child),
        routes: [
          GoRoute(
            path: RouteConstants.adminDashboard,
            name: RouteConstants.adminDashboardName,
            builder: (context, state) => const AdminDashboardScreen(),
          ),
          GoRoute(
            path: RouteConstants.adminClaims,
            name: RouteConstants.adminClaimsName,
            builder: (context, state) => const AdminClaimsScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (context, state) => AdminClaimDetailScreen(
                  claimId: state.pathParameters['id']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: RouteConstants.adminUsers,
            name: RouteConstants.adminUsersName,
            builder: (context, state) => const AdminUsersScreen(),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Not Found')),
      body: Center(
        child: Text('Route not found: ${state.uri}'),
      ),
    ),
  );
});
