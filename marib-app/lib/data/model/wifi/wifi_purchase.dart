import 'package:equatable/equatable.dart';

class WifiPurchase extends Equatable {
  const WifiPurchase({
    required this.id,
    this.planId,
    this.planName,
    this.networkName,
    this.quantity = 1,
    this.total,
    this.currency,
    this.status,
    this.paymentGateway,
    this.codes = const <String>[],
    this.createdAt,
    this.reference,
    this.metadata = const <String, dynamic>{},
  });

  final int id;
  final int? planId;
  final String? planName;
  final String? networkName;
  final int quantity;
  final num? total;
  final String? currency;
  final String? status;
  final String? paymentGateway;
  final List<String> codes;
  final DateTime? createdAt;
  final String? reference;
  final Map<String, dynamic> metadata;

  factory WifiPurchase.fromJson(Map<String, dynamic> json) {
    int? parseInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value.toString());
    }

    num? parseNum(dynamic value) {
      if (value == null) return null;
      if (value is num) return value;
      return num.tryParse(value.toString());
    }

    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      if (value is int) {
        // treat as seconds if small, milliseconds otherwise
        if (value > 1000000000000) {
          return DateTime.fromMillisecondsSinceEpoch(value);
        }
        return DateTime.fromMillisecondsSinceEpoch(value * 1000);
      }
      final String string = value.toString();
      if (string.isEmpty) return null;
      try {
        return DateTime.parse(string);
      } catch (_) {
        return null;
      }
    }

    List<String> parseCodes(dynamic value) {
      if (value == null) return const <String>[];
      if (value is List) {
        return value
            .map((dynamic element) => element?.toString())
            .whereType<String>()
            .where((element) => element.trim().isNotEmpty)
            .toList();
      }
      if (value is Map) {
        return value.values
            .map((dynamic element) => element?.toString())
            .whereType<String>()
            .where((element) => element.trim().isNotEmpty)
            .toList();
      }
      final String string = value.toString();
      if (string.trim().isEmpty) return const <String>[];
      if (string.contains(',')) {
        return string
            .split(',')
            .map((segment) => segment.trim())
            .where((segment) => segment.isNotEmpty)
            .toList();
      }
      return <String>[string];
    }

    Map<String, dynamic> parseMap(dynamic value) {
      if (value is Map<String, dynamic>) {
        return value;
      }
      if (value is Map) {
        return Map<String, dynamic>.from(value as Map);
      }
      return <String, dynamic>{};
    }

    final Map<String, dynamic> planMap = parseMap(json['plan']);
    final Map<String, dynamic> networkMap = parseMap(json['network']);
    final Map<String, dynamic> baseMeta = {
      ...parseMap(json['meta']),
      ...parseMap(json['metadata']),
      ...parseMap(json['extras']),
    };

    final int id = parseInt(
      json['id'] ??
          json['purchase_id'] ??
          json['order_id'] ??
          json['transaction_id'],
    ) ??
        0;

    final int? planId = parseInt(
      json['plan_id'] ?? json['wifi_plan_id'] ?? planMap['id'],
    );

    final String? planName = (json['plan_name'] ??
        json['plan_title'] ??
        planMap['name'] ??
        planMap['title'])
        ?.toString();

    final String? networkName = (json['network_name'] ?? networkMap['name'])
        ?.toString();

    final int quantity = parseInt(json['quantity']) ??
        parseInt(json['count']) ??
        parseInt(baseMeta['quantity']) ??
        1;

    final num? total = parseNum(
      json['total'] ??
          json['amount'] ??
          json['total_amount'] ??
          json['paid_amount'] ??
          baseMeta['total'],
    );

    final String? currency = (json['currency'] ??
        json['currency_code'] ??
        json['currency_symbol'] ??
        baseMeta['currency'])
        ?.toString();

    final String? status = (json['status'] ??
        json['purchase_status'] ??
        json['payment_status'] ??
        json['state'] ??
        baseMeta['status'])
        ?.toString();

    final String? gateway = (json['payment_gateway'] ??
        json['payment_method'] ??
        json['gateway'] ??
        baseMeta['payment_gateway'])
        ?.toString();

    final DateTime? createdAt = parseDate(
      json['created_at'] ?? json['createdAt'] ?? json['date'] ?? json['purchased_at'],
    );

    final List<String> codes = [
      ...parseCodes(json['codes']),
      ...parseCodes(json['masked_codes']),
      ...parseCodes(json['vouchers']),
      ...parseCodes(json['access_codes']),
      ...parseCodes(json['pins']),
    ];

    if (codes.isEmpty && json['code'] != null) {
      codes.add(json['code'].toString());
    }

    final String? reference = (json['reference'] ??
        json['transaction_reference'] ??
        json['payment_reference'] ??
        json['order_reference'])
        ?.toString();


    final Map<String, dynamic> derivedMeta = <String, dynamic>{
      if (json['transaction_id'] != null)
        'transaction_id': parseInt(json['transaction_id']),
      if (json['payment_status'] != null)
        'payment_status': json['payment_status'].toString(),
      if (json['payment_status_label'] != null)
        'payment_status_label': json['payment_status_label'].toString(),
      if (json['status_label'] != null)
        'status_label': json['status_label'].toString(),
      if (json['reveal_count'] != null)
        'reveal_count': parseInt(json['reveal_count']),
      if (json['revealed_at'] != null)
        'revealed_at': json['revealed_at'],
      if (json['code_id'] != null)
        'code_id': parseInt(json['code_id']),
    };

    final Map<String, dynamic> meta = <String, dynamic>{
      ...baseMeta,
      ...derivedMeta,
    }..removeWhere((_, value) => value == null);

    return WifiPurchase(
      id: id,
      planId: planId,
      planName: planName,
      networkName: networkName,
      quantity: quantity,
      total: total,
      currency: currency,
      status: status,
      paymentGateway: gateway,
      codes: codes.toSet().toList(),
      createdAt: createdAt,
      reference: reference,
      metadata: meta,
    );
  }

  WifiPurchase copyWith({
    int? id,
    int? planId,
    String? planName,
    String? networkName,
    int? quantity,
    num? total,
    String? currency,
    String? status,
    String? paymentGateway,
    List<String>? codes,
    DateTime? createdAt,
    String? reference,
    Map<String, dynamic>? metadata,
  }) {
    return WifiPurchase(
      id: id ?? this.id,
      planId: planId ?? this.planId,
      planName: planName ?? this.planName,
      networkName: networkName ?? this.networkName,
      quantity: quantity ?? this.quantity,
      total: total ?? this.total,
      currency: currency ?? this.currency,
      status: status ?? this.status,
      paymentGateway: paymentGateway ?? this.paymentGateway,
      codes: codes ?? this.codes,
      createdAt: createdAt ?? this.createdAt,
      reference: reference ?? this.reference,
      metadata: metadata ?? this.metadata,
    );
  }


  WifiPurchase withoutCodes() {
    if (codes.isEmpty) {
      return this;
    }
    return copyWith(codes: const <String>[]);
  }

  bool get isWalletGateway {
    final gateway = paymentGateway?.toLowerCase() ?? '';
    if (gateway.isEmpty) {
      final metaGateway = metadata['payment_gateway']?.toString().toLowerCase() ?? '';
      return metaGateway == 'wallet' || metaGateway.contains('wallet');
    }
    return gateway == 'wallet' || gateway.contains('wallet');
  }

  String? get statusLabel {
    final value = status ?? metadata['status']?.toString();
    if (value == null || value.isEmpty) {
      return null;
    }
    return value;
  }


  int? get transactionId {
    final dynamic raw = metadata['transaction_id'] ?? metadata['transactionId'];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) {
      final String trimmed = raw.trim();
      if (trimmed.isEmpty) {
        return null;
      }
      return int.tryParse(trimmed);
    }
    return null;
  }

  String? get paymentStatusLabel {
    final dynamic raw = metadata['payment_status_label'] ??
        metadata['payment_status'] ??
        metadata['status_label'];
    if (raw == null) {
      return null;
    }
    final String label = raw.toString().trim();
    return label.isEmpty ? null : label;
  }


  @override
  List<Object?> get props => [
    id,
    planId,
    planName,
    networkName,
    quantity,
    total,
    currency,
    status,
    paymentGateway,
    codes,
    createdAt,
    reference,
    metadata,
  ];
}