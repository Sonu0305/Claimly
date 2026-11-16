import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/status_badge.dart';
import '../models/claim_timeline_model.dart';

class ClaimTimelineWidget extends StatelessWidget {
  final List<ClaimTimelineModel> timeline;

  const ClaimTimelineWidget({
    super.key,
    required this.timeline,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (timeline.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
        ),
        child: Text(
          'No timeline events recorded yet.',
          style: TextStyle(
            fontSize: 13,
            color: isDark ? AppColors.gray400 : AppColors.gray600,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Claim Timeline & Audit Trail',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.onSurfaceDark : AppColors.onSurfaceLight,
            ),
          ),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: timeline.length,
            itemBuilder: (context, index) {
              final item = timeline[index];
              final isLast = index == timeline.length - 1;

              return IntrinsicHeight(
                child: Row(
                  key: const Key('claim_timeline_step'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Node & Connector Line
                    Column(
                      children: [
                        Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: isLast ? AppColors.primary : AppColors.success,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                        if (!isLast)
                          Expanded(
                            child: Container(
                              width: 2,
                              color: isDark ? AppColors.borderDark : AppColors.gray300,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 12),

                    // Content
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: isLast ? 4.0 : 18.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                StatusBadge(status: item.toStatus, fontSize: 11),
                                Text(
                                  DateFormatter.formatDisplayDate(item.createdAt),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? AppColors.gray400 : AppColors.gray500,
                                  ),
                                ),
                              ],
                            ),
                            if (item.notes != null && item.notes!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                item.notes!,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? AppColors.gray300 : AppColors.gray700,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

