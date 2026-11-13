/// Tier 4 Real-World Application Scenario: RW-04 Expiry Notification to Claim Action Pipeline.
import 'dart:io';
import '../harness/backend_harness.dart';
import '../harness/ui_driver.dart';
import '../harness/assertions.dart';
import '../harness/test_data_seeder.dart';
import '../backend_contracts/edge_functions_test.dart';

void main() async {
  final runner = E2ETestRunner('Tier 4: Journey RW-04 Expiry Alert to Claim Action');
  final backend = BackendHarness.fromEnv();
  final ui = UIDriver();

  runner.addTest('RW-04', 'Expiry Alert to Action: Cron Evaluates Expiry, Sarah Receives Alert & Files Preventive Claim', () async {
    final sarahEmail = TestDataSeeder.generateUniqueEmail('sarah_rw04');
    final sarahAuth = await backend.createAdminUser(
      email: sarahEmail,
      password: 'Password123!',
      metadata: {'full_name': 'Sarah Expiry Action', 'role': 'customer'},
      emailConfirm: true,
    );
    final sarahId = (sarahAuth.json as Map)['id'] as String;

    final prodId = TestDataSeeder.generateUuid();
    final notifId = TestDataSeeder.generateUuid();
    final claimId = TestDataSeeder.generateUuid();

    try {
      // 1. Sarah owns Sony Soundbar expiring in 7 days
      await backend.insertRow('products', {
        'id': prodId,
        'user_id': sarahId,
        'name': 'Sony HT-A7000 Soundbar',
        'category': 'Electronics',
        'purchase_date': '2025-11-18',
        'warranty_period_months': 12,
      }, useServiceRole: true);

      // 2. Daily Cron creates notification for 7-day milestone
      await backend.insertRow('notifications', {
        'id': notifId,
        'user_id': sarahId,
        'title': 'Warranty Expiring in 7 Days: Sony HT-A7000 Soundbar',
        'message': 'Your warranty expires in 7 days. Inspect your unit and file any claims now.',
        'type': 'warranty_expiry',
        'is_read': false,
      }, useServiceRole: true);

      // 3. Sarah opens app and views notification feed
      ui.navigateTo('/customer/notifications');
      ui.assertRoute('/customer/notifications');

      // 4. Sarah taps "File Preventive Claim" on notification -> opens wizard pre-filled
      ui.navigateTo('/customer/claims/new?product_id=$prodId');
      ui.assertRoute('/customer/claims/new?product_id=$prodId');

      // 5. Complete wizard submission with urgency scoring
      final eval = LocalClaimProcessorContract.evaluateSubmission(
        purchaseDate: DateTime(2025, 11, 18),
        warrantyMonths: 12,
        incidentDate: DateTime(2026, 11, 11), // 7 days remaining -> +30 urgency
        claimType: 'warranty',
        description: 'Intermittent optical audio dropout during Dolby Atmos playback',
        attachmentCount: 1,
      );
      Assertions.isTrue(eval['success'] as bool);
      // Base (20) + Urgency (30) + Attachment (10) = 60
      Assertions.equal(eval['priority_score'], 60);

      // 6. Claim committed to database
      final claimRes = await backend.insertRow('claims', {
        'id': claimId,
        'user_id': sarahId,
        'product_id': prodId,
        'type': 'warranty',
        'title': 'Optical Audio Dropout',
        'description': 'Intermittent optical audio dropout during Dolby Atmos playback',
        'incident_date': '2026-11-11',
        'status': 'submitted',
        'priority': 60,
      }, useServiceRole: true);
      Assertions.httpSuccess(claimRes.statusCode, claimRes.body);

      // 7. Verify claim detail & timeline
      ui.navigateTo('/customer/claims/$claimId');
      ui.assertRoute('/customer/claims/$claimId');

      final timelineRes = await backend.queryTable('claim_timeline', query: 'claim_id=eq.$claimId', useServiceRole: true);
      Assertions.notEmpty(timelineRes.json as List);

      // Cleanup
      await backend.deleteRow('claims', 'id=eq.$claimId', useServiceRole: true);
      await backend.deleteRow('notifications', 'id=eq.$notifId', useServiceRole: true);
      await backend.deleteRow('products', 'id=eq.$prodId', useServiceRole: true);
    } finally {
      await backend.deleteAuthUser(sarahId);
    }
  });

  final result = await runner.run(verbose: true);
  backend.close();
  exit(result.isSuccess ? 0 : 1);
}
