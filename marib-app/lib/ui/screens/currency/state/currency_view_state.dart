import 'package:marib/data/model/metal_rate.dart';
import 'package:marib/data/model/preference_option.dart';

import 'currency_page_status.dart';
import 'currency_rates_state.dart';
import 'metal_rates_state.dart';

class CurrencyViewState {
  CurrencyViewState({
    required this.status,
    this.errorMessage,
    required this.currency,
    required this.gold,
    required this.silver,
    required this.metalsLastUpdatedAt,
    required List<Map<String, String?>> governorates,
    required this.selectedGovernorateCode,
    required this.appliedGovernorateCode,
    required this.appliedGovernorateName,
    required this.requestedGovernorateCode,
    required this.requestedGovernorateName,
    required this.usedFallback,
    required this.amountText,
    required this.fromCurrency,
    required this.toCurrency,
    required this.convertedAmount,
    required this.hasCalculated,
    required this.notificationFrequency,
    required List<PreferenceOption> notificationOptions,
  })  : governorates = _wrapGovernorates(governorates),
        notificationOptions =
        List<PreferenceOption>.unmodifiable(notificationOptions);

  final CurrencyPageStatus status;
  final String? errorMessage;
  final CurrencyRatesState currency;
  final GoldRatesState gold;
  final SilverRatesState silver;
  final DateTime? metalsLastUpdatedAt;
  final List<Map<String, String?>> governorates;
  final String? selectedGovernorateCode;
  final String? appliedGovernorateCode;
  final String? appliedGovernorateName;
  final String? requestedGovernorateCode;
  final String? requestedGovernorateName;
  final bool usedFallback;

  final String amountText;
  final String fromCurrency;
  final String toCurrency;
  final double convertedAmount;
  final bool hasCalculated;

  final String notificationFrequency;
  final List<PreferenceOption> notificationOptions;

  List<dynamic> get rates => currency.rates;
  List<dynamic> get displayRates => currency.displayRates;
  DateTime? get lastUpdatedAt => currency.lastUpdatedAt;
  Set<int> get currencyWatchlist => currency.watchlist;
  bool get showWatchlistOnly => currency.showWatchlistOnly;
  Map<int, int> get selectedHistoryRanges => currency.selectedHistoryRanges;
  int get defaultHistoryRangeDays => currency.defaultHistoryRangeDays;
  bool get isDisplayRatesStale => currency.isDisplayRatesStale;

  List<MetalRate> get goldRates => gold.rates;
  List<MetalRate> get displayGoldRates => gold.displayRates;
  List<MetalRate> get silverRates => silver.rates;
  List<MetalRate> get displaySilverRates => silver.displayRates;
  Set<int> get metalWatchlist => gold.watchlist;

  int historyRangeForCurrency(int? currencyId) =>
      currency.historyRangeForCurrency(currencyId);

  CurrencyViewState copyWith({
    CurrencyPageStatus? status,
    String? errorMessage,
    CurrencyRatesState? currency,
    GoldRatesState? gold,
    SilverRatesState? silver,
    DateTime? metalsLastUpdatedAt,
    List<Map<String, String?>>? governorates,
    String? selectedGovernorateCode,
    String? appliedGovernorateCode,
    String? appliedGovernorateName,
    String? requestedGovernorateCode,
    String? requestedGovernorateName,
    bool? usedFallback,
    String? amountText,
    String? fromCurrency,
    String? toCurrency,
    double? convertedAmount,
    bool? hasCalculated,
    String? notificationFrequency,
    List<PreferenceOption>? notificationOptions,
  }) {
    return CurrencyViewState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      currency: currency ?? this.currency,
      gold: gold ?? this.gold,
      silver: silver ?? this.silver,
      metalsLastUpdatedAt: metalsLastUpdatedAt ?? this.metalsLastUpdatedAt,
      governorates: governorates ?? this.governorates,
      selectedGovernorateCode:
      selectedGovernorateCode ?? this.selectedGovernorateCode,
      appliedGovernorateCode:
      appliedGovernorateCode ?? this.appliedGovernorateCode,
      appliedGovernorateName:
      appliedGovernorateName ?? this.appliedGovernorateName,
      requestedGovernorateCode:
      requestedGovernorateCode ?? this.requestedGovernorateCode,
      requestedGovernorateName:
      requestedGovernorateName ?? this.requestedGovernorateName,
      usedFallback: usedFallback ?? this.usedFallback,
      amountText: amountText ?? this.amountText,
      fromCurrency: fromCurrency ?? this.fromCurrency,
      toCurrency: toCurrency ?? this.toCurrency,
      convertedAmount: convertedAmount ?? this.convertedAmount,
      hasCalculated: hasCalculated ?? this.hasCalculated,
      notificationFrequency:
      notificationFrequency ?? this.notificationFrequency,
      notificationOptions:
      notificationOptions ?? this.notificationOptions,
    );
  }

  static List<Map<String, String?>> _wrapGovernorates(
      List<Map<String, String?>> source,
      ) {
    return List<Map<String, String?>>.unmodifiable(
      source.map(
            (entry) => Map<String, String?>.unmodifiable(entry),
      ),
    );
  }
}