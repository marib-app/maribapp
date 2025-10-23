class TransactionModel {
  int? id;
  int? userId;
  double? amount;
  String? paymentGateway;
  String? orderId;
  String? paymentId;
  String? paymentSignature;
  String? paymentStatus;
  String? createdAt;
  String? updatedAt;

  TransactionModel(
      {this.id,
      this.userId,
      this.amount,
      this.paymentGateway,
      this.orderId,
      this.paymentId,
      this.paymentSignature,
      this.paymentStatus,
      this.createdAt,
      this.updatedAt});

  TransactionModel.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    userId = json['user_id'];
    amount = _parseAmount(json['amount'] ?? json['amount_value']) ?? 0.0;
    paymentGateway = _resolvePaymentGateway(json);

    orderId = json['order_id'] ??
        json['transaction_reference'] ??
        json['reference'] ??
        json['payment_reference'];
    paymentId = (json['payment_id'] ??
            json['payment_transaction_id'] ??
            json['transaction_id'] ??
            json['transaction_identifier'] ??
            json['identifier'] ??
            json['manual_payment_id'] ??
            json['id'])
        ?.toString();

    paymentSignature = json['payment_signature'];
    paymentStatus =
        json['payment_status'] ?? json['status'] ?? json['transaction_status'];

    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
  }

  String _resolvePaymentGateway(Map<String, dynamic> json) {
    const List<String> labelKeys = <String>[
      'payment_gateway_label',
      'gateway_label',
      'channel_label',
      'bank_label',
      'manual_bank_name',
    ];

    for (final String key in labelKeys) {
      final String? label = _cleanLabel(json[key]);
      if (label != null) {
        return label;
      }
    }

    final dynamic rawCandidate =
        json['payment_gateway'] ?? json['payment_method'] ?? json['gateway'];

    final String? formatted = _formatGatewayName(rawCandidate);

    return formatted ?? '—';
  }

  String? _cleanLabel(dynamic value) {
    if (value == null) {
      return null;
    }
    final String label = value.toString().trim();
    if (label.isEmpty) {
      return null;
    }
    return label;
  }

  String? _formatGatewayName(dynamic value) {
    final String? raw = _cleanLabel(value);
    if (raw == null) {
      return null;
    }

    final String lower = raw.toLowerCase();
    if (lower.contains('wallet')) {
      return 'المحفظة';
    }

    final String cleaned = raw
        .replaceAll(RegExp(r'[_\-]+'), ' ')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();

    if (cleaned.isNotEmpty) {
      return cleaned;
    }

    return raw;
  }

  double? _parseAmount(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      final sanitized = value.replaceAll(RegExp(r'[^0-9\.-]'), '');
      return double.tryParse(sanitized);
    }
    return null;
  }

  String get paymentGatewayDisplay {
    final String? label = _cleanLabel(paymentGateway);
    return label ?? '—';
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['user_id'] = this.userId;
    data['amount'] = this.amount;
    data['payment_gateway'] = this.paymentGateway;
    data['order_id'] = this.orderId;
    data['payment_id'] = this.paymentId;
    data['payment_signature'] = this.paymentSignature;
    data['payment_status'] = this.paymentStatus;
    data['created_at'] = this.createdAt;
    data['updated_at'] = this.updatedAt;
    return data;
  }
}
