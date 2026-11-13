import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:claimly/features/customer/claims/models/claim_model.dart';
import 'package:claimly/features/customer/claims/widgets/claim_card.dart';
import 'package:claimly/features/customer/dashboard/widgets/dashboard_kpi_card.dart';
import 'package:claimly/features/customer/products/models/product_model.dart';
import 'package:claimly/features/customer/products/widgets/product_card.dart';
import '../test_helpers/pump_app.dart';

void main() {
  group('Feature Cards Widget Tests (ProductCard, ClaimCard, DashboardKpiCard)', () {
    testWidgets('ProductCard renders product information, status badge, and responds to tap', (tester) async {
      bool tapped = false;
      final product = ProductModel(
        id: 'p1',
        userId: 'u1',
        name: 'Sony WH-1000XM5',
        category: 'Electronics',
        brand: 'Sony',
        modelNumber: 'WH1000XM5',
        purchaseDate: DateTime(2025, 1, 1),
        warrantyPeriodMonths: 24,
        warrantyExpiryDate: DateTime(2027, 1, 1),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpApp(
        ProductCard(
          product: product,
          onTap: () => tapped = true,
        ),
        wrapScaffold: true,
      );

      expect(find.text('Sony WH-1000XM5'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(find.byIcon(Icons.inventory_2_outlined), findsOneWidget);

      await tester.tap(find.text('Sony WH-1000XM5'));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('ClaimCard renders claim number, title, date, priority chip, and handles tap', (tester) async {
      bool tapped = false;
      final claim = ClaimModel(
        id: 'c1',
        claimNumber: 'CLM-001',
        userId: 'u1',
        productId: 'p1',
        type: 'warranty',
        status: 'submitted',
        title: 'Battery draining fast',
        description: 'Battery dies in 30 minutes',
        priority: 65,
        createdAt: DateTime(2026, 1, 10),
        updatedAt: DateTime(2026, 1, 10),
      );

      await tester.pumpApp(
        ClaimCard(
          claim: claim,
          onTap: () => tapped = true,
        ),
        wrapScaffold: true,
      );

      expect(find.text('CLM-001'), findsOneWidget);
      expect(find.text('Battery draining fast'), findsOneWidget);
      expect(find.text('Submitted'), findsOneWidget);
      expect(find.text('65/100 • Medium Priority'), findsOneWidget);

      await tester.tap(find.text('CLM-001'));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('DashboardKpiCard displays metric value, title, icon, and handles tap', (tester) async {
      bool tapped = false;

      await tester.pumpApp(
        DashboardKpiCard(
          title: 'Active Warranties',
          value: '14',
          icon: Icons.shield,
          color: Colors.blue,
          onTap: () => tapped = true,
        ),
        wrapScaffold: true,
      );

      expect(find.text('14'), findsOneWidget);
      expect(find.text('Active Warranties'), findsOneWidget);
      expect(find.byIcon(Icons.shield), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward_ios), findsOneWidget);

      await tester.tap(find.text('Active Warranties'));
      await tester.pump();

      expect(tapped, isTrue);
    });
  });
}

