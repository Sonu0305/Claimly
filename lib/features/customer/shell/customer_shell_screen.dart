import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/router/route_constants.dart';
import '../notifications/controllers/notifications_controller.dart';

class CustomerShellScreen extends ConsumerWidget {
  final Widget child;

  const CustomerShellScreen({
    super.key,
    required this.child,
  });

  int _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith(RouteConstants.customerProducts)) {
      return 1;
    }
    if (location.startsWith(RouteConstants.customerClaims)) {
      return 2;
    }
    if (location.startsWith(RouteConstants.customerNotifications)) {
      return 3;
    }
    if (location.startsWith(RouteConstants.customerProfile)) {
      return 4;
    }
    return 0; // Default to Home
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go(RouteConstants.customerHome);
        break;
      case 1:
        context.go(RouteConstants.customerProducts);
        break;
      case 2:
        context.go(RouteConstants.customerClaims);
        break;
      case 3:
        context.go(RouteConstants.customerNotifications);
        break;
      case 4:
        context.go(RouteConstants.customerProfile);
        break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = _calculateSelectedIndex(context);
    final unreadCount = ref.watch(unreadNotificationsCountProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) => _onItemTapped(index, context),
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        indicatorColor: AppColors.primary.withAlpha(40),
        destinations: [
          const NavigationDestination(
            key: Key('nav_item_home'),
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard, color: AppColors.primary),
            label: 'Home',
          ),
          const NavigationDestination(
            key: Key('nav_item_products'),
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2, color: AppColors.primary),
            label: 'Products',
          ),
          const NavigationDestination(
            key: Key('nav_item_claims'),
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment, color: AppColors.primary),
            label: 'Claims',
          ),
          NavigationDestination(
            key: const Key('nav_item_notifications'),
            icon: Badge(
              key: const Key('nav_unread_badge'),
              isLabelVisible: unreadCount > 0,
              label: Text('$unreadCount'),
              child: const Icon(Icons.notifications_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: unreadCount > 0,
              label: Text('$unreadCount'),
              child: const Icon(Icons.notifications, color: AppColors.primary),
            ),
            label: 'Alerts',
          ),
          const NavigationDestination(
            key: Key('nav_item_profile'),
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: AppColors.primary),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

