class SubscriptionStatus {
  const SubscriptionStatus({
    required this.hasActive,
    this.availableBalance,
    this.featuredCount,
    this.isFeatured,
    this.canPause,
    this.allowed,
    this.total,
    this.remaining,
    this.expiresAt,
  });

  final bool hasActive;
  final double? availableBalance;
  final int? featuredCount;
  final bool? isFeatured;
  final bool? canPause;
  final bool? allowed;
  final int? total;
  final int? remaining;
  final DateTime? expiresAt;
  factory SubscriptionStatus.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> data = Map<String, dynamic>.from(json);

    dynamic read(Iterable<String> keys) {
      for (final String key in keys) {
        if (data.containsKey(key) && data[key] != null) {
          return data[key];
        }
      }
      return null;
    }

    bool? parseBool(dynamic value) {
      if (value == null) return null;
      if (value is bool) return value;
      if (value is num) return value != 0;
      if (value is String) {
        final String normalized = value.trim().toLowerCase();
        if (normalized.isEmpty) return null;
        if (normalized == 'true') return true;
        if (normalized == 'false') return false;
        if (normalized == 'yes') return true;
        if (normalized == 'no') return false;
        final num? asNum = num.tryParse(normalized);
        if (asNum != null) {
          return asNum != 0;
        }
      }
      return null;
    }

    double? parseDouble(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      if (value is String) {
        return double.tryParse(value.trim());
      }
      return null;
    }

    int? parseInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) {
        return int.tryParse(value.trim());
      }
      return null;
    }

    DateTime? parseDateTime(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      if (value is int) {
        try {
          return DateTime.fromMillisecondsSinceEpoch(value *
              (value.toString().length == 10 ? 1000 : 1));
        } catch (_) {
          return null;
        }
      }
      if (value is num) {
        try {
          return DateTime.fromMillisecondsSinceEpoch(value.toInt());
        } catch (_) {
          return null;
        }
      }
      if (value is String) {
        final String trimmed = value.trim();
        if (trimmed.isEmpty) return null;
        final DateTime? parsed = DateTime.tryParse(trimmed);
        if (parsed != null) {
          return parsed;
        }
      }
      return null;
    }

    final bool? allowed = parseBool(read(
      const ['allowed', 'allow', 'isAllowed'],
    ));

    final bool hasActive = parseBool(read(
      const ['hasActive', 'has_active', 'active', 'allowed', 'allow'],
    )) ??
        false;

    final double? availableBalance = parseDouble(read(
      const ['availableBalance', 'available_balance', 'balance'],
    ));

    final int? parsedRemaining = parseInt(read(
      const ['remaining', 'remaining_count', 'left'],
    ));

    final int? parsedFeaturedCount = parseInt(read(
      const [
        'featuredCount',
        'featured_count',
        'count',
        'remaining',
        'remaining_count',
      ],
    )) ??
        parsedRemaining;

    final int? parsedTotal = parseInt(read(
      const ['total', 'total_allowed', 'limit_total', 'allowed_total'],
    ));

    final DateTime? parsedExpiresAt = parseDateTime(read(
      const ['expiresAt', 'expires_at', 'expiry', 'expiry_date', 'expires_on'],
    ));




    return SubscriptionStatus(
      hasActive: hasActive,

      availableBalance: availableBalance,
      featuredCount: parsedFeaturedCount,


      isFeatured: parseBool(read(
        const ['isFeatured', 'is_featured'],
      )),
      canPause: parseBool(read(
        const ['canPause', 'can_pause'],
      )),

      allowed: allowed ?? (hasActive ? true : null),
      total: parsedTotal,
      remaining: parsedRemaining ?? parsedFeaturedCount,
      expiresAt: parsedExpiresAt,

    );
  }

  SubscriptionStatus copyWith({
    bool? hasActive,
    double? availableBalance,
    int? featuredCount,
    bool? isFeatured,
    bool? canPause,
    bool? allowed,
    int? total,
    int? remaining,
    DateTime? expiresAt,
  }) {
    return SubscriptionStatus(
      hasActive: hasActive ?? this.hasActive,
      availableBalance: availableBalance ?? this.availableBalance,
      featuredCount: featuredCount ?? this.featuredCount,
      isFeatured: isFeatured ?? this.isFeatured,
      canPause: canPause ?? this.canPause,
      allowed: allowed ?? this.allowed,
      total: total ?? this.total,
      remaining: remaining ?? this.remaining,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'hasActive': hasActive,
      'availableBalance': availableBalance,
      'featuredCount': featuredCount,
      'isFeatured': isFeatured,
      'canPause': canPause,
      'allowed': allowed,
      'total': total,
      'remaining': remaining,
      'expiresAt': expiresAt?.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'SubscriptionStatus(hasActive: '
        '$hasActive, availableBalance: $availableBalance, featuredCount: '
        '$featuredCount, isFeatured: $isFeatured, canPause: $canPause, '
        'allowed: $allowed, total: $total, remaining: $remaining, '
        'expiresAt: $expiresAt)';

  }
}