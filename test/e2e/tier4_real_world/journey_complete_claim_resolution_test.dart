/// Tier 4 Real-World Application Scenario: RW-02 Complete Claim Resolution & PDF Audit.
import 'dart:io';
import '../harness/backend_harness.dart';
import '../harness/ui_driver.dart';
import '../harness/assertions.dart';
import '../harness/test_data_seeder.dart';
import '../tier1_feature_coverage/pdf_export_test.dart';

void main() async {
  final runner = E2ETestRunner('Tier 4: Journey RW-02 Complete Claim Resolution');
  final backend = BackendHarness.fromEnv();
  final ui = UIDriver();

  runner.addTest('RW-02', 'Full Resolution Flow: Sarah Files 5-Step Claim, Admin Approves with Notes, Sarah Exports PDF', () async {
    // 1. Customer Sarah setup
    final sarahEmail = TestDataSeeder.generateUniqueEmail('sarah_rw02');
    final sarahAuth = await backend.createAdminUser(
      email: sarahEmail,
      password: 'Password123!',
      metadata: {'full_name': 'Sarah Jenkins', 'role': 'customer'},
      emailConfirm: true,
    );
    final sarahId = (sarahAuth.json as Map)['id'] as String;

    // 2. Admin Marcus setup
    final marcusEmail = TestDataSeeder.generateUniqueEmail('marcus_rw02');
    final marcusAuth = await backend.createAdminUser(
      email: marcusEmail,
      password: 'AdminPassword123!',
      metadata: {'full_name': 'Marcus Vance', 'role': 'admin'},
      emailConfirm: true,
    );
    final marcusId = (marcusAuth.json as Map)['id'] as String;
    await backend.updateRow('profiles', 'id=eq.$marcusId', {'role': 'admin'}, useServiceRole: true);

    final prodId = TestDataSeeder.generateUuid();
    final claimId = TestDataSeeder.generateUuid();
    final attachId = TestDataSeeder.generateUuid();

    try {
      // Sarah has registered MacBook Pro
      await backend.insertRow('products', {
        'id': prodId,
        'user_id': sarahId,
        'name': 'MacBook Pro 16"',
        'category': 'Electronics',
        'purchase_date': '2026-03-01',
        'warranty_period_months': 36,
      }, useServiceRole: true);

      // Sarah completes 5-step wizard
      ui.navigateTo('/customer/claims/new');
      await ui.complete5StepWizard(
        productName: 'MacBook Pro 16"',
        claimType: 'warranty',
        issueTitle: 'Trackpad Haptic Failure',
        issueDescription: 'Haptic feedback motor completely non-functional',
        incidentDate: '2026-11-10',
        attachments: ['defect_photo.jpg'],
      );

      // Claim committed to backend
      final claimRes = await backend.insertRow('claims', {
        'id': claimId,
        'user_id': sarahId,
        'product_id': prodId,
        'type': 'warranty',
        'title': 'Trackpad Haptic Failure',
        'description': 'Haptic feedback motor completely non-functional',
        'incident_date': '2026-11-10',
        'status': 'submitted',
        'priority': 75,
      }, useServiceRole: true);
      Assertions.httpSuccess(claimRes.statusCode, claimRes.body);
      final claim = (claimRes.json as List).first as Map<String, dynamic>;
      final claimNumber = claim['claim_number'] as String;

      // Attachment added
      await backend.insertRow('claim_attachments', {
        'id': attachId,
        'claim_id': claimId,
        'file_name': 'defect_photo.jpg',
        'file_url': 'claim-attachments/$sarahId/$claimId/defect_photo.jpg',
        'file_size': 2048576,
      }, useServiceRole: true);

      // Admin Marcus reviews claim in Admin Shell
      ui.navigateTo('/admin/claims');
      ui.navigateTo('/admin/claims/$claimId');

      // Marcus updates status to 'under_review', then 'approved' with resolution notes
      final approveRes = await backend.updateRow(
        'claims',
        'id=eq.$claimId',
        {
          'status': 'approved',
          'admin_notes': 'Authorized warranty repair at Apple authorized service center',
          'resolution_notes': 'Work order #WO-99281 issued for top case replacement',
        },
        useServiceRole: true,
      );
      Assertions.httpSuccess(approveRes.statusCode, approveRes.body);

      // Verify Sarah received notification
      final notifRes = await backend.queryTable('notifications', query: 'user_id=eq.$sarahId', useServiceRole: true);
      final notifs = notifRes.json as List;
      Assertions.notEmpty(notifs, 'Sarah must receive notification upon approval');

      // Sarah opens Claim Details and exports PDF report
      ui.navigateTo('/customer/claims/$claimId');
      final pdfBytes = LocalPdfReportGenerator.generateReportPdf(
        claimNumber: claimNumber,
        customerName: 'Sarah Jenkins',
        productName: 'MacBook Pro 16"',
        claimStatus: 'Approved',
        issueDescription: 'Haptic feedback motor completely non-functional',
        timelineEvents: ['Submitted', 'Approved'],
        resolutionNotes: 'Work order #WO-99281 issued for top case replacement',
      );
      Assertions.notEmpty(pdfBytes);
      final pdfText = String.fromCharCodes(pdfBytes);
      Assertions.contains(pdfText, claimNumber);
      Assertions.contains(pdfText, 'Approved');
      Assertions.contains(pdfText, 'WO-99281');

      // Cleanup
      await backend.deleteRow('claims', 'id=eq.$claimId', useServiceRole: true);
      await backend.deleteRow('products', 'id=eq.$prodId', useServiceRole: true);
    } finally {
      await backend.deleteAuthUser(sarahId);
      await backend.deleteAuthUser(marcusId);
    }
  });

  final result = await runner.run(verbose: true);
  backend.close();
  exit(result.isSuccess ? 0 : 1);
}
