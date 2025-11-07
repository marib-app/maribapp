class MerchantOrder {
  const MerchantOrder({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.paymentStatus,
    required this.total,
    required this.currency,
    required this.createdAt,
  });

  factory MerchantOrder.fromJson(Map<String, dynamic> json) {
    final String? createdAtRaw = json['created_at'] as String?;
    return MerchantOrder(
      id: _asInt(json['id']),
      orderNumber: _asString(json['order_number']) ?? '#${_asInt(json['id'])}',
      status: _asString(json['status']) ?? '',
      paymentStatus: _asString(json['payment_status']) ?? '',
      total: _asDouble(json['total']),
      currency: _asString(json['currency']) ?? 'ر.ي',
      createdAt:
          createdAtRaw != null ? DateTime.tryParse(createdAtRaw) : null,
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static double _asDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  static String? _asString(dynamic value) {
    if (value == null) return null;
    final String result = value.toString().trim();
    return result.isEmpty ? null : result;
  }

  final int id;
  final String orderNumber;
  final String status;
  final String paymentStatus;
  final double total;
  final String currency;
  final DateTime? createdAt;
}
