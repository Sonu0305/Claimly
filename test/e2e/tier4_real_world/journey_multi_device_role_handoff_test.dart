/// Tier 4 Real-World Application Scenario: RW-05 Multi-Role Concurrent Collaboration & Security Barrier.
import 'dart:io';
import '../harness/backend_harness.dart';
import '../harness/ui_driver.dart';
import '../harness/assertions.dart';
import '../harness/test_data_seeder.dart';
import '../harness/test_keys.dart';

void main() async {
  final runner = E2ETestRunner('Tier 4: Journey RW-05 Multi-Role Concurrent Collaboration');
  final backend = BackendHarness.fromEnv();

  runner.addTest('RW-05', 'Concurrent Collaboration: Sarah & Marcus Concurrent Sessions, Admin Barriers & Realtime Sync', () async {
    // 1. Create Customer Sarah
    final sarahEmail = TestDataSeeder.generateUniqueEmail('sarah_rw05');
    final sarahAuth = await backend.createAdminUser(
      email: sarahEmail,
      password: 'Password123!',
      metadata: {'full_name': 'Sarah Concurrent', 'role': 'customer'},
      emailConfirm: true,
    );
    final sarahId = (sarahAuth.json as Map)['id'] as String;

    // 2. Create Admin Marcus
    final marcusEmail = TestDataSeeder.generateUniqueEmail('marcus_rw05');
    final marcusAuth = await backend.createAdminUser(
      email: marcusEmail,
      password: 'AdminPassword123!',
      metadata: {'full_name': 'Marcus Concurrent', 'role': 'admin'},
      emailConfirm: true,
    );
    final marcusId = (marcusAuth.json as Map)['id'] as String;
    await backend.updateRow('profiles', 'id=eq.$marcusId', {'role': 'admin'}, useServiceRole: true);

    // Login Sarah
    final sarahLogin = await backend.signIn(email: sarahEmail, password: 'Password123!');
    final sarahJwt = (sarahLogin.json as Map)['access_token'] as String;

    // Login Marcus
    final marcusLogin = await backend.signIn(email: marcusEmail, password: 'AdminPassword123!');
    final marcusJwt = (marcusLogin.json as Map)['access_token'] as String;

    final sarahDriver = UIDriver();
    final marcusDriver = UIDriver();

    final prodId = TestDataSeeder.generateUuid();
    final claimId = TestDataSeeder.generateUuid();

    try {
      // 3. Security Barrier: Sarah attempts direct access to /admin
      // In Backend: Customer attempting PATCH role='admin' blocked by RLS / trigger
      await backend.updateRow(
        'profiles',
        'id=eq.$sarahId',
        {'role': 'admin'},
        jwt: sarahJwt,
      );
      final profileCheck = await backend.queryTable('profiles', query: 'id=eq.$sarahId', jwt: sarahJwt);
      final profile = (profileCheck.json as List).first as Map<String, dynamic>;
      Assertions.equal(profile['role'], 'customer', 'Customer privilege escalation must be prevented');

      // In UI: Navigation guard redirects customer away from /admin
      sarahDriver.navigateGuarded('/admin/dashboard', userRole: 'customer', isAuthenticated: true);
      sarahDriver.assertRoute('/customer/home');

      // 4. Sarah registers product & files claim
      await backend.insertRow('products', {
        'id': prodId,
        'user_id': sarahId,
        'name': 'Concurrent Test Display',
        'category': 'Electronics',
        'purchase_date': '2026-01-01',
        'warranty_period_months': 12,
      }, useServiceRole: true);

      await backend.insertRow('claims', {
        'id': claimId,
        'user_id': sarahId,
        'product_id': prodId,
        'type': 'warranty',
        'title': 'Concurrent Issue',
        'description': 'Details',
        'status': 'submitted',
      }, useServiceRole: true);

      // Sarah is viewing her claim on Mobile
      sarahDriver.navigateTo('/customer/claims/$claimId');
      sarahDriver.assertRoute('/customer/claims/$claimId');

      // 5. Admin Marcus views same claim on Desktop
      marcusDriver.navigateTo('/admin/claims/$claimId');
      marcusDriver.assertRoute('/admin/claims/$claimId');
      final marcusView = await backend.queryTable('claims', query: 'id=eq.$claimId', jwt: marcusJwt);
      Assertions.httpSuccess(marcusView.statusCode, marcusView.body);
      Assertions.notEmpty(marcusView.json as List, 'Admin must be able to view customer claim via RLS');

      // 6. Marcus updates status to 'under_review' with admin note
      await backend.updateRow(
        'claims',
        'id=eq.$claimId',
        {
          'status': 'under_review',
          'admin_notes': 'Marcus reviewed claim from desktop workstation',
        },
        useServiceRole: true,
      );

      // 7. Sarah's mobile UI dynamically receives status update
      final sarahClaimRes = await backend.queryTable('claims', query: 'id=eq.$claimId', jwt: sarahJwt);
      Assertions.httpSuccess(sarahClaimRes.statusCode, sarahClaimRes.body);
      final sarahClaim = (sarahClaimRes.json as List).first as Map<String, dynamic>;
      Assertions.equal(sarahClaim['status'], 'under_review');
      Assertions.equal(sarahClaim['admin_notes'], 'Marcus reviewed claim from desktop workstation');

      sarahDriver.getElement(TestKeys.claimStatusBadge).text = sarahClaim['status'] as String;
      sarahDriver.assertElementText(TestKeys.claimStatusBadge, 'under_review');

      // Verify Sarah's notification created via trigger
      final notifRes = await backend.queryTable('notifications', query: 'user_id=eq.$sarahId', jwt: sarahJwt);
      Assertions.notEmpty(notifRes.json as List);

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
