import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:claimly/features/customer/notifications/repositories/notification_repository.dart';
import '../../test_helpers/mocks.dart';
import '../../test_helpers/test_fixtures.dart';

void main() {
  late MockSupabaseClient mockSupabase;
  late NotificationRepositoryImpl repository;

  setUpAll(() {
    registerCommonFallbackValues();
  });

  setUp(() {
    mockSupabase = MockSupabaseClient();
    repository = NotificationRepositoryImpl(mockSupabase);
  });

  group('NotificationRepositoryImpl Tests', () {
    test('fetchNotifications returns mapped NotificationModel list', () async {
      when(() => mockSupabase.from('notifications')).thenAnswer(
        (_) => FakeSupabaseQueryBuilder([sampleNotification.toJson()]),
      );

      final notifications = await repository.fetchNotifications();

      expect(notifications.length, equals(1));
      expect(notifications.first.id, equals(sampleNotification.id));
      expect(notifications.first.title, equals(sampleNotification.title));
    });

    test('getUnreadCount calculates unread notifications count', () async {
      when(() => mockSupabase.from('notifications')).thenAnswer(
        (_) => FakeSupabaseQueryBuilder([
          {'id': 'notif-1'},
          {'id': 'notif-2'},
        ]),
      );

      final count = await repository.getUnreadCount('usr-customer-001');

      expect(count, equals(2));
    });

    test('markAsRead updates is_read flag for notification id', () async {
      when(() => mockSupabase.from('notifications')).thenAnswer(
        (_) => FakeSupabaseQueryBuilder(null),
      );

      await expectLater(
        repository.markAsRead('notif-001'),
        completes,
      );
    });
  });
}
