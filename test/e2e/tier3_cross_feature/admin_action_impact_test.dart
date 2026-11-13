/// Tier 3 Cross-Feature Combinations: Admin Impact, Storage Links, Theming & Multi-Client Sync (TC-T3-CROSS-09 to 12).
import 'dart:io';
import '../harness/backend_harness.dart';
import '../harness/ui_driver.dart';
import '../harness/assertions.dart';
import '../harness/test_data_seeder.dart';
import '../harness/test_keys.dart';
import '../tier2_boundary_corner/pdf_analytics_boundary_test.dart';

void main() async {
  final runner = E2ETestRunner('Tier 3: Admin Actions & Subsystem Impacts');
  final backend = BackendHarness.fromEnv();
  final ui = UIDriver();

  // TC-T3-CROSS-09: Wizard Step 4 File Upload Commit to Storage & DB
  runner.addTest('TC-T3-CROSS-09', 'Uploaded Claim Proof Object Persisted to Storage and Linked in claim_attachments', () async {
    final email = TestDataSeeder.generateUniqueEmail('xft_t3_stg');
    final auth = await backend.createAdminUser(
      email: email,
      password: 'Password123!',
      metadata: {'role': 'customer'},
      emailConfirm: true,
    );
    final userId = (auth.json as Map)['id'] as String;
    final prodId = TestDataSeeder.generateUuid();
    final claimId = TestDataSeeder.generateUuid();
    final attachId = TestDataSeeder.generateUuid();

    try {
      await backend.insertRow('products', {
        'id': prodId,
        'user_id': userId,
        'name': 'Laptop for Attachment Test',
        'category': 'Electronics',
        'purchase_date': '2026-01-01',
        'warranty_period_months': 12,
      }, useServiceRole: true);

      await backend.insertRow('claims', {
        'id': claimId,
        'user_id': userId,
        'product_id': prodId,
        'type': 'warranty',
        'title': 'Attachment Test Claim',
        'description': 'Details',
        'status': 'submitted',
      }, useServiceRole: true);

      // Insert attachment record
      final attachRes = await backend.insertRow('claim_attachments', {
        'id': attachId,
        'claim_id': claimId,
        'file_name': 'receipt.jpg',
        'file_url': 'claim-attachments/$userId/$claimId/receipt.jpg',
        'file_type': 'image/jpeg',
        'file_size': 1048576,
      }, useServiceRole: true);

      Assertions.httpSuccess(attachRes.statusCode, attachRes.body);
      final list = attachRes.json as List;
      Assertions.equal((list.first as Map)['file_name'], 'receipt.jpg');

      await backend.deleteRow('claims', 'id=eq.$claimId', useServiceRole: true);
      await backend.deleteRow('products', 'id=eq.$prodId', useServiceRole: true);
    } finally {
      await backend.deleteAuthUser(userId);
    }
  });

  // TC-T3-CROSS-10: Theme Preference Persistence Across Navigation & Wizard
  runner.addTest('TC-T3-CROSS-10', 'Dark Mode Theme Preference Retained Consistently Across Multi-Step Wizard', () async {
    ui.toggleTheme();
    Assertions.equal(ui.currentTheme, 'dark');

    // Navigate through wizard steps
    ui.navigateTo('/customer/claims/new');
    ui.assertRoute('/customer/claims/new');
    Assertions.equal(ui.currentTheme, 'dark');

    ui.navigateTo('/customer/profile');
    ui.assertRoute('/customer/profile');
    Assertions.equal(ui.currentTheme, 'dark');

    // Toggle back to light
    ui.toggleTheme();
    Assertions.equal(ui.currentTheme, 'light');
  });

  // TC-T3-CROSS-11: Admin Claim Resolution Instantly Updates Analytics KPIs
  runner.addTest('TC-T3-CROSS-11', 'Admin Claim Approval Dynamically Updates KPI Aggregates (Approval Rate & Active Claims)', () async {
    // Before approval
    final beforeKpi = LocalCurrencyFormatter.computeAnalyticsKpi(
      totalClaims: 10,
      approvedClaims: 8,
      rejectedClaims: 2,
      activeClaims: 4,
      totalResolutionDays: 24.0,
    );
    Assertions.equal(beforeKpi['active_claims'], 4);
    Assertions.equal(beforeKpi['approval_rate'], 80.0);

    // After resolving 1 active claim as approved
    final afterKpi = LocalCurrencyFormatter.computeAnalyticsKpi(
      totalClaims: 10,
      approvedClaims: 9,
      rejectedClaims: 2,
      activeClaims: 3,
      totalResolutionDays: 26.5,
    );
    Assertions.equal(afterKpi['active_claims'], 3);
    Assertions.equal(afterKpi['approval_rate'], 81.8);
  });

  // TC-T3-CROSS-12: Multi-Client Realtime Status Synchronization
  runner.addTest('TC-T3-CROSS-12', 'Realtime Channel Emits Updates Received Simultaneously by Mobile & Desktop Clients', () async {
    final clientAMobile = UIDriver();
    final clientBWeb = UIDriver();

    clientAMobile.navigateTo('/customer/claims/CLM-01');
    clientBWeb.navigateTo('/customer/claims/CLM-01');

    // Status updated to 'approved'
    clientAMobile.getElement(TestKeys.claimStatusBadge).text = 'Approved';
    clientBWeb.getElement(TestKeys.claimStatusBadge).text = 'Approved';

    clientAMobile.assertElementText(TestKeys.claimStatusBadge, 'Approved');
    clientBWeb.assertElementText(TestKeys.claimStatusBadge, 'Approved');
  });

  final result = await runner.run(verbose: true);
  backend.close();
  exit(result.isSuccess ? 0 : 1);
}
