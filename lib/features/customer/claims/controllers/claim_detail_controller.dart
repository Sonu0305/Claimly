import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/claim_model.dart';
import '../repositories/claim_repository.dart';

class ClaimDetailState {
  final ClaimModel? claim;
  final bool isLoading;
  final String? errorMessage;

  const ClaimDetailState({
    this.claim,
    this.isLoading = false,
    this.errorMessage,
  });

  ClaimDetailState copyWith({
    ClaimModel? claim,
    bool? isLoading,
    String? errorMessage,
  }) {
    return ClaimDetailState(
      claim: claim ?? this.claim,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class ClaimDetailController extends StateNotifier<ClaimDetailState> {
  final ClaimRepository _repository;
  final String _claimId;
  RealtimeChannel? _timelineSubscription;
  RealtimeChannel? _claimSubscription;

  ClaimDetailController(this._repository, this._claimId)
      : super(const ClaimDetailState(isLoading: true)) {
    loadClaim();
    _setupRealtime();
  }

  Future<void> loadClaim() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final claim = await _repository.getClaimDetail(_claimId);
      state = state.copyWith(claim: claim, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  void _setupRealtime() {
    try {
      _timelineSubscription = _repository.subscribeToClaimTimeline(
        claimId: _claimId,
        onInsert: (newEntry) {
          if (state.claim != null) {
            final existing = state.claim!.timeline;
            if (!existing.any((t) => t.id == newEntry.id)) {
              final updatedTimeline = [...existing, newEntry]
                ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
              state = state.copyWith(
                claim: state.claim!.copyWith(
                  timeline: updatedTimeline,
                  status: newEntry.toStatus,
                ),
              );
            }
          }
        },
      );

      _claimSubscription = _repository.subscribeToClaim(
        claimId: _claimId,
        onUpdate: (updatedRecord) {
          if (state.claim != null) {
            state = state.copyWith(
              claim: state.claim!.copyWith(
                status: updatedRecord['status'] as String?,
                priority: (updatedRecord['priority'] as num?)?.toInt(),
                adminNotes: updatedRecord['admin_notes'] as String?,
                resolutionNotes: updatedRecord['resolution_notes'] as String?,
              ),
            );
          }
        },
      );
    } catch (_) {
      // Realtime subscription optional in offline testing
    }
  }

  @override
  void dispose() {
    _timelineSubscription?.unsubscribe();
    _claimSubscription?.unsubscribe();
    super.dispose();
  }
}

final claimDetailControllerProvider = StateNotifierProvider.family<
    ClaimDetailController, ClaimDetailState, String>((ref, claimId) {
  final repo = ref.watch(claimRepositoryProvider);
  return ClaimDetailController(repo, claimId);
});
