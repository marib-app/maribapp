import 'dart:math';

class CurrencyHistoryBundle {
  CurrencyHistoryBundle({
    required this.currencyId,
    required this.currencyName,
    required this.ranges,
    this.lastHourlyAt,
    this.lastCapturedAt,
    this.sourceQuality,
    this.source,
  });

  final int currencyId;
  final String currencyName;
  final Map<int, CurrencyHistoryRange> ranges;
  final DateTime? lastHourlyAt;
  final DateTime? lastCapturedAt;
  final String? sourceQuality;
  final String? source;

  CurrencyHistoryRange? range(int days) => ranges[days];

  factory CurrencyHistoryBundle.fromJson(Map<String, dynamic> json) {
    final Map<int, CurrencyHistoryRange> parsedRanges = <int, CurrencyHistoryRange>{};
    final dynamic rawRanges = json['ranges'];

    if (rawRanges is Map) {
      rawRanges.forEach((dynamic key, dynamic value) {
        final int? days = int.tryParse(key.toString());
        if (days == null || value is! Map<String, dynamic>) {
          return;
        }
        parsedRanges[days] = CurrencyHistoryRange.fromJson(value);
      });
    }

    return CurrencyHistoryBundle(
      currencyId: (json['currency_id'] as num?)?.toInt() ?? 0,
      currencyName: json['currency_name']?.toString() ?? '',
      ranges: parsedRanges,
      lastHourlyAt: _parseDate(json['last_hourly_at']),
      lastCapturedAt: _parseDate(json['last_captured_at']),
      sourceQuality: json['source_quality']?.toString(),
      source: json['source']?.toString(),
    );
  }
}

class CurrencyHistoryRange {
  CurrencyHistoryRange({
    required this.interval,
    required this.rangeDays,
    required this.points,
    required this.summary,
  });

  final String interval;
  final int rangeDays;
  final List<CurrencyHistoryPoint> points;
  final CurrencyHistorySummary summary;

  bool get hasTrend => points.length >= 2;

  factory CurrencyHistoryRange.fromJson(Map<String, dynamic> json) {
    final List<CurrencyHistoryPoint> parsedPoints = <CurrencyHistoryPoint>[];
    final dynamic rawPoints = json['points'];
    if (rawPoints is List) {
      for (final dynamic entry in rawPoints) {
        if (entry is Map<String, dynamic>) {
          parsedPoints.add(CurrencyHistoryPoint.fromJson(entry));
        }
      }
    }

    return CurrencyHistoryRange(
      interval: json['interval']?.toString() ?? 'daily',
      rangeDays: (json['range_days'] as num?)?.toInt() ?? parsedPoints.length,
      points: parsedPoints,
      summary: CurrencyHistorySummary.fromJson(
        (json['summary'] as Map<String, dynamic>?) ?? <String, dynamic>{},
      ),
    );
  }

  double? get minSell => points.isEmpty
      ? null
      : points.map((CurrencyHistoryPoint point) => point.sellPrice).reduce(min);

  double? get maxSell => points.isEmpty
      ? null
      : points.map((CurrencyHistoryPoint point) => point.sellPrice).reduce(max);
}

class CurrencyHistoryPoint {
  CurrencyHistoryPoint({
    required this.timestamp,
    required this.sellPrice,
    required this.buyPrice,
  });

  final DateTime timestamp;
  final double sellPrice;
  final double buyPrice;

  factory CurrencyHistoryPoint.fromJson(Map<String, dynamic> json) {
    return CurrencyHistoryPoint(
      timestamp: _parseDate(json['timestamp']) ?? DateTime.now(),
      sellPrice: _parseDouble(json['sell_price']) ?? 0,
      buyPrice: _parseDouble(json['buy_price']) ?? 0,
    );
  }
}

class CurrencyHistorySummary {
  CurrencyHistorySummary({
    this.latestSell,
    this.latestBuy,
    this.changeSell,
    this.changeSellPercent,
    this.changeBuy,
    this.changeBuyPercent,
    this.trend,
    this.highSell,
    this.lowSell,
    this.highBuy,
    this.lowBuy,
  });

  final double? latestSell;
  final double? latestBuy;
  final double? changeSell;
  final double? changeSellPercent;
  final double? changeBuy;
  final double? changeBuyPercent;
  final String? trend;
  final double? highSell;
  final double? lowSell;
  final double? highBuy;
  final double? lowBuy;

  bool get isPositiveTrend => (trend ?? '').toLowerCase() == 'up';
  bool get isNegativeTrend => (trend ?? '').toLowerCase() == 'down';

  factory CurrencyHistorySummary.fromJson(Map<String, dynamic> json) {
    return CurrencyHistorySummary(
      latestSell: _parseDouble(json['latest_sell']),
      latestBuy: _parseDouble(json['latest_buy']),
      changeSell: _parseDouble(json['change_sell']),
      changeSellPercent: _parseDouble(json['change_sell_percent']),
      changeBuy: _parseDouble(json['change_buy']),
      changeBuyPercent: _parseDouble(json['change_buy_percent']),
      trend: json['trend']?.toString(),
      highSell: _parseDouble(json['high_sell']),
      lowSell: _parseDouble(json['low_sell']),
      highBuy: _parseDouble(json['high_buy']),
      lowBuy: _parseDouble(json['low_buy']),
    );
  }
}

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
  if (value is String) {
    return double.tryParse(value);
  }
  return null;
}