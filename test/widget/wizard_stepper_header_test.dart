import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:claimly/features/customer/claims/claim_wizard/widgets/wizard_stepper_header.dart';
import '../test_helpers/pump_app.dart';

void main() {
  group('WizardStepperHeader Widget Tests', () {
    testWidgets('WizardStepperHeader displays all 5 steps with step 1 active', (tester) async {
      await tester.pumpApp(
        const WizardStepperHeader(currentStep: 0),
        wrapScaffold: true,
      );

      for (final label in WizardStepperHeader.stepLabels) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('WizardStepperHeader renders checkmarks for completed steps and active number for current step', (tester) async {
      // Step 2 is active (index 2: "Details"), steps 0 and 1 are completed
      await tester.pumpApp(
        const WizardStepperHeader(currentStep: 2),
        wrapScaffold: true,
      );

      expect(find.byIcon(Icons.check), findsNWidgets(2));
      expect(find.text('3'), findsOneWidget);
    });
  });
}

