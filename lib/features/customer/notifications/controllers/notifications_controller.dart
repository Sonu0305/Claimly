import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/supabase_client.dart';
import '../models/notification_model.dart';
import '../repositories/notification_repository.dart';

class NotificationsState {
  final List<NotificationModel> notifications;
  final int unreadCount;
  final bool isLoading;
  final String? errorMessage;
  final String filter; // 'all', 'unread', 'warranty_expiry', 'claim_update'

  const NotificationsState({
    this.notifications = const [],
    this.unreadCount = 0,
    this.isLoading = false,
    this.errorMessage,
    this.filter = 'all',
  });

  List<NotificationModel> get filteredNotifications {
    return notifications.where((n) {
      if (filter == 'unread') return !n.isRead;
      if (filter == 'warranty_expiry') return n.isWarrantyExpiry;
      if (filter == 'claim_update') return n.isClaimUpdate;
      return true;
    }).toList();
  }

  NotificationsState copyWith({
    List<NotificationModel>? notifications,
    int? unreadCount,
    bool? isLoading,
    String? errorMessage,
    String? filter,
  }) {
    return NotificationsState(
      notifications: notifications ?? this.notifications,
      unreadCount: unreadCount ?? this.unreadCount,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      filter: filter ?? this.filter,
    );
  }
}

class NotificationsController extends StateNotifier<NotificationsState> {
  final NotificationRepository _repo;
  final String? _userId;
  RealtimeChannel? _subscription;

  NotificationsController(this._repo, this._userId)
      : super(const NotificationsState(isLoading: true)) {
    init();
  }

  Future<void> init() async {
    await fetchNotifications();
    _setupRealtime();
  }

  void _setupRealtime() {
    final userId = _userId;
    if (userId == null) return;

    try {
      _subscription = _repo.subscribeToUserNotifications(
        userId: userId,
        onInsert: (newNotification) {
          state = state.copyWith(
            notifications: [newNotification, ...state.notifications],
            unreadCount: state.unreadCount + (newNotification.isRead ? 0 : 1),
          );
        },
        onUpdate: (id, isRead) {
          final updatedList = state.notifications.map((n) {
            if (n.id == id) return n.copyWith(isRead: isRead);
            return n;
          }).toList();
          final newUnread = updatedList.where((n) => !n.isRead).length;
          state = state.copyWith(notifications: updatedList, unreadCount: newUnread);
        },
      );
    } catch (_) {
      // Optional for offline unit tests
    }
  }

  Future<void> fetchNotifications() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final list = await _repo.fetchNotifications();
      final unread = list.where((n) => !n.isRead).length;
      state = state.copyWith(notifications: list, unreadCount: unread, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  void setFilter(String filter) {
    state = state.copyWith(filter: filter);
  }

  Future<void> markAsRead(String id) async {
    try {
      await _repo.markAsRead(id);
      final updatedList = state.notifications.map((n) {
        if (n.id == id) return n.copyWith(isRead: true);
        return n;
      }).toList();
      final newUnread = updatedList.where((n) => !n.isRead).length;
      state = state.copyWith(notifications: updatedList, unreadCount: newUnread);
    } catch (_) {}
  }

  Future<void> markAllAsRead() async {
    final userId = _userId;
    if (userId == null) return;
    try {
      await _repo.markAllAsRead(userId);
      final updatedList = state.notifications.map((n) => n.copyWith(isRead: true)).toList();
      state = state.copyWith(notifications: updatedList, unreadCount: 0);
    } catch (_) {}
  }

  Future<void> deleteNotification(String id) async {
    try {
      await _repo.deleteNotification(id);
      final updatedList = state.notifications.where((n) => n.id != id).toList();
      final newUnread = updatedList.where((n) => !n.isRead).length;
      state = state.copyWith(notifications: updatedList, unreadCount: newUnread);
    } catch (_) {}
  }

  @override
  void dispose() {
    _subscription?.unsubscribe();
    super.dispose();
  }
}

final notificationsControllerProvider =
    StateNotifierProvider<NotificationsController, NotificationsState>((ref) {
  final repo = ref.watch(notificationRepositoryProvider);
  final user = ref.watch(currentUserProvider);
  return NotificationsController(repo, user?.id);
});

final unreadNotificationsCountProvider = Provider<int>((ref) {
  final state = ref.watch(notificationsControllerProvider);
  return state.unreadCount;
});
