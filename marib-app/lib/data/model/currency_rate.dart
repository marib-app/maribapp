class CurrencyRate {
  final String currencyName;
  final double sellPrice;
  final double buyPrice;
  final DateTime? lastUpdatedAt;

  CurrencyRate({
    required this.currencyName,
    required this.sellPrice,
    required this.buyPrice,
    this.lastUpdatedAt,
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
    );
  }
}
