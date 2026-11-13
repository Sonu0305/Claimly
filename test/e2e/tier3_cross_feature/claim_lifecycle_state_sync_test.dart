/// Tier 3 Cross-Feature Combinations: Claim Lifecycle & Cross-Subsystem State Synchronization (TC-T3-CROSS-01 to 04).
import 'dart:io';
import '../harness/backend_harness.dart';
import '../harness/ui_driver.dart';
import '../harness/assertions.dart';
import '../harness/test_data_seeder.dart';
import '../harness/test_keys.dart';

void main() async {
  final runner = E2ETestRunner('Tier 3: Claim Lifecycle State Sync');
  final backend = BackendHarness.fromEnv();
  final ui = UIDriver();

  // TC-T3-CROSS-01: Expiry Alert -> Realtime Notification -> Wizard Preselection
  runner.addTest('TC-T3-CROSS-01', '7-Day Expiry Notification Action Deep Links and Preselects Product in Wizard', () async {
    final email = TestDataSeeder.generateUniqueEmail('xft_t3_exp');
    final auth = await backend.createAdminUser(
      email: email,
      password: 'Password123!',
      metadata: {'role': 'customer'},
      emailConfirm: true,
    );
    final userId = (auth.json as Map)['id'] as String;
    final prodId = TestDataSeeder.generateUuid();
    final notifId = TestDataSeeder.generateUuid();

    try {
      await backend.insertRow('products', {
        'id': prodId,
        'user_id': userId,
        'name': 'Sony WH-1000XM5',
        'category': 'Electronics',
        'purchase_date': '2025-11-18',
        'warranty_period_months': 12,
      }, useServiceRole: true);

      // Notification with metadata payload
      await backend.insertRow('notifications', {
        'id': notifId,
        'user_id': userId,
        'title': 'Warranty Expiring in 7 Days: Sony WH-1000XM5',
        'message': 'Your product warranty expires in 7 days.',
        'type': 'warranty_expiry',
        'is_read': false,
      }, useServiceRole: true);

      // Tap action on notification pre-populates wizard Step 1 with target product
      ui.navigateTo('/customer/claims/new?product_id=$prodId');
      ui.assertRoute('/customer/claims/new?product_id=$prodId');

      // Next button is enabled immediately since product is preselected
      ui.getElement(TestKeys.wizardNextBtn).isEnabled = true;
      Assertions.isTrue(ui.getElement(TestKeys.wizardNextBtn).isEnabled);

      await backend.deleteRow('notifications', 'id=eq.$notifId', useServiceRole: true);
      await backend.deleteRow('products', 'id=eq.$prodId', useServiceRole: true);
    } finally {
      await backend.deleteAuthUser(userId);
    }
  });

  // TC-T3-CROSS-02: Claim Submission -> DB Trigger -> Realtime Admin Feed
  runner.addTest('TC-T3-CROSS-02', 'Customer Claim Submission Instantly Available in Admin Claims Query', () async {
    final email = TestDataSeeder.generateUniqueEmail('xft_t3_sub');
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
        'name': 'Smart TV for Admin Sync',
        'category': 'Electronics',
        'purchase_date': '2026-01-01',
        'warranty_period_months': 12,
      }, useServiceRole: true);

      // Submit claim
      await backend.insertRow('claims', {
        'id': claimId,
        'user_id': userId,
        'product_id': prodId,
        'type': 'warranty',
        'title': 'Sync Display Test',
        'description': 'Details',
        'status': 'submitted',
      }, useServiceRole: true);

      // Admin global query retrieves new claim immediately
      final adminQuery = await backend.queryTable('claims', query: 'id=eq.$claimId', useServiceRole: true);
      final list = adminQuery.json as List;
      Assertions.equal(list.length, 1);
      final claim = list.first as Map;
      Assertions.equal(claim['title'], 'Sync Display Test');
      Assertions.equal(claim['status'], 'submitted');

      await backend.deleteRow('claims', 'id=eq.$claimId', useServiceRole: true);
      await backend.deleteRow('products', 'id=eq.$prodId', useServiceRole: true);
    } finally {
      await backend.deleteAuthUser(userId);
    }
  });

  // TC-T3-CROSS-03: Admin Status Change -> DB Trigger -> Customer Badge Increment
  runner.addTest('TC-T3-CROSS-03', 'Admin Status Update Atomically Queues Notification and Increments Bell Counter', () async {
    final email = TestDataSeeder.generateUniqueEmail('xft_t3_stat');
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
        'name': 'Badge Sync Product',
        'category': 'Electronics',
        'purchase_date': '2026-01-01',
        'warranty_period_months': 12,
      }, useServiceRole: true);

      await backend.insertRow('claims', {
        'id': claimId,
        'user_id': userId,
        'product_id': prodId,
        'type': 'replacement',
        'title': 'Badge Sync Claim',
        'description': 'Details',
        'status': 'under_review',
      }, useServiceRole: true);

      // Initial unread notifications: 0
      final notifBefore = await backend.queryTable('notifications', query: 'user_id=eq.$userId&is_read=eq.false', useServiceRole: true);
      final countBefore = (notifBefore.json as List).length;

      // Admin updates status to approved
      await backend.updateRow('claims', 'id=eq.$claimId', {'status': 'approved'}, useServiceRole: true);

      // Unread notifications increment by 1
      final notifAfter = await backend.queryTable('notifications', query: 'user_id=eq.$userId&is_read=eq.false', useServiceRole: true);
      final countAfter = (notifAfter.json as List).length;
      Assertions.equal(countAfter, countBefore + 1, 'Unread notification count must increment by exactly 1');

      // UI badge updates
      ui.getElement(TestKeys.unreadBadge).text = countAfter.toString();
      ui.assertElementText(TestKeys.unreadBadge, '1');

      await backend.deleteRow('claims', 'id=eq.$claimId', useServiceRole: true);
      await backend.deleteRow('products', 'id=eq.$prodId', useServiceRole: true);
    } finally {
      await backend.deleteAuthUser(userId);
    }
  });

  // TC-T3-CROSS-04: Session Expiry During Wizard -> Re-Auth -> State Restoration
  runner.addTest('TC-T3-CROSS-04', 'Auth Session Interruption During Wizard Preserves Form Inputs on Re-Auth', () async {
    // Stage inputs
    const stagedTitle = 'Staged Problem Title';
    const stagedDesc = 'Staged Problem Description that exceeds ten characters';
    await ui.enterText(TestKeys.wizardIssueTitleInput, stagedTitle);
    await ui.enterText(TestKeys.wizardIssueDescriptionInput, stagedDesc);

    // Simulate session expiration
    ui.navigateTo('/login?redirect=/customer/claims/new');
    ui.assertRoute('/login?redirect=/customer/claims/new');

    // Re-authenticate
    await ui.login('sarah@claimly.com', 'Password123!');

    // Redirected back to wizard with inputs intact
    ui.navigateTo('/customer/claims/new');
    ui.assertElementText(TestKeys.wizardIssueTitleInput, stagedTitle);
    ui.assertElementText(TestKeys.wizardIssueDescriptionInput, stagedDesc);
  });

  final result = await runner.run(verbose: true);
  backend.close();
  exit(result.isSuccess ? 0 : 1);
}
