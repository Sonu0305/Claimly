import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/status_badge.dart';
import '../models/claim_model.dart';
import 'claim_priority_chip.dart';

class ClaimCard extends StatelessWidget {
  final ClaimModel claim;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? margin;

  const ClaimCard({
    super.key,
    required this.claim,
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Claim Number & Status Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      claim.claimNumber,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        letterSpacing: 0.5,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusBadge(status: claim.status),
                ],
              ),
              const SizedBox(height: 8),

              // Title
              Text(
                claim.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.onSurfaceDark : AppColors.onSurfaceLight,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),

              // Product Name & Type
              if (claim.product != null)
                Text(
                  '${claim.product!.name} • ${claim.type.toUpperCase()}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark ? AppColors.gray400 : AppColors.gray600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              const SizedBox(height: 10),

              // Bottom Row: Date & Priority
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8.0,
                runSpacing: 6.0,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 13,
                        color: isDark ? AppColors.gray400 : AppColors.gray500,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        DateFormatter.formatDisplayDate(claim.createdAt),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: isDark ? AppColors.gray400 : AppColors.gray500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  ClaimPriorityChip(priority: claim.priority),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

