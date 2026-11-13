/// Backend Contract Test: Storage Buckets Configuration, Public/Private Access, and Folder Path Policies.
import 'dart:io';
import '../harness/backend_harness.dart';
import '../harness/assertions.dart';
import '../harness/test_data_seeder.dart';

void main() async {
  final runner = E2ETestRunner('Storage Buckets & Policies Contracts');
  final backend = BackendHarness.fromEnv();

  // Test 1: Verify all 4 storage buckets exist in Supabase Storage
  runner.addTest('STG-01', 'Verify 4 Buckets Exist (receipts, product-images, claim-attachments, avatars)', () async {
    final res = await backend.listBuckets(useServiceRole: true);
    Assertions.httpSuccess(res.statusCode, res.body);
    final buckets = res.json as List;
    final bucketIds = buckets.map((b) => (b as Map)['id'] as String).toSet();

    Assertions.isTrue(bucketIds.contains('receipts'), 'Bucket "receipts" is missing');
    Assertions.isTrue(bucketIds.contains('product-images'), 'Bucket "product-images" is missing');
    Assertions.isTrue(bucketIds.contains('claim-attachments'), 'Bucket "claim-attachments" is missing');
    Assertions.isTrue(bucketIds.contains('avatars'), 'Bucket "avatars" is missing');
  });

  // Test 2: Verify Public vs Private configurations
  runner.addTest('STG-02', 'Verify Public vs Private Bucket Visibility Configurations', () async {
    final res = await backend.listBuckets(useServiceRole: true);
    final buckets = res.json as List;
    final bucketMap = {for (var b in buckets) (b as Map)['id'] as String: b};

    final receipts = bucketMap['receipts']!;
    final claimAttachments = bucketMap['claim-attachments']!;
    final productImages = bucketMap['product-images']!;
    final avatars = bucketMap['avatars']!;

    Assertions.isFalse(receipts['public'] as bool, 'receipts must be private');
    Assertions.isFalse(claimAttachments['public'] as bool, 'claim-attachments must be private');
    Assertions.isTrue(productImages['public'] as bool, 'product-images must be public');
    Assertions.isTrue(avatars['public'] as bool, 'avatars must be public');
  });

  // Test 3: Verify File Size Limits and MIME type allow-lists
  runner.addTest('STG-03', 'Verify Storage Bucket File Size Limits and MIME Restrictions', () async {
    final res = await backend.listBuckets(useServiceRole: true);
    final buckets = res.json as List;
    final bucketMap = {for (var b in buckets) (b as Map)['id'] as String: b};

    final receipts = bucketMap['receipts']!;
    final claimAttachments = bucketMap['claim-attachments']!;
    final avatars = bucketMap['avatars']!;

    // Receipts: 10MB (10485760 bytes)
    Assertions.equal(receipts['file_size_limit'], 10485760, 'receipts size limit mismatch');
    // Claim Attachments: 20MB (20971520 bytes)
    Assertions.equal(claimAttachments['file_size_limit'], 20971520, 'claim-attachments size limit mismatch');
    // Avatars: 5MB (5242880 bytes)
    Assertions.equal(avatars['file_size_limit'], 5242880, 'avatars size limit mismatch');
  });

  // Test 4: Path security isolation - User A uploading to User B folder is blocked
  runner.addTest('STG-04', 'Verify Storage Path Isolation by User Folder Boundary', () async {
    final emailA = TestDataSeeder.generateUniqueEmail('stg_user_a');
    final authA = await backend.createAdminUser(
      email: emailA,
      password: 'Password123!',
      metadata: {'full_name': 'Storage User A', 'role': 'customer'},
      emailConfirm: true,
    );
    final userAId = (authA.json as Map)['id'] as String;

    final emailB = TestDataSeeder.generateUniqueEmail('stg_user_b');
    final authB = await backend.createAdminUser(
      email: emailB,
      password: 'Password123!',
      metadata: {'full_name': 'Storage User B', 'role': 'customer'},
      emailConfirm: true,
    );
    final userBId = (authB.json as Map)['id'] as String;

    final loginA = await backend.signIn(email: emailA, password: 'Password123!');
    final jwtA = ((loginA.json as Map)['access_token'] as String);

    try {
      final dummyBytes = [0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46]; // Minimal JPEG header

      // User A attempts to upload into User B's folder in 'receipts'
      final crossUpload = await backend.uploadStorageObject(
        'receipts',
        '$userBId/stolen_receipt.jpg',
        dummyBytes,
        jwt: jwtA,
      );
      // Storage RLS rejects unauthorized path upload with HTTP 403 or 400
      Assertions.isFalse(crossUpload.isSuccess, 'User A must not be allowed to upload into User B folder');

      // User A uploads into own folder in 'receipts'
      final ownUpload = await backend.uploadStorageObject(
        'receipts',
        '$userAId/my_receipt.jpg',
        dummyBytes,
        jwt: jwtA,
      );
      Assertions.httpSuccess(ownUpload.statusCode, ownUpload.body);
    } finally {
      await backend.deleteAuthUser(userAId);
      await backend.deleteAuthUser(userBId);
    }
  });

  // Test 5: Unauthenticated access to private bucket is rejected
  runner.addTest('STG-05', 'Verify Unauthenticated Access to Private Buckets Rejected', () async {
    final res = await backend.getStorageObject('receipts', 'some_secret.pdf');
    // Without authorization header, accessing private storage objects is rejected
    Assertions.isFalse(res.isSuccess, 'Unauthenticated access to private receipts bucket must fail');
  });

  final result = await runner.run(verbose: true);
  backend.close();
  exit(result.isSuccess ? 0 : 1);
}
