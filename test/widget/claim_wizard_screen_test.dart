import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:claimly/features/customer/claims/claim_wizard/screens/claim_wizard_screen.dart';
import 'package:claimly/features/customer/claims/repositories/claim_repository.dart';
import 'package:claimly/features/customer/products/controllers/products_controller.dart';
import '../test_helpers/mocks.dart';
import '../test_helpers/pump_app.dart';
import '../test_helpers/test_fixtures.dart';

void main() {
  late MockProductRepository mockProductRepo;
  late MockClaimRepository mockClaimRepo;

  setUpAll(() {
    registerCommonFallbackValues();
  });

  setUp(() {
    mockProductRepo = MockProductRepository();
    mockClaimRepo = MockClaimRepository();
  });

  group('ClaimWizardScreen Widget Tests', () {
    testWidgets('ClaimWizardScreen initializes at step 1 with Next button disabled when no product is selected', (tester) async {
      await tester.pumpApp(
        const ClaimWizardScreen(),
        overrides: [
          claimRepositoryProvider.overrideWith((ref) => mockClaimRepo),
          productsControllerProvider.overrideWith(
            (ref) => ProductsController(mockProductRepo, 'usr-test'),
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('File New Claim (1/5)'), findsOneWidget);

      final nextButton = tester.widget<ElevatedButton>(find.byKey(const Key('wizard_next_btn')));
      expect(nextButton.onPressed, isNull);

      expect(find.byKey(const Key('wizard_back_btn')), findsNothing);
    });

    testWidgets('ClaimWizardScreen enables Next button with preselected product and advances to Step 2', (tester) async {
      final controller = ProductsController(mockProductRepo, 'usr-test');
      controller.state = controller.state.copyWith(
        products: [sampleProduct],
        isLoading: false,
      );

      await tester.pumpApp(
        ClaimWizardScreen(initialProductId: sampleProduct.id),
        theme: ThemeData.light(),
        overrides: [
          claimRepositoryProvider.overrideWith((ref) => mockClaimRepo),
          productsControllerProvider.overrideWith((ref) => controller),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('File New Claim (1/5)'), findsOneWidget);

      final nextButton = tester.widget<ElevatedButton>(find.byKey(const Key('wizard_next_btn')));
      expect(nextButton.onPressed, isNotNull);

      // Tap Next button to advance to Step 2
      await tester.tap(find.byKey(const Key('wizard_next_btn')));
      await tester.pumpAndSettle();

      expect(find.text('File New Claim (2/5)'), findsOneWidget);
      expect(find.byKey(const Key('wizard_back_btn')), findsOneWidget);
    });

    testWidgets('ClaimWizardScreen displays discard confirmation dialog when cancel icon is tapped', (tester) async {
      await tester.pumpApp(
        const ClaimWizardScreen(),
        overrides: [
          claimRepositoryProvider.overrideWith((ref) => mockClaimRepo),
          productsControllerProvider.overrideWith(
            (ref) => ProductsController(mockProductRepo, 'usr-test'),
          ),
        ],
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('wizard_cancel_btn')));
      await tester.pumpAndSettle();

      expect(find.text('Discard Claim Draft?'), findsOneWidget);
      expect(find.text('Continue Editing'), findsOneWidget);
      expect(find.text('Discard Draft'), findsOneWidget);
    });
  });
}
