class CurrencyRate {
  final String currencyName;
  final double sellPrice;
  final double buyPrice;
  final DateTime? lastUpdatedAt;
  final String? iconUrl;
  final String? iconAlt;
  final String? quoteGovernorateCode;
  final String? quoteGovernorateName;
  final String? quoteSource;
  final DateTime? quoteQuotedAt;
  final bool quoteIsDefault;
  final bool quoteUsedFallback;



  CurrencyRate({
    required this.currencyName,
    required this.sellPrice,
    required this.buyPrice,
    this.lastUpdatedAt,
    this.iconUrl,
    this.iconAlt,
    this.quoteGovernorateCode,
    this.quoteGovernorateName,
    this.quoteSource,
    this.quoteQuotedAt,
    this.quoteIsDefault = false,
    this.quoteUsedFallback = false,








  });

  factory CurrencyRate.fromJson(Map<String, dynamic> json) {
    // Safe parsing for numeric values that might be returned as strings
    double parseSafeDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      if (value is String) {
        return double.tryParse(value) ?? 0.0;
      }
      return 0.0;
    }

    return CurrencyRate(
      currencyName: json['currency_name'] as String,
      sellPrice: parseSafeDouble(json['sell_price']),
      buyPrice: parseSafeDouble(json['buy_price']),
      lastUpdatedAt: json['last_updated_at'] != null
          ? DateTime.tryParse(json['last_updated_at'].toString())
          : null,
      iconUrl: json['icon_url'] as String?,
      iconAlt: json['icon_alt'] as String?,
      quoteGovernorateCode: json['quote_governorate_code'] as String?,
      quoteGovernorateName: json['quote_governorate_name'] as String?,
      quoteSource: json['quote_source'] as String?,
      quoteQuotedAt: json['quote_quoted_at'] != null
          ? DateTime.tryParse(json['quote_quoted_at'].toString())
          : null,
      quoteIsDefault: json['quote_is_default'] == true,
      quoteUsedFallback: json['quote_used_fallback'] == true,


    );
  }
}
