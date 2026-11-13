import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:claimly/core/errors/exceptions.dart';
import 'package:claimly/features/customer/notifications/controllers/notifications_controller.dart';
import 'package:claimly/features/customer/notifications/models/notification_model.dart';
import '../../test_helpers/mocks.dart';
import '../../test_helpers/test_fixtures.dart';

void main() {
  late MockNotificationRepository mockNotificationRepo;

  setUpAll(() {
    registerCommonFallbackValues();
  });

  setUp(() {
    mockNotificationRepo = MockNotificationRepository();
  });

  group('NotificationsController Tests', () {
    test('fetchNotifications populates notifications list and calculates unreadCount', () async {
      when(() => mockNotificationRepo.fetchNotifications())
          .thenAnswer((_) async => [sampleNotification]);

      final controller = NotificationsController(mockNotificationRepo, null);
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.isLoading, isFalse);
      expect(controller.state.notifications.length, equals(1));
      expect(controller.state.unreadCount, equals(1));
    });

    test('filter property filters notifications by type or read status', () async {
      final now = DateTime.now();

      final unreadClaimNotif = sampleNotification; // isRead = false, type = 'claim_update'
      final readExpiryNotif = NotificationModel(
        id: 'n-exp',
        userId: 'usr-customer-001',
        type: 'warranty_expiry',
        title: 'Warranty Alert',
        message: 'Expiring soon',
        isRead: true,
        createdAt: now,
      );

      when(() => mockNotificationRepo.fetchNotifications())
          .thenAnswer((_) async => [unreadClaimNotif, readExpiryNotif]);

      final controller = NotificationsController(mockNotificationRepo, null);
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.notifications.length, equals(2));
      expect(controller.state.unreadCount, equals(1));

      // Filter by unread
      controller.setFilter('unread');
      expect(controller.state.filteredNotifications.length, equals(1));
      expect(controller.state.filteredNotifications.first.id, equals(unreadClaimNotif.id));

      // Filter by warranty_expiry
      controller.setFilter('warranty_expiry');
      expect(controller.state.filteredNotifications.length, equals(1));
      expect(controller.state.filteredNotifications.first.id, equals(readExpiryNotif.id));

      // Filter by claim_update
      controller.setFilter('claim_update');
      expect(controller.state.filteredNotifications.length, equals(1));
      expect(controller.state.filteredNotifications.first.id, equals(unreadClaimNotif.id));

      // Filter all
      controller.setFilter('all');
      expect(controller.state.filteredNotifications.length, equals(2));
    });

    test('fetchNotifications sets errorMessage on failure', () async {
      when(() => mockNotificationRepo.fetchNotifications())
          .thenThrow(const ServerException(message: 'Failed to fetch notification feed'));

      final controller = NotificationsController(mockNotificationRepo, null);
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.isLoading, isFalse);
      expect(controller.state.errorMessage, isNotNull);
      expect(controller.state.errorMessage, contains('Failed to fetch notification feed'));
    });
  });
}

