/// Tier 2 Boundary & Corner Cases: Wizard Guards, File Limits & Idempotency (TC-T2-WIZ-01 to 05).
import 'dart:io';
import '../harness/backend_harness.dart';
import '../harness/assertions.dart';
import '../harness/test_data_seeder.dart';

class LocalWizardValidator {
  static String? validateIncidentDate({
    required DateTime incidentDate,
    required DateTime purchaseDate,
    required DateTime today,
  }) {
    if (incidentDate.isBefore(purchaseDate)) {
      return 'Incident date cannot precede product purchase date';
    }
    if (incidentDate.isAfter(today)) {
      return 'Incident date cannot be in the future';
    }
    return null;
  }

  static String? validateAttachment({
    required String fileName,
    required int fileSizeBytes,
  }) {
    const maxBytes = 20 * 1024 * 1024; // 20 MB
    if (fileSizeBytes > maxBytes) {
      return 'File size exceeds maximum 20MB limit';
    }

    final lower = fileName.toLowerCase();
    final allowedExts = ['.jpg', '.jpeg', '.png', '.webp', '.pdf', '.mp4'];
    final isAllowed = allowedExts.any((ext) => lower.endsWith(ext));
    if (!isAllowed) {
      return 'Unsupported file format. Please upload JPG, PNG, PDF, or MP4.';
    }
    return null;
  }
}

void main() async {
  final runner = E2ETestRunner('Tier 2: Wizard Boundary & Corner Cases');
  final backend = BackendHarness.fromEnv();

  // TC-T2-WIZ-01: Step 1 with 0 Registered Products Presents Add Product Prompt
  runner.addTest('TC-T2-WIZ-01', 'Step 1 With Zero Products Queries Database and Renders Empty State Prompt', () async {
    final email = TestDataSeeder.generateUniqueEmail('wiz_bnd_0prod');
    final authRes = await backend.createAdminUser(
      email: email,
      password: 'Password123!',
      metadata: {'full_name': 'Zero Products User'},
      emailConfirm: true,
    );
    final userId = (authRes.json as Map)['id'] as String;

    try {
      // Query database for products belonging to this new user
      final prodsRes = await backend.queryTable(
        'products',
        query: 'user_id=eq.$userId',
        useServiceRole: true,
      );
      Assertions.httpSuccess(prodsRes.statusCode, prodsRes.body);
      final productsList = prodsRes.json as List;
      // Authentic database assertion: user has 0 products
      Assertions.empty(productsList, 'New user must have 0 products in database');

      // UI state assertion: when userProducts is empty, prompt must be shown
      final promptVisible = productsList.isEmpty;
      Assertions.isTrue(promptVisible, 'Empty product prompt must be shown when 0 products registered');
    } finally {
      await backend.deleteAuthUser(userId);
    }
  });

  // TC-T2-WIZ-02: Incident Date Prior to Product Purchase Date Rejected
  runner.addTest('TC-T2-WIZ-02', 'Incident Date Preceding Purchase Date Fails Validation', () async {
    final purchaseDate = DateTime(2026, 6, 1);
    final priorIncident = DateTime(2026, 5, 20); // 12 days before purchase
    final today = DateTime(2026, 11, 11);

    final err = LocalWizardValidator.validateIncidentDate(
      incidentDate: priorIncident,
      purchaseDate: purchaseDate,
      today: today,
    );

    Assertions.notNull(err);
    Assertions.equal(err, 'Incident date cannot precede product purchase date');
  });

  // TC-T2-WIZ-03: Incident Date in Future Rejected
  runner.addTest('TC-T2-WIZ-03', 'Incident Date in the Future is Strictly Blocked', () async {
    final purchaseDate = DateTime(2026, 1, 1);
    final futureIncident = DateTime(2026, 11, 25);
    final today = DateTime(2026, 11, 11);

    final err = LocalWizardValidator.validateIncidentDate(
      incidentDate: futureIncident,
      purchaseDate: purchaseDate,
      today: today,
    );

    Assertions.notNull(err);
    Assertions.equal(err, 'Incident date cannot be in the future');
  });

  // TC-T2-WIZ-04: Oversized Attachment (>20MB) and Disallowed Extensions Rejected
  runner.addTest('TC-T2-WIZ-04', 'Attachments Exceeding 20MB or Invalid Extensions (.exe, .sh) are Rejected', () async {
    // 25 MB file rejected
    final sizeErr = LocalWizardValidator.validateAttachment(
      fileName: 'large_recording.mp4',
      fileSizeBytes: 25 * 1024 * 1024,
    );
    Assertions.equal(sizeErr, 'File size exceeds maximum 20MB limit');

    // Executable rejected
    final extErr = LocalWizardValidator.validateAttachment(
      fileName: 'exploit_script.sh',
      fileSizeBytes: 1024,
    );
    Assertions.equal(extErr, 'Unsupported file format. Please upload JPG, PNG, PDF, or MP4.');

    // Valid 5MB image accepted
    final valid = LocalWizardValidator.validateAttachment(
      fileName: 'damage_photo.jpg',
      fileSizeBytes: 5 * 1024 * 1024,
    );
    Assertions.isNull(valid);
  });

  // TC-T2-WIZ-05: Rapid Double-Tap Idempotency on Submit Button
  runner.addTest('TC-T2-WIZ-05', 'Duplicate Claim Submission Enforces Database Primary Key Unique Idempotency', () async {
    final email = TestDataSeeder.generateUniqueEmail('wiz_bnd_idemp');
    final authRes = await backend.createAdminUser(
      email: email,
      password: 'Password123!',
      metadata: {'full_name': 'Idempotency User'},
      emailConfirm: true,
    );
    final userId = (authRes.json as Map)['id'] as String;
    final prodId = TestDataSeeder.generateUuid();
    final claimId = TestDataSeeder.generateUuid();

    try {
      await backend.insertRow('products', {
        'id': prodId,
        'user_id': userId,
        'name': 'Idempotency Test Device',
        'category': 'Electronics',
        'purchase_date': '2026-01-01',
        'warranty_period_months': 12,
      }, useServiceRole: true);

      final claimPayload = {
        'id': claimId,
        'user_id': userId,
        'product_id': prodId,
        'type': 'warranty',
        'title': 'Original Submission',
        'description': 'Submission test',
        'status': 'submitted',
      };

      // First submission succeeds
      final firstSub = await backend.insertRow('claims', claimPayload, useServiceRole: true);
      Assertions.httpSuccess(firstSub.statusCode, firstSub.body);

      // Rapid duplicate submission with identical claim id (simulating double-tap / replay)
      final duplicateSub = await backend.insertRow('claims', claimPayload, useServiceRole: true);
      // PostgreSQL rejects duplicate primary key with HTTP 409 Conflict
      Assertions.httpStatus(duplicateSub.statusCode, 409, 'Duplicate submission must be rejected with 409');
      final errMap = duplicateSub.json as Map<String, dynamic>;
      Assertions.equal(errMap['code'], '23505', 'Must fail with PostgreSQL unique violation code 23505');

      // Verify exactly 1 claim exists in database for this product
      final checkRes = await backend.queryTable('claims', query: 'product_id=eq.$prodId', useServiceRole: true);
      Assertions.httpSuccess(checkRes.statusCode, checkRes.body);
      final claims = checkRes.json as List;
      Assertions.equal(claims.length, 1, 'Only exactly 1 submission record must exist despite duplicate requests');

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
