import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:claimly/core/errors/exceptions.dart';
import 'package:claimly/features/auth/repositories/auth_repository.dart';
import '../../test_helpers/mocks.dart';
import '../../test_helpers/test_fixtures.dart';

void main() {
  late MockSupabaseClient mockSupabase;
  late MockGoTrueClient mockGoTrue;
  late MockAuthResponse mockAuthResponse;
  late MockUser mockUser;
  late AuthRepositoryImpl repository;

  setUpAll(() {
    registerCommonFallbackValues();
  });

  setUp(() {
    mockSupabase = MockSupabaseClient();
    mockGoTrue = MockGoTrueClient();
    mockAuthResponse = MockAuthResponse();
    mockUser = MockUser();

    when(() => mockSupabase.auth).thenReturn(mockGoTrue);
    when(() => mockUser.id).thenReturn(sampleUserProfile.id);
    when(() => mockUser.email).thenReturn(sampleUserProfile.email);
    when(() => mockAuthResponse.user).thenReturn(mockUser);

    repository = AuthRepositoryImpl(mockSupabase);
  });

  group('AuthRepositoryImpl Tests', () {
    test('signInWithEmailAndPassword returns UserProfile on valid credentials', () async {
      when(() => mockGoTrue.signInWithPassword(
            email: 'sarah.jenkins@claimly.com',
            password: 'password123',
          )).thenAnswer((_) async => mockAuthResponse);

      when(() => mockSupabase.from('profiles')).thenAnswer(
        (_) => FakeSupabaseQueryBuilder(sampleUserProfile.toJson()),
      );

      final result = await repository.signInWithEmailAndPassword(
        email: 'sarah.jenkins@claimly.com',
        password: 'password123',
      );

      expect(result.id, equals(sampleUserProfile.id));
      expect(result.email, equals(sampleUserProfile.email));
      expect(result.fullName, equals(sampleUserProfile.fullName));
    });

    test('signInWithEmailAndPassword throws ServerException when Supabase auth throws AuthException', () async {
      when(() => mockGoTrue.signInWithPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenThrow(const sb.AuthException('Invalid login credentials'));

      expect(
        () => repository.signInWithEmailAndPassword(
          email: 'wrong@example.com',
          password: 'wrongpassword',
        ),
        throwsA(isA<ServerException>().having(
          (e) => e.message,
          'message',
          contains('Invalid login credentials'),
        )),
      );
    });

    test('signUpWithEmailAndPassword registers user and fetches profile', () async {
      when(() => mockGoTrue.signUp(
            email: 'sarah.jenkins@claimly.com',
            password: 'password123',
            data: {'full_name': 'Sarah Jenkins'},
          )).thenAnswer((_) async => mockAuthResponse);

      when(() => mockSupabase.from('profiles')).thenAnswer(
        (_) => FakeSupabaseQueryBuilder(sampleUserProfile.toJson()),
      );

      final result = await repository.signUpWithEmailAndPassword(
        email: 'sarah.jenkins@claimly.com',
        password: 'password123',
        fullName: 'Sarah Jenkins',
      );

      expect(result.id, equals(sampleUserProfile.id));
      expect(result.fullName, equals('Sarah Jenkins'));
    });

    test('signOut calls Supabase signOut', () async {
      when(() => mockGoTrue.signOut()).thenAnswer((_) async {});

      await repository.signOut();

      verify(() => mockGoTrue.signOut()).called(1);
    });
  });
}
