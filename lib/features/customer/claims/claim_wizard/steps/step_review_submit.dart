import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:claimly/core/constants/app_colors.dart';
import 'package:claimly/core/router/route_constants.dart';
import 'package:claimly/core/utils/date_formatter.dart';
import 'package:claimly/core/widgets/app_button.dart';
import 'package:claimly/core/widgets/status_badge.dart';
import 'package:claimly/features/customer/products/models/product_model.dart';
import '../controllers/wizard_controller.dart';

class StepReviewSubmit extends ConsumerWidget {
  final ProductModel? initialProduct;

  const StepReviewSubmit({
    super.key,
    this.initialProduct,
  });

  Future<void> _handleSubmit(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(claimWizardControllerProvider(initialProduct).notifier);

    try {
      final claimId = await controller.submitClaim();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Claim submitted successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        context.go('${RouteConstants.customerClaims}/$claimId');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit claim: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(claimWizardControllerProvider(initialProduct));
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final product = state.selectedProduct;
    final validation = state.validationResult;

    final estimatedPriority = (validation?['priority_score'] as num?)?.toInt() ?? 50;
    final warrantyStatus = (validation?['warranty_status'] as String?) ??
        (product?.status.name ?? 'active');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Review Claim & Triage Assessment',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.onBackgroundDark : AppColors.onBackgroundLight,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Verify all details before submitting. Your claim will be assigned a priority score automatically.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark ? AppColors.gray400 : AppColors.gray600,
            ),
          ),
          const SizedBox(height: 16),

          if (state.errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withAlpha(25),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.error.withAlpha(77)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      state.errorMessage!,
                      style: const TextStyle(color: AppColors.error, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Pre-validation Triage Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withAlpha(30),
                  AppColors.secondary.withAlpha(20),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primary.withAlpha(60)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Automated Triage Score',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    StatusBadge(status: warrantyStatus, fontSize: 11),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      '$estimatedPriority',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const Text(' / 100', style: TextStyle(fontSize: 14, color: AppColors.gray600)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: estimatedPriority >= 70
                            ? AppColors.error
                            : estimatedPriority >= 40
                                ? AppColors.warning
                                : AppColors.info,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        estimatedPriority >= 70
                            ? 'High Priority'
                            : estimatedPriority >= 40
                                ? 'Medium Priority'
                                : 'Standard',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Calculated based on warranty duration, incident date, claim type, and defect keywords.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark ? AppColors.gray400 : AppColors.gray700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Details Summary
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Claim Summary',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.onSurfaceDark : AppColors.onSurfaceLight,
                  ),
                ),
                const Divider(height: 20),
                _summaryRow('Product', product?.name ?? '—', isDark),
                _summaryRow('Category', product?.category ?? '—', isDark),
                _summaryRow('Claim Type', state.claimType.toUpperCase(), isDark),
                if (state.issueCategory != null)
                  _summaryRow('Issue Category', state.issueCategory!, isDark),
                if (state.incidentDate != null)
                  _summaryRow('Incident Date', DateFormatter.formatDisplayDate(state.incidentDate!), isDark),
                _summaryRow('Attachments', '${state.attachments.length} files attached', isDark),
                const SizedBox(height: 12),
                Text(
                  'Issue Title',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.gray400 : AppColors.gray600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  state.issueTitle,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.onSurfaceDark : AppColors.onSurfaceLight,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Description',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.gray400 : AppColors.gray600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  state.issueDescription,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppColors.gray300 : AppColors.gray800,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Submit Button (with idempotency guard)
          AppButton(
            buttonKey: const Key('wizard_submit_btn'),
            text: 'Submit Official Claim',
            icon: const Icon(Icons.send),
            isLoading: state.isSubmitting,
            onPressed: state.isSubmitting ? null : () => _handleSubmit(context, ref),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.gray400 : AppColors.gray600,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.onSurfaceDark : AppColors.onSurfaceLight,
            ),
          ),
        ],
      ),
    );
  }
}
