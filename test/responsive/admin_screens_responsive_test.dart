import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:claimly/features/admin/claims_review/controllers/admin_claims_controller.dart';
import 'package:claimly/features/admin/claims_review/screens/admin_claims_screen.dart';
import 'package:claimly/features/admin/dashboard/controllers/admin_dashboard_controller.dart';
import 'package:claimly/features/admin/dashboard/screens/admin_dashboard_screen.dart';
import 'package:claimly/features/admin/users/controllers/admin_users_controller.dart';
import 'package:claimly/features/admin/users/models/admin_user_model.dart';
import 'package:claimly/features/admin/users/screens/admin_users_screen.dart';

import '../test_helpers/mocks.dart';
import '../test_helpers/pump_app.dart';
import '../test_helpers/responsive_test_helper.dart';
import '../test_helpers/test_fixtures.dart';

void main() {
  late MockSupabaseClient mockSupabase;

  setUpAll(() {
    registerCommonFallbackValues();
  });

  setUp(() {
    mockSupabase = MockSupabaseClient();
  });

  final sampleAdminClaimItem = AdminClaimItem(
    id: 'clm-001',
    claimNumber: 'CLM-2026-0001',
    userId: 'usr-customer-001',
    productId: 'prod-001',
    type: 'warranty',
    status: 'submitted',
    title: 'Display flicker and artifacts',
    description: 'Screen randomly glitches with vertical colored lines.',
    priority: 85,
    createdAt: DateTime(2026, 1, 10, 14, 0, 0),
    customerName: 'Sarah Jenkins',
    productName: 'MacBook Pro 16" M3',
    productCategory: 'Electronics',
  );

  final testAdminUser = AdminUserModel(
    id: 'usr-customer-001',
    role: 'customer',
    fullName: 'Sarah Jenkins',
    avatarUrl: null,
    phoneNumber: '+15551234567',
    createdAt: DateTime(2025, 1, 15, 10, 0, 0),
    productCount: 3,
    claimCount: 1,
  );

  group('Admin Screens Responsive Tests', () {
    for (final breakpoint in ResponsiveBreakpoint.values) {
      testWidgets('AdminDashboardScreen renders KPIs and analytics charts without overflow at ${breakpoint.label}', (tester) async {
        await tester.setBreakpoint(breakpoint);

        await tester.pumpApp(
          const AdminDashboardScreen(),
          overrides: [
            adminDashboardControllerProvider.overrideWith(
              (ref) => AdminDashboardController(mockSupabase)..state = const AsyncValue.data(sampleAnalytics),
            ),
          ],
        );
        await tester.pumpAndSettle();

        expectNoRenderFlexOverflow(tester);
        expect(find.byType(AdminDashboardScreen), findsOneWidget);
        expect(find.byKey(const Key('admin_kpi_total_claims')), findsOneWidget);
        expect(find.byKey(const Key('admin_analytics_chart')), findsOneWidget);
      });

      testWidgets('AdminClaimsScreen renders claims directory without overflow at ${breakpoint.label}', (tester) async {
        await tester.setBreakpoint(breakpoint);

        await tester.pumpApp(
          const AdminClaimsScreen(),
          overrides: [
            adminClaimsControllerProvider.overrideWith(
              (ref) => AdminClaimsController(mockSupabase)
                ..state = AdminClaimsState(claims: [sampleAdminClaimItem], isLoading: false),
            ),
          ],
        );
        await tester.pumpAndSettle();

        expectNoRenderFlexOverflow(tester);
        expect(find.byType(AdminClaimsScreen), findsOneWidget);
        expect(find.text('CLM-2026-0001'), findsOneWidget);
      });

      testWidgets('AdminUsersScreen renders user directory without overflow at ${breakpoint.label}', (tester) async {
        await tester.setBreakpoint(breakpoint);

        await tester.pumpApp(
          const AdminUsersScreen(),
          overrides: [
            adminUsersControllerProvider.overrideWith(
              (ref) => AdminUsersController(mockSupabase)
                ..state = AdminUsersState(users: [testAdminUser], isLoading: false),
            ),
          ],
        );
        await tester.pumpAndSettle();

        expectNoRenderFlexOverflow(tester);
        expect(find.byType(AdminUsersScreen), findsOneWidget);
        expect(find.byKey(const Key('admin_user_directory')), findsOneWidget);
        expect(find.text('Sarah Jenkins'), findsOneWidget);
      });
    }

    testWidgets('AdminDashboardScreen renders cleanly at narrow mobile viewport (360x640) with 0px overflow', (tester) async {
      await tester.setViewport(const Size(360, 640));

      await tester.pumpApp(
        const AdminDashboardScreen(),
        overrides: [
          adminDashboardControllerProvider.overrideWith(
            (ref) => AdminDashboardController(mockSupabase)..state = const AsyncValue.data(sampleAnalytics),
          ),
        ],
      );
      await tester.pumpAndSettle();

      expectNoRenderFlexOverflow(tester);
      expect(find.byType(AdminDashboardScreen), findsOneWidget);
    });

    testWidgets('AdminUsersScreen renders cleanly at narrow mobile viewport (360x640) with 0px overflow', (tester) async {
      await tester.setViewport(const Size(360, 640));

      await tester.pumpApp(
        const AdminUsersScreen(),
        overrides: [
          adminUsersControllerProvider.overrideWith(
            (ref) => AdminUsersController(mockSupabase)
              ..state = AdminUsersState(users: [testAdminUser], isLoading: false),
          ),
        ],
      );
      await tester.pumpAndSettle();

      expectNoRenderFlexOverflow(tester);
      expect(find.byType(AdminUsersScreen), findsOneWidget);
    });
  });
}
