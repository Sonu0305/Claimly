import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:claimly/core/constants/app_colors.dart';
import 'package:claimly/features/customer/products/models/product_model.dart';
import '../controllers/wizard_controller.dart';

class StepClaimType extends ConsumerWidget {
  final ProductModel? initialProduct;

  const StepClaimType({
    super.key,
    this.initialProduct,
  });

  static const List<Map<String, String>> claimTypes = [
    {
      'type': 'warranty',
      'title': 'Warranty Repair',
      'description':
          'Request free manufacturer repairs or defect fixes under active warranty coverage.',
      'icon': 'build_outlined',
    },
    {
      'type': 'replacement',
      'title': 'Product Replacement',
      'description':
          'Request an identical or equivalent replacement unit for damaged or irreparably defective items.',
      'icon': 'swap_horiz_outlined',
    },
    {
      'type': 'refund',
      'title': 'Full or Partial Refund',
      'description':
          'Claim financial reimbursement or store credit for failed, non-compliant, or recalled products.',
      'icon': 'currency_exchange_outlined',
    },
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(claimWizardControllerProvider(initialProduct));
    final controller = ref.read(claimWizardControllerProvider(initialProduct).notifier);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Claim Type',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.onBackgroundDark : AppColors.onBackgroundLight,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Choose the type of resolution requested for this claim:',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark ? AppColors.gray400 : AppColors.gray600,
            ),
          ),
          const SizedBox(height: 16),
          ...claimTypes.map((item) {
            final type = item['type']!;
            final isSelected = state.claimType == type;

            IconData iconData;
            switch (item['icon']) {
              case 'build_outlined':
                iconData = Icons.build_outlined;
                break;
              case 'swap_horiz_outlined':
                iconData = Icons.swap_horiz_outlined;
                break;
              default:
                iconData = Icons.currency_exchange_outlined;
            }

            return Card(
              key: Key('wizard_claim_type_card_$type'),
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 12.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
                side: BorderSide(
                  color: isSelected
                      ? AppColors.primary
                      : (isDark ? AppColors.borderDark : AppColors.borderLight),
                  width: isSelected ? 2.0 : 1.0,
                ),
              ),
              color: isSelected
                  ? AppColors.primary.withAlpha(15)
                  : (isDark ? AppColors.surfaceDark : AppColors.surfaceLight),
              child: InkWell(
                key: const Key('wizard_claim_type_radio'),
                borderRadius: BorderRadius.circular(12.0),
                onTap: () => controller.setClaimType(type),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? AppColors.primary : AppColors.gray400,
                            width: 2,
                          ),
                        ),
                        child: isSelected
                            ? Center(
                                child: Container(
                                  width: 12,
                                  height: 12,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.primary,
                                  ),
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(iconData, color: AppColors.primary, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  item['title']!,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? AppColors.onSurfaceDark
                                        : AppColors.onSurfaceLight,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              item['description']!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: isDark ? AppColors.gray400 : AppColors.gray600,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
