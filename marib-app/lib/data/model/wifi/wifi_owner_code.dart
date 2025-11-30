class WifiOwnerCode {
  WifiOwnerCode({
    required this.id,
    required this.status,
    this.codeSuffix,
    this.codeLast4,
    this.planId,
    this.planName,
    this.allocatedUserId,
    this.allocatedUserName,
    this.allocatedUserEmail,
    this.allocatedAt,
    this.soldAt,
    this.deliveredAt,
    this.revealedAt,
  });

  final int id;
  final String? status;
  final String? codeSuffix;
  final String? codeLast4;
  final int? planId;
  final String? planName;
  final int? allocatedUserId;
  final String? allocatedUserName;
  final String? allocatedUserEmail;
  final DateTime? allocatedAt;
  final DateTime? soldAt;
  final DateTime? deliveredAt;
  final DateTime? revealedAt;

  factory WifiOwnerCode.fromJson(Map<String, dynamic> json) {
    int? parseInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '');
    }

    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      final String text = value.toString();
      if (text.isEmpty) return null;
      return DateTime.tryParse(text);
    }

    return WifiOwnerCode(
      id: parseInt(json['id']) ?? 0,
      status: json['status']?.toString(),
      codeSuffix: json['code_suffix']?.toString(),
      codeLast4: json['code_last4']?.toString(),
      planId: parseInt(json['plan_id']),
      planName: json['plan_name']?.toString(),
      allocatedUserId: parseInt(json['allocated_to_user_id']),
      allocatedUserName: json['allocated_user_name']?.toString(),
      allocatedUserEmail: json['allocated_user_email']?.toString(),
      allocatedAt: parseDate(json['allocated_at']),
      soldAt: parseDate(json['sold_at']),
      deliveredAt: parseDate(json['delivered_at']),
      revealedAt: parseDate(json['revealed_at']),
    );
  }
}
