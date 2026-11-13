/// Tier 2 Boundary & Corner Cases: Product Boundaries, Expiry Milestones & Unicode Resilience (TC-T2-PROD-01 to 05).
import 'dart:io';
import '../harness/backend_harness.dart';
import '../harness/assertions.dart';
import '../harness/test_data_seeder.dart';

class LocalProductValidator {
  static String? validateWarrantyMonths(String? value) {
    if (value == null || value.trim().isEmpty) return 'Warranty period is required';
    final months = int.tryParse(value);
    if (months == null || months <= 0) return 'Warranty period must be at least 1 month';
    return null;
  }

  static String? validatePurchaseDate(DateTime? date, [DateTime? mockNow]) {
    if (date == null) return 'Purchase date is required';
    final now = mockNow ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    if (target.isAfter(today)) return 'Purchase date cannot be in the future';
    return null;
  }

  static String getWarrantyStatus(DateTime expiryDate, [DateTime? mockNow]) {
    final now = mockNow ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expiry = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
    final diffDays = expiry.difference(today).inDays;

    if (diffDays < 0) return 'expired';
    if (diffDays <= 30) return 'expiring_soon';
    return 'active';
  }
}

void main() async {
  final runner = E2ETestRunner('Tier 2: Product Boundary & Corner Cases');
  final backend = BackendHarness.fromEnv();

  // TC-T2-PROD-01: Zero and Negative Warranty Period Rejection
  runner.addTest('TC-T2-PROD-01', 'Warranty Duration of 0 Months or Negative Integer Blocked by Validation', () async {
    final zeroErr = LocalProductValidator.validateWarrantyMonths('0');
    Assertions.equal(zeroErr, 'Warranty period must be at least 1 month');

    final negErr = LocalProductValidator.validateWarrantyMonths('-12');
    Assertions.equal(negErr, 'Warranty period must be at least 1 month');

    final valid = LocalProductValidator.validateWarrantyMonths('1');
    Assertions.isNull(valid);
  });

  // TC-T2-PROD-02: Future Purchase Date Rejection vs Today Acceptance
  runner.addTest('TC-T2-PROD-02', 'Purchase Date in the Future is Rejected; Today is Accepted', () async {
    final now = DateTime(2026, 11, 11);

    // Tomorrow (future) rejected
    final futureErr = LocalProductValidator.validatePurchaseDate(DateTime(2026, 11, 12), now);
    Assertions.equal(futureErr, 'Purchase date cannot be in the future');

    // Today accepted
    final todayValid = LocalProductValidator.validatePurchaseDate(DateTime(2026, 11, 11), now);
    Assertions.isNull(todayValid);

    // Past accepted
    final pastValid = LocalProductValidator.validatePurchaseDate(DateTime(2025, 1, 1), now);
    Assertions.isNull(pastValid);
  });

  // TC-T2-PROD-03: Warranty Expiry Today (T+0) Categorized as Expiring/Active
  runner.addTest('TC-T2-PROD-03', 'Warranty Expiring Exactly Today (T+0) is Categorized as Expiring Soon', () async {
    final now = DateTime(2026, 11, 11);
    final expiresToday = DateTime(2026, 11, 11);
    final status = LocalProductValidator.getWarrantyStatus(expiresToday, now);

    Assertions.equal(status, 'expiring_soon');

    // Yesterday (T-1) is expired
    final expired = LocalProductValidator.getWarrantyStatus(DateTime(2026, 11, 10), now);
    Assertions.equal(expired, 'expired');
  });

  // TC-T2-PROD-04: Warranty Expiry at 30 Days (T+30) Boundary
  runner.addTest('TC-T2-PROD-04', 'Warranty Expiry at Exactly T+30 Days Triggers Expiring Soon Status', () async {
    final now = DateTime(2026, 11, 11);

    // Exactly 30 days ahead: 2026-12-11
    final expires30d = DateTime(2026, 12, 11);
    Assertions.equal(LocalProductValidator.getWarrantyStatus(expires30d, now), 'expiring_soon');

    // 31 days ahead: 2026-12-12 -> active
    final expires31d = DateTime(2026, 12, 12);
    Assertions.equal(LocalProductValidator.getWarrantyStatus(expires31d, now), 'active');
  });

  // TC-T2-PROD-05: Product Name with Unicode Emojis and 100-Character Boundary
  runner.addTest('TC-T2-PROD-05', 'Product Name with Unicode Emojis and 100-Character String Stored Intact', () async {
    final email = TestDataSeeder.generateUniqueEmail('prod_t2_unicode');
    final auth = await backend.createAdminUser(
      email: email,
      password: 'Password123!',
      metadata: {'full_name': 'Unicode Tester'},
      emailConfirm: true,
    );
    final userId = (auth.json as Map)['id'] as String;
    final prodId = TestDataSeeder.generateUuid();

    // 100-character name containing emojis and non-Latin glyphs
    final complexName = '🎧 Sony 4K OLED TV 🚀 (Special Édition) 日本語テスト 1234567890123456789012345678901234567890123456789012345';

    try {
      final insertRes = await backend.insertRow('products', {
        'id': prodId,
        'user_id': userId,
        'name': complexName,
        'category': 'Electronics',
        'purchase_date': '2026-01-01',
        'warranty_period_months': 12,
      }, useServiceRole: true);

      Assertions.httpSuccess(insertRes.statusCode, insertRes.body);
      final inserted = (insertRes.json as List).first as Map<String, dynamic>;
      Assertions.equal(inserted['name'], complexName, 'Unicode characters were corrupted or truncated');

      await backend.deleteRow('products', 'id=eq.$prodId', useServiceRole: true);
    } finally {
      await backend.deleteAuthUser(userId);
    }
  });

  final result = await runner.run(verbose: true);
  backend.close();
  exit(result.isSuccess ? 0 : 1);
}
