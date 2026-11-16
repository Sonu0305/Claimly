import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_breakpoints.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/router/route_constants.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../core/widgets/responsive_content_wrapper.dart';
import '../../../../core/widgets/status_badge.dart';
import '../controllers/admin_claims_controller.dart';

class AdminClaimsScreen extends ConsumerStatefulWidget {
  const AdminClaimsScreen({super.key});

  @override
  ConsumerState<AdminClaimsScreen> createState() => _AdminClaimsScreenState();
}

class _AdminClaimsScreenState extends ConsumerState<AdminClaimsScreen> {
  final _searchController = TextEditingController();

  static const List<Map<String, String>> _statusFilters = [
    {'label': 'All', 'value': 'all'},
    {'label': 'Submitted', 'value': 'submitted'},
    {'label': 'Under Review', 'value': 'under_review'},
    {'label': 'Approved', 'value': 'approved'},
    {'label': 'Rejected', 'value': 'rejected'},
    {'label': 'Completed', 'value': 'completed'},
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildClaimCard(AdminClaimItem claim, bool isDark, ThemeData theme, {EdgeInsetsGeometry? margin}) {
    return Card(
      elevation: 0,
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('${RouteConstants.adminClaims}/${claim.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      claim.claimNumber,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusBadge(status: claim.status),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                claim.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.onSurfaceDark : AppColors.onSurfaceLight,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                'Customer: ${claim.customerName ?? 'Unknown'} • Product: ${claim.productName ?? 'General'}',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.gray400 : AppColors.gray600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8.0,
                runSpacing: 4.0,
                children: [
                  Text(
                    DateFormatter.formatDisplayDate(claim.createdAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.gray400 : AppColors.gray500,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: claim.priority >= 70
                          ? AppColors.error.withAlpha(25)
                          : claim.priority >= 40
                              ? AppColors.warning.withAlpha(25)
                              : AppColors.gray200,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Priority: ${claim.priority}/100',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: claim.priority >= 70
                            ? AppColors.error
                            : claim.priority >= 40
                                ? AppColors.warningDark
                                : AppColors.gray700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminClaimsControllerProvider);
    final controller = ref.read(adminClaimsControllerProvider.notifier);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Claims Review'),
        actions: [
          IconButton(
            icon: Icon(
              state.sortByPriority ? Icons.bolt : Icons.access_time,
              color: state.sortByPriority ? AppColors.warning : null,
            ),
            tooltip: state.sortByPriority ? 'Sorting: Priority Descending' : 'Sorting: Newest First',
            onPressed: () => controller.togglePrioritySort(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => controller.fetchClaims(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => controller.fetchClaims(),
        child: ResponsiveContentWrapper(
          maxWidth: AppBreakpoints.maxContentWidth,
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  key: const Key('admin_claim_search_input'),
                  controller: _searchController,
                  onChanged: controller.setSearchQuery,
                  decoration: InputDecoration(
                    hintText: 'Search claims by #, title, or customer...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: state.searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              controller.setSearchQuery('');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: isDark ? AppColors.surfaceDark : AppColors.gray100,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),

              // Status Filter Chips
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: _statusFilters.map((f) {
                    final isSelected = state.selectedStatusFilter == f['value'];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: FilterChip(
                        label: Text(f['label']!),
                        selected: isSelected,
                        onSelected: (_) => controller.setStatusFilter(f['value']!),
                        selectedColor: AppColors.primary.withAlpha(35),
                        checkmarkColor: AppColors.primary,
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 6),

              // Claims Review List
              Expanded(
                child: Builder(
                  builder: (context) {
                    if (state.isLoading && state.claims.isEmpty) {
                      return const LoadingIndicator(message: 'Loading claims directory...');
                    }

                    if (state.errorMessage != null && state.claims.isEmpty) {
                      return ErrorView(
                        message: state.errorMessage!,
                        onRetry: () => controller.fetchClaims(),
                      );
                    }

                    final filtered = state.filteredClaims;

                    if (filtered.isEmpty) {
                      return const Center(
                        child: EmptyState(
                          title: 'No claims found',
                          message: 'No claims match your search or filter parameters.',
                        ),
                      );
                    }

                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final availableWidth = constraints.maxWidth;
                        if (availableWidth < 560) {
                          return ListView.builder(
                            itemCount: filtered.length,
                            padding: const EdgeInsets.only(bottom: 24),
                            itemBuilder: (context, index) {
                              return _buildClaimCard(filtered[index], isDark, theme);
                            },
                          );
                        }

                        final bool isDesktopGrid = availableWidth >= 900;
                        return GridView.builder(
                          itemCount: filtered.length,
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: isDesktopGrid ? 3 : 2,
                            childAspectRatio: isDesktopGrid ? 1.65 : 1.50,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemBuilder: (context, index) {
                            return _buildClaimCard(filtered[index], isDark, theme, margin: EdgeInsets.zero);
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
