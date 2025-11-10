class MerchantStoreSnapshot {
  MerchantStoreSnapshot({
    required this.id,
    required this.name,
    required this.status,
    required this.slug,
    required this.logoUrl,
    required this.statusChangedAt,
    required this.rejectionReason,
    required this.raw,
  });

  factory MerchantStoreSnapshot.fromDynamic(dynamic source) {
    if (source is MerchantStoreSnapshot) {
      return source;
    }
    if (source is Map<String, dynamic>) {
      return MerchantStoreSnapshot.fromMap(source);
    }
    if (source is Map) {
      return MerchantStoreSnapshot.fromMap(
        source.map(
          (dynamic key, dynamic value) => MapEntry(
            key.toString(),
            value,
          ),
        ),
      );
    }
    return MerchantStoreSnapshot(
      id: null,
      name: null,
      status: null,
      slug: null,
      logoUrl: null,
      statusChangedAt: null,
      rejectionReason: null,
      raw: const <String, dynamic>{},
    );
  }

  factory MerchantStoreSnapshot.fromMap(Map<String, dynamic> map) {
    return MerchantStoreSnapshot(
      id: _asInt(map['id']),
      name: map['name']?.toString(),
      status: map['status']?.toString(),
      slug: map['slug']?.toString(),
      logoUrl: map['logo_url']?.toString(),
      statusChangedAt: map['status_changed_at']?.toString(),
      rejectionReason: map['rejection_reason']?.toString(),
      raw: Map<String, dynamic>.from(map),
    );
  }

  final int? id;
  final String? name;
  final String? status;
  final String? slug;
  final String? logoUrl;
  final String? statusChangedAt;
  final String? rejectionReason;
  final Map<String, dynamic> raw;

  String get normalizedStatus => (status ?? '').trim().toLowerCase();
  bool get isApproved => normalizedStatus == 'approved';
  bool get isPendingReview =>
      normalizedStatus == 'pending' || normalizedStatus == 'draft';
  bool get isRejected => normalizedStatus == 'rejected';
  bool get isSuspended => normalizedStatus == 'suspended';

  Map<String, dynamic> toMap() => Map<String, dynamic>.from(raw);

  static int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
