import 'package:intl/intl.dart';

/// Utility for consistent date and time formatting throughout Claimly.
class DateFormatter {
  DateFormatter._();

  static final DateFormat _isoFormat = DateFormat('yyyy-MM-dd');
  static final DateFormat _displayFormat = DateFormat('MMM d, yyyy');
  static final DateFormat _displayDateTimeFormat = DateFormat('MMM d, yyyy HH:mm');
  static final DateFormat _shortFormat = DateFormat('MM/dd/yyyy');

  /// Formats date to ISO format 'yyyy-MM-dd'.
  static String formatDate(DateTime date) {
    return _isoFormat.format(date);
  }

  /// Formats date to readable display format 'MMM d, yyyy' (e.g. 'Nov 12, 2026').
  static String formatDisplayDate(DateTime date) {
    return _displayFormat.format(date);
  }

  /// Formats date and time to display format 'MMM d, yyyy HH:mm'.
  static String formatDateTime(DateTime date) {
    return _displayDateTimeFormat.format(date);
  }

  /// Formats date to short format 'MM/dd/yyyy'.
  static String formatShort(DateTime date) {
    return _shortFormat.format(date);
  }

  /// Returns a human-friendly relative time string (e.g. 'Just now', '2 hours ago', 'In 3 days').
  static String formatRelative(DateTime date, {DateTime? now}) {
    final current = now ?? DateTime.now();
    final difference = date.difference(current);
    final isFuture = difference.isNegative == false && difference.inSeconds > 0;
    final absDiff = difference.abs();

    if (absDiff.inMinutes < 1) {
      return isFuture ? 'In a few seconds' : 'Just now';
    } else if (absDiff.inHours < 1) {
      final mins = absDiff.inMinutes;
      return isFuture ? 'In $mins minute${mins > 1 ? 's' : ''}' : '$mins minute${mins > 1 ? 's' : ''} ago';
    } else if (absDiff.inDays < 1) {
      final hours = absDiff.inHours;
      return isFuture ? 'In $hours hour${hours > 1 ? 's' : ''}' : '$hours hour${hours > 1 ? 's' : ''} ago';
    } else if (absDiff.inDays == 1) {
      return isFuture ? 'Tomorrow' : 'Yesterday';
    } else if (absDiff.inDays < 30) {
      final days = absDiff.inDays;
      return isFuture ? 'In $days days' : '$days days ago';
    } else if (absDiff.inDays < 365) {
      final months = (absDiff.inDays / 30).floor();
      return isFuture ? 'In $months month${months > 1 ? 's' : ''}' : '$months month${months > 1 ? 's' : ''} ago';
    } else {
      final years = (absDiff.inDays / 365).floor();
      return isFuture ? 'In $years year${years > 1 ? 's' : ''}' : '$years year${years > 1 ? 's' : ''} ago';
    }
  }

  /// Attempts to parse an ISO or standard date string.
  static DateTime? tryParse(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return DateTime.tryParse(value.trim());
  }
}
