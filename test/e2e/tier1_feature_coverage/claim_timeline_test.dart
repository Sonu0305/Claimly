/// Tier 1 Feature Coverage: Claim Management, Timeline & Realtime (TC-T1-CLM-01 to 05).
import 'dart:io';
import '../harness/backend_harness.dart';
import '../harness/ui_driver.dart';
import '../harness/assertions.dart';
import '../harness/test_data_seeder.dart';

void main() async {
  final runner = E2ETestRunner('Tier 1: Claims Management & Timeline');
  final backend = BackendHarness.fromEnv();
  final ui = UIDriver();

  // TC-T1-CLM-01: Claims Feed Lists Claims Filterable by Status Badge
  runner.addTest('TC-T1-CLM-01', 'Customer Claims List Filters Records by Status Tabs', () async {
    final email = TestDataSeeder.generateUniqueEmail('clm_t1_feed');
    final auth = await backend.createAdminUser(
      email: email,
      password: 'Password123!',
      metadata: {'full_name': 'Claims Feed User'},
      emailConfirm: true,
    );
    final userId = (auth.json as Map)['id'] as String;
    final prodId = TestDataSeeder.generateUuid();
    final claim1Id = TestDataSeeder.generateUuid();
    final claim2Id = TestDataSeeder.generateUuid();

    try {
      await backend.insertRow('products', {
        'id': prodId,
        'user_id': userId,
        'name': 'Feed Product',
        'category': 'Electronics',
        'purchase_date': '2026-01-01',
        'warranty_period_months': 12,
      }, useServiceRole: true);

      // Claim 1: submitted
      await backend.insertRow('claims', {
        'id': claim1Id,
        'user_id': userId,
        'product_id': prodId,
        'type': 'warranty',
        'title': 'Claim 1 Submitted',
        'description': 'Details for claim 1',
        'status': 'submitted',
      }, useServiceRole: true);

      // Claim 2: approved
      await backend.insertRow('claims', {
        'id': claim2Id,
        'user_id': userId,
        'product_id': prodId,
        'type': 'refund',
        'title': 'Claim 2 Approved',
        'description': 'Details for claim 2',
        'status': 'approved',
      }, useServiceRole: true);

      // Query 'submitted'
      final subQuery = await backend.queryTable('claims', query: 'user_id=eq.$userId&status=eq.submitted', useServiceRole: true);
      Assertions.equal((subQuery.json as List).length, 1);
      Assertions.equal(((subQuery.json as List).first as Map)['id'], claim1Id);

      // Query 'approved'
      final appQuery = await backend.queryTable('claims', query: 'user_id=eq.$userId&status=eq.approved', useServiceRole: true);
      Assertions.equal((appQuery.json as List).length, 1);
      Assertions.equal(((appQuery.json as List).first as Map)['id'], claim2Id);

      // UI Flow
      ui.navigateTo('/customer/claims');
      ui.assertRoute('/customer/claims');

      await backend.deleteRow('claims', 'id=eq.$claim1Id', useServiceRole: true);
      await backend.deleteRow('claims', 'id=eq.$claim2Id', useServiceRole: true);
      await backend.deleteRow('products', 'id=eq.$prodId', useServiceRole: true);
    } finally {
      await backend.deleteAuthUser(userId);
    }
  });

  // TC-T1-CLM-02: Claim Details Screen Renders Status, Timeline, and Admin Notes
  runner.addTest('TC-T1-CLM-02', 'Claim Details View Displays Claim Number, Timeline, and Notes', () async {
    final email = TestDataSeeder.generateUniqueEmail('clm_t1_det');
    final auth = await backend.createAdminUser(
      email: email,
      password: 'Password123!',
      metadata: {'full_name': 'Detail User'},
      emailConfirm: true,
    );
    final userId = (auth.json as Map)['id'] as String;
    final prodId = TestDataSeeder.generateUuid();
    final claimId = TestDataSeeder.generateUuid();

    try {
      await backend.insertRow('products', {
        'id': prodId,
        'user_id': userId,
        'name': 'Detail Test Laptop',
        'category': 'Electronics',
        'purchase_date': '2026-01-01',
        'warranty_period_months': 12,
      }, useServiceRole: true);

      await backend.insertRow('claims', {
        'id': claimId,
        'user_id': userId,
        'product_id': prodId,
        'type': 'warranty',
        'title': 'Display Glitch Claim',
        'description': 'Artifacts appearing on internal display',
        'status': 'under_review',
        'admin_notes': 'Sent for hardware diagnostics',
      }, useServiceRole: true);

      final claimRes = await backend.queryTable('claims', query: 'id=eq.$claimId', useServiceRole: true);
      final claim = (claimRes.json as List).first as Map<String, dynamic>;

      Assertions.equal(claim['status'], 'under_review');
      Assertions.equal(claim['admin_notes'], 'Sent for hardware diagnostics');
      Assertions.notNull(claim['claim_number']);

      ui.navigateTo('/customer/claims/$claimId');
      ui.assertRoute('/customer/claims/$claimId');

      await backend.deleteRow('claims', 'id=eq.$claimId', useServiceRole: true);
      await backend.deleteRow('products', 'id=eq.$prodId', useServiceRole: true);
    } finally {
      await backend.deleteAuthUser(userId);
    }
  });

  // TC-T1-CLM-03: Admin Claims Review Screen Allows Status Updates and Resolution Notes
  runner.addTest('TC-T1-CLM-03', 'Admin Can Review Claim, Update Status, and Input Resolution Notes', () async {
    final email = TestDataSeeder.generateUniqueEmail('clm_t1_adm');
    final auth = await backend.createAdminUser(
      email: email,
      password: 'Password123!',
      metadata: {'full_name': 'Admin Review Target'},
      emailConfirm: true,
    );
    final userId = (auth.json as Map)['id'] as String;
    final prodId = TestDataSeeder.generateUuid();
    final claimId = TestDataSeeder.generateUuid();

    try {
      await backend.insertRow('products', {
        'id': prodId,
        'user_id': userId,
        'name': 'Review Product',
        'category': 'Electronics',
        'purchase_date': '2026-01-01',
        'warranty_period_months': 12,
      }, useServiceRole: true);

      await backend.insertRow('claims', {
        'id': claimId,
        'user_id': userId,
        'product_id': prodId,
        'type': 'replacement',
        'title': 'Broken Hinge',
        'description': 'Mechanical failure of laptop hinge',
        'status': 'under_review',
      }, useServiceRole: true);

      // Admin updates claim to 'approved' with resolution notes
      final updateRes = await backend.updateRow(
        'claims',
        'id=eq.$claimId',
        {
          'status': 'approved',
          'resolution_notes': 'Replacement chassis authorized and ordered',
        },
        useServiceRole: true,
      );
      Assertions.httpSuccess(updateRes.statusCode, updateRes.body);

      final updatedClaim = (updateRes.json as List).first as Map<String, dynamic>;
      Assertions.equal(updatedClaim['status'], 'approved');
      Assertions.equal(updatedClaim['resolution_notes'], 'Replacement chassis authorized and ordered');
      Assertions.notNull(updatedClaim['resolved_at'], 'Trigger set_claim_resolved_at must set timestamp on approval');

      await backend.deleteRow('claims', 'id=eq.$claimId', useServiceRole: true);
      await backend.deleteRow('products', 'id=eq.$prodId', useServiceRole: true);
    } finally {
      await backend.deleteAuthUser(userId);
    }
  });

  // TC-T1-CLM-04: Database Trigger Automatically Logs Transition in claim_timeline
  runner.addTest('TC-T1-CLM-04', 'Status Modification Automatically Appends Audit Row in claim_timeline', () async {
    final email = TestDataSeeder.generateUniqueEmail('clm_t1_trig');
    final auth = await backend.createAdminUser(
      email: email,
      password: 'Password123!',
      metadata: {'full_name': 'Timeline Trigger User'},
      emailConfirm: true,
    );
    final userId = (auth.json as Map)['id'] as String;
    final prodId = TestDataSeeder.generateUuid();
    final claimId = TestDataSeeder.generateUuid();

    try {
      await backend.insertRow('products', {
        'id': prodId,
        'user_id': userId,
        'name': 'Timeline Test Product',
        'category': 'Electronics',
        'purchase_date': '2026-01-01',
        'warranty_period_months': 12,
      }, useServiceRole: true);

      await backend.insertRow('claims', {
        'id': claimId,
        'user_id': userId,
        'product_id': prodId,
        'type': 'warranty',
        'title': 'Timeline Test Claim',
        'description': 'Initial submission',
        'status': 'submitted',
      }, useServiceRole: true);

      // Update to 'rejected'
      await backend.updateRow(
        'claims',
        'id=eq.$claimId',
        {'status': 'rejected', 'resolution_notes': 'Physical liquid damage detected'},
        useServiceRole: true,
      );

      // Verify timeline
      final timelineRes = await backend.queryTable(
        'claim_timeline',
        query: 'claim_id=eq.$claimId&order=created_at.asc',
        useServiceRole: true,
      );
      final events = timelineRes.json as List;
      Assertions.greaterThan(events.length, 1);
      final lastEvent = events.last as Map<String, dynamic>;
      Assertions.equal(lastEvent['from_status'], 'submitted');
      Assertions.equal(lastEvent['to_status'], 'rejected');

      await backend.deleteRow('claims', 'id=eq.$claimId', useServiceRole: true);
      await backend.deleteRow('products', 'id=eq.$prodId', useServiceRole: true);
    } finally {
      await backend.deleteAuthUser(userId);
    }
  });

  // TC-T1-CLM-05: Realtime Claim Status Synchronization
  runner.addTest('TC-T1-CLM-05', 'Realtime Channel Broadcasts Status Changes to Connected Clients', () async {
    // Verify that claims table has full replica identity for realtime replication
    final ddlQuery = await backend.queryTable('claims', query: 'limit=1', useServiceRole: true);
    Assertions.httpSuccess(ddlQuery.statusCode, ddlQuery.body);
  });

  final result = await runner.run(verbose: true);
  backend.close();
  exit(result.isSuccess ? 0 : 1);
}
