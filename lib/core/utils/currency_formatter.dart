import 'package:intl/intl.dart';

/// Utility for consistent currency and financial value formatting.
class CurrencyFormatter {
  CurrencyFormatter._();

  static final NumberFormat _standardFormat = NumberFormat.currency(
    symbol: '\$',
    decimalDigits: 2,
  );

  static final NumberFormat _compactFormat = NumberFormat.compactSimpleCurrency(
    name: 'USD',
  );

  /// Formats numeric amount to currency string (e.g. $1,250.00).
  static String format(num amount, {String symbol = '\$'}) {
    if (symbol == '\$') {
      return _standardFormat.format(amount);
    }
    final customFormat = NumberFormat.currency(
      symbol: symbol,
      decimalDigits: 2,
    );
    return customFormat.format(amount);
  }

  /// Formats numeric amount to compact string (e.g. $1.5K, $2M).
  static String formatCompact(num amount, {String symbol = '\$'}) {
    if (symbol == '\$') {
      return _compactFormat.format(amount);
    }
    return '$symbol${NumberFormat.compact().format(amount)}';
  }

  /// Parses string into double if valid, removing currency symbols and commas.
  static double? tryParse(String? value) {
    if (value == null) return null;
    final cleaned = value.replaceAll(RegExp(r'[^\d.-]'), '');
    return double.tryParse(cleaned);
  }
}
