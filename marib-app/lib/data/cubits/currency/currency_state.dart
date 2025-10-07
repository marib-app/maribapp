part of 'currency_cubit.dart';

abstract class CurrencyState {}

class CurrencyInitial extends CurrencyState {}

class CurrencyLoading extends CurrencyState {}

class CurrencySuccess extends CurrencyState {
  final List<CurrencyRate> currencyRates;

  CurrencySuccess(this.currencyRates);
}

class CurrencyError extends CurrencyState {
  final String message;

  CurrencyError(this.message);
}
