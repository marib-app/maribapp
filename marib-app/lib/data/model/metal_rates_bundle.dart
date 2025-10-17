import 'package:marib/data/model/metal_rate.dart';

class MetalRatesBundle {
  final List<MetalRate> rates;
  final DateTime? lastUpdatedAt;

  const MetalRatesBundle({
    required this.rates,
    required this.lastUpdatedAt,
  });

  factory MetalRatesBundle.fromApi(Map<String, dynamic> payload) {
    final List<dynamic>? data = payload['data'] as List<dynamic>?;
    final List<MetalRate> rates = data != null
        ? data
        .map((entry) => MetalRate.fromJson(entry as Map<String, dynamic>))
        .toList(growable: false)
        : const [];

    DateTime? lastUpdated;
    final dynamic meta = payload['meta'];
    if (meta is Map<String, dynamic>) {
      final dynamic raw = meta['last_updated_at'] ?? meta['lastUpdatedAt'];
      if (raw is String && raw.isNotEmpty) {
        lastUpdated = DateTime.tryParse(raw);
      }
    }

    if (lastUpdated == null && rates.isNotEmpty) {
      lastUpdated = rates
          .map((rate) => rate.updatedAt ?? rate.quotedAt)
          .whereType<DateTime>()
          .fold<DateTime?>(null, (current, next) {
        if (current == null) return next;
        return current.isAfter(next) ? current : next;
      });
    }

    return MetalRatesBundle(rates: rates, lastUpdatedAt: lastUpdated);
  }
}