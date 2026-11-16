import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/status_badge.dart';
import '../models/product_model.dart';

class ProductCard extends StatelessWidget {
  final ProductModel product;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? margin;

  const ProductCard({
    super.key,
    required this.product,
    this.onTap,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      elevation: 0,
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: BorderSide(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Image / Thumbnail
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.cardDark : AppColors.gray100,
                  borderRadius: BorderRadius.circular(10.0),
                ),
                child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10.0),
                        child: Image.network(
                          product.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.inventory_2_outlined,
                            color: AppColors.gray500,
                            size: 28,
                          ),
                        ),
                      )
                    : const Icon(
                        Icons.inventory_2_outlined,
                        color: AppColors.primary,
                        size: 28,
                      ),
              ),
              const SizedBox(width: 14),

              // Product Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            product.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppColors.onSurfaceDark : AppColors.onSurfaceLight,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        StatusBadge.fromWarrantyStatus(
                          product.status,
                          key: const Key('product_status_badge'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    if (product.brand != null || product.modelNumber != null) ...[
                      Text(
                        [product.brand, product.modelNumber].where((s) => s != null && s.isNotEmpty).join(' • '),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark ? AppColors.gray400 : AppColors.gray600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                    ],

                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 13,
                          color: isDark ? AppColors.gray400 : AppColors.gray500,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Purchased: ${DateFormatter.formatDisplayDate(product.purchaseDate)}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: isDark ? AppColors.gray400 : AppColors.gray500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            product.daysRemaining >= 0
                                ? '${product.daysRemaining}d remaining'
                                : 'Expired',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: product.daysRemaining <= 7
                                  ? AppColors.error
                                  : product.daysRemaining <= 30
                                      ? AppColors.warning
                                      : AppColors.success,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
