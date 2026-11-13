import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide StorageException;
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/supabase_client.dart';
import '../models/product_model.dart';

abstract class ProductRepository {
  Future<List<ProductModel>> getProducts({String? userId});
  Future<ProductModel> getProductById(String id);
  Future<ProductModel> createProduct(ProductModel product);
  Future<ProductModel> updateProduct(ProductModel product);
  Future<void> deleteProduct(String id);
  Future<String> uploadReceipt({
    required String userId,
    required String fileName,
    required Uint8List bytes,
    String? mimeType,
  });
  Future<String> uploadProductImage({
    required String userId,
    required String fileName,
    required Uint8List bytes,
    String? mimeType,
  });
}

class ProductRepositoryImpl implements ProductRepository {
  final SupabaseClient _supabase;

  ProductRepositoryImpl(this._supabase);

  @override
  Future<List<ProductModel>> getProducts({String? userId}) async {
    try {
      var query = _supabase.from('products').select();
      if (userId != null && userId.isNotEmpty) {
        query = query.eq('user_id', userId);
      }
      final response = await query.order('created_at', ascending: false);
      return (response as List<dynamic>)
          .map((json) => ProductModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<ProductModel> getProductById(String id) async {
    try {
      final response = await _supabase
          .from('products')
          .select()
          .eq('id', id)
          .single();
      return ProductModel.fromJson(response);
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<ProductModel> createProduct(ProductModel product) async {
    try {
      final payload = product.toJson();
      // Ensure clean payload for DB insertion
      payload.remove('id');
      final response = await _supabase
          .from('products')
          .insert(payload)
          .select()
          .single();
      return ProductModel.fromJson(response);
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<ProductModel> updateProduct(ProductModel product) async {
    try {
      final payload = product.toJson();
      payload['updated_at'] = DateTime.now().toIso8601String();
      final response = await _supabase
          .from('products')
          .update(payload)
          .eq('id', product.id)
          .select()
          .single();
      return ProductModel.fromJson(response);
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<void> deleteProduct(String id) async {
    try {
      await _supabase.from('products').delete().eq('id', id);
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<String> uploadReceipt({
    required String userId,
    required String fileName,
    required Uint8List bytes,
    String? mimeType,
  }) async {
    try {
      final cleanFileName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final path = '$userId/${DateTime.now().millisecondsSinceEpoch}_$cleanFileName';

      await _supabase.storage.from('receipts').uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(
          contentType: mimeType ?? 'application/pdf',
          upsert: true,
        ),
      );

      // Receipts bucket is private; create signed URL for secure access
      final signedUrl = await _supabase.storage
          .from('receipts')
          .createSignedUrl(path, 60 * 60 * 24 * 7); // 7 days
      return signedUrl;
    } on sb.StorageException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<String> uploadProductImage({
    required String userId,
    required String fileName,
    required Uint8List bytes,
    String? mimeType,
  }) async {
    try {
      final cleanFileName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final path = '$userId/${DateTime.now().millisecondsSinceEpoch}_$cleanFileName';

      await _supabase.storage.from('product-images').uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(
          contentType: mimeType ?? 'image/jpeg',
          upsert: true,
        ),
      );

      return _supabase.storage.from('product-images').getPublicUrl(path);
    } on sb.StorageException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }
}

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return ProductRepositoryImpl(supabase);
});
