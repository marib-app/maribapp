part of 'currency_cubit.dart';

abstract class CurrencyState {}

class CurrencyInitial extends CurrencyState {}

class CurrencyLoading extends CurrencyState {}

class CurrencySuccess extends CurrencyState {
  final List<CurrencyRate> currencyRates;
  final List<Governorate> governorates;
  final Governorate? requestedGovernorate;
  final Governorate? appliedGovernorate;
  final bool usedFallback;
  final String? requestedGovernorateCode;
  final UserPreferences preferences;
  final List<PreferenceOption> notificationOptions;
  final bool showWatchlistOnly;
  final AssetFilterType assetFilter;
  final RateChangeFilter changeFilter;
  final List<CurrencyRate> visibleCurrencyRates;
  final List<MetalRate> metalRates;
  final List<MetalRate> visibleMetalRates;
  final DateTime? metalsLastUpdatedAt;

  CurrencySuccess({
    required this.currencyRates,
    required this.governorates,
    this.requestedGovernorate,
    required this.visibleCurrencyRates,
    required this.metalRates,
    required this.visibleMetalRates,
    required this.metalsLastUpdatedAt,
    this.appliedGovernorate,
    required this.preferences,
    required this.notificationOptions,
    required this.showWatchlistOnly,
    required this.assetFilter,
    required this.changeFilter,
    required this.usedFallback,
    this.requestedGovernorateCode,
  });
}

class CurrencyError extends CurrencyState {
  final String message;

  CurrencyError(this.message);
}
