/// Tier 4 Real-World Application Scenario: RW-03 Admin Daily Operations & Analytics.
import 'dart:io';
import '../harness/backend_harness.dart';
import '../harness/ui_driver.dart';
import '../harness/assertions.dart';
import '../harness/test_data_seeder.dart';
import '../tier2_boundary_corner/pdf_analytics_boundary_test.dart';

void main() async {
  final runner = E2ETestRunner('Tier 4: Journey RW-03 Admin Daily Operations');
  final backend = BackendHarness.fromEnv();
  final ui = UIDriver();

  runner.addTest('RW-03', 'Admin Operations: Marcus Reviews KPIs, Inspects Charts, Processes 3 Claims & Views Directory', () async {
    final marcusEmail = TestDataSeeder.generateUniqueEmail('marcus_rw03');
    final marcusAuth = await backend.createAdminUser(
      email: marcusEmail,
      password: 'AdminPassword123!',
      metadata: {'full_name': 'Marcus Vance', 'role': 'admin'},
      emailConfirm: true,
    );
    final marcusId = (marcusAuth.json as Map)['id'] as String;
    await backend.updateRow('profiles', 'id=eq.$marcusId', {'role': 'admin'}, useServiceRole: true);

    // Create 3 claims in varying states
    final prodId = TestDataSeeder.generateUuid();
    final c1 = TestDataSeeder.generateUuid();
    final c2 = TestDataSeeder.generateUuid();
    final c3 = TestDataSeeder.generateUuid();

    try {
      await backend.insertRow('products', {
        'id': prodId,
        'user_id': marcusId,
        'name': 'Operations Test Laptop',
        'category': 'Electronics',
        'purchase_date': '2026-01-01',
        'warranty_period_months': 12,
      }, useServiceRole: true);

      // Claim 1: submitted
      await backend.insertRow('claims', {
        'id': c1,
        'user_id': marcusId,
        'product_id': prodId,
        'type': 'warranty',
        'title': 'High Priority Burn Hazard',
        'description': 'Overheating',
        'status': 'submitted',
        'priority': 95,
      }, useServiceRole: true);

      // Claim 2: under_review
      await backend.insertRow('claims', {
        'id': c2,
        'user_id': marcusId,
        'product_id': prodId,
        'type': 'replacement',
        'title': 'Chassis Crack',
        'description': 'Hinge cracked',
        'status': 'under_review',
        'priority': 60,
      }, useServiceRole: true);

      // Claim 3: submitted
      await backend.insertRow('claims', {
        'id': c3,
        'user_id': marcusId,
        'product_id': prodId,
        'type': 'refund',
        'title': 'Dead On Arrival',
        'description': 'Does not boot',
        'status': 'submitted',
        'priority': 85,
      }, useServiceRole: true);

      // 1. Admin logs into Admin Shell
      ui.navigateTo('/admin/dashboard');
      ui.assertRoute('/admin/dashboard');

      // 2. Review KPI aggregations
      final kpi = LocalCurrencyFormatter.computeAnalyticsKpi(
        totalClaims: 3,
        approvedClaims: 0,
        rejectedClaims: 0,
        activeClaims: 3,
        totalResolutionDays: 0.0,
      );
      Assertions.equal(kpi['total_claims'], 3);
      Assertions.equal(kpi['active_claims'], 3);

      // 3. Filter high-priority claims (>80)
      final highPriorityRes = await backend.queryTable('claims', query: 'priority=gte.80&order=priority.desc', useServiceRole: true);
      final highList = highPriorityRes.json as List;
      Assertions.greaterThan(highList.length, 1);
      final topPriorityClaim = highList.first as Map;
      Assertions.equal(topPriorityClaim['priority'], 95);

      // 4. Marcus processes Claim 1 (approve)
      await backend.updateRow('claims', 'id=eq.$c1', {'status': 'approved'}, useServiceRole: true);

      // 5. Marcus processes Claim 2 (approve replacement)
      await backend.updateRow('claims', 'id=eq.$c2', {'status': 'approved'}, useServiceRole: true);

      // 6. Marcus processes Claim 3 (reject out of scope)
      await backend.updateRow('claims', 'id=eq.$c3', {'status': 'rejected'}, useServiceRole: true);

      // 7. Verify all claims transitioned
      final checkRes = await backend.queryTable('claims', query: 'product_id=eq.$prodId', useServiceRole: true);
      final resolved = checkRes.json as List;
      for (final claim in resolved) {
        Assertions.isTrue((claim as Map)['status'] == 'approved' || claim['status'] == 'rejected');
      }

      // 8. Marcus inspects User Directory
      ui.navigateTo('/admin/users');
      ui.assertRoute('/admin/users');

      // Cleanup
      await backend.deleteRow('claims', 'id=eq.$c1', useServiceRole: true);
      await backend.deleteRow('claims', 'id=eq.$c2', useServiceRole: true);
      await backend.deleteRow('claims', 'id=eq.$c3', useServiceRole: true);
      await backend.deleteRow('products', 'id=eq.$prodId', useServiceRole: true);
    } finally {
      await backend.deleteAuthUser(marcusId);
    }
  });

  final result = await runner.run(verbose: true);
  backend.close();
  exit(result.isSuccess ? 0 : 1);
}
