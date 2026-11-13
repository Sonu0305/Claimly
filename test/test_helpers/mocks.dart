import 'dart:async';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:claimly/features/auth/repositories/auth_repository.dart';
import 'package:claimly/features/customer/products/repositories/product_repository.dart';
import 'package:claimly/features/customer/claims/repositories/claim_repository.dart';
import 'package:claimly/features/customer/notifications/repositories/notification_repository.dart';
import 'package:claimly/features/customer/profile/repositories/profile_repository.dart';

// Supabase Core Mocks
class MockSupabaseClient extends Mock implements SupabaseClient {}
class MockGoTrueClient extends Mock implements GoTrueClient {}
class MockFunctionsClient extends Mock implements FunctionsClient {}
class MockSupabaseStorageClient extends Mock implements SupabaseStorageClient {}
class MockStorageFileApi extends Mock implements StorageFileApi {}
class MockRealtimeClient extends Mock implements RealtimeClient {}
class MockRealtimeChannel extends Mock implements RealtimeChannel {}

// Auth Entity Mocks
class MockUser extends Mock implements User {}
class MockSession extends Mock implements Session {}
class MockAuthResponse extends Mock implements AuthResponse {}
class MockFunctionResponse extends Mock implements FunctionResponse {}

// Repository Mocks
class MockAuthRepository extends Mock implements AuthRepository {}
class MockProductRepository extends Mock implements ProductRepository {}
class MockClaimRepository extends Mock implements ClaimRepository {}
class MockNotificationRepository extends Mock implements NotificationRepository {}
class MockProfileRepository extends Mock implements ProfileRepository {}

// Fake PostgREST Builder implementations to allow fluent chaining and await
class FakePostgrestTransformBuilder<T> extends Fake implements PostgrestTransformBuilder<T> {
  final dynamic _result;
  final Object? _error;

  FakePostgrestTransformBuilder(this._result, [this._error]);

  @override
  PostgrestTransformBuilder<PostgrestMap> single() {
    return FakePostgrestTransformBuilder<PostgrestMap>(_result, _error);
  }

  @override
  PostgrestTransformBuilder<PostgrestMap?> maybeSingle() {
    return FakePostgrestTransformBuilder<PostgrestMap?>(_result, _error);
  }

  @override
  PostgrestTransformBuilder<T> order(
    String column, {
    bool ascending = false,
    bool nullsFirst = false,
    String? referencedTable,
  }) {
    return this;
  }

  @override
  Future<R> then<R>(FutureOr<R> Function(T value) onValue, {Function? onError}) {
    if (_error != null) {
      return Future<T>.error(_error).then(onValue, onError: onError);
    }
    return Future<T>.value(_result as T).then(onValue, onError: onError);
  }
}

class FakePostgrestFilterBuilder<T> extends Fake implements PostgrestFilterBuilder<T> {
  final dynamic _result;
  final Object? _error;

  FakePostgrestFilterBuilder(this._result, [this._error]);

  @override
  PostgrestFilterBuilder<T> eq(String column, Object value) => this;

  @override
  PostgrestFilterBuilder<T> inFilter(String column, List<dynamic> values) => this;

  @override
  PostgrestTransformBuilder<T> order(
    String column, {
    bool ascending = false,
    bool nullsFirst = false,
    String? referencedTable,
  }) {
    return FakePostgrestTransformBuilder<T>(_result, _error);
  }

  @override
  PostgrestTransformBuilder<PostgrestList> select([String columns = '*']) {
    return FakePostgrestTransformBuilder<PostgrestList>(_result, _error);
  }

  @override
  PostgrestTransformBuilder<PostgrestMap> single() {
    return FakePostgrestTransformBuilder<PostgrestMap>(
      _result as PostgrestMap,
      _error,
    );
  }

  @override
  PostgrestTransformBuilder<PostgrestMap?> maybeSingle() {
    return FakePostgrestTransformBuilder<PostgrestMap?>(
      _result as PostgrestMap?,
      _error,
    );
  }

  @override
  Future<R> then<R>(FutureOr<R> Function(T value) onValue, {Function? onError}) {
    if (_error != null) {
      return Future<T>.error(_error).then(onValue, onError: onError);
    }
    return Future<T>.value(_result as T).then(onValue, onError: onError);
  }
}

class FakeSupabaseQueryBuilder extends Fake implements SupabaseQueryBuilder {
  final dynamic _result;
  final Object? _error;

  FakeSupabaseQueryBuilder(this._result, [this._error]);

  @override
  PostgrestFilterBuilder<PostgrestList> select([String columns = '*']) {
    return FakePostgrestFilterBuilder<PostgrestList>(_result, _error);
  }

  @override
  PostgrestFilterBuilder<dynamic> insert(Object values, {bool defaultToNull = true}) {
    return FakePostgrestFilterBuilder<dynamic>(_result, _error);
  }

  @override
  PostgrestFilterBuilder<dynamic> update(Map values, {bool defaultToNull = true}) {
    return FakePostgrestFilterBuilder<dynamic>(_result, _error);
  }

  @override
  PostgrestFilterBuilder<dynamic> delete({bool defaultToNull = true}) {
    return FakePostgrestFilterBuilder<dynamic>(_result, _error);
  }
}

class FakeFileOptions extends Fake implements FileOptions {}
class FakeUri extends Fake implements Uri {}

void registerCommonFallbackValues() {
  registerFallbackValue(FakeFileOptions());
  registerFallbackValue(FakeUri());
  registerFallbackValue(OAuthProvider.google);
}
