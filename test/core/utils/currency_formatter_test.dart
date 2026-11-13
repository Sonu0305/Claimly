import 'package:flutter_test/flutter_test.dart';
import 'package:claimly/core/utils/currency_formatter.dart';

void main() {
  group('CurrencyFormatter', () {
    test('format formats numbers with dollar sign and commas', () {
      expect(CurrencyFormatter.format(0), '\$0.00');
      expect(CurrencyFormatter.format(12.5), '\$12.50');
      expect(CurrencyFormatter.format(1250), '\$1,250.00');
      expect(CurrencyFormatter.format(999999.99), '\$999,999.99');
    });

    test('format supports custom symbol', () {
      expect(CurrencyFormatter.format(100, symbol: '€'), '€100.00');
    });

    test('formatCompact formats large numbers concisely', () {
      expect(CurrencyFormatter.formatCompact(1500), '\$1.5K');
      expect(CurrencyFormatter.formatCompact(2000000), '\$2M');
    });

    test('tryParse parses formatted and unformatted numeric strings', () {
      expect(CurrencyFormatter.tryParse('\$1,250.50'), 1250.50);
      expect(CurrencyFormatter.tryParse('1250.50'), 1250.50);
      expect(CurrencyFormatter.tryParse('0'), 0.0);
      expect(CurrencyFormatter.tryParse('invalid'), isNull);
      expect(CurrencyFormatter.tryParse(null), isNull);
    });
  });
}
