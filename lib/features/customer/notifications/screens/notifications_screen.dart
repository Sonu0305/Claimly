import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/router/route_constants.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../controllers/notifications_controller.dart';
import '../models/notification_model.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationsControllerProvider);
    final controller = ref.read(notificationsControllerProvider.notifier);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (state.unreadCount > 0)
            TextButton(
              key: const Key('notification_mark_all_read_btn'),
              onPressed: () => controller.markAllAsRead(),
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => controller.fetchNotifications(),
        child: Column(
          children: [
            // Filter Chips
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                children: [
                  _filterChip(context, 'All', 'all', state.filter, controller),
                  _filterChip(context, 'Unread (${state.unreadCount})', 'unread', state.filter, controller),
                  _filterChip(context, 'Warranties', 'warranty_expiry', state.filter, controller),
                  _filterChip(context, 'Claims', 'claim_update', state.filter, controller),
                ],
              ),
            ),
            const Divider(height: 1),

            // Notifications List Body
            Expanded(
              child: Builder(
                builder: (context) {
                  if (state.isLoading && state.notifications.isEmpty) {
                    return const LoadingIndicator(message: 'Loading notifications...');
                  }

                  if (state.errorMessage != null && state.notifications.isEmpty) {
                    return ErrorView(
                      message: state.errorMessage!,
                      onRetry: () => controller.fetchNotifications(),
                    );
                  }

                  final filtered = state.filteredNotifications;

                  if (filtered.isEmpty) {
                    return const Center(
                      key: Key('notification_empty_state'),
                      child: EmptyState(
                        title: 'All caught up!',
                        message: 'No notifications matching the selected filter.',
                        icon: Icons.notifications_none_outlined,
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      return _NotificationTile(
                        item: item,
                        isDark: isDark,
                        onTap: () async {
                          if (!item.isRead) {
                            await controller.markAsRead(item.id);
                          }
                          if (item.claimId != null && context.mounted) {
                            unawaited(context.push('${RouteConstants.customerClaims}/${item.claimId}'));
                          }
                        },
                        onDismiss: () {
                          unawaited(controller.deleteNotification(item.id));
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
    );
  }

  Widget _filterChip(
    BuildContext context,
    String label,
    String filterValue,
    String currentFilter,
    NotificationsController controller,
  ) {
    final isSelected = currentFilter == filterValue;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => controller.setFilter(filterValue),
        selectedColor: AppColors.primary.withAlpha(35),
        checkmarkColor: AppColors.primary,
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationModel item;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _NotificationTile({
    required this.item,
    required this.isDark,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    Color iconColor;
    IconData iconData;
    if (item.isWarrantyExpiry) {
      iconColor = AppColors.statusExpiring;
      iconData = Icons.warning_amber_rounded;
    } else if (item.isClaimUpdate) {
      iconColor = AppColors.primary;
      iconData = Icons.assignment_outlined;
    } else {
      iconColor = AppColors.secondary;
      iconData = Icons.info_outline;
    }

    return Dismissible(
      key: Key('dismiss_${item.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: AppColors.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => onDismiss(),
      child: ListTile(
        key: const Key('notification_item'),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        tileColor: item.isRead
            ? Colors.transparent
            : (isDark ? AppColors.primary.withAlpha(20) : AppColors.primary.withAlpha(10)),
        leading: Stack(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withAlpha(25),
                shape: BoxShape.circle,
              ),
              child: Icon(iconData, color: iconColor, size: 22),
            ),
            if (!item.isRead)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                item.title,
                style: TextStyle(
                  fontWeight: item.isRead ? FontWeight.w500 : FontWeight.bold,
                  fontSize: 14,
                  color: isDark ? AppColors.onSurfaceDark : AppColors.onSurfaceLight,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              DateFormatter.formatRelative(item.createdAt),
              style: TextStyle(
                fontSize: 11,
                color: isDark ? AppColors.gray400 : AppColors.gray500,
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            item.message,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.gray400 : AppColors.gray600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}
