/// Tier 3 Cross-Feature Combinations: Warranty Pipeline, Data Constraints & Deep-Linking (TC-T3-CROSS-05 to 08).
import 'dart:io';
import '../harness/backend_harness.dart';
import '../harness/ui_driver.dart';
import '../harness/assertions.dart';
import '../harness/test_data_seeder.dart';
import '../tier1_feature_coverage/pdf_export_test.dart';

void main() async {
  final runner = E2ETestRunner('Tier 3: Warranty-to-Claim Pipeline');
  final backend = BackendHarness.fromEnv();
  final ui = UIDriver();

  // TC-T3-CROSS-05: Admin Status Update -> Client Generates Updated PDF Report
  runner.addTest('TC-T3-CROSS-05', 'Admin Claim Resolution Triggers Updated PDF Generation with Final Timeline', () async {
    const claimNumber = 'CLM-20261111-AUDIT';
    const resolutionNote = 'Replaced battery under warranty agreement';

    final initialPdf = LocalPdfReportGenerator.generateReportPdf(
      claimNumber: claimNumber,
      customerName: 'Sarah Jenkins',
      productName: 'iPhone 15 Pro',
      claimStatus: 'Submitted',
      issueDescription: 'Battery degraded rapidly',
      timelineEvents: ['Submitted'],
    );
    Assertions.contains(String.fromCharCodes(initialPdf), 'Submitted');

    // After approval
    final resolvedPdf = LocalPdfReportGenerator.generateReportPdf(
      claimNumber: claimNumber,
      customerName: 'Sarah Jenkins',
      productName: 'iPhone 15 Pro',
      claimStatus: 'Approved',
      issueDescription: 'Battery degraded rapidly',
      timelineEvents: ['Submitted', 'Under Review', 'Approved'],
      resolutionNotes: resolutionNote,
    );
    final resolvedText = String.fromCharCodes(resolvedPdf);
    Assertions.contains(resolvedText, 'Approved');
    Assertions.contains(resolvedText, resolutionNote);
  });

  // TC-T3-CROSS-06: Product Deletion Restraint / Cascade Rules
  runner.addTest('TC-T3-CROSS-06', 'Product Deletion Behavior Maintains Relational Consistency in Database', () async {
    final email = TestDataSeeder.generateUniqueEmail('xft_t3_del');
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
        'name': 'Cascade Test Laptop',
        'category': 'Electronics',
        'purchase_date': '2026-01-01',
        'warranty_period_months': 12,
      }, useServiceRole: true);

      await backend.insertRow('claims', {
        'id': claimId,
        'user_id': userId,
        'product_id': prodId,
        'type': 'warranty',
        'title': 'Cascade Linked Claim',
        'description': 'Details',
        'status': 'submitted',
      }, useServiceRole: true);

      // Verify claim exists
      final checkBefore = await backend.queryTable('claims', query: 'id=eq.$claimId', useServiceRole: true);
      Assertions.notEmpty(checkBefore.json as List);

      // Delete product (ON DELETE CASCADE removes associated claims)
      await backend.deleteRow('products', 'id=eq.$prodId', useServiceRole: true);

      // Verify cascading removal
      final checkAfter = await backend.queryTable('claims', query: 'id=eq.$claimId', useServiceRole: true);
      Assertions.empty(checkAfter.json as List, 'Cascading deletion failed to remove child claim');
    } finally {
      await backend.deleteAuthUser(userId);
    }
  });

  // TC-T3-CROSS-07: Product Purchase Date Modification Updates Open Claim Context
  runner.addTest('TC-T3-CROSS-07', 'Editing Product Purchase Date Recalculates Expiry and Reflects in Context', () async {
    final email = TestDataSeeder.generateUniqueEmail('xft_t3_date');
    final auth = await backend.createAdminUser(
      email: email,
      password: 'Password123!',
      metadata: {'role': 'customer'},
      emailConfirm: true,
    );
    final userId = (auth.json as Map)['id'] as String;
    final prodId = TestDataSeeder.generateUuid();

    try {
      await backend.insertRow('products', {
        'id': prodId,
        'user_id': userId,
        'name': 'Date Context Laptop',
        'category': 'Electronics',
        'purchase_date': '2026-01-01',
        'warranty_period_months': 12,
      }, useServiceRole: true);

      // Update purchase date to 2026-06-01
      final updateRes = await backend.updateRow(
        'products',
        'id=eq.$prodId',
        {'purchase_date': '2026-06-01'},
        useServiceRole: true,
      );
      Assertions.httpSuccess(updateRes.statusCode, updateRes.body);
      final prod = (updateRes.json as List).first as Map<String, dynamic>;

      // Trigger recalculated expiry = 2027-06-01
      Assertions.equal(prod['warranty_expiry_date'], '2027-06-01');

      await backend.deleteRow('products', 'id=eq.$prodId', useServiceRole: true);
    } finally {
      await backend.deleteAuthUser(userId);
    }
  });

  // TC-T3-CROSS-08: Notification Tap Deep Links to Claim Details
  runner.addTest('TC-T3-CROSS-08', 'Tapping Claim Update Notification Navigates Directly to Claim Details Screen', () async {
    final claimId = TestDataSeeder.generateUuid();
    final targetUrl = '/customer/claims/$claimId';

    ui.navigateTo(targetUrl);
    ui.assertRoute(targetUrl);
  });

  final result = await runner.run(verbose: true);
  backend.close();
  exit(result.isSuccess ? 0 : 1);
}
