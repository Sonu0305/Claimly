import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:claimly/core/errors/exceptions.dart';
import 'package:claimly/features/customer/claims/controllers/claims_controller.dart';
import 'package:claimly/features/customer/claims/models/claim_model.dart';
import '../../test_helpers/mocks.dart';
import '../../test_helpers/test_fixtures.dart';

void main() {
  late MockClaimRepository mockClaimRepo;

  setUpAll(() {
    registerCommonFallbackValues();
  });

  setUp(() {
    mockClaimRepo = MockClaimRepository();
  });

  group('ClaimsController Tests', () {
    test('loadClaims populates claims list in state', () async {
      when(() => mockClaimRepo.fetchClaims(userId: 'usr-customer-001'))
          .thenAnswer((_) async => [sampleClaim]);

      final controller = ClaimsController(mockClaimRepo, 'usr-customer-001');
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.isLoading, isFalse);
      expect(controller.state.claims.length, equals(1));
      expect(controller.state.claims.first.claimNumber, equals(sampleClaim.claimNumber));
    });

    test('setStatusTab filters claims by status tab (pending, approved, rejected)', () async {
      final now = DateTime.now();

      final pendingClaim = sampleClaim; // status: 'submitted', so isPending = true
      final approvedClaim = ClaimModel(
        id: 'c-app',
        claimNumber: 'CLM-APP-001',
        userId: 'usr-customer-001',
        productId: 'prod-001',
        type: 'warranty',
        status: 'approved',
        title: 'Screen replaced',
        description: 'Completed warranty service',
        createdAt: now,
        updatedAt: now,
      );
      final rejectedClaim = ClaimModel(
        id: 'c-rej',
        claimNumber: 'CLM-REJ-002',
        userId: 'usr-customer-001',
        productId: 'prod-001',
        type: 'refund',
        status: 'rejected',
        title: 'Accidental drop damage',
        description: 'Physical damage not covered',
        createdAt: now,
        updatedAt: now,
      );

      when(() => mockClaimRepo.fetchClaims(userId: any(named: 'userId')))
          .thenAnswer((_) async => [pendingClaim, approvedClaim, rejectedClaim]);

      final controller = ClaimsController(mockClaimRepo, 'usr-customer-001');
      await Future<void>.delayed(Duration.zero);

      // Pending tab
      controller.setStatusTab('pending');
      expect(controller.state.filteredClaims.length, equals(1));
      expect(controller.state.filteredClaims.first.id, equals(pendingClaim.id));

      // Approved tab
      controller.setStatusTab('approved');
      expect(controller.state.filteredClaims.length, equals(1));
      expect(controller.state.filteredClaims.first.id, equals(approvedClaim.id));

      // Rejected tab
      controller.setStatusTab('rejected');
      expect(controller.state.filteredClaims.length, equals(1));
      expect(controller.state.filteredClaims.first.id, equals(rejectedClaim.id));

      // All tab
      controller.setStatusTab('all');
      expect(controller.state.filteredClaims.length, equals(3));
    });

    test('setSearchQuery filters claims by claimNumber and title', () async {
      when(() => mockClaimRepo.fetchClaims(userId: any(named: 'userId')))
          .thenAnswer((_) async => [sampleClaim]);

      final controller = ClaimsController(mockClaimRepo, 'usr-customer-001');
      await Future<void>.delayed(Duration.zero);

      // Search by claim number
      controller.setSearchQuery('2026-0001');
      expect(controller.state.filteredClaims.length, equals(1));

      // Search by keyword in title
      controller.setSearchQuery('flicker');
      expect(controller.state.filteredClaims.length, equals(1));

      // Search non-matching
      controller.setSearchQuery('nonexistent');
      expect(controller.state.filteredClaims, isEmpty);
    });

    test('loadClaims sets errorMessage on repository failure', () async {
      when(() => mockClaimRepo.fetchClaims(userId: any(named: 'userId')))
          .thenThrow(const ServerException(message: 'Network connection lost'));

      final controller = ClaimsController(mockClaimRepo, 'usr-customer-001');
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.isLoading, isFalse);
      expect(controller.state.errorMessage, isNotNull);
      expect(controller.state.errorMessage, contains('Network connection lost'));
    });
  });
}

