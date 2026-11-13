import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:claimly/core/errors/exceptions.dart';
import 'package:claimly/features/auth/controllers/auth_controller.dart';
import '../../test_helpers/mocks.dart';
import '../../test_helpers/test_fixtures.dart';

void main() {
  late MockAuthRepository mockAuthRepository;

  setUpAll(() {
    registerCommonFallbackValues();
  });

  setUp(() {
    mockAuthRepository = MockAuthRepository();
  });

  group('AuthController Tests', () {
    test('AuthController initializes and fetches current user profile', () async {
      when(() => mockAuthRepository.getCurrentUserProfile())
          .thenAnswer((_) async => sampleUserProfile);

      final controller = AuthController(mockAuthRepository);

      // Await async initialization
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.value, equals(sampleUserProfile));
      expect(controller.state.value?.id, equals(sampleUserProfile.id));
      verify(() => mockAuthRepository.getCurrentUserProfile()).called(1);
    });

    test('login updates state to AsyncData on success', () async {
      when(() => mockAuthRepository.getCurrentUserProfile())
          .thenAnswer((_) async => null);

      final controller = AuthController(mockAuthRepository);
      await Future<void>.delayed(Duration.zero);

      when(() => mockAuthRepository.signInWithEmailAndPassword(
            email: 'sarah.jenkins@claimly.com',
            password: 'SecurePassword123!',
          )).thenAnswer((_) async => sampleUserProfile);

      final user = await controller.login(
        email: 'sarah.jenkins@claimly.com',
        password: 'SecurePassword123!',
      );

      expect(user, equals(sampleUserProfile));
      expect(controller.state.value, equals(sampleUserProfile));
    });

    test('login sets state to AsyncError and rethrows on failure', () async {
      when(() => mockAuthRepository.getCurrentUserProfile())
          .thenAnswer((_) async => null);

      final controller = AuthController(mockAuthRepository);
      await Future<void>.delayed(Duration.zero);

      when(() => mockAuthRepository.signInWithEmailAndPassword(
            email: 'bad@example.com',
            password: 'wrong',
          )).thenThrow(const ServerException(message: 'Invalid email or password'));

      expect(
        () => controller.login(
          email: 'bad@example.com',
          password: 'wrong',
        ),
        throwsA(isA<ServerException>()),
      );

      // Verify controller state transitioned to AsyncError
      expect(controller.state.hasError, isTrue);
      expect(
        controller.state.error.toString(),
        contains('Invalid email or password'),
      );
    });

    test('logout clears user state to AsyncData(null)', () async {
      when(() => mockAuthRepository.getCurrentUserProfile())
          .thenAnswer((_) async => sampleUserProfile);
      when(() => mockAuthRepository.signOut()).thenAnswer((_) async {});

      final controller = AuthController(mockAuthRepository);
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.value, isNotNull);

      await controller.logout();

      expect(controller.state.hasValue, isTrue);
      expect(controller.state.value, isNull);
      verify(() => mockAuthRepository.signOut()).called(1);
    });
  });
}
