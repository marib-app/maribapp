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
  final List<MetalRate> metalRates;
  final DateTime? metalsLastUpdatedAt;


  CurrencySuccess({
    required this.currencyRates,
    required this.governorates,
    this.requestedGovernorate,
    this.appliedGovernorate,
    required this.metalRates,
    required this.metalsLastUpdatedAt,
    required this.usedFallback,
    this.requestedGovernorateCode,
  });
}

class CurrencyError extends CurrencyState {
  final String message;

  CurrencyError(this.message);
}
