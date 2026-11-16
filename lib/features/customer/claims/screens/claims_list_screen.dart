import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_breakpoints.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/router/route_constants.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../core/widgets/responsive_content_wrapper.dart';
import '../controllers/claims_controller.dart';
import '../widgets/claim_card.dart';

class ClaimsListScreen extends ConsumerStatefulWidget {
  const ClaimsListScreen({super.key});

  @override
  ConsumerState<ClaimsListScreen> createState() => _ClaimsListScreenState();
}

class _ClaimsListScreenState extends ConsumerState<ClaimsListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();

  final List<Map<String, dynamic>> _tabs = [
    {'label': 'All', 'key': const Key('claim_tab_all'), 'value': 'all'},
    {'label': 'Pending', 'key': const Key('claim_tab_pending'), 'value': 'pending'},
    {'label': 'Approved', 'key': const Key('claim_tab_approved'), 'value': 'approved'},
    {'label': 'Rejected', 'key': const Key('claim_tab_rejected'), 'value': 'rejected'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) {
      final tab = _tabs[_tabController.index]['value'] as String;
      ref.read(claimsControllerProvider.notifier).setStatusTab(tab);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(claimsControllerProvider);
    final controller = ref.read(claimsControllerProvider.notifier);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Claims Management', overflow: TextOverflow.ellipsis),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: AppColors.primary,
          labelColor: isDark ? Colors.white : AppColors.primary,
          unselectedLabelColor: isDark ? AppColors.gray400 : AppColors.gray600,
          tabs: _tabs.map((tab) {
            return Tab(
              key: tab['key'] as Key,
              text: tab['label'] as String,
            );
          }).toList(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(RouteConstants.claimWizard),
        icon: const Icon(Icons.add),
        label: const Text('File Claim'),
      ),
      body: RefreshIndicator(
        onRefresh: () => controller.loadClaims(),
        child: ResponsiveContentWrapper(
          maxWidth: AppBreakpoints.maxContentWidth,
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              // Search Input
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: controller.setSearchQuery,
                  decoration: InputDecoration(
                    hintText: 'Search by claim #, title, product...',
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

              // Claims List
              Expanded(
                child: Builder(
                  builder: (context) {
                    if (state.isLoading && state.claims.isEmpty) {
                      return const LoadingIndicator(message: 'Loading claims...');
                    }

                    if (state.errorMessage != null && state.claims.isEmpty) {
                      return ErrorView(
                        message: state.errorMessage!,
                        onRetry: () => controller.loadClaims(),
                      );
                    }

                    final filtered = state.filteredClaims;

                    if (filtered.isEmpty) {
                      return EmptyState(
                        title: state.searchQuery.isNotEmpty
                            ? 'No matching claims'
                            : 'No claims in this tab',
                        message: state.searchQuery.isNotEmpty
                            ? 'Try modifying your search keywords.'
                            : 'You can submit a claim for any eligible product with warranty coverage.',
                        actionText: 'File New Claim',
                        onAction: () => context.push(RouteConstants.claimWizard),
                      );
                    }

                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final availableWidth = constraints.maxWidth;
                        if (availableWidth < 560) {
                          return ListView.builder(
                            itemCount: filtered.length,
                            padding: const EdgeInsets.only(bottom: 80.0),
                            itemBuilder: (context, index) {
                              final claim = filtered[index];
                              return ClaimCard(
                                claim: claim,
                                onTap: () => context.push('${RouteConstants.customerClaims}/${claim.id}'),
                              );
                            },
                          );
                        }

                        final bool isDesktopGrid = availableWidth >= 900;
                        return GridView.builder(
                          itemCount: filtered.length,
                          padding: const EdgeInsets.only(bottom: 80.0, left: 16.0, right: 16.0),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: isDesktopGrid ? 3 : 2,
                            childAspectRatio: isDesktopGrid ? 1.70 : 1.50,
                            crossAxisSpacing: 12.0,
                            mainAxisSpacing: 12.0,
                          ),
                          itemBuilder: (context, index) {
                            final claim = filtered[index];
                            return ClaimCard(
                              claim: claim,
                              margin: EdgeInsets.zero,
                              onTap: () => context.push('${RouteConstants.customerClaims}/${claim.id}'),
                            );
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
