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
    paymentGateway =
        json['payment_gateway'] ?? json['payment_method'] ?? json['gateway'];
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
