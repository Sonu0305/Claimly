/// Tier 2 Boundary & Corner Cases: Security, Anti-Tamper & Injection Resilience (TC-T2-BE-01 to 05).
import 'dart:io';
import '../harness/backend_harness.dart';
import '../harness/assertions.dart';
import '../harness/test_data_seeder.dart';

void main() async {
  final runner = E2ETestRunner('Tier 2: Security & Backend Boundaries');
  final backend = BackendHarness.fromEnv();

  // TC-T2-BE-01: Customer Attempting Direct PATCH role='admin' Blocked
  runner.addTest('TC-T2-BE-01', 'Direct PATCH role=admin Blocked by protect_user_role Trigger', () async {
    final email = TestDataSeeder.generateUniqueEmail('sec_t2_role');
    final auth = await backend.createAdminUser(
      email: email,
      password: 'Password123!',
      metadata: {'role': 'customer'},
      emailConfirm: true,
    );
    final userId = (auth.json as Map)['id'] as String;
    final login = await backend.signIn(email: email, password: 'Password123!');
    final customerJwt = (login.json as Map)['access_token'] as String;

    try {
      final patchRes = await backend.updateRow(
        'profiles',
        'id=eq.$userId',
        {'role': 'admin'},
        jwt: customerJwt,
      );

      // Trigger throws exception or RLS blocks update
      if (patchRes.isSuccess) {
        final list = patchRes.json as List;
        if (list.isNotEmpty) {
          Assertions.notEqual((list.first as Map)['role'], 'admin');
        }
      } else {
        Assertions.inRange(patchRes.statusCode, 400, 499);
      }
    } finally {
      await backend.deleteAuthUser(userId);
    }
  });

  // TC-T2-BE-02: Storage Upload Without Auth Header Rejected
  runner.addTest('TC-T2-BE-02', 'Unauthenticated Storage Upload to Receipts Returns HTTP 400/401', () async {
    final res = await backend.uploadStorageObject('receipts', 'anon_hack.jpg', [0x00]);
    Assertions.isFalse(res.isSuccess, 'Unauthenticated storage upload must be rejected');
    Assertions.isTrue(res.statusCode == 400 || res.statusCode == 401 || res.statusCode == 403);
  });

  // TC-T2-BE-03: PostgREST Corrupted JWT Signature Rejection
  runner.addTest('TC-T2-BE-03', 'Corrupted JWT Bearer Signature Returns HTTP 401 PGRST301', () async {
    final res = await backend.queryTable('products', jwt: 'invalid.signature.bearer');
    Assertions.equal(res.statusCode, 401);
    Assertions.contains(res.body, 'PGRST301');
  });

  // TC-T2-BE-04: SQL Injection in Search Strings Sanitized Safely
  runner.addTest('TC-T2-BE-04', 'SQL Injection Strings in PostgREST Query Parameter Safely Sanitized', () async {
    const maliciousQuery = "name=ilike.%' OR '1'='1' --%";
    final res = await backend.queryTable('products', query: maliciousQuery, useServiceRole: true);

    // Either Cloudflare WAF thwarts attack with 403 or PostgREST sanitizes parameter with 200
    Assertions.isTrue(
      res.statusCode == 200 || res.statusCode == 403,
      'Unexpected response status for SQL injection string: ${res.statusCode}',
    );

    // Verify products table remains intact
    final checkTable = await backend.queryTable('products', query: 'limit=1', useServiceRole: true);
    Assertions.httpSuccess(checkTable.statusCode, checkTable.body);
  });

  // TC-T2-BE-05: Cross-Tenant Delete Affects Zero Rows
  runner.addTest('TC-T2-BE-05', 'Cross-Tenant DELETE Request on Foreign Product Affects 0 Rows', () async {
    final emailA = TestDataSeeder.generateUniqueEmail('sec_t2_del_a');
    final authA = await backend.createAdminUser(
      email: emailA,
      password: 'Password123!',
      metadata: {'role': 'customer'},
      emailConfirm: true,
    );
    final userAId = (authA.json as Map)['id'] as String;

    final emailB = TestDataSeeder.generateUniqueEmail('sec_t2_del_b');
    final authB = await backend.createAdminUser(
      email: emailB,
      password: 'Password123!',
      metadata: {'role': 'customer'},
      emailConfirm: true,
    );
    final userBId = (authB.json as Map)['id'] as String;

    final loginA = await backend.signIn(email: emailA, password: 'Password123!');
    final jwtA = (loginA.json as Map)['access_token'] as String;

    final prodBId = TestDataSeeder.generateUuid();

    try {
      await backend.insertRow('products', {
        'id': prodBId,
        'user_id': userBId,
        'name': 'User B Inviolable Laptop',
        'category': 'Electronics',
        'purchase_date': '2026-01-01',
        'warranty_period_months': 12,
      }, useServiceRole: true);

      // User A executes DELETE on User B's product
      final delRes = await backend.deleteRow('products', 'id=eq.$prodBId', jwt: jwtA);
      final list = delRes.json as List;
      Assertions.empty(list, 'Cross-tenant DELETE must affect 0 rows');

      // Verify product still intact
      final checkRes = await backend.queryTable('products', query: 'id=eq.$prodBId', useServiceRole: true);
      Assertions.notEmpty(checkRes.json as List);

      await backend.deleteRow('products', 'id=eq.$prodBId', useServiceRole: true);
    } finally {
      await backend.deleteAuthUser(userAId);
      await backend.deleteAuthUser(userBId);
    }
  });

  final result = await runner.run(verbose: true);
  backend.close();
  exit(result.isSuccess ? 0 : 1);
}
