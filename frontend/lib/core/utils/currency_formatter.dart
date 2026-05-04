/// Currency formatting utility — formats amounts using the user's chosen currency symbol.
library;

import 'package:intl/intl.dart';

class CurrencyFormatter {
  CurrencyFormatter._();

  static String format(
    double amount, {
    String symbol = '\$',
    bool showSign = false,
    bool compact = false,
  }) {
    if (compact && amount.abs() >= 1000) {
      return _formatCompact(amount, symbol: symbol, showSign: showSign);
    }

    final formatter = NumberFormat.currency(
      symbol: symbol,
      decimalDigits: 2,
    );

    final formatted = formatter.format(amount.abs());

    if (showSign && amount > 0) return '+$formatted';
    if (amount < 0) return '-$formatted';
    return formatted;
  }

  /// e.g. $1.2K, $3.4M
  static String _formatCompact(double amount, {String symbol = '\$', bool showSign = false}) {
    final abs = amount.abs();
    String suffix;
    double value;

    if (abs >= 1000000) {
      value = abs / 1000000;
      suffix = 'M';
    } else {
      value = abs / 1000;
      suffix = 'K';
    }

    final str = value == value.truncate() ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
    final formatted = '$symbol$str$suffix';

    if (showSign && amount > 0) return '+$formatted';
    if (amount < 0) return '-$formatted';
    return formatted;
  }

  /// Parses a formatted string back to double (strips symbol and commas).
  static double? parse(String value) {
    final cleaned = value.replaceAll(RegExp(r'[^0-9.\-]'), '');
    return double.tryParse(cleaned);
  }

  /// Masks a formatted amount as  ••••••
  static String masked({String symbol = '\$'}) => '$symbol ••••••';
}
