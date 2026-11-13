import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:claimly/core/widgets/empty_state.dart';
import 'package:claimly/core/widgets/error_view.dart';
import 'package:claimly/core/widgets/loading_indicator.dart';
import '../test_helpers/pump_app.dart';

void main() {
  group('Feedback Views Widget Tests', () {
    testWidgets('EmptyState displays icon, title, message, and executes action', (tester) async {
      bool actionTriggered = false;

      await tester.pumpApp(
        EmptyState(
          title: 'No Claims',
          message: 'No claims submitted yet.',
          actionText: 'Create Claim',
          onAction: () => actionTriggered = true,
        ),
        wrapScaffold: true,
      );

      expect(find.text('No Claims'), findsOneWidget);
      expect(find.text('No claims submitted yet.'), findsOneWidget);
      expect(find.text('Create Claim'), findsOneWidget);

      await tester.tap(find.text('Create Claim'));
      await tester.pump();

      expect(actionTriggered, isTrue);
    });

    testWidgets('ErrorView displays title, error message, and triggers retry callback', (tester) async {
      bool retryTriggered = false;

      await tester.pumpApp(
        ErrorView(
          message: 'Failed to load data from server.',
          onRetry: () => retryTriggered = true,
        ),
        wrapScaffold: true,
      );

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text('Failed to load data from server.'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);

      await tester.tap(find.text('Try Again'));
      await tester.pump();

      expect(retryTriggered, isTrue);
    });

    testWidgets('LoadingIndicator renders spinner and descriptive text', (tester) async {
      await tester.pumpApp(
        const LoadingIndicator(
          message: 'Loading details...',
        ),
        wrapScaffold: true,
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading details...'), findsOneWidget);
    });
  });
}

