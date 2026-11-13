import 'package:flutter_test/flutter_test.dart';
import 'package:claimly/core/utils/warranty_calculator.dart';

void main() {
  group('WarrantyCalculator', () {
    final baseDate = DateTime(2025, 1, 15, 10, 0);

    test('calculateExpiryDate adds months correctly across standard dates', () {
      final expiry12 = WarrantyCalculator.calculateExpiryDate(baseDate, 12);
      expect(expiry12.year, 2026);
      expect(expiry12.month, 1);
      expect(expiry12.day, 15);

      final expiry24 = WarrantyCalculator.calculateExpiryDate(baseDate, 24);
      expect(expiry24.year, 2027);
      expect(expiry24.month, 1);
      expect(expiry24.day, 15);
    });

    test('calculateExpiryDate clamps to end of month for shorter months', () {
      final jan31 = DateTime(2025, 1, 31);
      final feb = WarrantyCalculator.calculateExpiryDate(jan31, 1);
      expect(feb.year, 2025);
      expect(feb.month, 2);
      expect(feb.day, 28); // 2025 is not a leap year

      final leapJan31 = DateTime(2024, 1, 31);
      final leapFeb = WarrantyCalculator.calculateExpiryDate(leapJan31, 1);
      expect(leapFeb.year, 2024);
      expect(leapFeb.month, 2);
      expect(leapFeb.day, 29); // 2024 is a leap year
    });

    test('calculateDaysRemaining computes correct difference', () {
      final now = DateTime(2026, 6, 1);
      final future = DateTime(2026, 6, 11);
      expect(WarrantyCalculator.calculateDaysRemaining(future, now: now), 10);

      final past = DateTime(2026, 5, 25);
      expect(WarrantyCalculator.calculateDaysRemaining(past, now: now), -7);

      final today = DateTime(2026, 6, 1, 18, 30);
      expect(WarrantyCalculator.calculateDaysRemaining(today, now: now), 0);
    });

    test('calculateStatus classifies active, expiringSoon, and expired', () {
      final now = DateTime(2026, 6, 1);

      // Expiry in 45 days -> active
      final purchaseActive = DateTime(2025, 7, 16);
      expect(
        WarrantyCalculator.calculateStatus(purchaseActive, 12, now: now),
        WarrantyStatus.active,
      );

      // Expiry in 15 days -> expiringSoon (<= 30 days)
      final purchaseExpiring = DateTime(2025, 6, 16);
      expect(
        WarrantyCalculator.calculateStatus(purchaseExpiring, 12, now: now),
        WarrantyStatus.expiringSoon,
      );

      // Expiry 5 days ago -> expired
      final purchaseExpired = DateTime(2025, 5, 27);
      expect(
        WarrantyCalculator.calculateStatus(purchaseExpired, 12, now: now),
        WarrantyStatus.expired,
      );
    });

    test('isWithinGracePeriod validates 7-day grace period', () {
      final now = DateTime(2026, 6, 1);

      // Expired 3 days ago -> within 7-day grace period
      final expired3DaysAgo = DateTime(2026, 5, 29);
      expect(
        WarrantyCalculator.isWithinGracePeriod(expired3DaysAgo, now: now),
        isTrue,
      );

      // Expired exactly 7 days ago -> within 7-day grace period
      final expired7DaysAgo = DateTime(2026, 5, 25);
      expect(
        WarrantyCalculator.isWithinGracePeriod(expired7DaysAgo, now: now),
        isTrue,
      );

      // Expired 8 days ago -> exceeds grace period
      final expired8DaysAgo = DateTime(2026, 5, 24);
      expect(
        WarrantyCalculator.isWithinGracePeriod(expired8DaysAgo, now: now),
        isFalse,
      );

      // Active warranty is not in grace period
      final active = DateTime(2026, 6, 10);
      expect(
        WarrantyCalculator.isWithinGracePeriod(active, now: now),
        isFalse,
      );
    });

    test('statusLabel returns user-friendly string', () {
      expect(WarrantyCalculator.statusLabel(WarrantyStatus.active), 'Active');
      expect(WarrantyCalculator.statusLabel(WarrantyStatus.expiringSoon), 'Expiring Soon');
      expect(WarrantyCalculator.statusLabel(WarrantyStatus.expired), 'Expired');
    });
  });
}
