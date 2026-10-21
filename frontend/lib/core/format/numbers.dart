import 'package:intl/intl.dart';

/// Symbols beginners recognize; every other currency shows its code ("SAR 25.76").
const _symbols = {'USD': r'$', 'EUR': '€', 'GBP': '£', 'JPY': '¥', 'INR': '₹'};

String _symbol(String currency) => _symbols[currency] ?? '$currency\u00A0';

/// Price with sensible precision: small coins need more decimals, currencies use 4.
String formatPrice(
  double value,
  String? currency, {
  String? locale,
  bool forex = false,
}) {
  final abs = value.abs();
  final digits = forex
      ? 4
      : abs >= 1
      ? 2
      : abs >= 0.01
      ? 4
      : 6;
  if (currency == null || currency.isEmpty) {
    return NumberFormat.decimalPatternDigits(
      locale: locale,
      decimalDigits: digits,
    ).format(value);
  }
  return NumberFormat.currency(
    locale: locale,
    name: currency,
    symbol: _symbol(currency),
    decimalDigits: digits,
  ).format(value);
}

/// 4980555644928 -> "4.98T".
String formatCompact(double value, {String? locale}) =>
    NumberFormat.compact(locale: locale).format(value);

/// 4980555644928, "USD" -> "\$4.98T".
String formatCompactMoney(double value, String currency, {String? locale}) =>
    NumberFormat.compactCurrency(
      locale: locale,
      name: currency,
      symbol: _symbol(currency),
    ).format(value);

/// 1.234 -> "+1.23%".
String formatPercent(double value, {bool signed = true}) {
  final sign = signed && value > 0 ? '+' : '';
  return '$sign${value.toStringAsFixed(2)}%';
}

String formatNumber(double value, {String? locale, int decimals = 2}) =>
    NumberFormat.decimalPatternDigits(
      locale: locale,
      decimalDigits: value == value.roundToDouble() ? 0 : decimals,
    ).format(value);

/// Cash amounts always use cents: 0.5 -> "$0.50" (prices of tiny coins use more digits).
String formatMoney(double value, String currency, {String? locale}) =>
    NumberFormat.currency(
      locale: locale,
      name: currency,
      symbol: _symbol(currency),
      decimalDigits: 2,
    ).format(value);

/// 123.4 -> "+$123.40", -5 -> "-$5.00": gains and losses always show their sign.
String formatSignedMoney(double value, String currency, {String? locale}) {
  final sign = value > 0
      ? '+'
      : value < 0
      ? '-'
      : '';
  return '$sign${formatMoney(value.abs(), currency, locale: locale)}';
}

/// Units held or traded: whole numbers stay whole, fractions keep up to 8 decimals.
String formatQuantity(double value, {String? locale}) =>
    NumberFormat('#,##0.########', locale).format(value);
