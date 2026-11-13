import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:claimly/features/customer/claims/repositories/claim_repository.dart';
import '../../test_helpers/mocks.dart';
import '../../test_helpers/test_fixtures.dart';

void main() {
  late MockSupabaseClient mockSupabase;
  late MockFunctionsClient mockFunctions;
  late MockFunctionResponse mockFunctionResponse;
  late ClaimRepositoryImpl repository;

  setUpAll(() {
    registerCommonFallbackValues();
  });

  setUp(() {
    mockSupabase = MockSupabaseClient();
    mockFunctions = MockFunctionsClient();
    mockFunctionResponse = MockFunctionResponse();

    when(() => mockSupabase.functions).thenReturn(mockFunctions);
    repository = ClaimRepositoryImpl(mockSupabase);
  });

  group('ClaimRepositoryImpl Tests', () {
    test('fetchClaims returns mapped ClaimModel list', () async {
      when(() => mockSupabase.from('claims')).thenAnswer(
        (_) => FakeSupabaseQueryBuilder([sampleClaim.toJson()]),
      );

      final claims = await repository.fetchClaims(userId: 'usr-customer-001');

      expect(claims.length, equals(1));
      expect(claims.first.id, equals(sampleClaim.id));
      expect(claims.first.claimNumber, equals(sampleClaim.claimNumber));
    });

    test('getClaimDetail queries claim with attachments and timeline', () async {
      when(() => mockSupabase.from('claims')).thenAnswer(
        (_) => FakeSupabaseQueryBuilder(sampleClaim.toJson()),
      );

      final detail = await repository.getClaimDetail('clm-001');

      expect(detail.id, equals('clm-001'));
      expect(detail.title, equals(sampleClaim.title));
      expect(detail.priority, equals(85));
    });

    test('validateClaim invokes claim-processor Edge Function with validate action', () async {
      when(() => mockFunctionResponse.status).thenReturn(200);
      when(() => mockFunctionResponse.data).thenReturn({
        'valid': true,
        'calculated_priority': 85,
        'message': 'Claim meets warranty criteria',
      });

      when(() => mockFunctions.invoke(
            'claim-processor',
            body: any(named: 'body'),
          )).thenAnswer((_) async => mockFunctionResponse);

      final result = await repository.validateClaim({
        'product_id': 'prod-001',
        'type': 'warranty',
      });

      expect(result['valid'], isTrue);
      expect(result['calculated_priority'], equals(85));
      verify(() => mockFunctions.invoke(
            'claim-processor',
            body: any(
              named: 'body',
              that: containsPair('action', 'validate'),
            ),
          )).called(1);
    });

    test('submitClaim invokes claim-processor Edge Function with submit action', () async {
      when(() => mockFunctionResponse.status).thenReturn(200);
      when(() => mockFunctionResponse.data).thenReturn({
        'success': true,
        'claim_id': 'clm-001',
        'claim_number': 'CLM-2026-0001',
      });

      when(() => mockFunctions.invoke(
            'claim-processor',
            body: any(named: 'body'),
          )).thenAnswer((_) async => mockFunctionResponse);

      final result = await repository.submitClaim({
        'product_id': 'prod-001',
        'title': 'Display issue',
      });

      expect(result['success'], isTrue);
      expect(result['claim_number'], equals('CLM-2026-0001'));
      verify(() => mockFunctions.invoke(
            'claim-processor',
            body: any(
              named: 'body',
              that: containsPair('action', 'submit'),
            ),
          )).called(1);
    });
  });
}
