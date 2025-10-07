import 'dart:convert';

class SubscriptionPackageLimit {
  const SubscriptionPackageLimit({
    this.allowed,
    this.remaining,
    this.total,
    this.expiresAt,
  });

  factory SubscriptionPackageLimit.fromJson(String source) =>
      SubscriptionPackageLimit.fromMap(json.decode(source));

  factory SubscriptionPackageLimit.fromMap(Map<String, dynamic> map) {
    return SubscriptionPackageLimit(
      allowed: _parseAllowed(map['allowed'] ?? map['can_create']),
      remaining: _parseNullableInt(map['remaining'] ?? map['remaining_limit']),
      total: _parseNullableInt(map['total'] ?? map['total_limit']),
      expiresAt: _parseNullableDate(map['expires_at'] ?? map['expire_at']),
    );
  }

  final bool? allowed;
  final int? remaining;
  final int? total;
  final DateTime? expiresAt;

  bool get isUnlimited => remaining == null;

  SubscriptionPackageLimit copyWith({
    bool? allowed,
    int? remaining,
    int? total,
    DateTime? expiresAt,
  }) {
    return SubscriptionPackageLimit(
      allowed: allowed ?? this.allowed,
      remaining: remaining ?? this.remaining,
      total: total ?? this.total,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'allowed': allowed,
        'remaining': remaining,
        'total': total,
        'expires_at': expiresAt?.toIso8601String(),
      };

  String toJson() => json.encode(toMap());

  @override
  String toString() {
    return 'SubscriptionPackageLimit(allowed: $allowed, remaining: $remaining, total: $total, expiresAt: $expiresAt)';
  }

  static bool? _parseAllowed(dynamic value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized.isEmpty) return null;
      if (normalized == 'true' || normalized == 'allowed') {
        return true;
      }
      if (normalized == 'false' || normalized == 'denied') {
        return false;
      }
      final numeric = int.tryParse(normalized);
      if (numeric != null) {
        return numeric != 0;
      }
    }
    return null;
  }

  static int? _parseNullableInt(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      final normalized = value.trim();
      if (normalized.isEmpty) {
        return null;
      }
      if (normalized.toLowerCase() == 'unlimited') {
        return null;
      }
      return int.tryParse(normalized);
    }
    return null;
  }

  static DateTime? _parseNullableDate(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is DateTime) {
      return value;
    }
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value.trim());
    }
    return null;
  }
}
