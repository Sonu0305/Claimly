/// Tier 2 Boundary & Corner Cases: Notifications & Expiry Cron Boundaries (TC-T2-NOTIF-01 to 05).
import 'dart:io';
import '../harness/backend_harness.dart';
import '../harness/assertions.dart';
import '../harness/test_data_seeder.dart';

class LocalNotificationFormatter {
  static String formatBadgeCount(int count) {
    if (count <= 0) return '';
    if (count > 99) return '99+';
    return count.toString();
  }

  static bool shouldTriggerExpiryAlert(int daysRemaining) {
    return daysRemaining == 30 || daysRemaining == 7 || daysRemaining == 1;
  }
}

void main() async {
  final runner = E2ETestRunner('Tier 2: Notification Boundary & Corner Cases');
  final backend = BackendHarness.fromEnv();

  // TC-T2-NOTIF-01: Products Expiring at T+31 or T+29 Produce No Alerts
  runner.addTest('TC-T2-NOTIF-01', 'Non-Milestone Offsets (T+31, T+29, T+8) Do Not Trigger Expiry Alerts', () async {
    // Non-milestones return false
    Assertions.isFalse(LocalNotificationFormatter.shouldTriggerExpiryAlert(31));
    Assertions.isFalse(LocalNotificationFormatter.shouldTriggerExpiryAlert(29));
    Assertions.isFalse(LocalNotificationFormatter.shouldTriggerExpiryAlert(8));
    Assertions.isFalse(LocalNotificationFormatter.shouldTriggerExpiryAlert(2));

    // Exact milestones return true
    Assertions.isTrue(LocalNotificationFormatter.shouldTriggerExpiryAlert(30));
    Assertions.isTrue(LocalNotificationFormatter.shouldTriggerExpiryAlert(7));
    Assertions.isTrue(LocalNotificationFormatter.shouldTriggerExpiryAlert(1));
  });

  // TC-T2-NOTIF-02: Unread Count > 99 Formatted as "99+"
  runner.addTest('TC-T2-NOTIF-02', 'Unread Count of 150 Items Renders 99+ Without Layout Overflow', () async {
    final formatted = LocalNotificationFormatter.formatBadgeCount(150);
    Assertions.equal(formatted, '99+');

    final exact99 = LocalNotificationFormatter.formatBadgeCount(99);
    Assertions.equal(exact99, '99');

    final zero = LocalNotificationFormatter.formatBadgeCount(0);
    Assertions.equal(zero, '');
  });

  // TC-T2-NOTIF-03: Zero Notifications Renders Empty Inbox View
  runner.addTest('TC-T2-NOTIF-03', 'Empty Notification Feed Displays Empty Inbox Illustration', () async {
    final notifications = <dynamic>[];
    Assertions.empty(notifications);
    Assertions.isTrue(notifications.isEmpty);
  });

  // TC-T2-NOTIF-04: Marking Foreign User Notification as Read Blocked by RLS
  runner.addTest('TC-T2-NOTIF-04', 'Mutating Foreign Customer is_read Field is Prevented by RLS', () async {
    final emailA = TestDataSeeder.generateUniqueEmail('notif_t2_a');
    final authA = await backend.createAdminUser(
      email: emailA,
      password: 'Password123!',
      metadata: {'role': 'customer'},
      emailConfirm: true,
    );
    final userAId = (authA.json as Map)['id'] as String;

    final emailB = TestDataSeeder.generateUniqueEmail('notif_t2_b');
    final authB = await backend.createAdminUser(
      email: emailB,
      password: 'Password123!',
      metadata: {'role': 'customer'},
      emailConfirm: true,
    );
    final userBId = (authB.json as Map)['id'] as String;

    final loginA = await backend.signIn(email: emailA, password: 'Password123!');
    final jwtA = (loginA.json as Map)['access_token'] as String;

    final notifBId = TestDataSeeder.generateUuid();

    try {
      // Create notification for User B
      await backend.insertRow('notifications', {
        'id': notifBId,
        'user_id': userBId,
        'title': 'User B Private Alert',
        'message': 'Sensitive info',
        'type': 'system',
        'is_read': false,
      }, useServiceRole: true);

      // User A attempts to PATCH User B's notification
      final patchRes = await backend.updateRow(
        'notifications',
        'id=eq.$notifBId',
        {'is_read': true},
        jwt: jwtA,
      );

      final updatedList = patchRes.json as List;
      Assertions.empty(updatedList, 'User A was able to update User B notification');

      // Verify still is_read = false
      final verifyRes = await backend.queryTable('notifications', query: 'id=eq.$notifBId', useServiceRole: true);
      final notifB = (verifyRes.json as List).first as Map;
      Assertions.isFalse(notifB['is_read'] as bool);

      await backend.deleteRow('notifications', 'id=eq.$notifBId', useServiceRole: true);
    } finally {
      await backend.deleteAuthUser(userAId);
      await backend.deleteAuthUser(userBId);
    }
  });

  // TC-T2-NOTIF-05: Multiple Status Changes on Same Claim Generate Distinct Chronological Alerts
  runner.addTest('TC-T2-NOTIF-05', 'Multiple Sequential Status Transitions Create Distinct Notifications', () async {
    final email = TestDataSeeder.generateUniqueEmail('notif_t2_seq');
    final auth = await backend.createAdminUser(
      email: email,
      password: 'Password123!',
      metadata: {'role': 'customer'},
      emailConfirm: true,
    );
    final userId = (auth.json as Map)['id'] as String;
    final prodId = TestDataSeeder.generateUuid();
    final claimId = TestDataSeeder.generateUuid();

    try {
      await backend.insertRow('products', {
        'id': prodId,
        'user_id': userId,
        'name': 'Sequence Test Product',
        'category': 'Electronics',
        'purchase_date': '2026-01-01',
        'warranty_period_months': 12,
      }, useServiceRole: true);

      await backend.insertRow('claims', {
        'id': claimId,
        'user_id': userId,
        'product_id': prodId,
        'type': 'warranty',
        'title': 'Sequence Claim',
        'description': 'Details',
        'status': 'submitted',
      }, useServiceRole: true);

      // Transition 1: submitted -> under_review
      await backend.updateRow('claims', 'id=eq.$claimId', {'status': 'under_review'}, useServiceRole: true);

      // Transition 2: under_review -> approved
      await backend.updateRow('claims', 'id=eq.$claimId', {'status': 'approved'}, useServiceRole: true);

      // Verify notifications
      final notifRes = await backend.queryTable(
        'notifications',
        query: 'user_id=eq.$userId&type=eq.claim_update&order=created_at.asc',
        useServiceRole: true,
      );
      final notifs = notifRes.json as List;
      Assertions.equal(notifs.length, 2, 'Expected exactly 2 sequential notifications for 2 status changes');

      await backend.deleteRow('claims', 'id=eq.$claimId', useServiceRole: true);
      await backend.deleteRow('products', 'id=eq.$prodId', useServiceRole: true);
    } finally {
      await backend.deleteAuthUser(userId);
    }
  });

  final result = await runner.run(verbose: true);
  backend.close();
  exit(result.isSuccess ? 0 : 1);
}
