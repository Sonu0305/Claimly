import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:claimly/core/network/supabase_client.dart';
import 'package:claimly/features/customer/products/models/product_model.dart';
import '../../repositories/claim_repository.dart';
import '../models/wizard_state.dart';

class ClaimWizardController extends StateNotifier<ClaimWizardState> {
  final ClaimRepository _claimRepo;
  final String? _userId;

  ClaimWizardController(this._claimRepo, this._userId, [ProductModel? initialProduct])
      : super(ClaimWizardState(selectedProduct: initialProduct));

  void selectProduct(ProductModel product) {
    state = state.copyWith(selectedProduct: product);
  }

  void setClaimType(String type) {
    state = state.copyWith(claimType: type);
  }

  void setIssueDetails({
    required String title,
    required String description,
    String? category,
    required DateTime incidentDate,
  }) {
    state = state.copyWith(
      issueTitle: title,
      issueDescription: description,
      issueCategory: category,
      incidentDate: incidentDate,
    );
  }

  void addAttachment(WizardAttachmentItem attachment) {
    state = state.copyWith(
      attachments: [...state.attachments, attachment],
    );
  }

  void removeAttachment(int index) {
    final list = List<WizardAttachmentItem>.from(state.attachments);
    list.removeAt(index);
    state = state.copyWith(attachments: list);
  }

  void nextStep() {
    if (state.currentStep < 4 && state.isCurrentStepValid) {
      final next = state.currentStep + 1;
      state = state.copyWith(currentStep: next);
      if (next == 4) {
        validatePreSubmission();
      }
    }
  }

  void previousStep() {
    if (state.currentStep > 0) {
      state = state.copyWith(currentStep: state.currentStep - 1);
    }
  }

  Future<void> validatePreSubmission() async {
    if (state.selectedProduct == null) return;
    state = state.copyWith(isValidating: true, errorMessage: null);

    try {
      final payload = {
        'product_id': state.selectedProduct!.id,
        'type': state.claimType,
        'title': state.issueTitle,
        'description': state.issueDescription,
        'issue_category': state.issueCategory,
        'incident_date': state.incidentDate?.toIso8601String().split('T')[0],
        'attachments': state.attachments.map((a) => {
          'file_name': a.fileName,
          'file_size': a.size,
          'file_type': a.mimeType,
        }).toList(),
      };

      final result = await _claimRepo.validateClaim(payload);
      state = state.copyWith(
        validationResult: result,
        isValidating: false,
      );
    } catch (e) {
      state = state.copyWith(
        isValidating: false,
        validationResult: {
          'priority_score': 50,
          'warranty_valid': true,
          'warranty_status': 'active',
          'score_breakdown': {'base': 20, 'urgency': 15, 'completeness': 15},
        },
      );
    }
  }

  Future<String> submitClaim() async {
    // Idempotency Guard: prevent rapid double-clicks
    if (state.isSubmitting) {
      throw Exception('Claim submission already in progress.');
    }

    state = state.copyWith(isSubmitting: true, errorMessage: null);

    try {
      final product = state.selectedProduct!;
      final incidentDateStr = state.incidentDate != null
          ? state.incidentDate!.toIso8601String().split('T')[0]
          : DateTime.now().toIso8601String().split('T')[0];

      // Prepare payload for claim-processor
      final payload = {
        'product_id': product.id,
        'type': state.claimType,
        'title': state.issueTitle,
        'description': state.issueDescription,
        'issue_category': state.issueCategory,
        'incident_date': incidentDateStr,
        'attachments': state.attachments.map((a) => {
          'file_name': a.fileName,
          'file_size': a.size,
          'file_type': a.mimeType,
        }).toList(),
      };

      final response = await _claimRepo.submitClaim(payload);
      final claimId = (response['claim_id'] ?? response['id']) as String?;

      if (claimId == null) {
        throw Exception('Claim submitted but no claim ID returned.');
      }

      // Upload actual attachment files if any
      if (state.attachments.isNotEmpty && _userId != null) {
        for (final att in state.attachments) {
          try {
            await _claimRepo.uploadAttachment(
              userId: _userId,
              claimId: claimId,
              fileName: att.fileName,
              bytes: att.bytes,
              mimeType: att.mimeType,
            );
          } catch (_) {
            // Non-fatal if secondary attachment upload fails after claim creation
          }
        }
      }

      state = state.copyWith(
        isSubmitting: false,
        createdClaimId: claimId,
      );

      return claimId;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: e.toString().replaceAll('Exception: ', '').replaceAll('ServerException: ', ''),
      );
      rethrow;
    }
  }
}

final claimWizardControllerProvider = StateNotifierProvider.autoDispose
    .family<ClaimWizardController, ClaimWizardState, ProductModel?>((ref, initialProduct) {
  final repo = ref.watch(claimRepositoryProvider);
  final user = ref.watch(currentUserProvider);
  return ClaimWizardController(repo, user?.id, initialProduct);
});
