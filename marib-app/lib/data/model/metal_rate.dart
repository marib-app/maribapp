class MetalRate {
  final int id;
  final String metalType;
  final double? karat;
  final String displayName;
  final double? buyPrice;
  final double? sellPrice;
  final String? source;
  final DateTime? quotedAt;
  final DateTime? updatedAt;
  final DateTime? createdAt;
  final bool isWatchlisted;
  final String? iconUrl;
  final String? iconAlt;
  final String? quoteGovernorateCode;
  final String? quoteGovernorateName;
  final bool quoteIsDefault;
  final bool quoteUsedFallback;
  final List<MetalRateQuote> quotes;
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
    this.quoteGovernorateCode,
    this.quoteGovernorateName,
    this.quoteIsDefault = false,
    this.quoteUsedFallback = false,
    this.quotes = const <MetalRateQuote>[],
  });

  bool get isGold => metalType.toLowerCase() == 'gold';

  bool get isSilver => metalType.toLowerCase() == 'silver';

  String get karatLabel {
    if (karat == null) {
      return isSilver ? 'فضة' : displayName;
    }

    final value =
        karat! % 1 == 0 ? karat!.toInt().toString() : karat!.toStringAsFixed(2);
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
    String? quoteGovernorateCode,
    String? quoteGovernorateName,
    bool? quoteIsDefault,
    bool? quoteUsedFallback,
    List<MetalRateQuote>? quotes,
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
      iconUrl:
          identical(iconUrl, _sentinel) ? this.iconUrl : iconUrl as String?,
      iconAlt:
          identical(iconAlt, _sentinel) ? this.iconAlt : iconAlt as String?,
      quoteGovernorateCode: quoteGovernorateCode ?? this.quoteGovernorateCode,
      quoteGovernorateName: quoteGovernorateName ?? this.quoteGovernorateName,
      quoteIsDefault: quoteIsDefault ?? this.quoteIsDefault,
      quoteUsedFallback: quoteUsedFallback ?? this.quoteUsedFallback,
      quotes: quotes ?? this.quotes,
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

    final List<MetalRateQuote> parsedQuotes;
    if (json['quotes'] is List) {
      parsedQuotes = (json['quotes'] as List)
          .whereType<Map>()
          .map((dynamic entry) => MetalRateQuote.fromJson(
                Map<String, dynamic>.from(entry as Map<dynamic, dynamic>),
              ))
          .toList(growable: false);
    } else {
      parsedQuotes = const <MetalRateQuote>[];
    }

    return MetalRate(
      id: (json['id'] as num?)?.toInt() ?? 0,
      metalType: (json['metal_type'] ?? json['metalType'] ?? '').toString(),
      karat: _parseDouble(json['karat']),
      displayName:
          (json['display_name'] ?? json['displayName'] ?? '').toString(),
      buyPrice: _parseDouble(json['buy_price']),
      sellPrice: _parseDouble(json['sell_price']),
      source: json['source']?.toString(),
      quotedAt: _parseDate(json['quoted_at'] ?? json['quotedAt']),
      updatedAt: _parseDate(json['updated_at'] ?? json['updatedAt']),
      createdAt: _parseDate(json['created_at'] ?? json['createdAt']),
      isWatchlisted: json['is_watchlisted'] == true,
      iconUrl: parsedIconUrl,
      iconAlt: _parseString(json['icon_alt'] ?? json['iconAlt']),
      quoteGovernorateCode: _parseString(
          json['quote_governorate_code'] ?? json['quoteGovernorateCode']),
      quoteGovernorateName: _parseString(
          json['quote_governorate_name'] ?? json['quoteGovernorateName']),
      quoteIsDefault: json['quote_is_default'] == true,
      quoteUsedFallback: json['quote_used_fallback'] == true,
      quotes: parsedQuotes,
    );
  }
}

class MetalRateQuote {
  final int governorateId;
  final String? governorateCode;
  final String? governorateName;
  final double? sellPrice;
  final double? buyPrice;
  final String? source;
  final DateTime? quotedAt;
  final bool isDefault;

  const MetalRateQuote({
    required this.governorateId,
    this.governorateCode,
    this.governorateName,
    this.sellPrice,
    this.buyPrice,
    this.source,
    this.quotedAt,
    this.isDefault = false,
  });

  factory MetalRateQuote.fromJson(Map<String, dynamic> json) {
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

    final Map<String, dynamic>? governorateJson = json['governorate'] is Map
        ? Map<String, dynamic>.from(json['governorate'] as Map)
        : null;

    return MetalRateQuote(
      governorateId: (json['governorate_id'] as num?)?.toInt() ?? 0,
      governorateCode: _parseString(governorateJson?['code']),
      governorateName: _parseString(governorateJson?['name']),
      sellPrice: _parseDouble(json['sell_price']),
      buyPrice: _parseDouble(json['buy_price']),
      source: _parseString(json['source']),
      quotedAt: _parseDate(json['quoted_at']),
      isDefault: json['is_default'] == true,
    );
  }
}
