import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../utils/date_formatter.dart';

/// Card banner alerting the customer of an upcoming warranty expiry,
/// with urgency styling and an action button to initiate a claim.
class ExpiryAlertCard extends StatelessWidget {
  final String productName;
  final DateTime expiryDate;
  final int daysRemaining;
  final VoidCallback? onFileClaim;
  final VoidCallback? onViewDetails;

  const ExpiryAlertCard({
    super.key,
    required this.productName,
    required this.expiryDate,
    required this.daysRemaining,
    this.onFileClaim,
    this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    final urgency = _resolveUrgency(daysRemaining);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: urgency.backgroundColor,
        borderRadius: const BorderRadius.all(Radius.circular(12.0)),
        border: Border.all(color: urgency.borderColor, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  urgency.icon,
                  color: urgency.textColor,
                  size: 24.0,
                ),
                const SizedBox(width: 8.0),
                Expanded(
                  child: Text(
                    urgency.headline,
                    style: TextStyle(
                      fontSize: 14.0,
                      fontWeight: FontWeight.w700,
                      color: urgency.textColor,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
                  decoration: BoxDecoration(
                    color: urgency.badgeColor,
                    borderRadius: const BorderRadius.all(Radius.circular(12.0)),
                  ),
                  child: Text(
                    _daysLabel(daysRemaining),
                    style: TextStyle(
                      fontSize: 12.0,
                      fontWeight: FontWeight.w700,
                      color: urgency.badgeTextColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8.0),
            Text(
              productName,
              style: const TextStyle(
                fontSize: 16.0,
                fontWeight: FontWeight.w600,
                color: AppColors.gray900,
              ),
            ),
            const SizedBox(height: 4.0),
            Text(
              'Expires on ${DateFormatter.formatDisplayDate(expiryDate)}',
              style: const TextStyle(
                fontSize: 13.0,
                color: AppColors.gray600,
              ),
            ),
            if (onFileClaim != null || onViewDetails != null) ...[
              const SizedBox(height: 12.0),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (onViewDetails != null)
                    TextButton(
                      onPressed: onViewDetails,
                      child: const Text('View Product'),
                    ),
                  if (onFileClaim != null) ...[
                    const SizedBox(width: 8.0),
                    ElevatedButton(
                      onPressed: onFileClaim,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: urgency.buttonColor,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 36.0),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 8.0,
                        ),
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(8.0)),
                        ),
                      ),
                      child: const Text('File Claim'),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _daysLabel(int days) {
    if (days <= 0) return 'Expired';
    if (days == 1) return '1 day left';
    return '$days days left';
  }

  _AlertUrgency _resolveUrgency(int days) {
    if (days <= 1) {
      return const _AlertUrgency(
        headline: 'Critical: Warranty Expires Tomorrow!',
        backgroundColor: Color(0xFFFEF2F2),
        borderColor: Color(0xFFF87171),
        textColor: Color(0xFFB91C1C),
        badgeColor: Color(0xFFEF4444),
        badgeTextColor: Colors.white,
        buttonColor: Color(0xFFDC2626),
        icon: Icons.error_outline,
      );
    } else if (days <= 7) {
      return const _AlertUrgency(
        headline: 'Urgent: Warranty Expiring This Week',
        backgroundColor: Color(0xFFFFF7ED),
        borderColor: Color(0xFFFB923C),
        textColor: Color(0xFFC2410C),
        badgeColor: Color(0xFFF97316),
        badgeTextColor: Colors.white,
        buttonColor: Color(0xFFEA580C),
        icon: Icons.warning_amber_rounded,
      );
    } else {
      return const _AlertUrgency(
        headline: 'Warranty Expiring Soon',
        backgroundColor: Color(0xFFFFFBEB),
        borderColor: Color(0xFFFCD34D),
        textColor: Color(0xFFB45309),
        badgeColor: Color(0xFFFBBF24),
        badgeTextColor: Color(0xFF78350F),
        buttonColor: Color(0xFFD97706),
        icon: Icons.access_time,
      );
    }
  }
}

class _AlertUrgency {
  final String headline;
  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;
  final Color badgeColor;
  final Color badgeTextColor;
  final Color buttonColor;
  final IconData icon;

  const _AlertUrgency({
    required this.headline,
    required this.backgroundColor,
    required this.borderColor,
    required this.textColor,
    required this.badgeColor,
    required this.badgeTextColor,
    required this.buttonColor,
    required this.icon,
  });
}
