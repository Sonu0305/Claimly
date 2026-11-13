import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/supabase_client.dart';
import '../repositories/profile_repository.dart';

class ProfileState {
  final String? userId;
  final String? email;
  final String? fullName;
  final String? phoneNumber;
  final String? avatarUrl;
  final String role;
  final int totalProducts;
  final int activeWarranties;
  final int totalClaims;
  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;
  final String? successMessage;

  const ProfileState({
    this.userId,
    this.email,
    this.fullName,
    this.phoneNumber,
    this.avatarUrl,
    this.role = 'customer',
    this.totalProducts = 0,
    this.activeWarranties = 0,
    this.totalClaims = 0,
    this.isLoading = false,
    this.isSaving = false,
    this.errorMessage,
    this.successMessage,
  });

  bool get isAdmin => role == 'admin';

  ProfileState copyWith({
    String? userId,
    String? email,
    String? fullName,
    String? phoneNumber,
    String? avatarUrl,
    String? role,
    int? totalProducts,
    int? activeWarranties,
    int? totalClaims,
    bool? isLoading,
    bool? isSaving,
    String? errorMessage,
    String? successMessage,
  }) {
    return ProfileState(
      userId: userId ?? this.userId,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
      totalProducts: totalProducts ?? this.totalProducts,
      activeWarranties: activeWarranties ?? this.activeWarranties,
      totalClaims: totalClaims ?? this.totalClaims,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: errorMessage,
      successMessage: successMessage,
    );
  }
}

class ProfileController extends StateNotifier<ProfileState> {
  final ProfileRepository _repo;
  final SupabaseClient _supabase;

  ProfileController(this._repo, this._supabase)
      : super(const ProfileState(isLoading: true)) {
    loadProfile();
  }

  Future<void> loadProfile() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        state = state.copyWith(isLoading: false);
        return;
      }

      final profileData = await _repo.fetchProfile(user.id);
      final stats = await _repo.fetchUserStats(user.id);

      state = state.copyWith(
        userId: user.id,
        email: user.email,
        fullName: profileData['full_name'] as String?,
        phoneNumber: profileData['phone_number'] as String?,
        avatarUrl: profileData['avatar_url'] as String?,
        role: profileData['role'] as String? ?? 'customer',
        totalProducts: stats['total_products'] ?? 0,
        activeWarranties: stats['active_warranties'] ?? 0,
        totalClaims: stats['total_claims'] ?? 0,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> updateProfile({String? fullName, String? phoneNumber}) async {
    if (state.userId == null) return;
    state = state.copyWith(isSaving: true, errorMessage: null, successMessage: null);
    try {
      await _repo.updateProfile(
        userId: state.userId!,
        fullName: fullName,
        phoneNumber: phoneNumber,
      );
      state = state.copyWith(
        fullName: fullName ?? state.fullName,
        phoneNumber: phoneNumber ?? state.phoneNumber,
        isSaving: false,
        successMessage: 'Profile updated successfully!',
      );
    } catch (e) {
      state = state.copyWith(isSaving: false, errorMessage: e.toString());
    }
  }

  Future<void> uploadAvatar(Uint8List bytes, String fileName) async {
    if (state.userId == null) return;
    state = state.copyWith(isSaving: true, errorMessage: null);
    try {
      final publicUrl = await _repo.uploadAvatar(
        userId: state.userId!,
        bytes: bytes,
        fileName: fileName,
      );
      await _repo.updateProfile(userId: state.userId!, avatarUrl: publicUrl);
      state = state.copyWith(avatarUrl: publicUrl, isSaving: false);
    } catch (e) {
      state = state.copyWith(isSaving: false, errorMessage: e.toString());
    }
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }
}

final profileControllerProvider =
    StateNotifierProvider<ProfileController, ProfileState>((ref) {
  final repo = ref.watch(profileRepositoryProvider);
  final supabase = ref.watch(supabaseClientProvider);
  return ProfileController(repo, supabase);
});

