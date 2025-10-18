enum AssetFilterType {
  all,
  currencies,
  metals,
}

enum RateChangeFilter {
  all,
  rising,
  falling,
}

extension AssetFilterTypeStorage on AssetFilterType {
  String get storageValue => name;

  static AssetFilterType fromStorage(String? raw) {
    if (raw == null || raw.isEmpty) {
      return AssetFilterType.all;
    }
    return AssetFilterType.values.firstWhere(
          (value) => value.name == raw,
      orElse: () => AssetFilterType.all,
    );
  }
}

extension RateChangeFilterStorage on RateChangeFilter {
  String get storageValue => name;

  static RateChangeFilter fromStorage(String? raw) {
    if (raw == null || raw.isEmpty) {
      return RateChangeFilter.all;
    }
    return RateChangeFilter.values.firstWhere(
          (value) => value.name == raw,
      orElse: () => RateChangeFilter.all,
    );
  }
}