import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:claimly/core/constants/app_colors.dart';
import 'package:claimly/features/customer/products/controllers/products_controller.dart';
import 'package:claimly/features/customer/products/models/product_model.dart';
import '../controllers/wizard_controller.dart';
import '../steps/step_attachments.dart';
import '../steps/step_claim_type.dart';
import '../steps/step_issue_details.dart';
import '../steps/step_product_selection.dart';
import '../steps/step_review_submit.dart';
import '../widgets/wizard_stepper_header.dart';

class ClaimWizardScreen extends ConsumerStatefulWidget {
  final String? initialProductId;

  const ClaimWizardScreen({
    super.key,
    this.initialProductId,
  });

  @override
  ConsumerState<ClaimWizardScreen> createState() => _ClaimWizardScreenState();
}

class _ClaimWizardScreenState extends ConsumerState<ClaimWizardScreen> {
  ProductModel? _preselectedProduct;

  @override
  void initState() {
    super.initState();
    if (widget.initialProductId != null) {
      final productsState = ref.read(productsControllerProvider);
      final match = productsState.products.where((p) => p.id == widget.initialProductId);
      if (match.isNotEmpty) {
        _preselectedProduct = match.first;
      }
    }
  }

  Future<void> _handleCancel() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard Claim Draft?'),
        content: const Text(
          'Are you sure you want to exit the claim filing wizard? All entered information will be discarded.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Continue Editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Discard Draft'),
          ),
        ],
      ),
    );

    if (discard == true && mounted) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(claimWizardControllerProvider(_preselectedProduct));
    final controller = ref.read(claimWizardControllerProvider(_preselectedProduct).notifier);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final isFirstStep = state.currentStep == 0;
    final isLastStep = state.currentStep == 4;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleCancel();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('File New Claim (${state.currentStep + 1}/5)'),
          leading: IconButton(
            key: const Key('wizard_cancel_btn'),
            icon: const Icon(Icons.close),
            tooltip: 'Cancel Filing',
            onPressed: _handleCancel,
          ),
        ),
        body: Column(
          children: [
            // Visual Progress Header
            WizardStepperHeader(currentStep: state.currentStep),

            // Step Content
            Expanded(
              child: IndexedStack(
                index: state.currentStep,
                children: [
                  StepProductSelection(initialProduct: _preselectedProduct),
                  StepClaimType(initialProduct: _preselectedProduct),
                  StepIssueDetails(initialProduct: _preselectedProduct),
                  StepAttachments(initialProduct: _preselectedProduct),
                  StepReviewSubmit(initialProduct: _preselectedProduct),
                ],
              ),
            ),

            // Wizard Bottom Navigation Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                border: Border(
                  top: BorderSide(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  ),
                ),
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    // Back Button
                    if (!isFirstStep) ...[
                      OutlinedButton(
                        key: const Key('wizard_back_btn'),
                        onPressed: isFirstStep ? null : () => controller.previousStep(),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.arrow_back, size: 16),
                            SizedBox(width: 6),
                            Text('Back'),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],

                    // Next Button (or spacer on last step since step 5 has submit button)
                    if (!isLastStep)
                      Expanded(
                        child: ElevatedButton(
                          key: const Key('wizard_next_btn'),
                          onPressed: state.isCurrentStepValid
                              ? () => controller.nextStep()
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: isDark ? AppColors.cardDark : AppColors.gray300,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Next Step'),
                              SizedBox(width: 6),
                              Icon(Icons.arrow_forward, size: 16),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
