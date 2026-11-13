import '../constants/app_constants.dart';

/// Warranty lifecycle status classification.
enum WarrantyStatus {
  active,
  expiringSoon,
  expired,
}

/// Utility for computing product warranty expiry dates, remaining duration,
/// grace periods, and lifecycle status.
class WarrantyCalculator {
  WarrantyCalculator._();

  /// Calculates the warranty expiry date given a purchase date and warranty duration in months.
  static DateTime calculateExpiryDate(
    DateTime purchaseDate,
    int warrantyPeriodMonths,
  ) {
    var year = purchaseDate.year;
    var month = purchaseDate.month + warrantyPeriodMonths;
    year += (month - 1) ~/ 12;
    month = ((month - 1) % 12) + 1;
    final maxDay = _daysInMonth(year, month);
    final day = purchaseDate.day > maxDay ? maxDay : purchaseDate.day;
    return DateTime(
      year,
      month,
      day,
      purchaseDate.hour,
      purchaseDate.minute,
      purchaseDate.second,
    );
  }

  /// Calculates calendar days remaining until expiry.
  /// Returns negative value if the warranty has already expired.
  static int calculateDaysRemaining(
    DateTime expiryDate, {
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    final startOfCurrent = DateTime(current.year, current.month, current.day);
    final startOfExpiry = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
    return startOfExpiry.difference(startOfCurrent).inDays;
  }

  /// Computes the WarrantyStatus based on purchase date and warranty duration.
  static WarrantyStatus calculateStatus(
    DateTime purchaseDate,
    int warrantyPeriodMonths, {
    DateTime? now,
    int expiringThresholdDays = AppConstants.expiryWarningThresholdDays,
  }) {
    final expiryDate = calculateExpiryDate(purchaseDate, warrantyPeriodMonths);
    final daysRemaining = calculateDaysRemaining(expiryDate, now: now);

    if (daysRemaining < 0) {
      return WarrantyStatus.expired;
    } else if (daysRemaining <= expiringThresholdDays) {
      return WarrantyStatus.expiringSoon;
    } else {
      return WarrantyStatus.active;
    }
  }

  /// Computes WarrantyStatus directly from an already known expiry date.
  static WarrantyStatus calculateStatusFromExpiry(
    DateTime expiryDate, {
    DateTime? now,
    int expiringThresholdDays = AppConstants.expiryWarningThresholdDays,
  }) {
    final daysRemaining = calculateDaysRemaining(expiryDate, now: now);

    if (daysRemaining < 0) {
      return WarrantyStatus.expired;
    } else if (daysRemaining <= expiringThresholdDays) {
      return WarrantyStatus.expiringSoon;
    } else {
      return WarrantyStatus.active;
    }
  }

  /// Checks if an expired warranty is still within the allowable claim grace period.
  static bool isWithinGracePeriod(
    DateTime expiryDate, {
    DateTime? now,
    int gracePeriodDays = AppConstants.warrantyGracePeriodDays,
  }) {
    final daysRemaining = calculateDaysRemaining(expiryDate, now: now);
    return daysRemaining < 0 && daysRemaining >= -gracePeriodDays;
  }

  /// Returns user-facing label for a WarrantyStatus enum.
  static String statusLabel(WarrantyStatus status) {
    switch (status) {
      case WarrantyStatus.active:
        return 'Active';
      case WarrantyStatus.expiringSoon:
        return 'Expiring Soon';
      case WarrantyStatus.expired:
        return 'Expired';
    }
  }

  static int _daysInMonth(int year, int month) {
    if (month == 2) {
      final isLeapYear = (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
      return isLeapYear ? 29 : 28;
    }
    const days = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    return days[month - 1];
  }
}
