import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import '../../../core/errors/exceptions.dart';
import '../../../core/network/supabase_client.dart';
import '../models/user_model.dart';

abstract class AuthRepository {
  Future<UserProfile> signInWithEmailAndPassword({
    required String email,
    required String password,
  });

  Future<UserProfile> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String fullName,
  });

  Future<void> signInWithGoogle();

  Future<void> sendPasswordResetEmail(String email);

  Future<void> signOut();

  Future<UserProfile?> getCurrentUserProfile();

  Future<UserProfile> updateUserProfile({
    String? fullName,
    String? phoneNumber,
    String? avatarUrl,
  });

  Stream<sb.AuthState> get authStateChanges;
  sb.User? get currentAuthUser;
  sb.Session? get currentSession;
}

class AuthRepositoryImpl implements AuthRepository {
  final sb.SupabaseClient _supabase;

  AuthRepositoryImpl(this._supabase);

  @override
  Stream<sb.AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  @override
  sb.User? get currentAuthUser => _supabase.auth.currentUser;

  @override
  sb.Session? get currentSession => _supabase.auth.currentSession;

  @override
  Future<UserProfile> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );

      final user = response.user;
      if (user == null) {
        throw const AuthException(message: 'Login failed: user is null');
      }

      final profile = await _fetchProfileWithRetry(user.id, user.email ?? email);
      return profile;
    } on sb.AuthException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<UserProfile> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email.trim(),
        password: password,
        data: {'full_name': fullName.trim()},
      );

      final user = response.user;
      if (user == null) {
        throw const AuthException(message: 'Registration failed: user is null');
      }

      final profile = await _fetchProfileWithRetry(
        user.id,
        user.email ?? email,
        fallbackName: fullName,
      );
      return profile;
    } on sb.AuthException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<void> signInWithGoogle() async {
    try {
      await _supabase.auth.signInWithOAuth(sb.OAuthProvider.google);
    } on sb.AuthException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email.trim());
    } on sb.AuthException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
    } on sb.AuthException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<UserProfile?> getCurrentUserProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    try {
      final profile = await _fetchProfileWithRetry(user.id, user.email ?? '');
      return profile;
    } catch (_) {
      final roleStr = user.appMetadata['role'] as String? ??
          user.userMetadata?['role'] as String? ??
          'customer';
      final name = user.userMetadata?['full_name'] as String?;
      return UserProfile(
        id: user.id,
        email: user.email ?? '',
        role: UserRole.fromString(roleStr),
        fullName: name,
      );
    }
  }

  @override
  Future<UserProfile> updateUserProfile({
    String? fullName,
    String? phoneNumber,
    String? avatarUrl,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw const ServerException(message: 'No authenticated user');
    }

    try {
      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (fullName != null) updates['full_name'] = fullName.trim();
      if (phoneNumber != null) updates['phone_number'] = phoneNumber.trim();
      if (avatarUrl != null) updates['avatar_url'] = avatarUrl;

      final res = await _supabase
          .from('profiles')
          .update(updates)
          .eq('id', user.id)
          .select()
          .single();

      return UserProfile.fromJson(res, email: user.email);
    } on sb.PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  Future<UserProfile> _fetchProfileWithRetry(
    String userId,
    String email, {
    String? fallbackName,
  }) async {
    for (int i = 0; i < 3; i++) {
      try {
        final res = await _supabase
            .from('profiles')
            .select()
            .eq('id', userId)
            .maybeSingle();

        if (res != null) {
          return UserProfile.fromJson(res, email: email);
        }
      } catch (_) {
        // Wait briefly on DB trigger race condition
      }
      if (i < 2) {
        await Future.delayed(const Duration(milliseconds: 300));
      }
    }

    return UserProfile(
      id: userId,
      email: email,
      role: UserRole.customer,
      fullName: fallbackName,
    );
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return AuthRepositoryImpl(supabase);
});

final authStateProvider = StreamProvider<sb.AuthState>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

final currentUserProfileProvider = FutureProvider<UserProfile?>((ref) async {
  final repo = ref.watch(authRepositoryProvider);
  return repo.getCurrentUserProfile();
});
