import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_breakpoints.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../core/widgets/responsive_content_wrapper.dart';
import '../controllers/admin_users_controller.dart';
import '../models/admin_user_model.dart';

class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  final _searchController = TextEditingController();

  static const List<Map<String, String>> _roleFilters = [
    {'label': 'All Users', 'value': 'all'},
    {'label': 'Customers', 'value': 'customer'},
    {'label': 'Administrators', 'value': 'admin'},
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildUserCard(AdminUserModel user, bool isDark, ThemeData theme, {EdgeInsetsGeometry? margin}) {
    final initials = (user.fullName != null && user.fullName!.isNotEmpty)
        ? user.fullName!.trim().split(' ').map((s) => s.isNotEmpty ? s[0] : '').take(2).join().toUpperCase()
        : 'U';

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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: user.isAdmin ? AppColors.claimUnderReview : AppColors.primary,
              backgroundImage: user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                  ? NetworkImage(user.avatarUrl!)
                  : null,
              child: (user.avatarUrl == null || user.avatarUrl!.isEmpty)
                  ? Text(
                      initials,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    )
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          user.fullName ?? 'Unnamed User',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.onSurfaceDark : AppColors.onSurfaceLight,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: user.isAdmin
                              ? AppColors.claimUnderReview.withAlpha(25)
                              : AppColors.gray200,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          user.role.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: user.isAdmin ? AppColors.claimUnderReview : AppColors.gray700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Joined: ${DateFormatter.formatDisplayDate(user.createdAt)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.gray400 : AppColors.gray600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withAlpha(15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${user.productCount} Products',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withAlpha(15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${user.claimCount} Claims',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.secondary),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminUsersControllerProvider);
    final controller = ref.read(adminUsersControllerProvider.notifier);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management Directory'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => controller.fetchUsers(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => controller.fetchUsers(),
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
                    hintText: 'Search users by name or phone...',
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

              // Role Filters
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: _roleFilters.map((f) {
                    final isSelected = state.roleFilter == f['value'];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: FilterChip(
                        label: Text(f['label']!),
                        selected: isSelected,
                        onSelected: (_) => controller.setRoleFilter(f['value']!),
                        selectedColor: AppColors.primary.withAlpha(35),
                        checkmarkColor: AppColors.primary,
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 6),

              // User Directory List
              Expanded(
                child: Builder(
                  builder: (context) {
                    if (state.isLoading && state.users.isEmpty) {
                      return const LoadingIndicator(message: 'Loading user directory...');
                    }

                    if (state.errorMessage != null && state.users.isEmpty) {
                      return ErrorView(
                        message: state.errorMessage!,
                        onRetry: () => controller.fetchUsers(),
                      );
                    }

                    final filtered = state.filteredUsers;

                    if (filtered.isEmpty) {
                      return const Center(
                        child: EmptyState(
                          title: 'No users found',
                          message: 'No users match the search criteria.',
                          icon: Icons.people_outline,
                        ),
                      );
                    }

                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final availableWidth = constraints.maxWidth;
                        if (availableWidth < 560) {
                          return ListView.builder(
                            key: const Key('admin_user_directory'),
                            itemCount: filtered.length,
                            padding: const EdgeInsets.only(bottom: 24),
                            itemBuilder: (context, index) {
                              return _buildUserCard(filtered[index], isDark, theme);
                            },
                          );
                        }

                        final bool isDesktopGrid = availableWidth >= 900;
                        return GridView.builder(
                          key: const Key('admin_user_directory'),
                          itemCount: filtered.length,
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: isDesktopGrid ? 3 : 2,
                            childAspectRatio: isDesktopGrid ? 1.70 : 1.50,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemBuilder: (context, index) {
                            return _buildUserCard(filtered[index], isDark, theme, margin: EdgeInsets.zero);
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
