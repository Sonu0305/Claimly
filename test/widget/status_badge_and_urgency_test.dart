import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:claimly/core/widgets/expiry_alert_card.dart';
import 'package:claimly/core/widgets/status_badge.dart';
import 'package:claimly/features/customer/claims/widgets/claim_priority_chip.dart';
import '../test_helpers/pump_app.dart';

void main() {
  group('StatusBadge, PriorityChip & ExpiryAlertCard Widget Tests', () {
    testWidgets('StatusBadge displays correct labels and icons for multiple statuses', (tester) async {
      await tester.pumpApp(
        const Column(
          children: [
            StatusBadge(status: 'active'),
            StatusBadge(status: 'expired'),
            StatusBadge(status: 'under_review'),
            StatusBadge(status: 'approved'),
          ],
        ),
        wrapScaffold: true,
      );

      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Expired'), findsOneWidget);
      expect(find.text('Under Review'), findsOneWidget);
      expect(find.text('Approved'), findsOneWidget);

      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
      expect(find.byIcon(Icons.cancel_outlined), findsOneWidget);
      expect(find.byIcon(Icons.rate_review_outlined), findsOneWidget);
      expect(find.byIcon(Icons.verified_outlined), findsOneWidget);
    });

    testWidgets('ClaimPriorityChip displays score and priority category', (tester) async {
      await tester.pumpApp(
        const Column(
          children: [
            ClaimPriorityChip(priority: 85),
            ClaimPriorityChip(priority: 35),
          ],
        ),
        wrapScaffold: true,
      );

      expect(find.text('85/100 • High Priority'), findsOneWidget);
      expect(find.text('35/100 • Standard'), findsOneWidget);
      expect(find.byIcon(Icons.bolt), findsNWidgets(2));
    });

    testWidgets('ExpiryAlertCard renders critical urgency and triggers onFileClaim callback', (tester) async {
      bool claimFiled = false;

      await tester.pumpApp(
        ExpiryAlertCard(
          productName: 'MacBook Air M2',
          expiryDate: DateTime(2026, 12, 1),
          daysRemaining: 1,
          onFileClaim: () => claimFiled = true,
        ),
        wrapScaffold: true,
        theme: ThemeData.light(),
      );

      expect(find.text('Critical: Warranty Expires Tomorrow!'), findsOneWidget);
      expect(find.text('MacBook Air M2'), findsOneWidget);
      expect(find.text('1 day left'), findsOneWidget);

      await tester.tap(find.text('File Claim'));
      await tester.pump();

      expect(claimFiled, isTrue);
    });
  });
}
