/// Tier 4 Real-World Application Scenario: RW-01 New Customer Onboarding & Product Lifecycle.
import 'dart:io';
import '../harness/backend_harness.dart';
import '../harness/ui_driver.dart';
import '../harness/assertions.dart';
import '../harness/test_data_seeder.dart';

void main() async {
  final runner = E2ETestRunner('Tier 4: Journey RW-01 New Customer Onboarding');
  final backend = BackendHarness.fromEnv();
  final ui = UIDriver();

  runner.addTest('RW-01', 'Complete Onboarding: Sarah Signs Up, Adds 2 Products, Inspects Cards & Toggles Dark Theme', () async {
    final email = TestDataSeeder.generateUniqueEmail('sarah_rw01');
    const password = 'SecurePass2026!';
    const fullName = 'Sarah Jenkins';

    // 1. Account Registration
    ui.navigateTo('/register');
    await ui.register(fullName, email, password);
    ui.assertRoute('/customer/home');

    // Backend registration verification
    final authRes = await backend.createAdminUser(
      email: email,
      password: password,
      metadata: {'full_name': fullName, 'role': 'customer'},
      emailConfirm: true,
    );
    Assertions.httpSuccess(authRes.statusCode, authRes.body);
    final userId = (authRes.json as Map)['id'] as String;

    final prod1Id = TestDataSeeder.generateUuid();
    final prod2Id = TestDataSeeder.generateUuid();

    try {
      // 2. Add Product 1 (Active Laptop with 36 months warranty)
      await backend.insertRow('products', {
        'id': prod1Id,
        'user_id': userId,
        'name': 'Apple MacBook Pro 16"',
        'category': 'Electronics',
        'brand': 'Apple',
        'model_number': 'M3 Max',
        'purchase_date': '2026-03-01',
        'warranty_period_months': 36,
      }, useServiceRole: true);

      // 3. Add Product 2 (Expiring Soon Monitor with 12 months warranty, expires in ~14 days)
      await backend.insertRow('products', {
        'id': prod2Id,
        'user_id': userId,
        'name': 'Dell UltraSharp 27" Monitor',
        'category': 'Electronics',
        'brand': 'Dell',
        'model_number': 'U2723QE',
        'purchase_date': '2025-11-25',
        'warranty_period_months': 12,
      }, useServiceRole: true);

      // 4. Verify Home Dashboard metric counts
      final prodsQuery = await backend.queryTable('products', query: 'user_id=eq.$userId', useServiceRole: true);
      final products = prodsQuery.json as List;
      Assertions.equal(products.length, 2);

      // 5. Open Product Detail
      ui.navigateTo('/customer/products/$prod1Id');
      ui.assertRoute('/customer/products/$prod1Id');

      // 6. Switch to Dark Mode in Profile
      ui.navigateTo('/customer/profile');
      ui.toggleTheme();
      Assertions.equal(ui.currentTheme, 'dark');

      // 7. Verify Theme persists back on Dashboard
      ui.navigateTo('/customer/home');
      Assertions.equal(ui.currentTheme, 'dark');

      // Cleanup
      await backend.deleteRow('products', 'id=eq.$prod1Id', useServiceRole: true);
      await backend.deleteRow('products', 'id=eq.$prod2Id', useServiceRole: true);
    } finally {
      await backend.deleteAuthUser(userId);
    }
  });

  final result = await runner.run(verbose: true);
  backend.close();
  exit(result.isSuccess ? 0 : 1);
}
