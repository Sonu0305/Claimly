/// Backend Contract Test: Row Level Security (RLS) Policies, Tenant Isolation, and Role Escalation Guards.
import 'dart:io';
import '../harness/backend_harness.dart';
import '../harness/assertions.dart';
import '../harness/test_data_seeder.dart';

void main() async {
  final runner = E2ETestRunner('Row Level Security (RLS) Contracts');
  final backend = BackendHarness.fromEnv();

  // Test 1: Customer A cannot read Customer B's products or claims
  runner.addTest('RLS-01', 'Verify Multi-Tenant Data Isolation Between Customers', () async {
    // Create Customer A
    final emailA = TestDataSeeder.generateUniqueEmail('rls_cust_a');
    final authA = await backend.createAdminUser(
      email: emailA,
      password: 'Password123!',
      metadata: {'full_name': 'Customer A', 'role': 'customer'},
      emailConfirm: true,
    );
    final userAId = (authA.json as Map)['id'] as String;

    // Create Customer B
    final emailB = TestDataSeeder.generateUniqueEmail('rls_cust_b');
    final authB = await backend.createAdminUser(
      email: emailB,
      password: 'Password123!',
      metadata: {'full_name': 'Customer B', 'role': 'customer'},
      emailConfirm: true,
    );
    final userBId = (authB.json as Map)['id'] as String;

    // Login as Customer A to obtain JWT
    final loginA = await backend.signIn(email: emailA, password: 'Password123!');
    final jwtA = ((loginA.json as Map)['access_token'] as String);

    // Login as Customer B to obtain JWT
    final loginB = await backend.signIn(email: emailB, password: 'Password123!');
    final jwtB = ((loginB.json as Map)['access_token'] as String);

    try {
      // Customer B creates a product
      final prodBId = TestDataSeeder.generateUuid();
      await backend.insertRow('products', {
        'id': prodBId,
        'user_id': userBId,
        'name': 'Customer B Secret Product',
        'category': 'Electronics',
        'purchase_date': '2026-01-01',
        'warranty_period_months': 12,
      }, jwt: jwtB);

      // Customer A attempts to query all products
      final queryA = await backend.queryTable('products', jwt: jwtA);
      Assertions.httpSuccess(queryA.statusCode, queryA.body);
      final productsA = queryA.json as List;
      // Customer A should see 0 products (cannot see Customer B's product)
      for (final p in productsA) {
        Assertions.notEqual((p as Map)['id'], prodBId, 'Customer A leaked Customer B product');
      }

      // Customer A attempts to query Customer B's product directly by ID
      final directQueryA = await backend.queryTable('products', query: 'id=eq.$prodBId', jwt: jwtA);
      Assertions.httpSuccess(directQueryA.statusCode, directQueryA.body);
      final directListA = directQueryA.json as List;
      Assertions.empty(directListA, 'Customer A must receive empty list when querying Customer B product');

      // Cleanup product
      await backend.deleteRow('products', 'id=eq.$prodBId', useServiceRole: true);
    } finally {
      await backend.deleteAuthUser(userAId);
      await backend.deleteAuthUser(userBId);
    }
  });

  // Test 2: Customer A cannot mutate or delete Customer B's products
  runner.addTest('RLS-02', 'Verify Cross-Tenant Mutation and Deletion Blocked by RLS', () async {
    final emailA = TestDataSeeder.generateUniqueEmail('rls_mut_a');
    final authA = await backend.createAdminUser(
      email: emailA,
      password: 'Password123!',
      metadata: {'full_name': 'Mutate User A', 'role': 'customer'},
      emailConfirm: true,
    );
    final userAId = (authA.json as Map)['id'] as String;

    final emailB = TestDataSeeder.generateUniqueEmail('rls_mut_b');
    final authB = await backend.createAdminUser(
      email: emailB,
      password: 'Password123!',
      metadata: {'full_name': 'Mutate User B', 'role': 'customer'},
      emailConfirm: true,
    );
    final userBId = (authB.json as Map)['id'] as String;

    final loginA = await backend.signIn(email: emailA, password: 'Password123!');
    final jwtA = ((loginA.json as Map)['access_token'] as String);

    try {
      final prodBId = TestDataSeeder.generateUuid();
      await backend.insertRow('products', {
        'id': prodBId,
        'user_id': userBId,
        'name': 'Customer B Protected Laptop',
        'category': 'Electronics',
        'purchase_date': '2026-01-01',
        'warranty_period_months': 12,
      }, useServiceRole: true);

      // Customer A attempts to PATCH Customer B's product name
      final patchRes = await backend.updateRow(
        'products',
        'id=eq.$prodBId',
        {'name': 'Hacked by Customer A'},
        jwt: jwtA,
      );
      // Under RLS, updating an inaccessible row returns empty representation list
      final patchList = patchRes.json as List;
      Assertions.empty(patchList, 'Customer A was able to mutate Customer B product');

      // Verify product was not modified
      final verifyRes = await backend.queryTable('products', query: 'id=eq.$prodBId', useServiceRole: true);
      final verifiedProd = (verifyRes.json as List).first as Map;
      Assertions.equal(verifiedProd['name'], 'Customer B Protected Laptop');

      // Customer A attempts to DELETE Customer B's product
      final deleteRes = await backend.deleteRow('products', 'id=eq.$prodBId', jwt: jwtA);
      final deleteList = deleteRes.json as List;
      Assertions.empty(deleteList, 'Customer A was able to delete Customer B product');

      // Verify product still exists
      final checkRes = await backend.queryTable('products', query: 'id=eq.$prodBId', useServiceRole: true);
      Assertions.notEmpty(checkRes.json as List, 'Customer B product was deleted by Customer A');

      // Cleanup
      await backend.deleteRow('products', 'id=eq.$prodBId', useServiceRole: true);
    } finally {
      await backend.deleteAuthUser(userAId);
      await backend.deleteAuthUser(userBId);
    }
  });

  // Test 3: Customer cannot escalate role to 'admin'
  runner.addTest('RLS-03', 'Verify Role Escalation to admin is Blocked by Trigger/RLS', () async {
    final email = TestDataSeeder.generateUniqueEmail('rls_escalate');
    final authRes = await backend.createAdminUser(
      email: email,
      password: 'Password123!',
      metadata: {'full_name': 'Escalation Target', 'role': 'customer'},
      emailConfirm: true,
    );
    final userId = (authRes.json as Map)['id'] as String;

    final loginRes = await backend.signIn(email: email, password: 'Password123!');
    final jwt = ((loginRes.json as Map)['access_token'] as String);

    try {
      // Customer attempts to UPDATE own profile role to 'admin'
      final patchRes = await backend.updateRow(
        'profiles',
        'id=eq.$userId',
        {'role': 'admin'},
        jwt: jwt,
      );

      // The database trigger protect_user_role throws an exception (HTTP 400/403) or RLS policy blocks it
      if (patchRes.isSuccess) {
        // If it didn't throw an error, verify the role did NOT change to admin
        final verifyRes = await backend.queryTable('profiles', query: 'id=eq.$userId', useServiceRole: true);
        final profile = (verifyRes.json as List).first as Map;
        Assertions.equal(profile['role'], 'customer', 'Customer was able to escalate role to admin');
      } else {
        // Rejected with error code
        Assertions.inRange(patchRes.statusCode, 400, 499, 'Role escalation must be rejected');
      }
    } finally {
      await backend.deleteAuthUser(userId);
    }
  });

  // Test 4: Admin role bypass allows viewing global records
  runner.addTest('RLS-04', 'Verify Admin Role Possesses Global View Privileges', () async {
    // Create Customer
    final emailCust = TestDataSeeder.generateUniqueEmail('rls_cust');
    final authCust = await backend.createAdminUser(
      email: emailCust,
      password: 'Password123!',
      metadata: {'full_name': 'Regular Customer', 'role': 'customer'},
      emailConfirm: true,
    );
    final custId = (authCust.json as Map)['id'] as String;

    // Create Admin user
    final emailAdmin = TestDataSeeder.generateUniqueEmail('rls_admin');
    final authAdmin = await backend.createAdminUser(
      email: emailAdmin,
      password: 'Password123!',
      metadata: {'full_name': 'System Administrator', 'role': 'admin'},
      emailConfirm: true,
    );
    final adminId = (authAdmin.json as Map)['id'] as String;

    // Directly set role='admin' on profiles table using service_role
    await backend.updateRow('profiles', 'id=eq.$adminId', {'role': 'admin'}, useServiceRole: true);

    final loginAdmin = await backend.signIn(email: emailAdmin, password: 'Password123!');
    final adminJwt = ((loginAdmin.json as Map)['access_token'] as String);

    try {
      // Customer creates a product
      final prodId = TestDataSeeder.generateUuid();
      await backend.insertRow('products', {
        'id': prodId,
        'user_id': custId,
        'name': 'Product Visible to Admin',
        'category': 'Electronics',
        'purchase_date': '2026-01-01',
        'warranty_period_months': 12,
      }, useServiceRole: true);

      // Admin queries products table using admin JWT
      final adminQuery = await backend.queryTable('products', query: 'id=eq.$prodId', jwt: adminJwt);
      Assertions.httpSuccess(adminQuery.statusCode, adminQuery.body);
      final adminList = adminQuery.json as List;
      Assertions.notEmpty(adminList, 'Admin must be able to view customer products via RLS bypass');
      Assertions.equal((adminList.first as Map)['id'], prodId);

      // Cleanup product
      await backend.deleteRow('products', 'id=eq.$prodId', useServiceRole: true);
    } finally {
      await backend.deleteAuthUser(custId);
      await backend.deleteAuthUser(adminId);
    }
  });

  // Test 5: Unauthenticated access is blocked
  runner.addTest('RLS-05', 'Verify Unauthenticated Access Returns Zero Records', () async {
    // Query without JWT (anon public key only)
    final res = await backend.queryTable('claims');
    Assertions.httpSuccess(res.statusCode, res.body);
    final list = res.json as List;
    Assertions.empty(list, 'Unauthenticated query must return empty list');
  });

  final result = await runner.run(verbose: true);
  backend.close();
  exit(result.isSuccess ? 0 : 1);
}
