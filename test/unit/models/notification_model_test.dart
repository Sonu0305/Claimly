import 'package:flutter_test/flutter_test.dart';
import 'package:claimly/features/customer/notifications/models/notification_model.dart';
import '../../test_helpers/test_fixtures.dart';

void main() {
  group('NotificationModel Tests', () {
    test('NotificationModel constructor and type getters', () {
      final notif = sampleNotification;

      expect(notif.isClaimUpdate, isTrue);
      expect(notif.isWarrantyExpiry, isFalse);
      expect(notif.isSystem, isFalse);

      final expiryNotif = NotificationModel(
        id: 'n-exp',
        userId: 'u1',
        type: 'warranty_expiry',
        title: 'Warranty Expiring',
        message: 'Your laptop warranty expires in 7 days.',
        createdAt: DateTime.now(),
      );
      expect(expiryNotif.isWarrantyExpiry, isTrue);

      final systemNotif = NotificationModel(
        id: 'n-sys',
        userId: 'u1',
        type: 'system',
        title: 'System Notice',
        message: 'Maintenance scheduled.',
        createdAt: DateTime.now(),
      );
      expect(systemNotif.isSystem, isTrue);
    });

    test('NotificationModel.fromJson parses payload with default values', () {
      final json = {
        'id': 'notif-99',
        'user_id': 'usr-99',
      };

      final parsed = NotificationModel.fromJson(json);

      expect(parsed.id, equals('notif-99'));
      expect(parsed.userId, equals('usr-99'));
      expect(parsed.type, equals('system'));
      expect(parsed.title, equals(''));
      expect(parsed.message, equals(''));
      expect(parsed.isRead, isFalse);
      expect(parsed.metadata, isEmpty);
      expect(parsed.createdAt, isNotNull);
    });

    test('NotificationModel.toJson serializes notification and metadata', () {
      final json = sampleNotification.toJson();

      expect(json['id'], equals('notif-001'));
      expect(json['user_id'], equals('usr-customer-001'));
      expect(json['claim_id'], equals('clm-001'));
      expect(json['type'], equals('claim_update'));
      expect(json['is_read'], isFalse);
      expect(json['metadata']['claim_number'], equals('CLM-2026-0001'));
    });

    test('NotificationModel copyWith and value equality', () {
      final original = sampleNotification;
      final markedRead = original.copyWith(isRead: true);

      expect(markedRead.id, equals(original.id));
      expect(markedRead.isRead, isTrue);
      expect(original == markedRead, isFalse);

      final identicalNotif = NotificationModel(
        id: original.id,
        userId: original.userId,
        claimId: original.claimId,
        type: original.type,
        title: original.title,
        message: original.message,
        isRead: original.isRead,
        metadata: original.metadata,
        createdAt: original.createdAt,
      );

      expect(identicalNotif == original, isTrue);
      expect(identicalNotif.hashCode, equals(original.hashCode));
    });
  });
}

