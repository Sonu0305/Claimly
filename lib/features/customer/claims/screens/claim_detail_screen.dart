import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../auth/controllers/auth_controller.dart';
import '../controllers/claim_detail_controller.dart';
import '../services/claim_pdf_service.dart';
import '../widgets/claim_priority_chip.dart';
import '../widgets/claim_timeline_widget.dart';

class ClaimDetailScreen extends ConsumerWidget {
  final String claimId;

  const ClaimDetailScreen({
    super.key,
    required this.claimId,
  });

  Future<void> _handlePdfExport(BuildContext context, WidgetRef ref) async {
    final state = ref.read(claimDetailControllerProvider(claimId));
    final claim = state.claim;
    if (claim == null) return;

    final product = claim.product;
    if (product == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot export PDF: Product details are missing.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final userProfile = ref.read(authControllerProvider).asData?.value;

    final reportData = ClaimReportData(
      reportId: 'RPT-${claim.claimNumber}',
      generatedAt: DateTime.now(),
      claim: claim,
      product: product,
      customerName: userProfile?.fullName ?? 'Valued Customer',
      customerEmail: userProfile?.email ?? 'customer@claimly.com',
      customerPhone: userProfile?.phoneNumber,
      timeline: claim.timeline,
      attachments: claim.attachments,
      verificationCode: 'CLM-VFY-${claim.claimNumber.replaceAll(RegExp(r'[^A-Z0-9]'), '')}',
      verificationUrl: 'https://claimly.app/verify/${claim.id}',
    );

    try {
      await ClaimPdfService.previewOrPrintPdf(context, reportData);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate PDF: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(claimDetailControllerProvider(claimId));
    final controller = ref.read(claimDetailControllerProvider(claimId).notifier);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (state.isLoading && state.claim == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Claim Details')),
        body: const LoadingIndicator(message: 'Loading claim details...'),
      );
    }

    if (state.errorMessage != null && state.claim == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Claim Details')),
        body: ErrorView(
          message: state.errorMessage!,
          onRetry: () => controller.loadClaim(),
        ),
      );
    }

    final claim = state.claim!;

    return Scaffold(
      appBar: AppBar(
        title: Text(claim.claimNumber),
        actions: [
          IconButton(
            key: const Key('claim_pdf_export_btn'),
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Export PDF Report',
            onPressed: () => _handlePdfExport(context, ref),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => controller.loadClaim(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Claim Header Card
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(16.0),
                  border: Border.all(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          claim.claimNumber,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        StatusBadge(
                          key: const Key('claim_status_badge'),
                          status: claim.status,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      claim.title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.onSurfaceDark : AppColors.onSurfaceLight,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        ClaimPriorityChip(priority: claim.priority),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withAlpha(25),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            claim.type.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.secondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Product Info Card (if present)
              if (claim.product != null) ...[
                Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(16.0),
                    border: Border.all(
                      color: isDark ? AppColors.borderDark : AppColors.borderLight,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withAlpha(20),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.devices, color: AppColors.primary, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              claim.product!.name,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppColors.onSurfaceDark : AppColors.onSurfaceLight,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Category: ${claim.product!.category}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: isDark ? AppColors.gray400 : AppColors.gray600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Issue Details Card
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(16.0),
                  border: Border.all(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Issue Description',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.onSurfaceDark : AppColors.onSurfaceLight,
                      ),
                    ),
                    const Divider(height: 20),
                    if (claim.issueCategory != null) ...[
                      Text(
                        'Category: ${claim.issueCategory}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.gray400 : AppColors.gray700,
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                    if (claim.incidentDate != null) ...[
                      Text(
                        'Incident Date: ${DateFormatter.formatDisplayDate(claim.incidentDate!)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.gray400 : AppColors.gray600,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Text(
                      claim.description,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: isDark ? AppColors.onSurfaceDark : AppColors.onSurfaceLight,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Resolution Notes (if present)
              if (claim.resolutionNotes != null && claim.resolutionNotes!.isNotEmpty) ...[
                Container(
                  key: const Key('claim_resolution_notes'),
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: AppColors.successLight.withAlpha(40),
                    borderRadius: BorderRadius.circular(16.0),
                    border: Border.all(color: AppColors.success.withAlpha(80)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.check_circle_outline, color: AppColors.success, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Resolution Details',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.successDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        claim.resolutionNotes!,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? AppColors.gray300 : AppColors.gray800,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Attachments Section
              if (claim.attachments.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(16.0),
                    border: Border.all(
                      color: isDark ? AppColors.borderDark : AppColors.borderLight,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Proof Attachments (${claim.attachments.length})',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.onSurfaceDark : AppColors.onSurfaceLight,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...claim.attachments.map((att) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            children: [
                              Icon(
                                att.isPdf ? Icons.picture_as_pdf : Icons.image,
                                size: 20,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  att.fileName,
                                  style: const TextStyle(fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                att.formattedSize,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? AppColors.gray400 : AppColors.gray600,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Realtime Vertical Timeline
              ClaimTimelineWidget(timeline: claim.timeline),
              const SizedBox(height: 24),

              // Export PDF Button
              AppButton(
                text: 'Export Official Claim PDF',
                icon: const Icon(Icons.download, size: 18),
                variant: AppButtonVariant.outlined,
                onPressed: () => _handlePdfExport(context, ref),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
