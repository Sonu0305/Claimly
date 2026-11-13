import 'package:flutter_test/flutter_test.dart';
import 'package:claimly/core/utils/date_formatter.dart';

void main() {
  group('DateFormatter', () {
    final sampleDate = DateTime(2026, 11, 12, 14, 30);

    test('formatDate outputs yyyy-MM-dd format', () {
      expect(DateFormatter.formatDate(sampleDate), '2026-11-12');
    });

    test('formatDisplayDate outputs MMM d, yyyy format', () {
      expect(DateFormatter.formatDisplayDate(sampleDate), 'Nov 12, 2026');
    });

    test('formatDateTime outputs date and 24h time', () {
      expect(DateFormatter.formatDateTime(sampleDate), 'Nov 12, 2026 14:30');
    });

    test('formatRelative produces natural language relative times', () {
      final now = DateTime(2026, 11, 12, 12, 0);

      // Just now
      expect(
        DateFormatter.formatRelative(DateTime(2026, 11, 12, 11, 59, 45), now: now),
        'Just now',
      );

      // Minutes ago
      expect(
        DateFormatter.formatRelative(DateTime(2026, 11, 12, 11, 45), now: now),
        '15 minutes ago',
      );

      // Hours ago
      expect(
        DateFormatter.formatRelative(DateTime(2026, 11, 12, 9, 0), now: now),
        '3 hours ago',
      );

      // Yesterday
      expect(
        DateFormatter.formatRelative(DateTime(2026, 11, 11, 12, 0), now: now),
        'Yesterday',
      );

      // Days ago
      expect(
        DateFormatter.formatRelative(DateTime(2026, 11, 7, 12, 0), now: now),
        '5 days ago',
      );

      // Future relative
      expect(
        DateFormatter.formatRelative(DateTime(2026, 11, 15, 12, 0), now: now),
        'In 3 days',
      );
    });

    test('tryParse parses ISO strings correctly', () {
      final parsed = DateFormatter.tryParse('2026-11-12T14:30:00.000Z');
      expect(parsed, isNotNull);
      expect(parsed!.year, 2026);
      expect(parsed.month, 11);
      expect(parsed.day, 12);

      expect(DateFormatter.tryParse('invalid'), isNull);
      expect(DateFormatter.tryParse(''), isNull);
      expect(DateFormatter.tryParse(null), isNull);
    });
  });
}
