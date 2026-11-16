import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class ClaimPriorityChip extends StatelessWidget {
  final int priority;

  const ClaimPriorityChip({
    super.key,
    required this.priority,
  });

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    if (priority >= 70) {
      color = AppColors.error;
      label = 'High Priority';
    } else if (priority >= 40) {
      color = AppColors.warning;
      label = 'Medium Priority';
    } else {
      color = AppColors.gray600;
      label = 'Standard';
    }

    return Container(
      key: const Key('claim_priority_score'),
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: color.withAlpha(70)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt, size: 14, color: color),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              '$priority/100 • $label',
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

