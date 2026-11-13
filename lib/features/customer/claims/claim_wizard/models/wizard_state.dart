import 'dart:typed_data';
import '../../../products/models/product_model.dart';

class WizardAttachmentItem {
  final String fileName;
  final Uint8List bytes;
  final int size;
  final String mimeType;

  const WizardAttachmentItem({
    required this.fileName,
    required this.bytes,
    required this.size,
    required this.mimeType,
  });

  String get formattedSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) {
      return '${(size / 1024).toStringAsFixed(1)} KB';
    }
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class ClaimWizardState {
  final int currentStep; // 0 to 4
  final ProductModel? selectedProduct;
  final String claimType; // 'warranty', 'refund', 'replacement'
  final String issueTitle;
  final String issueDescription;
  final String? issueCategory;
  final DateTime? incidentDate;
  final List<WizardAttachmentItem> attachments;
  final bool isValidating;
  final bool isSubmitting;
  final Map<String, dynamic>? validationResult;
  final String? errorMessage;
  final String? createdClaimId;

  const ClaimWizardState({
    this.currentStep = 0,
    this.selectedProduct,
    this.claimType = 'warranty',
    this.issueTitle = '',
    this.issueDescription = '',
    this.issueCategory,
    this.incidentDate,
    this.attachments = const [],
    this.isValidating = false,
    this.isSubmitting = false,
    this.validationResult,
    this.errorMessage,
    this.createdClaimId,
  });

  bool get isStep1Valid => selectedProduct != null;
  bool get isStep2Valid => claimType.isNotEmpty;
  bool get isStep3Valid {
    if (issueTitle.trim().length < 5) return false;
    if (issueDescription.trim().isEmpty) return false;
    if (incidentDate == null) return false;
    if (incidentDate!.isAfter(DateTime.now())) return false;
    if (selectedProduct != null && incidentDate!.isBefore(selectedProduct!.purchaseDate)) {
      return false;
    }
    return true;
  }
  bool get isStep4Valid => true; // Optional attachments
  bool get isStep5Valid => isStep1Valid && isStep2Valid && isStep3Valid;

  bool get isCurrentStepValid {
    switch (currentStep) {
      case 0:
        return isStep1Valid;
      case 1:
        return isStep2Valid;
      case 2:
        return isStep3Valid;
      case 3:
        return isStep4Valid;
      case 4:
        return isStep5Valid;
      default:
        return false;
    }
  }

  ClaimWizardState copyWith({
    int? currentStep,
    ProductModel? selectedProduct,
    String? claimType,
    String? issueTitle,
    String? issueDescription,
    String? issueCategory,
    DateTime? incidentDate,
    List<WizardAttachmentItem>? attachments,
    bool? isValidating,
    bool? isSubmitting,
    Map<String, dynamic>? validationResult,
    String? errorMessage,
    String? createdClaimId,
  }) {
    return ClaimWizardState(
      currentStep: currentStep ?? this.currentStep,
      selectedProduct: selectedProduct ?? this.selectedProduct,
      claimType: claimType ?? this.claimType,
      issueTitle: issueTitle ?? this.issueTitle,
      issueDescription: issueDescription ?? this.issueDescription,
      issueCategory: issueCategory ?? this.issueCategory,
      incidentDate: incidentDate ?? this.incidentDate,
      attachments: attachments ?? this.attachments,
      isValidating: isValidating ?? this.isValidating,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      validationResult: validationResult ?? this.validationResult,
      errorMessage: errorMessage,
      createdClaimId: createdClaimId ?? this.createdClaimId,
    );
  }
}

