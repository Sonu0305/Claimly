import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:claimly/core/errors/exceptions.dart';
import 'package:claimly/features/customer/dashboard/controllers/dashboard_controller.dart';
import '../../test_helpers/mocks.dart';
import '../../test_helpers/test_fixtures.dart';

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

  group('DashboardController Tests', () {
    test('loadDashboard loads products and claims concurrently and populates state', () async {
      when(() => mockProductRepo.getProducts(userId: 'usr-customer-001'))
          .thenAnswer((_) async => [sampleProduct]);
      when(() => mockClaimRepo.fetchClaims(userId: 'usr-customer-001'))
          .thenAnswer((_) async => [sampleClaim]);

      final controller = DashboardController(
        mockProductRepo,
        mockClaimRepo,
        'usr-customer-001',
      );

      // Await loadDashboard completion
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.isLoading, isFalse);
      expect(controller.state.products.length, equals(1));
      expect(controller.state.claims.length, equals(1));
      expect(controller.state.errorMessage, isNull);
    });

    test('DashboardState computed getters calculate active warranties and pending claims', () async {
      when(() => mockProductRepo.getProducts(userId: any(named: 'userId')))
          .thenAnswer((_) async => [sampleProduct]);
      when(() => mockClaimRepo.fetchClaims(userId: any(named: 'userId')))
          .thenAnswer((_) async => [sampleClaim]);

      final controller = DashboardController(
        mockProductRepo,
        mockClaimRepo,
        'usr-customer-001',
      );
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.activeWarrantiesCount, equals(1));
      expect(controller.state.pendingClaimsCount, equals(1));
      expect(controller.state.recentClaims.length, equals(1));
    });

    test('loadDashboard sets errorMessage when repository throws error', () async {
      when(() => mockProductRepo.getProducts(userId: any(named: 'userId')))
          .thenThrow(const ServerException(message: 'Database query failed'));
      when(() => mockClaimRepo.fetchClaims(userId: any(named: 'userId')))
          .thenAnswer((_) async => []);

      final controller = DashboardController(
        mockProductRepo,
        mockClaimRepo,
        'usr-customer-001',
      );
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.isLoading, isFalse);
      expect(controller.state.errorMessage, isNotNull);
      expect(controller.state.errorMessage, contains('Database query failed'));
    });
  });
}

