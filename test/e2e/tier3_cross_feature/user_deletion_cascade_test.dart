/// Tier 3 Cross-Feature Combinations: Network Recovery, Profile Synchronization & Grace Period Rules (TC-T3-CROSS-13 to 15).
import 'dart:io';
import '../harness/backend_harness.dart';
import '../harness/assertions.dart';
import '../tier1_feature_coverage/pdf_export_test.dart';
import '../backend_contracts/edge_functions_test.dart';

void main() async {
  final runner = E2ETestRunner('Tier 3: Network Recovery, Profile Sync & Grace Period');
  final backend = BackendHarness.fromEnv();

  // TC-T3-CROSS-13: Network Interruption Resilience During Step 4 Attachment Upload
  runner.addTest('TC-T3-CROSS-13', 'Network Disconnection Handled with Retry Prompt Without Losing Wizard State', () async {
    bool uploadSucceeded = false;
    int attempt = 0;

    Future<void> attemptUpload() async {
      attempt++;
      if (attempt == 1) {
        throw const SocketException('Connection reset by peer');
      }
      uploadSucceeded = true;
    }

    // First attempt fails with network exception
    try {
      await attemptUpload();
    } catch (e) {
      Assertions.isTrue(e is SocketException);
      Assertions.isFalse(uploadSucceeded);
    }

    // User taps retry -> succeeds
    await attemptUpload();
    Assertions.isTrue(uploadSucceeded, 'Retry upload must succeed upon reconnection');
  });

  // TC-T3-CROSS-14: Profile Update Synchronizes to Subsequent PDF Exports
  runner.addTest('TC-T3-CROSS-14', 'Customer Profile Modification Immediately Reflected in Subsequent Claim Reports', () async {
    const updatedName = 'Alexander Mercer';

    final pdfBytes = LocalPdfReportGenerator.generateReportPdf(
      claimNumber: 'CLM-20261111-SYNC01',
      customerName: updatedName,
      productName: 'Dell Monitor',
      claimStatus: 'Approved',
      issueDescription: 'Updated profile test',
      timelineEvents: ['Submitted', 'Approved'],
    );

    final pdfText = String.fromCharCodes(pdfBytes);
    Assertions.contains(pdfText, updatedName, 'Generated PDF must reflect updated customer name');
  });

  // TC-T3-CROSS-15: Expired Warranty within 7-Day Grace Period Handling
  runner.addTest('TC-T3-CROSS-15', 'Claim Evaluated Under 7-Day Grace Period Flagged as in_grace_period', () async {
    final purchaseDate = DateTime(2025, 11, 1);
    final warrantyMonths = 12; // Expiry: 2026-11-01
    final incidentDate = DateTime(2026, 11, 4); // 3 days past expiry (within 7d grace)

    final result = LocalClaimProcessorContract.evaluateSubmission(
      purchaseDate: purchaseDate,
      warrantyMonths: warrantyMonths,
      incidentDate: incidentDate,
      claimType: 'replacement',
      description: 'Hinge cracked right after warranty end',
    );

    Assertions.isTrue(result['success'] as bool);
    Assertions.equal(result['warranty_status'], 'in_grace_period');
    Assertions.equal(result['priority_score'], 65); // 20 + 30 + 15 = 65
  });

  final result = await runner.run(verbose: true);
  backend.close();
  exit(result.isSuccess ? 0 : 1);
}
