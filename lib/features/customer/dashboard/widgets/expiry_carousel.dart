import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/router/route_constants.dart';
import '../../../../core/widgets/expiry_alert_card.dart';
import '../../products/models/product_model.dart';

class ExpiryCarousel extends StatelessWidget {
  final List<ProductModel> expiringProducts;

  const ExpiryCarousel({
    super.key,
    required this.expiringProducts,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (expiringProducts.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: AppColors.successLight.withAlpha(50),
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(color: AppColors.success.withAlpha(70)),
        ),
        child: Row(
          children: [
            const Icon(Icons.verified, color: AppColors.success, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'All Warranties Healthy',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.successDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'No items expiring within the next 30 days.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark ? AppColors.gray400 : AppColors.gray700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Expiry Alerts (${expiringProducts.length})',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.onBackgroundDark : AppColors.onBackgroundLight,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Action Needed',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.warning,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: expiringProducts.length,
          itemBuilder: (context, index) {
            final product = expiringProducts[index];
            return ExpiryAlertCard(
              productName: product.name,
              expiryDate: product.warrantyExpiryDate,
              daysRemaining: product.daysRemaining,
              onFileClaim: () {
                context.push('${RouteConstants.claimWizard}?productId=${product.id}');
              },
              onViewDetails: () {
                context.push('${RouteConstants.customerProducts}/${product.id}');
              },
            );
          },
        ),
      ],
    );
  }
}

