import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_breakpoints.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/router/route_constants.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../core/widgets/responsive_content_wrapper.dart';
import '../../../auth/controllers/auth_controller.dart';
import '../controllers/dashboard_controller.dart';
import '../widgets/dashboard_kpi_card.dart';
import '../widgets/expiry_carousel.dart';
import '../widgets/recent_claims_list.dart';

class CustomerDashboardScreen extends ConsumerWidget {
  const CustomerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardControllerProvider);
    final controller = ref.read(dashboardControllerProvider.notifier);
    final userProfile = ref.watch(authControllerProvider).asData?.value;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isDesktop = MediaQuery.sizeOf(context).width >= AppBreakpoints.desktopMin;

    final displayName = userProfile?.fullName ?? 'User';

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.shield_outlined, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            const Flexible(
              child: Text(
                'Claimly Dashboard',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => context.push(RouteConstants.customerNotifications),
            tooltip: 'Notifications',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => controller.loadDashboard(),
        child: Builder(
          builder: (context) {
            if (state.isLoading && state.products.isEmpty && state.claims.isEmpty) {
              return const LoadingIndicator(message: 'Loading your dashboard...');
            }

            if (state.errorMessage != null && state.products.isEmpty && state.claims.isEmpty) {
              return ErrorView(
                message: state.errorMessage!,
                onRetry: () => controller.loadDashboard(),
              );
            }

            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: ResponsiveContentWrapper(
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Welcome Header
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome back, $displayName 👋',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.onBackgroundDark : AppColors.onBackgroundLight,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Here is an overview of your active warranties and claims.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: isDark ? AppColors.gray400 : AppColors.gray600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // KPI Responsive Grid
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final bodyWidth = constraints.maxWidth;
                        final crossAxisCount = bodyWidth < 900 ? 2 : 4;
                        final double childAspectRatio;
                        if (bodyWidth < 480) {
                          childAspectRatio = 1.10;
                        } else if (bodyWidth < 900) {
                          childAspectRatio = 1.35;
                        } else {
                          childAspectRatio = 1.20;
                        }

                        return GridView.count(
                          crossAxisCount: crossAxisCount,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 12.0,
                          mainAxisSpacing: 12.0,
                          childAspectRatio: childAspectRatio,
                          children: [
                            DashboardKpiCard(
                              title: 'Active Warranties',
                              value: state.activeWarrantiesCount.toString(),
                              icon: Icons.verified_outlined,
                              color: AppColors.statusActive,
                              onTap: () => context.go(RouteConstants.customerProducts),
                            ),
                            DashboardKpiCard(
                              title: 'Pending Claims',
                              value: state.pendingClaimsCount.toString(),
                              icon: Icons.hourglass_top_outlined,
                              color: AppColors.claimUnderReview,
                              onTap: () => context.go(RouteConstants.customerClaims),
                            ),
                            DashboardKpiCard(
                              title: 'Approved Claims',
                              value: state.approvedClaimsCount.toString(),
                              icon: Icons.check_circle_outline,
                              color: AppColors.claimApproved,
                              onTap: () => context.go(RouteConstants.customerClaims),
                            ),
                            DashboardKpiCard(
                              title: 'Expiring Soon',
                              value: state.expiringSoonCount.toString(),
                              icon: Icons.warning_amber_rounded,
                              color: AppColors.statusExpiring,
                              onTap: () => context.go(RouteConstants.customerProducts),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 20),

                    // Quick Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: AppButton(
                            text: '+ Add Product',
                            icon: const Icon(Icons.add_shopping_cart, size: 18),
                            onPressed: () => context.push('${RouteConstants.customerProducts}/new'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppButton(
                            text: 'File a Claim',
                            variant: AppButtonVariant.secondary,
                            icon: const Icon(Icons.assignment_add, size: 18),
                            onPressed: () => context.push(RouteConstants.claimWizard),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Expiry Carousel & Recent Claims
                    if (isDesktop)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: ExpiryCarousel(expiringProducts: state.expiringSoonProducts),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: RecentClaimsList(claims: state.recentClaims),
                          ),
                        ],
                      )
                    else ...[
                      // Expiry Countdown Alerts Carousel
                      ExpiryCarousel(expiringProducts: state.expiringSoonProducts),
                      const SizedBox(height: 16),

                      // Recent Claims Feed
                      RecentClaimsList(claims: state.recentClaims),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
