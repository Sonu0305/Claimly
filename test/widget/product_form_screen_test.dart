import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:claimly/core/utils/date_formatter.dart';
import 'package:claimly/core/utils/warranty_calculator.dart';
import 'package:claimly/features/customer/products/controllers/products_controller.dart';
import 'package:claimly/features/customer/products/screens/product_form_screen.dart';
import '../test_helpers/mocks.dart';
import '../test_helpers/pump_app.dart';

void main() {
  late MockProductRepository mockProductRepo;

  setUpAll(() {
    registerCommonFallbackValues();
  });

  setUp(() {
    mockProductRepo = MockProductRepository();
  });

  group('ProductFormScreen Widget Tests', () {
    testWidgets('ProductFormScreen renders title, input fields, and calculated expiry preview', (tester) async {
      await tester.pumpApp(
        const ProductFormScreen(),
        overrides: [
          productsControllerProvider.overrideWith(
            (ref) => ProductsController(mockProductRepo, 'usr-test'),
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('Register Product'), findsWidgets);
      expect(find.byKey(const Key('product_name_input')), findsOneWidget);
      expect(find.byKey(const Key('product_warranty_months_input')), findsOneWidget);
      expect(find.text('Calculated Warranty Expiry'), findsOneWidget);
    });

    testWidgets('ProductFormScreen displays validation error when product name is empty on save', (tester) async {
      await tester.pumpApp(
        const ProductFormScreen(),
        overrides: [
          productsControllerProvider.overrideWith(
            (ref) => ProductsController(mockProductRepo, 'usr-test'),
          ),
        ],
      );
      await tester.pumpAndSettle();

      // Scroll save button into view and tap it
      await tester.ensureVisible(find.byKey(const Key('product_save_btn')));
      await tester.tap(find.byKey(const Key('product_save_btn')));
      await tester.pumpAndSettle();

      expect(find.text('This field is required'), findsOneWidget);
    });

    testWidgets('ProductFormScreen dynamically updates calculated expiry preview when warranty months change', (tester) async {
      await tester.pumpApp(
        const ProductFormScreen(),
        overrides: [
          productsControllerProvider.overrideWith(
            (ref) => ProductsController(mockProductRepo, 'usr-test'),
          ),
        ],
      );
      await tester.pumpAndSettle();

      // Change warranty months to 36
      final warrantyInput = find.byKey(const Key('product_warranty_months_input'));
      await tester.ensureVisible(warrantyInput);
      await tester.enterText(warrantyInput, '36');
      await tester.pump();

      final expectedExpiry = WarrantyCalculator.calculateExpiryDate(DateTime.now(), 36);
      final formattedExpected = DateFormatter.formatDisplayDate(expectedExpiry);

      expect(find.text(formattedExpected), findsOneWidget);
    });
  });
}

