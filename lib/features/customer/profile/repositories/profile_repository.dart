import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/supabase_client.dart';

abstract class ProfileRepository {
  Future<Map<String, dynamic>> fetchProfile(String userId);
  Future<void> updateProfile({
    required String userId,
    String? fullName,
    String? phoneNumber,
    String? avatarUrl,
  });
  Future<String> uploadAvatar({
    required String userId,
    required Uint8List bytes,
    required String fileName,
  });
  Future<Map<String, int>> fetchUserStats(String userId);
}

class ProfileRepositoryImpl implements ProfileRepository {
  final SupabaseClient _supabase;

  ProfileRepositoryImpl(this._supabase);

  @override
  Future<Map<String, dynamic>> fetchProfile(String userId) async {
    try {
      final response = await _supabase.from('profiles').select().eq('id', userId).single();
      return response;
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<void> updateProfile({
    required String userId,
    String? fullName,
    String? phoneNumber,
    String? avatarUrl,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (fullName != null) updates['full_name'] = fullName;
      if (phoneNumber != null) updates['phone_number'] = phoneNumber;
      if (avatarUrl != null) updates['avatar_url'] = avatarUrl;

      await _supabase.from('profiles').update(updates).eq('id', userId);
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<String> uploadAvatar({
    required String userId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    try {
      final extension = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : 'jpg';
      final filePath = '$userId/avatar_${DateTime.now().millisecondsSinceEpoch}.$extension';

      await _supabase.storage.from('avatars').uploadBinary(
        filePath,
        bytes,
        fileOptions: FileOptions(upsert: true, contentType: 'image/$extension'),
      );

      return _supabase.storage.from('avatars').getPublicUrl(filePath);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<Map<String, int>> fetchUserStats(String userId) async {
    try {
      final productsResp = await _supabase
          .from('products')
          .select('id, warranty_expiry_date')
          .eq('user_id', userId);

      final claimsResp = await _supabase
          .from('claims')
          .select('id')
          .eq('user_id', userId);

      final products = productsResp as List<dynamic>;
      final claims = claimsResp as List<dynamic>;

      final today = DateTime.now();
      int activeWarranties = 0;
      for (final p in products) {
        final expiryStr = p['warranty_expiry_date'] as String?;
        if (expiryStr != null) {
          final expiry = DateTime.tryParse(expiryStr);
          if (expiry != null && expiry.isAfter(today)) {
            activeWarranties++;
          }
        }
      }

      return {
        'total_products': products.length,
        'active_warranties': activeWarranties,
        'total_claims': claims.length,
      };
    } catch (_) {
      return {
        'total_products': 0,
        'active_warranties': 0,
        'total_claims': 0,
      };
    }
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return ProfileRepositoryImpl(supabase);
});

