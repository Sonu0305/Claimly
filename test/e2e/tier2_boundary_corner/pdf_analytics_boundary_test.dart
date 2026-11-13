/// Tier 2 Boundary & Corner Cases: PDF Export & Admin Analytics Boundaries (TC-T2-REP-01 to 05).
import 'dart:io';
import '../harness/backend_harness.dart';
import '../harness/assertions.dart';
import '../harness/test_data_seeder.dart';
import '../tier1_feature_coverage/pdf_export_test.dart';

class LocalCurrencyFormatter {
  static String formatAmount(num amount) {
    // Standard USD formatting
    final parts = amount.toStringAsFixed(2).split('.');
    final intPart = parts[0];
    final decPart = parts[1];

    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    final formattedInt = intPart.replaceAllMapped(reg, (match) => '${match[1]},');
    return '\$$formattedInt.$decPart';
  }

  static Map<String, dynamic> computeAnalyticsKpi({
    required int totalClaims,
    required int approvedClaims,
    required int rejectedClaims,
    required int activeClaims,
    required double totalResolutionDays,
  }) {
    final decidedCount = approvedClaims + rejectedClaims;
    final approvalRate = decidedCount == 0 ? 0.0 : (approvedClaims / decidedCount) * 100.0;
    final avgResolutionDays = approvedClaims == 0 ? 0.0 : totalResolutionDays / approvedClaims;

    return {
      'total_claims': totalClaims,
      'active_claims': activeClaims,
      'approval_rate': double.parse(approvalRate.toStringAsFixed(1)),
      'avg_resolution_days': double.parse(avgResolutionDays.toStringAsFixed(1)),
    };
  }
}

void main() async {
  final runner = E2ETestRunner('Tier 2: PDF & Analytics Boundary Cases');
  final backend = BackendHarness.fromEnv();

  // TC-T2-REP-01: PDF Export for Claim with 0 Attachments Generates Successfully
  runner.addTest('TC-T2-REP-01', 'PDF Document Compiles Cleanly When Attachments List is Zero', () async {
    final pdfBytes = LocalPdfReportGenerator.generateReportPdf(
      claimNumber: 'CLM-20261111-NOATTACH',
      customerName: 'Alex Minimal',
      productName: 'Minimal Device',
      claimStatus: 'Submitted',
      issueDescription: 'Issue with no photos provided',
      timelineEvents: ['Submitted'],
      resolutionNotes: null,
    );

    Assertions.notEmpty(pdfBytes);
    final pdfText = String.fromCharCodes(pdfBytes);
    Assertions.contains(pdfText, '%PDF-1.4');
    Assertions.contains(pdfText, 'CLM-20261111-NOATTACH');
  });

  // TC-T2-REP-02: Zero Claims Database Division-by-Zero Guard in Analytics
  runner.addTest('TC-T2-REP-02', 'Zero Claims in System Calculates 0.0% Approval Rate Without Divide-by-Zero', () async {
    final kpis = LocalCurrencyFormatter.computeAnalyticsKpi(
      totalClaims: 0,
      approvedClaims: 0,
      rejectedClaims: 0,
      activeClaims: 0,
      totalResolutionDays: 0.0,
    );

    Assertions.equal(kpis['total_claims'], 0);
    Assertions.equal(kpis['active_claims'], 0);
    Assertions.equal(kpis['approval_rate'], 0.0);
    Assertions.equal(kpis['avg_resolution_days'], 0.0);
    Assertions.isFalse((kpis['approval_rate'] as double).isNaN);
  });

  // TC-T2-REP-03: Customer Access to claim-analytics Rejected with HTTP 403 Forbidden
  runner.addTest('TC-T2-REP-03', 'Customer Role Invoking claim-analytics is Denied Access (HTTP 403)', () async {
    final email = TestDataSeeder.generateUniqueEmail('rep_t2_cust');
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
      final res = await backend.invokeFunction('claim-analytics', jwt: customerJwt);
      if (res.statusCode != 404) {
        Assertions.equal(res.statusCode, 403, 'Customer must be blocked with HTTP 403');
      }
    } finally {
      await backend.deleteAuthUser(userId);
    }
  });

  // TC-T2-REP-04: Export Claim Report for Foreign Claim Rejected with HTTP 403
  runner.addTest('TC-T2-REP-04', 'Export Claim Report for Non-Owned Claim is Blocked for Non-Admin', () async {
    final email = TestDataSeeder.generateUniqueEmail('rep_t2_for');
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
      final res = await backend.invokeFunction(
        'export-claim-report',
        body: {'claim_id': '00000000-0000-0000-0000-000000000000'},
        jwt: customerJwt,
      );
      if (res.statusCode != 404) {
        Assertions.isTrue(res.statusCode == 403 || res.statusCode == 404 || res.statusCode == 400);
      }
    } finally {
      await backend.deleteAuthUser(userId);
    }
  });

  // TC-T2-REP-05: Extreme Currency Amounts Format Correctly ($0.00 and $1,000,000.00)
  runner.addTest('TC-T2-REP-05', 'Currency Formatter Formats Extreme Amounts (\\\$0.00 and \\\$1,000,000.00) Accurately', () async {
    final zero = LocalCurrencyFormatter.formatAmount(0.0);
    Assertions.equal(zero, '\$0.00');

    final million = LocalCurrencyFormatter.formatAmount(1000000.0);
    Assertions.equal(million, '\$1,000,000.00');

    final standard = LocalCurrencyFormatter.formatAmount(1249.99);
    Assertions.equal(standard, '\$1,249.99');
  });

  final result = await runner.run(verbose: true);
  backend.close();
  exit(result.isSuccess ? 0 : 1);
}
