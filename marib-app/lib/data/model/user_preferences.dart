class UserPreferences {
  const UserPreferences({
    this.favoriteGovernorateCode,
    Set<int>? currencyWatchlist,
    Set<int>? metalWatchlist,
    this.notificationFrequency = 'daily',
    Map<int, String>? currencyNotificationRegions,
  })  : currencyWatchlist = currencyWatchlist ?? const <int>{},
        metalWatchlist = metalWatchlist ?? const <int>{},
        currencyNotificationRegions =
            currencyNotificationRegions ?? const <int, String>{};

  final String? favoriteGovernorateCode;
  final Set<int> currencyWatchlist;
  final Set<int> metalWatchlist;
  final String notificationFrequency;
  final Map<int, String> currencyNotificationRegions;

  UserPreferences copyWith({
    String? favoriteGovernorateCode,
    Set<int>? currencyWatchlist,
    Set<int>? metalWatchlist,
    String? notificationFrequency,
    Map<int, String>? currencyNotificationRegions,
  }) {
    final Set<int> effectiveCurrency =
        (currencyWatchlist ?? this.currencyWatchlist).toSet();
    final Set<int> effectiveMetal =
        (metalWatchlist ?? this.metalWatchlist).toSet();
    final Map<int, String> effectiveRegions = Map<int, String>.from(
      currencyNotificationRegions ?? this.currencyNotificationRegions,
    );

    return UserPreferences(
      favoriteGovernorateCode:
          favoriteGovernorateCode ?? this.favoriteGovernorateCode,
      currencyWatchlist: effectiveCurrency,
      metalWatchlist: effectiveMetal,
      notificationFrequency:
          notificationFrequency ?? this.notificationFrequency,
      currencyNotificationRegions: effectiveRegions,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'favorite_governorate_code': favoriteGovernorateCode,
      'currency_watchlist': currencyWatchlist.toList(),
      'metal_watchlist': metalWatchlist.toList(),
      'notification_frequency': notificationFrequency,
      'currency_notification_regions': currencyNotificationRegions.map(
        (int key, String value) => MapEntry(key.toString(), value),
      ),
    };
  }

  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    Set<int> _parseSet(dynamic value) {
      if (value is List) {
        return value
            .map((dynamic entry) => int.tryParse(entry.toString()))
            .whereType<int>()
            .toSet();
      }
      return const <int>{};
    }

    Map<int, String> _parseRegions(dynamic value) {
      if (value is Map) {
        final Map<int, String> result = <int, String>{};
        value.forEach((dynamic key, dynamic raw) {
          final int? currencyId = int.tryParse(key.toString());
          final String code = raw?.toString().trim() ?? '';
          if (currencyId != null && currencyId > 0 && code.isNotEmpty) {
            result[currencyId] = code;
          }
        });
        return result;
      }
      return const <int, String>{};
    }

    return UserPreferences(
      favoriteGovernorateCode:
          (json['favorite_governorate_code'] ?? json['favoriteGovernorateCode'])
              ?.toString(),
      currencyWatchlist:
          _parseSet(json['currency_watchlist'] ?? json['currencyWatchlist']),
      metalWatchlist:
          _parseSet(json['metal_watchlist'] ?? json['metalWatchlist']),
      notificationFrequency: (json['notification_frequency'] ??
              json['notificationFrequency'] ??
              'daily')
          .toString(),
      currencyNotificationRegions: _parseRegions(
        json['currency_notification_regions'] ??
            json['currencyNotificationRegions'],
      ),
    );
  }
}
