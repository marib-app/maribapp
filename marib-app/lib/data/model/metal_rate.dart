class MetalRate {
  final int id;
  final String metalType;
  final double? karat;
  final String displayName;
  final double buyPrice;
  final double sellPrice;
  final String? source;
  final DateTime? quotedAt;
  final DateTime? updatedAt;
  final DateTime? createdAt;
  final bool isWatchlisted;
  final String? iconUrl;
  final String? iconAlt;

  static const Object _sentinel = Object();



  const MetalRate({
    required this.id,
    required this.metalType,
    required this.karat,
    required this.displayName,
    required this.buyPrice,
    required this.sellPrice,
    required this.source,
    required this.quotedAt,
    required this.updatedAt,
    required this.createdAt,
    this.isWatchlisted = false,
    this.iconUrl,
    this.iconAlt,
  });

  bool get isGold => metalType.toLowerCase() == 'gold';
  bool get isSilver => metalType.toLowerCase() == 'silver';

  String get karatLabel {
    if (karat == null) {
      return isSilver ? 'فضة' : displayName;
    }

    final value = karat! % 1 == 0 ? karat!.toInt().toString() : karat!.toStringAsFixed(2);
    return 'عيار $value';
  }

  MetalRate copyWith({
    int? id,
    String? metalType,
    double? karat,
    String? displayName,
    double? buyPrice,
    double? sellPrice,
    String? source,
    DateTime? quotedAt,
    DateTime? updatedAt,
    DateTime? createdAt,
    bool? isWatchlisted,
    Object? iconUrl = _sentinel,
    Object? iconAlt = _sentinel,
  }) {
    return MetalRate(
      id: id ?? this.id,
      metalType: metalType ?? this.metalType,
      karat: karat ?? this.karat,
      displayName: displayName ?? this.displayName,
      buyPrice: buyPrice ?? this.buyPrice,
      sellPrice: sellPrice ?? this.sellPrice,
      source: source ?? this.source,
      quotedAt: quotedAt ?? this.quotedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdAt: createdAt ?? this.createdAt,
      isWatchlisted: isWatchlisted ?? this.isWatchlisted,
      iconUrl: identical(iconUrl, _sentinel)
          ? this.iconUrl
          : iconUrl as String?,
      iconAlt: identical(iconAlt, _sentinel)
          ? this.iconAlt
          : iconAlt as String?,
    );
  }

  factory MetalRate.fromJson(Map<String, dynamic> json) {
    DateTime? _parseDate(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value);
      }
      return null;
    }

    double? _parseDouble(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      if (value is String && value.isNotEmpty) {
        return double.tryParse(value);
      }
      return null;
    }

    String? _parseString(dynamic value) {
      if (value == null) return null;
      if (value is String) {
        final String trimmed = value.trim();
        return trimmed.isEmpty ? null : trimmed;
      }
      return value.toString();
    }

    final String? parsedIconUrl = _parseString(
      json['icon_url'] ?? json['iconUrl'],
    );


    return MetalRate(
      id: (json['id'] as num?)?.toInt() ?? 0,
      metalType: (json['metal_type'] ?? json['metalType'] ?? '').toString(),
      karat: _parseDouble(json['karat']),
      displayName: (json['display_name'] ?? json['displayName'] ?? '').toString(),
      buyPrice: _parseDouble(json['buy_price']) ?? 0,
      sellPrice: _parseDouble(json['sell_price']) ?? 0,
      source: json['source']?.toString(),
      quotedAt: _parseDate(json['quoted_at'] ?? json['quotedAt']),
      updatedAt: _parseDate(json['updated_at'] ?? json['updatedAt']),
      createdAt: _parseDate(json['created_at'] ?? json['createdAt']),
      isWatchlisted: json['is_watchlisted'] == true,
      iconUrl: parsedIconUrl,
      iconAlt: _parseString(json['icon_alt'] ?? json['iconAlt']),
    );
  }
}