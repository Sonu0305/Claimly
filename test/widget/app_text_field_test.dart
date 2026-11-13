import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:claimly/core/widgets/app_text_field.dart';
import '../test_helpers/pump_app.dart';

void main() {
  group('AppTextField Widget Tests', () {
    testWidgets('AppTextField renders label, hint, and accepts text input', (tester) async {
      final controller = TextEditingController();

      await tester.pumpApp(
        AppTextField(
          label: 'Email',
          hint: 'name@example.com',
          controller: controller,
        ),
        wrapScaffold: true,
      );

      expect(find.text('Email'), findsOneWidget);
      expect(find.text('name@example.com'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), 'test@example.com');
      await tester.pump();

      expect(controller.text, equals('test@example.com'));
    });

    testWidgets('AppTextField toggles password visibility on icon tap', (tester) async {
      await tester.pumpApp(
        const AppTextField(
          label: 'Password',
          isPassword: true,
        ),
        wrapScaffold: true,
      );

      // Initially password is obscured and visibility_off is shown
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
      expect(find.byIcon(Icons.visibility_outlined), findsNothing);

      // Tap toggle icon
      await tester.tap(find.byIcon(Icons.visibility_off_outlined));
      await tester.pump();

      // Now visibility icon is shown
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
      expect(find.byIcon(Icons.visibility_off_outlined), findsNothing);
    });

    testWidgets('AppTextField displays validation error when Form is validated', (tester) async {
      final formKey = GlobalKey<FormState>();

      await tester.pumpApp(
        Form(
          key: formKey,
          child: AppTextField(
            label: 'Required Field',
            validator: (value) => (value == null || value.isEmpty) ? 'Field is required' : null,
          ),
        ),
        wrapScaffold: true,
      );

      formKey.currentState!.validate();
      await tester.pump();

      expect(find.text('Field is required'), findsOneWidget);
    });
  });
}

