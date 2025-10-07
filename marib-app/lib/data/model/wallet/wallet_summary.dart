import 'wallet_filter.dart';
import 'package:marib/utils/currency_utils.dart';

class WalletSummary {
  WalletSummary({
    required this.balance,
    this.currency,
    this.currencyCode,
    this.lastUpdatedAt,
    List<WalletFilter>? availableFilters,
    Map<String, dynamic>? raw,
  })  : availableFilters = availableFilters ?? const [],
        raw = raw ?? const {};

  final double balance;
  final String? currency;
  final DateTime? lastUpdatedAt;
  final List<WalletFilter> availableFilters;
  final Map<String, dynamic> raw;
  final String? currencyCode;

  factory WalletSummary.fromJson(Map<String, dynamic> json) {
    final balanceSource =
        json['balance'] ?? json['available_balance'] ?? json['current_balance'];
    final balanceDetails = _extractBalanceDetails(balanceSource);
    final balance = balanceDetails.amount ?? 0;
    final filters = WalletFilter.fromResponse(
      json['filters'] ?? json['available_filters'] ?? json['data_filters'],
    );
    final meta = json['meta'];
    final metadataFilters = WalletFilter.fromResponse(
      meta is Map ? (meta as Map)['filters'] : null,
    );


    final CurrencyParseResult currencyInfo = CurrencyUtils.parseCurrency(json);
    final String? currencyFromJson =
    _parseString(json['currency'] ?? json['balance_currency']);
    final String? displayCurrency = (currencyInfo.display ?? currencyFromJson ??
        balanceDetails.currency)
        ?.trim();
    final String? normalizedCurrencyCode = currencyInfo.code ??
        CurrencyUtils.normalizeCurrencyCode(displayCurrency) ??
        CurrencyUtils.normalizeCurrencyCode(balanceDetails.currency);

    return WalletSummary(
      balance: balance,
      currency: displayCurrency,
      currencyCode: normalizedCurrencyCode,

      lastUpdatedAt: _parseDate(json['last_updated_at'] ?? json['updated_at']),
      availableFilters: [
        ...filters,
        ...metadataFilters.where(
              (candidate) =>
          filters.indexWhere((existing) => existing.value == candidate.value) ==
              -1,
        ),
      ],
      raw: Map<String, dynamic>.from(json),
    );
  }

  WalletSummary copyWith({
    double? balance,
    String? currency,
    String? currencyCode,
    DateTime? lastUpdatedAt,
    List<WalletFilter>? availableFilters,
    Map<String, dynamic>? raw,
  }) {
    return WalletSummary(
      balance: balance ?? this.balance,
      currency: currency ?? this.currency,
      currencyCode: currencyCode ?? this.currencyCode,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
      availableFilters: availableFilters ?? this.availableFilters,
      raw: raw ?? this.raw,
    );
  }

  static double _parseDouble(dynamic value) {
    final details = _extractBalanceDetails(value);
    return details.amount ?? 0;
  }

  static _BalanceDetails _extractBalanceDetails(dynamic value) {
    double? amount;
    String? currency;

    double? parsePrimitive(dynamic candidate) {
      if (candidate is num) return candidate.toDouble();
      if (candidate is String) {
        final sanitized = candidate.replaceAll(RegExp(r'[^0-9\.-]'), '');
        final parsed = double.tryParse(sanitized);
        if (parsed != null) return parsed;
      }
      return null;
    }


    if (value is Map) {
      final map = value;
      currency = _parseString(map['currency']);

      for (final key in const ['value', 'amount']) {
        if (map.containsKey(key)) {
          final nested = _extractBalanceDetails(map[key]);
          amount ??= nested.amount;
          currency ??= nested.currency;
          if (amount != null && currency != null) {
            break;
          }
        }
      }

      amount ??= parsePrimitive(map['value']);
      amount ??= parsePrimitive(map['amount']);
      amount ??= parsePrimitive(map['current']);

      final minorValue = parsePrimitive(map['minor']);
      if (amount == null && minorValue != null) {
        amount = minorValue / 100;
      }

      if (amount == null) {
        for (final entry in map.entries) {
          if (entry.value is Map) {
            final nested = _extractBalanceDetails(entry.value);
            amount ??= nested.amount;
            currency ??= nested.currency;
            if (amount != null && currency != null) {
              break;
            }
          }
        }
      }
    } else {
      amount = parsePrimitive(value);
    }

    return _BalanceDetails(amount: amount, currency: currency);

  }

  static String? _parseString(dynamic value) {
    if (value == null) return null;
    if (value is String && value.trim().isEmpty) return null;
    return value.toString();
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is DateTime) {
      return value;
    }
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt() * 1000, isUtc: true);
    }
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}





class _BalanceDetails {
  const _BalanceDetails({
    this.amount,
    this.currency,
  });

  final double? amount;
  final String? currency;
}




class WalletSummaryBundle {
  const WalletSummaryBundle({
    required this.summary,
    this.filters = const [],
  });

  final WalletSummary summary;
  final List<WalletFilter> filters;

  List<WalletFilter> get mergedFilters {
    final filtersByValue = <String, WalletFilter>{
      for (final f in summary.availableFilters) f.value: f,
    };
    for (final f in filters) {
      filtersByValue.putIfAbsent(f.value, () => f);
    }
    return filtersByValue.values.toList();
  }
}