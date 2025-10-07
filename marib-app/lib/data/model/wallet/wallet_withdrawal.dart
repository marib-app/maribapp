class WalletWithdrawal {
  WalletWithdrawal({
    required this.id,
    this.reference,
    this.amount,
    this.currency,
    this.status,
    this.statusMessage,
    this.metadata = const <String, dynamic>{},
    this.createdAt,
    this.updatedAt,
    this.raw = const <String, dynamic>{},
  });

  final String id;
  final String? reference;
  final double? amount;
  final String? currency;
  final String? status;
  final String? statusMessage;
  final Map<String, dynamic> metadata;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic> raw;

  factory WalletWithdrawal.fromJson(Map<String, dynamic> json) {
    final map = Map<String, dynamic>.from(json);

    String? _parseString(dynamic value) {
      if (value == null) return null;
      if (value is String) return value;
      return value.toString();
    }

    double? _parseDouble(dynamic value) {
      if (value == null) return null;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is num) return value.toDouble();
      if (value is String && value.isNotEmpty) {
        return double.tryParse(value.replaceAll(',', ''));
      }
      return null;
    }

    DateTime? _parseDate(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      if (value is int) {
        return DateTime.fromMillisecondsSinceEpoch(value * (value.toString().length == 10 ? 1000 : 1));
      }
      if (value is String && value.isNotEmpty) {
        try {
          return DateTime.parse(value);
        } catch (_) {
          return null;
        }
      }
      return null;
    }

    Map<String, dynamic> _parseMetadata() {
      final candidates = [
        map['metadata'],
        map['meta'],
        map['details'],
        map['extra'],
      ];
      for (final candidate in candidates) {
        if (candidate is Map<String, dynamic>) {
          return Map<String, dynamic>.from(candidate);
        }
        if (candidate is Map) {
          return candidate.map((key, value) => MapEntry(key.toString(), value));
        }
      }
      return const <String, dynamic>{};
    }

    String? id = _parseString(map['id']);
    id ??= _parseString(map['uuid']);
    id ??= _parseString(map['reference']);
    id ??= _parseString(map['transaction_id']);

    if (id == null || id.isEmpty) {
      id = DateTime.now().millisecondsSinceEpoch.toString();
    }

    final amount = _parseDouble(map['amount'] ?? map['total'] ?? map['value']);
    final currency = _parseString(map['currency'] ?? map['currency_code']);
    final status = _parseString(map['status'] ?? map['state'] ?? map['payment_status']);
    final statusMessage = _parseString(
      map['status_message'] ?? map['message'] ?? map['description'],
    );

    return WalletWithdrawal(
      id: id,
      reference: _parseString(map['reference'] ?? map['display_id'] ?? map['code']),
      amount: amount,
      currency: currency,
      status: status,
      statusMessage: statusMessage,
      metadata: _parseMetadata(),
      createdAt: _parseDate(map['created_at'] ?? map['createdAt'] ?? map['created']),
      updatedAt: _parseDate(map['updated_at'] ?? map['updatedAt'] ?? map['updated']),
      raw: map,
    );
  }

  WalletWithdrawal copyWith({
    String? id,
    String? reference,
    double? amount,
    String? currency,
    String? status,
    String? statusMessage,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? raw,
  }) {
    return WalletWithdrawal(
      id: id ?? this.id,
      reference: reference ?? this.reference,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      status: status ?? this.status,
      statusMessage: statusMessage ?? this.statusMessage,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      raw: raw ?? this.raw,
    );
  }
}