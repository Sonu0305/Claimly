import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:claimly/core/utils/warranty_calculator.dart';
import 'package:claimly/core/widgets/app_button.dart';
import 'package:claimly/core/widgets/app_text_field.dart';
import 'package:claimly/core/widgets/empty_state.dart';
import 'package:claimly/core/widgets/error_view.dart';
import 'package:claimly/core/widgets/expiry_alert_card.dart';
import 'package:claimly/core/widgets/loading_indicator.dart';
import 'package:claimly/core/widgets/status_badge.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: child,
    ),
  );
}

void main() {
  group('Core Reusable Widgets', () {
    testWidgets('AppButton renders text and triggers callback on tap',
        (tester) async {
      var tapped = false;

      await tester.pumpWidget(_wrap(
        AppButton(
          text: 'Submit Claim',
          onPressed: () => tapped = true,
        ),
      ));

      expect(find.text('Submit Claim'), findsOneWidget);
      await tester.tap(find.text('Submit Claim'));
      expect(tapped, isTrue);
    });

    testWidgets('AppButton shows spinner and disables tap when isLoading is true',
        (tester) async {
      var tapped = false;

      await tester.pumpWidget(_wrap(
        AppButton(
          text: 'Submit Claim',
          isLoading: true,
          onPressed: () => tapped = true,
        ),
      ));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Submit Claim'), findsNothing);

      await tester.tap(find.byType(AppButton));
      expect(tapped, isFalse);
    });

    testWidgets('AppTextField renders label, accepts text, and toggles password',
        (tester) async {
      final controller = TextEditingController();

      await tester.pumpWidget(_wrap(
        AppTextField(
          label: 'Password',
          hint: 'Enter your password',
          isPassword: true,
          controller: controller,
        ),
      ));

      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Enter your password'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), 'MySecret123');
      expect(controller.text, 'MySecret123');

      // Check toggle obscure text button
      final toggleIcon = find.byIcon(Icons.visibility_off_outlined);
      expect(toggleIcon, findsOneWidget);
      await tester.tap(toggleIcon);
      await tester.pump();
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    });

    testWidgets('StatusBadge displays correct text and icons for statuses',
        (tester) async {
      await tester.pumpWidget(_wrap(
        Column(
          children: [
            const StatusBadge(status: 'active'),
            const StatusBadge(status: 'expiring_soon'),
            const StatusBadge(status: 'expired'),
            const StatusBadge(status: 'submitted'),
            const StatusBadge(status: 'approved'),
            const StatusBadge(status: 'rejected'),
            StatusBadge.fromWarrantyStatus(WarrantyStatus.expiringSoon),
          ],
        ),
      ));

      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Expiring Soon'), findsNWidgets(2));
      expect(find.text('Expired'), findsOneWidget);
      expect(find.text('Submitted'), findsOneWidget);
      expect(find.text('Approved'), findsOneWidget);
      expect(find.text('Rejected'), findsOneWidget);
    });

    testWidgets('ExpiryAlertCard renders urgency styling and triggers action',
        (tester) async {
      var filed = false;

      await tester.pumpWidget(_wrap(
        ExpiryAlertCard(
          productName: 'MacBook Pro M3',
          expiryDate: DateTime(2026, 12, 1),
          daysRemaining: 5,
          onFileClaim: () => filed = true,
        ),
      ));

      expect(find.text('MacBook Pro M3'), findsOneWidget);
      expect(find.text('5 days left'), findsOneWidget);
      expect(find.text('Urgent: Warranty Expiring This Week'), findsOneWidget);
      expect(find.text('File Claim'), findsOneWidget);

      await tester.tap(find.text('File Claim'));
      expect(filed, isTrue);
    });

    testWidgets('EmptyState renders title, message, and action button',
        (tester) async {
      var refreshed = false;

      await tester.pumpWidget(_wrap(
        EmptyState(
          title: 'No Claims Found',
          message: 'You have not submitted any warranty claims yet.',
          actionText: 'Start New Claim',
          onAction: () => refreshed = true,
        ),
      ));

      expect(find.text('No Claims Found'), findsOneWidget);
      expect(find.text('You have not submitted any warranty claims yet.'), findsOneWidget);
      expect(find.text('Start New Claim'), findsOneWidget);

      await tester.tap(find.text('Start New Claim'));
      expect(refreshed, isTrue);
    });

    testWidgets('ErrorView displays message and triggers retry',
        (tester) async {
      var retried = false;

      await tester.pumpWidget(_wrap(
        ErrorView(
          message: 'Failed to connect to the server.',
          onRetry: () => retried = true,
        ),
      ));

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text('Failed to connect to the server.'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);

      await tester.tap(find.text('Try Again'));
      expect(retried, isTrue);
    });

    testWidgets('LoadingIndicator renders spinner and optional message',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const LoadingIndicator(
          message: 'Loading products...',
        ),
      ));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading products...'), findsOneWidget);
    });
  });
}
