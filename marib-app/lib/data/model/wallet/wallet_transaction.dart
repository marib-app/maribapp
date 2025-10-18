import 'wallet_filter.dart';

class WalletTransaction {
  const WalletTransaction({
    required this.id,
    required this.amount,
    this.currency,
    this.beforeBalance,
    this.afterBalance,
    this.classification,
    this.category,
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
  final String? category;
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
    String? category,
  }) {
    return WalletTransaction(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      beforeBalance: beforeBalance ?? this.beforeBalance,
      afterBalance: afterBalance ?? this.afterBalance,
      classification: classification ?? this.classification,
      category: category ?? this.category,
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


    final metadataSource = json['meta'] ?? json['metadata'];
    final metadata = metadataSource is Map
        ? Map<String, dynamic>.from(metadataSource as Map)
        : const <String, dynamic>{};


    final appliedFilters = WalletFilter.fromResponse(
      json['filters'] ??
          json['applied_filters'] ??
          metadata['filters'] ??
          metadata['applied_filters'],
    );

    final category = _parseString(
      json['category'] ??
          json['classification'] ??
          metadata['category'] ??
          metadata['classification'],
    );

    final references = _parseReferences(json, metadata);
    final description = _parseDescription(json, metadata);
    final referenceCode = _parseReferenceCode(json, metadata);
    final deeplink = _parseDeeplink(json, metadata);

    return WalletTransaction(
      id: id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      amount: amount,
      currency:
      _parseString(
        json['currency'] ??
            json['amount_currency'] ??
            metadata['currency'] ??
            metadata['amount_currency'],
      ) ??
          amountDetails.currency,

      beforeBalance: _parseNullableDouble(
        json['before_balance'] ??
            json['balance_before'] ??
            metadata['before_balance'] ??
            metadata['balance_before'],
      ),
      afterBalance: _parseNullableDouble(
        json['after_balance'] ??
            json['balance_after'] ??
            metadata['after_balance'] ??
            metadata['balance_after'],
      ),
      classification: _parseString(
        json['classification'] ??
            json['type'] ??
            json['category'] ??
            metadata['classification'] ??
            metadata['type'] ??
            metadata['category'],
      ),
      category: category,
      description: description,
      references: references,
      referenceCode: referenceCode,
      createdAt: _parseDate(
        json['created_at'] ??
            json['date'] ??
            json['timestamp'] ??
            metadata['created_at'] ??
            metadata['timestamp'],
      ),
      deeplink: deeplink,
      idempotencyKey: _parseString(
        json['idempotency_key'] ??
            json['event_id'] ??
            metadata['idempotency_key'] ??
            _deepGet(metadata, const ['wallet', 'idempotency_key']),
      ),
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

  static String? _parseDescription(
      Map<String, dynamic> json,
      Map<String, dynamic> metadata,
      ) {
    final candidates = [
      json['description'],
      json['title'],
      json['message'],
      metadata['description'],
      metadata['title'],
      metadata['message'],
      metadata['summary'],
      metadata['note'],
      metadata['notes'],
      metadata['withdrawal_notes'],
    ];

    for (final candidate in candidates) {
      final parsed = _parseString(candidate);
      if (parsed != null) {
        return parsed;
      }

    }

    return null;
  }

  static String? _parseReferenceCode(
      Map<String, dynamic> json,
      Map<String, dynamic> metadata,
      ) {
    final candidates = [

      json['reference'],
      json['reference_code'],
      json['receipt'],
      metadata['reference_code'],
      metadata['reference'],
      metadata['wallet_reference'],
      metadata['withdrawal_request_reference'],
      metadata['transfer_reference'],
      metadata['external_reference'],
      metadata['manual_reference'],
      metadata['receipt'],
    ];

    for (final candidate in candidates) {
      final parsed = _parseString(candidate);
      if (parsed != null) {
        return parsed;
      }
    }

    return null;
  }

  static String? _parseDeeplink(
      Map<String, dynamic> json,
      Map<String, dynamic> metadata,
      ) {
    final candidates = [
      json['deeplink'],
      metadata['deeplink'],
      _deepGet(metadata, const ['links', 'deeplink']),
      _deepGet(metadata, const ['links', 'url']),
      _deepGet(metadata, const ['navigation', 'deeplink']),
      _deepGet(metadata, const ['navigation', 'url']),
      _deepGet(metadata, const ['wallet', 'deeplink']),
    ];

    for (final candidate in candidates) {
      final parsed = _parseString(candidate);
      if (parsed != null) {
        return parsed;
      }
    }

    return null;
  }

  static List<String> _parseReferences(
      Map<String, dynamic> json,
      Map<String, dynamic> metadata,
      ) {
    final refs = <String>{};

    void addCandidate(dynamic value) {
      final parsed = _parseString(value);
      if (parsed != null) {
        refs.add(parsed);
      }
    }

    void addCollection(dynamic value) {
      if (value is List) {
        for (final item in value) {
          addCandidate(item);
        }
      } else {
        addCandidate(value);
      }
    }

    addCollection(json['references'] ?? json['refs']);
    addCandidate(json['reference']);
    addCandidate(json['reference_code']);
    addCandidate(json['receipt']);
    addCandidate(json['transfer_reference']);
    addCandidate(json['external_reference']);

    addCollection(metadata['references'] ?? metadata['refs']);
    addCandidate(metadata['reference']);
    addCandidate(metadata['reference_code']);
    addCandidate(metadata['wallet_reference']);
    addCandidate(metadata['withdrawal_request_reference']);
    addCandidate(metadata['transfer_reference']);
    addCandidate(metadata['external_reference']);
    addCandidate(metadata['manual_reference']);
    addCandidate(metadata['receipt']);

    return refs.toList();
  }

  static dynamic _deepGet(Map<String, dynamic> source, List<Object> path) {
    dynamic current = source;
    for (final segment in path) {
      if (current is Map<String, dynamic>) {
        current = current[segment];
      } else if (current is Map) {
        current = Map<String, dynamic>.from(current as Map)[segment];
      } else {
        return null;
      }

      if (current == null) {
        return null;
      }
    }

    return current;

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