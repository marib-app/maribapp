import 'package:intl/intl.dart';

import 'package:marib/utils/currency_utils.dart';

/// Utility for formatting monetary values according to the cart currency that
/// comes from the server. Always prefer constructing this class with the
/// currency that belongs to the cart rather than relying on device settings or
/// global fallbacks.
class MoneyFormatter {
  MoneyFormatter(
      String? currency, {
        String? currencyCode,
        String? fallbackLabel,
      })  : _rawCurrency = _sanitize(currency),
        _rawCode = CurrencyUtils.normalizeCurrencyCode(currencyCode ?? currency),
        _fallbackLabel = _sanitize(fallbackLabel);

  /// Convenience factory to create a formatter from a [CurrencyParseResult].
  factory MoneyFormatter.fromCurrencyInfo(CurrencyParseResult info,
      {String? fallbackLabel}) {
    return MoneyFormatter(
      info.display,
      currencyCode: info.code,
      fallbackLabel: fallbackLabel,
    );
  }

  /// Convenience factory to create a formatter from cart item metadata.
  factory MoneyFormatter.fromCartCurrency({
    String? currency,
    String? currencyCode,
    String? fallbackLabel,
  }) {
    return MoneyFormatter(
      currency,
      currencyCode: currencyCode,
      fallbackLabel: fallbackLabel,
    );
  }

  final String? _rawCurrency;
  final String? _rawCode;
  final String? _fallbackLabel;

  static const Set<String> _zeroDecimalCurrencies = <String>{
    'BIF',
    'CLP',
    'DJF',
    'GNF',
    'JPY',
    'KMF',
    'KRW',
    'MGA',
    'PYG',
    'RWF',
    'UGX',
    'UYI',
    'VND',
    'VUV',
    'XAF',
    'XOF',
    'XPF',
  };

  static const Map<String, int> _threeDecimalCurrencies = <String, int>{
    'BHD': 3,
    'IQD': 3,
    'JOD': 3,
    'KWD': 3,
    'LYD': 3,
    'OMR': 3,
    'TND': 3,
  };

  static String? _sanitize(String? value) {
    if (value == null) {
      return null;
    }
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  /// Normalized ISO currency code when available.
  String? get currencyCode => _rawCode;

  /// Human friendly label or symbol.
  String? get currencyLabel => CurrencyUtils.displayToken(
    label: _rawCurrency,
    fallback: _fallbackLabel ?? currencyCode,
    code: currencyCode,
  ) ??
      _fallbackLabel ??
      currencyCode;

  /// Builds a formatted string for [amount]. By default the currency label is
  /// appended after the number (e.g. `123.45 USD`).
  String format(num amount, {bool includeCurrency = true, int? fractionDigits}) {
    final NumberFormat numberFormat = _numberFormat(fractionDigits: fractionDigits);
    final String numeric = numberFormat.format(amount);
    if (!includeCurrency) {
      return numeric;
    }

    final String? label = currencyLabel;
    if (label == null || label.isEmpty) {
      return numeric;
    }

    return '$numeric $label'.trim();
  }

  /// Same as [format] but returns [placeholder] when [amount] is `null`.
  String formatNullable(num? amount,
      {String placeholder = '—', bool includeCurrency = true, int? fractionDigits}) {
    if (amount == null) {
      return placeholder;
    }
    return format(amount,
        includeCurrency: includeCurrency, fractionDigits: fractionDigits);
  }

  NumberFormat _numberFormat({int? fractionDigits}) {
    final int digits = fractionDigits ?? _resolvedFractionDigits;
    final StringBuffer pattern = StringBuffer('#,##0');
    if (digits > 0) {
      pattern.write('.');
      pattern.write(List<String>.filled(digits, '0').join());
    }
    return NumberFormat(pattern.toString(), 'en');
  }

  int get _resolvedFractionDigits {
    final String? code = currencyCode;
    if (code == null) {
      return 2;
    }
    if (_threeDecimalCurrencies.containsKey(code)) {
      return _threeDecimalCurrencies[code]!;
    }
    if (_zeroDecimalCurrencies.contains(code)) {
      return 0;
    }
    return 2;
  }
}