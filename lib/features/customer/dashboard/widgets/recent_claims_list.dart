import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/router/route_constants.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../claims/models/claim_model.dart';

class RecentClaimsList extends StatelessWidget {
  final List<ClaimModel> claims;

  const RecentClaimsList({
    super.key,
    required this.claims,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (claims.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: EmptyState(
          title: 'No claims yet',
          message: 'You have not submitted any warranty or refund claims.',
          actionText: 'File a Claim',
          onAction: () => context.push(RouteConstants.claimWizard),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Recent Claims',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.onBackgroundDark : AppColors.onBackgroundLight,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(
                onPressed: () => context.push(RouteConstants.customerClaims),
                child: const Text('View All'),
              ),
            ],
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: claims.length,
          itemBuilder: (context, index) {
            final claim = claims[index];
            return Card(
              elevation: 0,
              margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 5.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
                side: BorderSide(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                ),
              ),
              color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
              child: ListTile(
                onTap: () => context.push('${RouteConstants.customerClaims}/${claim.id}'),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                leading: Container(
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(25),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: const Icon(Icons.assignment_outlined, color: AppColors.primary, size: 22),
                ),
                title: Text(
                  claim.title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.onSurfaceDark : AppColors.onSurfaceLight,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 2),
                    Text(
                      '${claim.claimNumber} • ${DateFormatter.formatDisplayDate(claim.createdAt)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? AppColors.gray400 : AppColors.gray600,
                      ),
                    ),
                  ],
                ),
                trailing: StatusBadge(
                  status: claim.status,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

