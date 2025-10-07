import 'wallet_filter.dart';

class WalletTransaction {
  const WalletTransaction({
    required this.id,
    required this.amount,
    this.currency,
    this.beforeBalance,
    this.afterBalance,
    this.classification,
    this.description,
    this.references = const [],
    this.referenceCode,
    this.createdAt,
    this.deeplink,
    this.idempotencyKey,
    this.metadata = const {},
    this.appliedFilters = const [],
    this.highlighted = false,
  });

  final String id;
  final double amount;
  final String? currency;
  final double? beforeBalance;
  final double? afterBalance;
  final String? classification;
  final String? description;
  final List<String> references;
  final String? referenceCode;
  final DateTime? createdAt;
  final String? deeplink;
  final String? idempotencyKey;
  final Map<String, dynamic> metadata;
  final List<WalletFilter> appliedFilters;
  final bool highlighted;

  bool get isCredit => amount >= 0;

  WalletTransaction copyWith({
    String? id,
    double? amount,
    String? currency,
    double? beforeBalance,
    double? afterBalance,
    String? classification,
    String? description,
    List<String>? references,
    String? referenceCode,
    DateTime? createdAt,
    String? deeplink,
    String? idempotencyKey,
    Map<String, dynamic>? metadata,
    List<WalletFilter>? appliedFilters,
    bool? highlighted,
  }) {
    return WalletTransaction(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      beforeBalance: beforeBalance ?? this.beforeBalance,
      afterBalance: afterBalance ?? this.afterBalance,
      classification: classification ?? this.classification,
      description: description ?? this.description,
      references: references ?? this.references,
      referenceCode: referenceCode ?? this.referenceCode,
      createdAt: createdAt ?? this.createdAt,
      deeplink: deeplink ?? this.deeplink,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      metadata: metadata ?? this.metadata,
      appliedFilters: appliedFilters ?? this.appliedFilters,
      highlighted: highlighted ?? this.highlighted,
    );
  }

  factory WalletTransaction.fromJson(Map<String, dynamic> json) {
    final id = _parseString(json['id'] ?? json['uuid'] ?? json['hash'] ?? json['reference']);
    final amountSource = json['amount'] ?? json['value'] ?? json['delta'];
    final amountDetails = _extractAmountDetails(amountSource);
    final amount = amountDetails.amount ?? 0.0;
    final appliedFilters = WalletFilter.fromResponse(json['filters'] ?? json['applied_filters']);

    final references = _parseReferences(json);

    final metadataSource = json['meta'] ?? json['metadata'];
    final metadata = metadataSource is Map
        ? Map<String, dynamic>.from(metadataSource as Map)
        : const <String, dynamic>{};

    return WalletTransaction(
      id: id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      amount: amount,
      currency:
      _parseString(json['currency'] ?? json['amount_currency']) ?? amountDetails.currency,

      beforeBalance: _parseNullableDouble(json['before_balance'] ?? json['balance_before']),
      afterBalance: _parseNullableDouble(json['after_balance'] ?? json['balance_after']),
      classification: _parseString(json['classification'] ?? json['type'] ?? json['category']),
      description: _parseString(json['description'] ?? json['title'] ?? json['message']),
      references: references,
      referenceCode: _parseString(json['reference'] ?? json['reference_code'] ?? json['receipt']),
      createdAt: _parseDate(json['created_at'] ?? json['date'] ?? json['timestamp']),
      deeplink: _parseString(json['deeplink']),
      idempotencyKey: _parseString(json['idempotency_key'] ?? json['event_id']),
      metadata: metadata,
      appliedFilters: appliedFilters,
    );
  }

  static double _parseDouble(dynamic value) {
    final details = _extractAmountDetails(value);
    return details.amount ?? 0.0;
  }

  static double? _parseNullableDouble(dynamic value) {
    if (value == null) return null;
    final details = _extractAmountDetails(value);
    return details.amount;
  }

  static _AmountDetails _extractAmountDetails(dynamic value) {
    if (value == null) return const _AmountDetails();

    double? amount;
    String? currency;

    double? parsePrimitive(dynamic candidate) {
      if (candidate is num) return candidate.toDouble();
      if (candidate is String) {
        final normalized = candidate.replaceAll(RegExp(r'[^0-9\.-]'), '');
        final parsed = double.tryParse(normalized);
        if (parsed != null) return parsed;
      }
      return null;

    }

    if (value is Map) {
      final map = value;
      currency = _parseString(map['currency']) ?? _parseString(map['amount_currency']);

      for (final key in const ['value', 'amount']) {
        if (map.containsKey(key)) {
          final nested = _extractAmountDetails(map[key]);
          amount ??= nested.amount;
          currency ??= nested.currency;
          if (amount != null && currency != null) {
            break;
          }
        }
      }

      amount ??= parsePrimitive(map['value']);
      amount ??= parsePrimitive(map['amount']);

      final minorValue = parsePrimitive(map['minor'] ?? map['minor_value']);
      if (amount == null && minorValue != null) {
        amount = minorValue / 100;
      }

      if (amount == null || currency == null) {
        for (final entry in map.entries) {
          final nestedValue = entry.value;
          if (nestedValue is Map) {
            final nested = _extractAmountDetails(nestedValue);
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

    return _AmountDetails(amount: amount, currency: currency);


  }

  static String? _parseString(dynamic value) {
    if (value == null) return null;
    final str = value.toString();
    if (str.trim().isEmpty) return null;
    return str;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is num) {
      if (value > 10000000000) {
        return DateTime.fromMillisecondsSinceEpoch(value.toInt(), isUtc: true);
      }
      return DateTime.fromMillisecondsSinceEpoch(value.toInt() * 1000, isUtc: true);
    }
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  static List<String> _parseReferences(Map<String, dynamic> json) {
    final refs = <String>[];
    final dynamic directRefs = json['references'] ?? json['refs'];
    if (directRefs is List) {
      for (final item in directRefs) {
        final parsed = _parseString(item);
        if (parsed != null) refs.add(parsed);
      }
    } else if (directRefs is String) {
      refs.add(directRefs);
    }

    final otherKeys = [
      json['reference'],
      json['reference_code'],
      json['receipt'],
      json['transfer_reference'],
      json['external_reference'],
    ];
    for (final item in otherKeys) {
      final parsed = _parseString(item);
      if (parsed != null) refs.add(parsed);
    }

    return refs.toSet().toList();
  }
}


class _AmountDetails {
  const _AmountDetails({
    this.amount,
    this.currency,
  });

  final double? amount;
  final String? currency;
}


class WalletTransactionsMeta {
  const WalletTransactionsMeta({
    this.currentPage = 1,
    this.lastPage,
    this.hasMore = false,
    this.availableFilters = const [],
  });

  final int currentPage;
  final int? lastPage;
  final bool hasMore;
  final List<WalletFilter> availableFilters;
}