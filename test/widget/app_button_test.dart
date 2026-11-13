import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:claimly/core/widgets/app_button.dart';
import '../test_helpers/pump_app.dart';

void main() {
  group('AppButton Widget Tests', () {
    testWidgets('AppButton renders text and triggers onPressed callback on tap', (tester) async {
      bool tapped = false;

      await tester.pumpApp(
        AppButton(
          text: 'Submit Claim',
          onPressed: () => tapped = true,
        ),
        wrapScaffold: true,
      );

      expect(find.text('Submit Claim'), findsOneWidget);

      await tester.tap(find.text('Submit Claim'));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('AppButton shows CircularProgressIndicator and disables tap when isLoading is true', (tester) async {
      bool tapped = false;

      await tester.pumpApp(
        AppButton(
          text: 'Submit Claim',
          isLoading: true,
          onPressed: () => tapped = true,
        ),
        wrapScaffold: true,
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Submit Claim'), findsNothing);

      await tester.tap(find.byType(CircularProgressIndicator));
      await tester.pump();

      expect(tapped, isFalse);
    });

    testWidgets('AppButton renders leading icon and respects AppButtonVariant.outlined', (tester) async {
      await tester.pumpApp(
        AppButton(
          text: 'Cancel',
          icon: const Icon(Icons.close),
          variant: AppButtonVariant.outlined,
          onPressed: () {},
        ),
        wrapScaffold: true,
      );

      expect(find.text('Cancel'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(find.byType(OutlinedButton), findsOneWidget);
    });

    testWidgets('AppButton disables interaction when onPressed is null', (tester) async {
      await tester.pumpApp(
        const AppButton(
          text: 'Disabled Button',
          onPressed: null,
        ),
        wrapScaffold: true,
      );

      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNull);
    });
  });
}

