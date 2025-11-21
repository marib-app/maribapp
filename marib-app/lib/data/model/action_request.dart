class ActionRequestModel {
  final String id;
  final String kind;
  final String? entity;
  final String? entityId;
  final double? amount;
  final String? currency;
  final String status;
  final DateTime? dueAt;
  final DateTime? expiresAt;
  final Map<String, dynamic>? meta;
  final DateTime? usedAt;

  const ActionRequestModel({
    required this.id,
    required this.kind,
    this.entity,
    this.entityId,
    this.amount,
    this.currency,
    required this.status,
    this.dueAt,
    this.expiresAt,
    this.meta,
    this.usedAt,
  });

  factory ActionRequestModel.fromJson(Map<String, dynamic> json) {
    return ActionRequestModel(
      id: json['id']?.toString() ?? '',
      kind: json['kind']?.toString() ?? 'action.request',
      entity: json['entity']?.toString(),
      entityId: json['entity_id']?.toString(),
      amount: json['amount'] is num
          ? (json['amount'] as num).toDouble()
          : double.tryParse(json['amount']?.toString() ?? ''),
      currency: json['currency']?.toString(),
      status: json['status']?.toString() ?? 'pending',
      dueAt: _parseDate(json['due_at']),
      expiresAt: _parseDate(json['expires_at']),
      meta: json['meta'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['meta'])
          : null,
      usedAt: _parseDate(json['used_at']),
    );
  }

  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);

  bool get isCompleted => status == 'completed';

  static DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    final String value = raw.toString();
    if (value.isEmpty) {
      return null;
    }
    try {
      return DateTime.parse(value).toLocal();
    } catch (_) {
      return null;
    }
  }
}
