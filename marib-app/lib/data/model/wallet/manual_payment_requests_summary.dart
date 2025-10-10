import 'dart:collection';

class ManualPaymentRequestsSummaryStatus {
  const ManualPaymentRequestsSummaryStatus({
    required this.key,
    required this.count,
    required this.amount,
    required this.amounts,
  });

  final String key;
  final int count;
  final double amount;
  final Map<String, double> amounts;

  ManualPaymentRequestsSummaryStatus copyWith({
    int? count,
    double? amount,
    Map<String, double>? amounts,
  }) {
    return ManualPaymentRequestsSummaryStatus(
      key: key,
      count: count ?? this.count,
      amount: amount ?? this.amount,
      amounts: amounts ?? this.amounts,
    );
  }

  static ManualPaymentRequestsSummaryStatus empty(String key) {
    return ManualPaymentRequestsSummaryStatus(
      key: key,
      count: 0,
      amount: 0.0,
      amounts: const <String, double>{},
    );
  }

  factory ManualPaymentRequestsSummaryStatus.fromJson(
      String key,
      dynamic json,
      ) {
    final map = _mapify(json);
    final count = _parseInt(map['count']);
    final amount = _parseDouble(map['amount']);
    final amounts = _parseAmounts(map['amounts']);
    return ManualPaymentRequestsSummaryStatus(
      key: key,
      count: count,
      amount: amount,
      amounts: UnmodifiableMapView(amounts),
    );
  }

  static Map<String, dynamic> _mapify(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, val) => MapEntry('$key', val));
    }
    return const <String, dynamic>{};
  }

  static Map<String, double> _parseAmounts(dynamic value) {
    final result = <String, double>{};
    if (value is Map<String, dynamic>) {
      value.forEach((key, val) {
        final currency = key.toUpperCase().trim();
        if (currency.isEmpty) return;
        final amount = _parseDouble(val);
        result[currency] = amount;
      });
    } else if (value is Map) {
      value.forEach((key, val) {
        final currency = key.toString().toUpperCase().trim();
        if (currency.isEmpty) return;
        final amount = _parseDouble(val);
        result[currency] = amount;
      });
    }
    return result;
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      return int.tryParse(value.trim()) ?? 0;
    }
    return 0;
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) {
      final sanitized = value.trim();
      if (sanitized.isEmpty) return 0.0;
      final normalized = sanitized.replaceAll(RegExp(r'[^0-9.\-]'), '');
      return double.tryParse(normalized) ?? 0.0;
    }
    return 0.0;
  }
}

class ManualPaymentRequestsSummary {
  ManualPaymentRequestsSummary({
    required this.total,
    required Map<String, ManualPaymentRequestsSummaryStatus> statuses,
  }) : statuses = UnmodifiableMapView(Map<String, ManualPaymentRequestsSummaryStatus>.from(statuses));

  final ManualPaymentRequestsSummaryStatus total;
  final Map<String, ManualPaymentRequestsSummaryStatus> statuses;

  factory ManualPaymentRequestsSummary.fromJson(Map<String, dynamic> json) {
    final total = ManualPaymentRequestsSummaryStatus.fromJson(
      'total',
      json['total'] ?? const <String, dynamic>{},
    );
    final statuses = <String, ManualPaymentRequestsSummaryStatus>{};
    final rawStatuses = json['statuses'];
    if (rawStatuses is Map<String, dynamic>) {
      rawStatuses.forEach((key, value) {
        statuses[key] = ManualPaymentRequestsSummaryStatus.fromJson(key, value);
      });
    } else if (rawStatuses is Map) {
      rawStatuses.forEach((key, value) {
        final statusKey = key.toString();
        statuses[statusKey] = ManualPaymentRequestsSummaryStatus.fromJson(statusKey, value);
      });
    }
    return ManualPaymentRequestsSummary(
      total: total,
      statuses: statuses,
    );
  }

  ManualPaymentRequestsSummaryStatus status(String key) {
    return statuses[key] ?? ManualPaymentRequestsSummaryStatus.empty(key);
  }

  List<ManualPaymentRequestsSummaryStatus> orderedStatuses(
      Iterable<String> keys,
      ) {
    return keys
        .map((key) => status(key))
        .toList(growable: false);
  }
}