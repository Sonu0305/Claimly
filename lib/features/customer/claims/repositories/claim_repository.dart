import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/supabase_client.dart';
import '../models/claim_model.dart';
import '../models/claim_timeline_model.dart';

abstract class ClaimRepository {
  Future<List<ClaimModel>> fetchClaims({String? userId, String? statusTab});
  Future<ClaimModel> getClaimDetail(String claimId);
  Future<Map<String, dynamic>> validateClaim(Map<String, dynamic> payload);
  Future<Map<String, dynamic>> submitClaim(Map<String, dynamic> payload);
  Future<String> uploadAttachment({
    required String userId,
    required String claimId,
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
  });
  RealtimeChannel subscribeToClaimTimeline({
    required String claimId,
    required void Function(ClaimTimelineModel timeline) onInsert,
  });
  RealtimeChannel subscribeToClaim({
    required String claimId,
    required void Function(Map<String, dynamic> updated) onUpdate,
  });
}

class ClaimRepositoryImpl implements ClaimRepository {
  final SupabaseClient _supabase;

  ClaimRepositoryImpl(this._supabase);

  @override
  Future<List<ClaimModel>> fetchClaims({String? userId, String? statusTab}) async {
    try {
      var query = _supabase.from('claims').select('''
        id, claim_number, user_id, product_id, type, status, title, description,
        issue_category, incident_date, priority, admin_notes, resolution_notes,
        resolved_at, created_at, updated_at,
        products(id, user_id, name, category, brand, model_number, serial_number,
                 purchase_date, warranty_period_months, warranty_expiry_date,
                 receipt_url, image_url, retailer, notes, created_at, updated_at)
      ''');

      if (userId != null && userId.isNotEmpty) {
        query = query.eq('user_id', userId);
      }

      if (statusTab != null && statusTab != 'all') {
        if (statusTab == 'pending') {
          query = query.inFilter('status', ['draft', 'submitted', 'under_review']);
        } else if (statusTab == 'approved') {
          query = query.inFilter('status', ['approved', 'completed']);
        } else if (statusTab == 'rejected') {
          query = query.eq('status', 'rejected');
        }
      }

      final response = await query.order('created_at', ascending: false);
      return (response as List<dynamic>)
          .map((json) => ClaimModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<ClaimModel> getClaimDetail(String claimId) async {
    try {
      final response = await _supabase.from('claims').select('''
        id, claim_number, user_id, product_id, type, status, title, description,
        issue_category, incident_date, priority, admin_notes, resolution_notes,
        resolved_at, created_at, updated_at,
        products(id, user_id, name, category, brand, model_number, serial_number,
                 purchase_date, warranty_period_months, warranty_expiry_date,
                 receipt_url, image_url, retailer, notes, created_at, updated_at),
        claim_attachments(id, claim_id, file_url, file_name, file_type, file_size, created_at),
        claim_timeline(id, claim_id, from_status, to_status, changed_by, notes, created_at)
      ''').eq('id', claimId).single();

      return ClaimModel.fromJson(response);
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<Map<String, dynamic>> validateClaim(Map<String, dynamic> payload) async {
    try {
      final response = await _supabase.functions.invoke(
        'claim-processor',
        body: {...payload, 'action': 'validate'},
      );
      if (response.status != 200) {
        throw ServerException(message: 'Validation failed: ${response.data}');
      }
      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<Map<String, dynamic>> submitClaim(Map<String, dynamic> payload) async {
    try {
      final response = await _supabase.functions.invoke(
        'claim-processor',
        body: {...payload, 'action': 'submit'},
      );
      if (response.status != 200) {
        throw ServerException(message: 'Submission failed: ${response.data}');
      }
      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<String> uploadAttachment({
    required String userId,
    required String claimId,
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    try {
      final cleanFileName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final path = '$userId/$claimId/${DateTime.now().millisecondsSinceEpoch}_$cleanFileName';

      await _supabase.storage.from('claim-attachments').uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(contentType: mimeType, upsert: true),
      );

      final signedUrl = await _supabase.storage
          .from('claim-attachments')
          .createSignedUrl(path, 60 * 60 * 24 * 7); // 7 days
      return signedUrl;
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  RealtimeChannel subscribeToClaimTimeline({
    required String claimId,
    required void Function(ClaimTimelineModel timeline) onInsert,
  }) {
    final channel = _supabase.channel('public:claim_timeline:$claimId');

    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'claim_timeline',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'claim_id',
        value: claimId,
      ),
      callback: (payload) {
        if (payload.newRecord.isNotEmpty) {
          onInsert(ClaimTimelineModel.fromJson(payload.newRecord));
        }
      },
    );

    channel.subscribe();
    return channel;
  }

  @override
  RealtimeChannel subscribeToClaim({
    required String claimId,
    required void Function(Map<String, dynamic> updated) onUpdate,
  }) {
    final channel = _supabase.channel('public:claims:$claimId');

    channel.onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'claims',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'id',
        value: claimId,
      ),
      callback: (payload) {
        if (payload.newRecord.isNotEmpty) {
          onUpdate(payload.newRecord);
        }
      },
    );

    channel.subscribe();
    return channel;
  }
}

final claimRepositoryProvider = Provider<ClaimRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return ClaimRepositoryImpl(supabase);
});

