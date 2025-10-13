class UserPreferences {
  const UserPreferences({
    this.favoriteGovernorateCode,
    Set<int>? currencyWatchlist,
    Set<int>? metalWatchlist,
    this.notificationFrequency = 'daily',
  })  : currencyWatchlist = currencyWatchlist ?? const <int>{},
        metalWatchlist = metalWatchlist ?? const <int>{};

  final String? favoriteGovernorateCode;
  final Set<int> currencyWatchlist;
  final Set<int> metalWatchlist;
  final String notificationFrequency;

  UserPreferences copyWith({
    String? favoriteGovernorateCode,
    Set<int>? currencyWatchlist,
    Set<int>? metalWatchlist,
    String? notificationFrequency,
  }) {
    final Set<int> effectiveCurrency =
    (currencyWatchlist ?? this.currencyWatchlist).toSet();
    final Set<int> effectiveMetal =
    (metalWatchlist ?? this.metalWatchlist).toSet();

    return UserPreferences(
      favoriteGovernorateCode:
      favoriteGovernorateCode ?? this.favoriteGovernorateCode,
      currencyWatchlist: effectiveCurrency,
      metalWatchlist: effectiveMetal,
      notificationFrequency:
      notificationFrequency ?? this.notificationFrequency,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'favorite_governorate_code': favoriteGovernorateCode,
      'currency_watchlist': currencyWatchlist.toList(),
      'metal_watchlist': metalWatchlist.toList(),
      'notification_frequency': notificationFrequency,
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
    );
  }
}