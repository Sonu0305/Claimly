import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../utils/warranty_calculator.dart';

/// Chip badge displaying claim or warranty status with color coding and icon.
class StatusBadge extends StatelessWidget {
  final String status;
  final double fontSize;
  final EdgeInsetsGeometry padding;

  const StatusBadge({
    super.key,
    required this.status,
    this.fontSize = 12.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
  });

  factory StatusBadge.fromWarrantyStatus(
    WarrantyStatus status, {
    Key? key,
    double fontSize = 12.0,
  }) {
    return StatusBadge(
      key: key,
      status: status.name,
      fontSize: fontSize,
    );
  }

  @override
  Widget build(BuildContext context) {
    final style = _resolveStatusStyle(status);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: style.backgroundColor,
        borderRadius: const BorderRadius.all(Radius.circular(16.0)),
        border: Border.all(color: style.borderColor, width: 1.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            style.icon,
            size: fontSize + 2.0,
            color: style.textColor,
          ),
          const SizedBox(width: 4.0),
          Text(
            style.label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: style.textColor,
            ),
          ),
        ],
      ),
    );
  }

  _StatusBadgeStyle _resolveStatusStyle(String rawStatus) {
    final normalized = rawStatus.toLowerCase().replaceAll(' ', '_');

    switch (normalized) {
      case 'active':
        return const _StatusBadgeStyle(
          label: 'Active',
          backgroundColor: Color(0xFFDCFCE7),
          textColor: Color(0xFF15803D),
          borderColor: Color(0xFF86EFAC),
          icon: Icons.check_circle_outline,
        );

      case 'expiring_soon':
      case 'expiringsoon':
        return const _StatusBadgeStyle(
          label: 'Expiring Soon',
          backgroundColor: Color(0xFFFEF3C7),
          textColor: Color(0xFFB45309),
          borderColor: Color(0xFFFCD34D),
          icon: Icons.access_time,
        );

      case 'expired':
        return const _StatusBadgeStyle(
          label: 'Expired',
          backgroundColor: Color(0xFFFEE2E2),
          textColor: Color(0xFFB91C1C),
          borderColor: Color(0xFFFCA5A5),
          icon: Icons.cancel_outlined,
        );

      case 'draft':
        return const _StatusBadgeStyle(
          label: 'Draft',
          backgroundColor: Color(0xFFF1F5F9),
          textColor: Color(0xFF475569),
          borderColor: Color(0xFFCBD5E1),
          icon: Icons.edit_note_outlined,
        );

      case 'submitted':
        return const _StatusBadgeStyle(
          label: 'Submitted',
          backgroundColor: Color(0xFFDBEAFE),
          textColor: Color(0xFF1D4ED8),
          borderColor: Color(0xFF93C5FD),
          icon: Icons.send_outlined,
        );

      case 'under_review':
        return const _StatusBadgeStyle(
          label: 'Under Review',
          backgroundColor: Color(0xFFF3E8FF),
          textColor: Color(0xFF6B21A8),
          borderColor: Color(0xFFD8B4FE),
          icon: Icons.rate_review_outlined,
        );

      case 'information_requested':
        return const _StatusBadgeStyle(
          label: 'Info Requested',
          backgroundColor: Color(0xFFFEF3C7),
          textColor: Color(0xFFB45309),
          borderColor: Color(0xFFFCD34D),
          icon: Icons.help_outline,
        );

      case 'approved':
        return const _StatusBadgeStyle(
          label: 'Approved',
          backgroundColor: Color(0xFFDCFCE7),
          textColor: Color(0xFF15803D),
          borderColor: Color(0xFF86EFAC),
          icon: Icons.verified_outlined,
        );

      case 'rejected':
        return const _StatusBadgeStyle(
          label: 'Rejected',
          backgroundColor: Color(0xFFFEE2E2),
          textColor: Color(0xFFB91C1C),
          borderColor: Color(0xFFFCA5A5),
          icon: Icons.highlight_off_outlined,
        );

      case 'completed':
        return const _StatusBadgeStyle(
          label: 'Completed',
          backgroundColor: Color(0xFFCCFBF1),
          textColor: Color(0xFF0F766E),
          borderColor: Color(0xFF5EEAD4),
          icon: Icons.task_alt,
        );

      case 'cancelled':
        return const _StatusBadgeStyle(
          label: 'Cancelled',
          backgroundColor: Color(0xFFF1F5F9),
          textColor: Color(0xFF475569),
          borderColor: Color(0xFFCBD5E1),
          icon: Icons.block_outlined,
        );

      default:
        return _StatusBadgeStyle(
          label: rawStatus,
          backgroundColor: AppColors.gray100,
          textColor: AppColors.gray700,
          borderColor: AppColors.gray300,
          icon: Icons.info_outline,
        );
    }
  }
}

class _StatusBadgeStyle {
  final String label;
  final Color backgroundColor;
  final Color textColor;
  final Color borderColor;
  final IconData icon;

  const _StatusBadgeStyle({
    required this.label,
    required this.backgroundColor,
    required this.textColor,
    required this.borderColor,
    required this.icon,
  });
}
