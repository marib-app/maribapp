class CurrencyRatesState {
  CurrencyRatesState({
    required List<dynamic> rates,
    required List<dynamic> displayRates,
    required this.lastUpdatedAt,
    required Set<int> watchlist,
    required this.showWatchlistOnly,
    required Map<int, int> selectedHistoryRanges,
    required Map<int, String> currencyNotificationRegions,

    required this.defaultHistoryRangeDays,
  })  : rates = List<dynamic>.unmodifiable(rates),
        displayRates = List<dynamic>.unmodifiable(displayRates),
        watchlist = Set<int>.unmodifiable(watchlist),
        selectedHistoryRanges = Map<int, int>.unmodifiable(selectedHistoryRanges),
        currencyNotificationRegions =
        Map<int, String>.unmodifiable(currencyNotificationRegions);

  final List<dynamic> rates;
  final List<dynamic> displayRates;
  final DateTime? lastUpdatedAt;
  final Set<int> watchlist;
  final bool showWatchlistOnly;
  final Map<int, int> selectedHistoryRanges;
  final int defaultHistoryRangeDays;
  final Map<int, String> currencyNotificationRegions;

  static const Duration _currencyDataSla = Duration(hours: 12);

  bool get isDisplayRatesStale {
    final DateTime now = DateTime.now();

    if (_isTimestampBeyondSla(lastUpdatedAt, now)) {
      return true;
    }

    for (final dynamic rate in displayRates) {
      if (_isRateDataStale(rate, now)) {
        return true;
      }
    }

    return false;
  }

  bool _isRateDataStale(dynamic rate, DateTime now) {
    if (rate == null) return false;

    try {
      final dynamic directQuality = rate.sourceQuality;
      if (_normalizeQuality(directQuality) == 'stale') {
        return true;
      }
    } catch (_) {}

    try {
      final dynamic history = rate.history;
      if (_isHistoryDataStale(history, now)) {
        return true;
      }
    } catch (_) {}

    DateTime? lastUpdated;
    try {
      lastUpdated = _coerceDateTime(rate.lastUpdatedAt);
    } catch (_) {}

    if (_isTimestampBeyondSla(lastUpdated, now)) {
      return true;
    }

    return false;
  }

  bool _isHistoryDataStale(dynamic history, DateTime now) {
    if (history == null) return false;

    String? quality;
    DateTime? capturedAt;
    DateTime? hourlyAt;

    if (history is Map) {
      quality = _normalizeQuality(
        history['sourceQuality'] ?? history['source_quality'],
      );
      capturedAt = _coerceDateTime(
        history['lastCapturedAt'] ?? history['last_captured_at'],
      );
      hourlyAt = _coerceDateTime(
        history['lastHourlyAt'] ?? history['last_hourly_at'],
      );
    } else {
      try {
        quality = _normalizeQuality(history.sourceQuality);
      } catch (_) {}
      try {
        capturedAt = _coerceDateTime(history.lastCapturedAt);
      } catch (_) {}
      try {
        hourlyAt = _coerceDateTime(history.lastHourlyAt);
      } catch (_) {}
    }

    if (quality == 'stale') {
      return true;
    }

    if (_isTimestampBeyondSla(capturedAt, now)) {
      return true;
    }

    if (_isTimestampBeyondSla(hourlyAt, now)) {
      return true;
    }

    return false;
  }

  bool _isTimestampBeyondSla(DateTime? timestamp, DateTime now) {
    if (timestamp == null) return false;
    final Duration diff = now.difference(timestamp);
    if (diff.isNegative) {
      return false;
    }
    return diff > _currencyDataSla;
  }

  DateTime? _coerceDateTime(dynamic value) {
    if (value is DateTime) {
      return value;
    }
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  String? _normalizeQuality(dynamic value) {
    if (value is String) {
      final String trimmed = value.trim();
      if (trimmed.isNotEmpty) {
        return trimmed.toLowerCase();
      }
    }
    return null;
  }

  int historyRangeForCurrency(int? currencyId) {
    if (currencyId == null) {
      return defaultHistoryRangeDays;
    }
    return selectedHistoryRanges[currencyId] ?? defaultHistoryRangeDays;
  }

  String? notificationRegionForCurrency(int? currencyId) {
    if (currencyId == null) {
      return null;
    }
    return currencyNotificationRegions[currencyId];
  }
}