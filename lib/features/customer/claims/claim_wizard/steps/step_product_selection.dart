import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:claimly/core/constants/app_colors.dart';
import 'package:claimly/core/router/route_constants.dart';
import 'package:claimly/core/utils/date_formatter.dart';
import 'package:claimly/core/widgets/empty_state.dart';
import 'package:claimly/core/widgets/loading_indicator.dart';
import 'package:claimly/core/widgets/status_badge.dart';
import 'package:claimly/features/customer/products/controllers/products_controller.dart';
import 'package:claimly/features/customer/products/models/product_model.dart';
import '../controllers/wizard_controller.dart';

class StepProductSelection extends ConsumerWidget {
  final ProductModel? initialProduct;

  const StepProductSelection({
    super.key,
    this.initialProduct,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsState = ref.watch(productsControllerProvider);
    final wizardState = ref.watch(claimWizardControllerProvider(initialProduct));
    final wizardController = ref.read(claimWizardControllerProvider(initialProduct).notifier);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (productsState.isLoading && productsState.products.isEmpty) {
      return const LoadingIndicator(message: 'Loading your products...');
    }

    if (productsState.products.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: EmptyState(
            title: 'No registered products found',
            message:
                'You must register a product first before filing a warranty or refund claim.',
            actionText: 'Register a Product',
            onAction: () => context.push('${RouteConstants.customerProducts}/new'),
          ),
        ),
      );
    }

    final selected = wizardState.selectedProduct;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Product for Claim',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.onBackgroundDark : AppColors.onBackgroundLight,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Choose the product experiencing an issue or defect:',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark ? AppColors.gray400 : AppColors.gray600,
            ),
          ),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: productsState.products.length,
            itemBuilder: (context, index) {
              final product = productsState.products[index];
              final isSelected = selected?.id == product.id;

              return Card(
                key: Key('wizard_product_card_${product.id}'),
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 10.0),
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
                  key: const Key('wizard_product_selector'),
                  borderRadius: BorderRadius.circular(12.0),
                  onTap: () => wizardController.selectProduct(product),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
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
                              Text(
                                product.name,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? AppColors.onSurfaceDark
                                      : AppColors.onSurfaceLight,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${product.category} • Purchased ${DateFormatter.formatDisplayDate(product.purchaseDate)}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: isDark ? AppColors.gray400 : AppColors.gray600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        StatusBadge.fromWarrantyStatus(product.status),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
