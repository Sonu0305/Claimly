import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_breakpoints.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../../core/router/route_constants.dart';
import '../../../../core/theme/theme_provider.dart';
import 'package:claimly/features/auth/controllers/auth_controller.dart';
import 'package:claimly/features/auth/models/user_model.dart';

class AdminShellScreen extends ConsumerWidget {
  final Widget child;

  const AdminShellScreen({
    super.key,
    required this.child,
  });

  int _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith(RouteConstants.adminClaims)) {
      return 1;
    }
    if (location.startsWith(RouteConstants.adminUsers)) {
      return 2;
    }
    return 0; // Default to Analytics Dashboard
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go(RouteConstants.adminDashboard);
        break;
      case 1:
        context.go(RouteConstants.adminClaims);
        break;
      case 2:
        context.go(RouteConstants.adminUsers);
        break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = _calculateSelectedIndex(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < AppBreakpoints.tabletMin;
    final isDesktop = width >= AppBreakpoints.desktopMin;

    final userProfile = ref.watch(authControllerProvider).asData?.value;
    final session = ref.watch(supabaseClientProvider).auth.currentSession;

    // Admin role verification guard
    final roleStr = session?.user.appMetadata['role'] as String? ??
        session?.user.userMetadata?['role'] as String? ??
        userProfile?.role.name ??
        'customer';

    final isAdmin = roleStr.toLowerCase() == 'admin' || userProfile?.role == UserRole.admin;

    if (!isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Access Denied')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.gpp_bad_outlined, size: 64, color: AppColors.error),
                const SizedBox(height: 16),
                Text(
                  'Administrator Access Required',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your current account does not hold administrative privileges to view this portal.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => context.go(RouteConstants.customerHome),
                  child: const Text('Return to Customer Home'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final appBar = AppBar(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.claimUnderReview,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'ADMIN',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
          const SizedBox(width: 10),
          const Flexible(
            child: Text(
              'Claimly Console',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      actions: [
        if (width >= 480)
          TextButton.icon(
            icon: const Icon(Icons.swap_horiz),
            label: const Text('Customer View'),
            onPressed: () => context.go(RouteConstants.customerHome),
          )
        else
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            tooltip: 'Customer View',
            onPressed: () => context.go(RouteConstants.customerHome),
          ),
        IconButton(
          icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
          tooltip: 'Toggle Theme',
          onPressed: () => ref.read(themeModeProvider.notifier).toggleTheme(),
        ),
      ],
    );

    if (!isMobile) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: selectedIndex,
              onDestinationSelected: (index) => _onItemTapped(index, context),
              extended: isDesktop,
              backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
              indicatorColor: AppColors.claimUnderReview.withAlpha(40),
              leading: isDesktop
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.claimUnderReview,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'ADMIN',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Console',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : AppColors.onSurfaceLight,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.claimUnderReview,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'ADM',
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.analytics_outlined),
                  selectedIcon: Icon(Icons.analytics, color: AppColors.claimUnderReview),
                  label: Text('Analytics'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.assignment_outlined),
                  selectedIcon: Icon(Icons.assignment, color: AppColors.claimUnderReview),
                  label: Text('Claims Review'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.people_outline),
                  selectedIcon: Icon(Icons.people, color: AppColors.claimUnderReview),
                  label: Text('Users Directory'),
                ),
              ],
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(
              child: Scaffold(
                appBar: appBar,
                body: child,
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: appBar,
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) => _onItemTapped(index, context),
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        indicatorColor: AppColors.claimUnderReview.withAlpha(40),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics, color: AppColors.claimUnderReview),
            label: 'Analytics',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment, color: AppColors.claimUnderReview),
            label: 'Claims Review',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people, color: AppColors.claimUnderReview),
            label: 'Users Directory',
          ),
        ],
      ),
    );
  }
}
