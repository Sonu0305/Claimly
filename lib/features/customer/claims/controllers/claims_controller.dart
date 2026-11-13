import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/supabase_client.dart';
import '../models/claim_model.dart';
import '../repositories/claim_repository.dart';

class ClaimsState {
  final List<ClaimModel> claims;
  final bool isLoading;
  final String? errorMessage;
  final String selectedStatusTab; // 'all', 'pending', 'approved', 'rejected'
  final String searchQuery;

  const ClaimsState({
    this.claims = const [],
    this.isLoading = false,
    this.errorMessage,
    this.selectedStatusTab = 'all',
    this.searchQuery = '',
  });

  List<ClaimModel> get filteredClaims {
    return claims.where((claim) {
      // Tab status filter
      if (selectedStatusTab == 'pending') {
        if (!claim.isPending) return false;
      } else if (selectedStatusTab == 'approved') {
        if (!claim.isApproved && !claim.isCompleted) return false;
      } else if (selectedStatusTab == 'rejected') {
        if (!claim.isRejected) return false;
      }

      // Search query filter
      if (searchQuery.isNotEmpty) {
        final query = searchQuery.toLowerCase();
        final matchNum = claim.claimNumber.toLowerCase().contains(query);
        final matchTitle = claim.title.toLowerCase().contains(query);
        final matchProd = (claim.product?.name ?? '').toLowerCase().contains(query);
        if (!matchNum && !matchTitle && !matchProd) return false;
      }

      return true;
    }).toList();
  }

  ClaimsState copyWith({
    List<ClaimModel>? claims,
    bool? isLoading,
    String? errorMessage,
    String? selectedStatusTab,
    String? searchQuery,
  }) {
    return ClaimsState(
      claims: claims ?? this.claims,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      selectedStatusTab: selectedStatusTab ?? this.selectedStatusTab,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

class ClaimsController extends StateNotifier<ClaimsState> {
  final ClaimRepository _repository;
  final String? _userId;

  ClaimsController(this._repository, this._userId)
      : super(const ClaimsState(isLoading: true)) {
    loadClaims();
  }

  Future<void> loadClaims() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final claims = await _repository.fetchClaims(userId: _userId);
      state = state.copyWith(claims: claims, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  void setStatusTab(String tab) {
    state = state.copyWith(selectedStatusTab: tab);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }
}

final claimsControllerProvider =
    StateNotifierProvider<ClaimsController, ClaimsState>((ref) {
  final repo = ref.watch(claimRepositoryProvider);
  final user = ref.watch(currentUserProvider);
  return ClaimsController(repo, user?.id);
});

