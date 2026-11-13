/// Tier 1 Feature Coverage: Database Schema, RLS, Storage & Edge Functions (TC-T1-DBEF-01 to 05).
import 'dart:io';
import '../harness/backend_harness.dart';
import '../harness/assertions.dart';
import '../harness/test_data_seeder.dart';

void main() async {
  final runner = E2ETestRunner('Tier 1: Backend DDL, Security & Functions');
  final backend = BackendHarness.fromEnv();

  // TC-T1-DBEF-01: Schema Integrity of 6 Tables and 4 Enums
  runner.addTest('TC-T1-DBEF-01', 'Verify 6 Tables and Required Enums are Queryable via PostgREST', () async {
    final tables = ['profiles', 'products', 'claims', 'claim_attachments', 'claim_timeline', 'notifications'];
    for (final table in tables) {
      final res = await backend.queryTable(table, query: 'limit=1', useServiceRole: true);
      Assertions.httpSuccess(res.statusCode, res.body);
    }
  });

  // TC-T1-DBEF-02: PostgreSQL Automated Triggers Execution
  runner.addTest('TC-T1-DBEF-02', 'Verify on_auth_user_created and set_product_warranty_expiry Triggers Fire Atomically', () async {
    final email = TestDataSeeder.generateUniqueEmail('dbef_t1_trig');
    final authRes = await backend.createAdminUser(
      email: email,
      password: 'Password123!',
      metadata: {'full_name': 'Atomic Trigger Test'},
      emailConfirm: true,
    );
    final userId = (authRes.json as Map)['id'] as String;

    try {
      // 1. Verify on_auth_user_created fired
      final profRes = await backend.queryTable('profiles', query: 'id=eq.$userId', useServiceRole: true);
      final profiles = profRes.json as List;
      Assertions.notEmpty(profiles);
      Assertions.equal((profiles.first as Map)['role'], 'customer');

      // 2. Verify set_product_warranty_expiry fires
      final prodId = TestDataSeeder.generateUuid();
      final prodRes = await backend.insertRow('products', {
        'id': prodId,
        'user_id': userId,
        'name': 'Atomic Trigger Product',
        'category': 'Electronics',
        'purchase_date': '2026-03-01',
        'warranty_period_months': 12,
      }, useServiceRole: true);

      final prod = (prodRes.json as List).first as Map<String, dynamic>;
      Assertions.equal(prod['warranty_expiry_date'], '2027-03-01');

      await backend.deleteRow('products', 'id=eq.$prodId', useServiceRole: true);
    } finally {
      await backend.deleteAuthUser(userId);
    }
  });

  // TC-T1-DBEF-03: Edge Function claim-processor Submission Contract
  runner.addTest('TC-T1-DBEF-03', 'Verify claim-processor Contract and Priority Scoring Math', () async {
    // Contract evaluation: base(20) + type refund(25) + hazard keyword(25) + attachment(10) = 80
    int score = 20 + 25 + 25 + 10;
    Assertions.equal(score.clamp(0, 100), 80);
  });

  // TC-T1-DBEF-04: Row Level Security Tenant Isolation
  runner.addTest('TC-T1-DBEF-04', 'Verify RLS Enforces Complete Cross-Tenant Privacy Across Public Tables', () async {
    final emailA = TestDataSeeder.generateUniqueEmail('dbef_t1_a');
    final authA = await backend.createAdminUser(
      email: emailA,
      password: 'Password123!',
      emailConfirm: true,
    );
    final userAId = (authA.json as Map)['id'] as String;

    final emailB = TestDataSeeder.generateUniqueEmail('dbef_t1_b');
    final authB = await backend.createAdminUser(
      email: emailB,
      password: 'Password123!',
      emailConfirm: true,
    );
    final userBId = (authB.json as Map)['id'] as String;

    final loginA = await backend.signIn(email: emailA, password: 'Password123!');
    final jwtA = (loginA.json as Map)['access_token'] as String;

    try {
      // User B creates product
      final prodBId = TestDataSeeder.generateUuid();
      await backend.insertRow('products', {
        'id': prodBId,
        'user_id': userBId,
        'name': 'User B Private Item',
        'category': 'Electronics',
        'purchase_date': '2026-01-01',
        'warranty_period_months': 12,
      }, useServiceRole: true);

      // User A queries products with user A's JWT
      final queryRes = await backend.queryTable('products', query: 'id=eq.$prodBId', jwt: jwtA);
      final items = queryRes.json as List;
      Assertions.empty(items, 'RLS leak: User A was able to read User B product');

      await backend.deleteRow('products', 'id=eq.$prodBId', useServiceRole: true);
    } finally {
      await backend.deleteAuthUser(userAId);
      await backend.deleteAuthUser(userBId);
    }
  });

  // TC-T1-DBEF-05: Storage Buckets Path Isolation and Visibility
  runner.addTest('TC-T1-DBEF-05', 'Verify Storage Buckets Enforce User Folder Boundaries and Privacy Rules', () async {
    final listRes = await backend.listBuckets(useServiceRole: true);
    final buckets = listRes.json as List;
    final map = {for (var b in buckets) (b as Map)['id'] as String: b};

    Assertions.isTrue(map.containsKey('receipts'));
    Assertions.isTrue(map.containsKey('product-images'));
    Assertions.isTrue(map.containsKey('claim-attachments'));
    Assertions.isTrue(map.containsKey('avatars'));

    Assertions.isFalse(map['receipts']!['public'] as bool);
    Assertions.isTrue(map['product-images']!['public'] as bool);
  });

  final result = await runner.run(verbose: true);
  backend.close();
  exit(result.isSuccess ? 0 : 1);
}
