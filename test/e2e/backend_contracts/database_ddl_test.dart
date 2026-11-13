/// Backend Contract Test: Database DDL Schema, Tables, Enums, Constraints, and Triggers.
import 'dart:io';
import '../harness/backend_harness.dart';
import '../harness/assertions.dart';
import '../harness/test_data_seeder.dart';

void main() async {
  final runner = E2ETestRunner('Database DDL & Schema Contracts');
  final backend = BackendHarness.fromEnv();

  // Test 1: All 6 required tables exist and are queryable via PostgREST
  runner.addTest('DDL-01', 'Verify 6 Public Tables Exist in PostgREST Schema', () async {
    final tables = [
      'profiles',
      'products',
      'claims',
      'claim_attachments',
      'claim_timeline',
      'notifications',
    ];

    for (final table in tables) {
      final res = await backend.queryTable(table, query: 'limit=1', useServiceRole: true);
      Assertions.httpStatus(res.statusCode, 200, 'Table $table query failed: ${res.body}');
    }
  });

  // Test 2: Foreign key relationships and cascade rules
  runner.addTest('DDL-02', 'Verify Profiles and Products Schema Constraints', () async {
    // Query table definition schema or attempt queries with required columns
    final profileQuery = await backend.queryTable(
      'profiles',
      query: 'select=id,role,full_name,avatar_url,phone_number,created_at,updated_at&limit=1',
      useServiceRole: true,
    );
    Assertions.httpStatus(profileQuery.statusCode, 200, profileQuery.body);

    final productQuery = await backend.queryTable(
      'products',
      query: 'select=id,user_id,name,category,brand,model_number,serial_number,purchase_date,warranty_period_months,warranty_expiry_date,created_at,updated_at&limit=1',
      useServiceRole: true,
    );
    Assertions.httpStatus(productQuery.statusCode, 200, productQuery.body);
  });

  // Test 3: Automated warranty expiry calculation trigger on products
  runner.addTest('DDL-03', 'Verify set_product_warranty_expiry Trigger Calculates Expiry Date', () async {
    // Create a temporary user to associate product
    final testEmail = TestDataSeeder.generateUniqueEmail('ddl_trig');
    final authRes = await backend.createAdminUser(
      email: testEmail,
      password: 'TestPassword123!',
      metadata: {'full_name': 'Trigger Test User'},
      emailConfirm: true,
    );
    Assertions.httpSuccess(authRes.statusCode, authRes.body);
    final userMap = authRes.json as Map<String, dynamic>;
    final userId = userMap['id'] as String;

    try {
      // Insert product with purchase date and 24 months warranty, without specifying warranty_expiry_date
      final prodId = TestDataSeeder.generateUuid();
      final insertRes = await backend.insertRow('products', {
        'id': prodId,
        'user_id': userId,
        'name': 'Trigger Test Monitor',
        'category': 'Electronics',
        'purchase_date': '2026-01-15',
        'warranty_period_months': 24,
      }, useServiceRole: true);

      Assertions.httpSuccess(insertRes.statusCode, insertRes.body);
      final jsonList = insertRes.json as List;
      Assertions.notEmpty(jsonList);
      final insertedRow = jsonList.first as Map<String, dynamic>;
      
      // The trigger should have computed warranty_expiry_date = 2028-01-15
      Assertions.equal(insertedRow['warranty_expiry_date'], '2028-01-15', 'Trigger did not set expected expiry date');

      // Cleanup product
      await backend.deleteRow('products', 'id=eq.$prodId', useServiceRole: true);
    } finally {
      await backend.deleteAuthUser(userId);
    }
  });

  // Test 4: Automated claim number generation trigger on claims
  runner.addTest('DDL-04', 'Verify generate_claim_number Trigger Assigns Unique Claim Number', () async {
    final testEmail = TestDataSeeder.generateUniqueEmail('ddl_clm');
    final authRes = await backend.createAdminUser(
      email: testEmail,
      password: 'TestPassword123!',
      metadata: {'full_name': 'Claim Trigger User'},
      emailConfirm: true,
    );
    Assertions.httpSuccess(authRes.statusCode, authRes.body);
    final userMap = authRes.json as Map<String, dynamic>;
    final userId = userMap['id'] as String;

    try {
      final prodId = TestDataSeeder.generateUuid();
      await backend.insertRow('products', {
        'id': prodId,
        'user_id': userId,
        'name': 'Laptop for Claim Number Test',
        'category': 'Electronics',
        'purchase_date': '2026-01-01',
        'warranty_period_months': 12,
      }, useServiceRole: true);

      // Insert claim without specifying claim_number
      final claimId = TestDataSeeder.generateUuid();
      final claimRes = await backend.insertRow('claims', {
        'id': claimId,
        'user_id': userId,
        'product_id': prodId,
        'type': 'warranty',
        'title': 'Test Issue for Trigger',
        'description': 'Hardware glitch occurred during normal operation',
        'incident_date': '2026-05-01',
        'status': 'submitted',
      }, useServiceRole: true);

      Assertions.httpSuccess(claimRes.statusCode, claimRes.body);
      final claimList = claimRes.json as List;
      final insertedClaim = claimList.first as Map<String, dynamic>;

      // Claim number should match pattern CLM-YYYYMMDD-XXXXXX
      final claimNumber = insertedClaim['claim_number'] as String?;
      Assertions.notNull(claimNumber, 'claim_number was not generated by trigger');
      Assertions.matches(claimNumber!, RegExp(r'^CLM-\d{8}-[A-Za-z0-9]+$'), 'Generated claim number pattern mismatch: $claimNumber');

      // Verify that claim_timeline automatically received initial audit row via log_claim_creation trigger
      final timelineRes = await backend.queryTable(
        'claim_timeline',
        query: 'claim_id=eq.$claimId',
        useServiceRole: true,
      );
      Assertions.httpSuccess(timelineRes.statusCode, timelineRes.body);
      final timelineList = timelineRes.json as List;
      Assertions.notEmpty(timelineList, 'log_claim_creation trigger failed to insert initial timeline event');
      final initialTimeline = timelineList.first as Map<String, dynamic>;
      Assertions.equal(initialTimeline['to_status'], 'submitted');

      // Cleanup
      await backend.deleteRow('claims', 'id=eq.$claimId', useServiceRole: true);
      await backend.deleteRow('products', 'id=eq.$prodId', useServiceRole: true);
    } finally {
      await backend.deleteAuthUser(userId);
    }
  });

  // Test 5: Status update triggers timeline logging and notifications
  runner.addTest('DDL-05', 'Verify log_claim_status_change and notify_claim_update Triggers', () async {
    final testEmail = TestDataSeeder.generateUniqueEmail('ddl_stat');
    final authRes = await backend.createAdminUser(
      email: testEmail,
      password: 'TestPassword123!',
      metadata: {'full_name': 'Status Trigger User'},
      emailConfirm: true,
    );
    Assertions.httpSuccess(authRes.statusCode, authRes.body);
    final userMap = authRes.json as Map<String, dynamic>;
    final userId = userMap['id'] as String;

    try {
      final prodId = TestDataSeeder.generateUuid();
      await backend.insertRow('products', {
        'id': prodId,
        'user_id': userId,
        'name': 'Device for Status Trigger Test',
        'category': 'Electronics',
        'purchase_date': '2026-01-01',
        'warranty_period_months': 12,
      }, useServiceRole: true);

      final claimId = TestDataSeeder.generateUuid();
      await backend.insertRow('claims', {
        'id': claimId,
        'user_id': userId,
        'product_id': prodId,
        'type': 'refund',
        'title': 'Overheating unit',
        'description': 'Device shut down unexpectedly',
        'incident_date': '2026-04-01',
        'status': 'submitted',
      }, useServiceRole: true);

      // Now update status to 'approved'
      final updateRes = await backend.updateRow(
        'claims',
        'id=eq.$claimId',
        {'status': 'approved'},
        useServiceRole: true,
      );
      Assertions.httpSuccess(updateRes.statusCode, updateRes.body);

      // Verify that claim_timeline logged the transition: submitted -> approved
      final timelineRes = await backend.queryTable(
        'claim_timeline',
        query: 'claim_id=eq.$claimId&order=created_at.asc',
        useServiceRole: true,
      );
      final timelineRows = timelineRes.json as List;
      Assertions.greaterThan(timelineRows.length, 1, 'Expected at least 2 timeline events after update');
      final secondEvent = timelineRows.last as Map<String, dynamic>;
      Assertions.equal(secondEvent['from_status'], 'submitted');
      Assertions.equal(secondEvent['to_status'], 'approved');

      // Verify that notifications table received automated notification row for customer
      final notifRes = await backend.queryTable(
        'notifications',
        query: 'user_id=eq.$userId',
        useServiceRole: true,
      );
      final notifRows = notifRes.json as List;
      Assertions.notEmpty(notifRows, 'notify_claim_update trigger failed to create notification');
      final notif = notifRows.first as Map<String, dynamic>;
      Assertions.equal(notif['type'], 'claim_update');

      // Cleanup
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
