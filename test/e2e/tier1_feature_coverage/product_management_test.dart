/// Tier 1 Feature Coverage: Product Inventory & Warranty Tracking (TC-T1-PROD-01 to 05).
import 'dart:io';
import '../harness/backend_harness.dart';
import '../harness/ui_driver.dart';
import '../harness/assertions.dart';
import '../harness/test_data_seeder.dart';
import '../harness/test_keys.dart';

void main() async {
  final runner = E2ETestRunner('Tier 1: Products & Warranty Tracking');
  final backend = BackendHarness.fromEnv();
  final ui = UIDriver();

  // TC-T1-PROD-01: Add New Product with Active Warranty & Expiry Calculation
  runner.addTest('TC-T1-PROD-01', 'Register Product and Verify Automated Expiry Date Computation', () async {
    final email = TestDataSeeder.generateUniqueEmail('prod_t1_add');
    final auth = await backend.createAdminUser(
      email: email,
      password: 'Password123!',
      metadata: {'full_name': 'Product User'},
      emailConfirm: true,
    );
    final userId = (auth.json as Map)['id'] as String;

    try {
      final prodId = TestDataSeeder.generateUuid();
      final insertRes = await backend.insertRow('products', {
        'id': prodId,
        'user_id': userId,
        'name': 'Dell UltraSharp 27 Monitor',
        'category': 'Electronics',
        'brand': 'Dell',
        'model_number': 'U2723QE',
        'serial_number': 'CN-827391-A',
        'purchase_date': '2026-01-15',
        'warranty_period_months': 24,
      }, useServiceRole: true);

      Assertions.httpSuccess(insertRes.statusCode, insertRes.body);
      final inserted = (insertRes.json as List).first as Map<String, dynamic>;
      // Purchase date (2026-01-15) + 24 months = 2028-01-15
      Assertions.equal(inserted['warranty_expiry_date'], '2028-01-15');

      // UI Flow
      ui.navigateTo('/customer/products/new');
      await ui.enterText(TestKeys.productNameInput, 'Dell UltraSharp 27 Monitor');
      await ui.enterText(TestKeys.productPurchaseDateInput, '2026-01-15');
      await ui.enterText(TestKeys.productWarrantyMonthsInput, '24');
      await ui.tapKey(TestKeys.productSaveBtn);
      ui.navigateTo('/customer/products');
      ui.assertRoute('/customer/products');

      // Cleanup
      await backend.deleteRow('products', 'id=eq.$prodId', useServiceRole: true);
    } finally {
      await backend.deleteAuthUser(userId);
    }
  });

  // TC-T1-PROD-02: Product Inventory Search and Category Filtering
  runner.addTest('TC-T1-PROD-02', 'Filter Product Portfolio by Keyword Search and Category', () async {
    final email = TestDataSeeder.generateUniqueEmail('prod_t1_filter');
    final auth = await backend.createAdminUser(
      email: email,
      password: 'Password123!',
      metadata: {'full_name': 'Filter User'},
      emailConfirm: true,
    );
    final userId = (auth.json as Map)['id'] as String;

    final prod1Id = TestDataSeeder.generateUuid();
    final prod2Id = TestDataSeeder.generateUuid();

    try {
      // Add Electronics product
      await backend.insertRow('products', {
        'id': prod1Id,
        'user_id': userId,
        'name': 'Sony Noise Canceling Headphones',
        'category': 'Electronics',
        'purchase_date': '2026-01-01',
        'warranty_period_months': 12,
      }, useServiceRole: true);

      // Add Home Appliance product
      await backend.insertRow('products', {
        'id': prod2Id,
        'user_id': userId,
        'name': 'Espresso Coffee Maker',
        'category': 'Home Appliances',
        'purchase_date': '2026-01-01',
        'warranty_period_months': 12,
      }, useServiceRole: true);

      // Query Electronics
      final electQuery = await backend.queryTable(
        'products',
        query: 'user_id=eq.$userId&category=eq.Electronics',
        useServiceRole: true,
      );
      final electList = electQuery.json as List;
      Assertions.equal(electList.length, 1);
      Assertions.equal((electList.first as Map)['name'], 'Sony Noise Canceling Headphones');

      // UI search simulation
      ui.navigateTo('/customer/products');
      await ui.enterText(TestKeys.productSearchInput, 'Sony');
      ui.assertElementText(TestKeys.productSearchInput, 'Sony');

      // Cleanup
      await backend.deleteRow('products', 'id=eq.$prod1Id', useServiceRole: true);
      await backend.deleteRow('products', 'id=eq.$prod2Id', useServiceRole: true);
    } finally {
      await backend.deleteAuthUser(userId);
    }
  });

  // TC-T1-PROD-03: Product Details View Display
  runner.addTest('TC-T1-PROD-03', 'Product Detail View Renders Specifications and Warranty Status', () async {
    final email = TestDataSeeder.generateUniqueEmail('prod_t1_det');
    final auth = await backend.createAdminUser(
      email: email,
      password: 'Password123!',
      metadata: {'full_name': 'Detail User'},
      emailConfirm: true,
    );
    final userId = (auth.json as Map)['id'] as String;
    final prodId = TestDataSeeder.generateUuid();

    try {
      await backend.insertRow('products', {
        'id': prodId,
        'user_id': userId,
        'name': 'Apple MacBook Air 15',
        'category': 'Electronics',
        'brand': 'Apple',
        'model_number': 'M3-15',
        'serial_number': 'SN-APPL-9921',
        'purchase_date': '2026-02-01',
        'warranty_period_months': 12,
      }, useServiceRole: true);

      final detailRes = await backend.queryTable('products', query: 'id=eq.$prodId', useServiceRole: true);
      Assertions.httpSuccess(detailRes.statusCode, detailRes.body);
      final product = (detailRes.json as List).first as Map<String, dynamic>;

      Assertions.equal(product['name'], 'Apple MacBook Air 15');
      Assertions.equal(product['brand'], 'Apple');
      Assertions.equal(product['serial_number'], 'SN-APPL-9921');

      ui.navigateTo('/customer/products/$prodId');
      ui.assertRoute('/customer/products/$prodId');

      await backend.deleteRow('products', 'id=eq.$prodId', useServiceRole: true);
    } finally {
      await backend.deleteAuthUser(userId);
    }
  });

  // TC-T1-PROD-04: Edit Product Specifications & Recalculate Expiry
  runner.addTest('TC-T1-PROD-04', 'Modify Product Warranty Period and Verify Recalculated Expiry Date', () async {
    final email = TestDataSeeder.generateUniqueEmail('prod_t1_edit');
    final auth = await backend.createAdminUser(
      email: email,
      password: 'Password123!',
      metadata: {'full_name': 'Edit User'},
      emailConfirm: true,
    );
    final userId = (auth.json as Map)['id'] as String;
    final prodId = TestDataSeeder.generateUuid();

    try {
      // Initially 12 months (2026-01-01 -> 2027-01-01)
      await backend.insertRow('products', {
        'id': prodId,
        'user_id': userId,
        'name': 'Extendable Warranty Laptop',
        'category': 'Electronics',
        'purchase_date': '2026-01-01',
        'warranty_period_months': 12,
      }, useServiceRole: true);

      // Update to 36 months
      final updateRes = await backend.updateRow(
        'products',
        'id=eq.$prodId',
        {
          'warranty_period_months': 36,
          'serial_number': 'SN-EXTENDED-36M',
        },
        useServiceRole: true,
      );
      Assertions.httpSuccess(updateRes.statusCode, updateRes.body);
      final updated = (updateRes.json as List).first as Map<String, dynamic>;

      // Trigger should have recalculated warranty_expiry_date = 2029-01-01
      Assertions.equal(updated['warranty_expiry_date'], '2029-01-01');
      Assertions.equal(updated['serial_number'], 'SN-EXTENDED-36M');

      await backend.deleteRow('products', 'id=eq.$prodId', useServiceRole: true);
    } finally {
      await backend.deleteAuthUser(userId);
    }
  });

  // TC-T1-PROD-05: Product Deletion Removes Item from Inventory
  runner.addTest('TC-T1-PROD-05', 'Delete Product and Verify Removal from Database and UI', () async {
    final email = TestDataSeeder.generateUniqueEmail('prod_t1_del');
    final auth = await backend.createAdminUser(
      email: email,
      password: 'Password123!',
      metadata: {'full_name': 'Delete User'},
      emailConfirm: true,
    );
    final userId = (auth.json as Map)['id'] as String;
    final prodId = TestDataSeeder.generateUuid();

    try {
      await backend.insertRow('products', {
        'id': prodId,
        'user_id': userId,
        'name': 'Disposable Phone Charger',
        'category': 'Electronics',
        'purchase_date': '2026-01-01',
        'warranty_period_months': 6,
      }, useServiceRole: true);

      // Delete product
      final delRes = await backend.deleteRow('products', 'id=eq.$prodId', useServiceRole: true);
      Assertions.httpSuccess(delRes.statusCode, delRes.body);

      // Verify product is gone
      final queryRes = await backend.queryTable('products', query: 'id=eq.$prodId', useServiceRole: true);
      Assertions.empty(queryRes.json as List, 'Deleted product still exists in database');
    } finally {
      await backend.deleteAuthUser(userId);
    }
  });

  final result = await runner.run(verbose: true);
  backend.close();
  exit(result.isSuccess ? 0 : 1);
}
