import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marib/data/model/currency_rate.dart';
import 'package:marib/data/repositories/currency_repository.dart';

part 'currency_state.dart';

class CurrencyCubit extends Cubit<CurrencyState> {
  final CurrencyRepository _currencyRepository;

  CurrencyCubit(this._currencyRepository) : super(CurrencyInitial());

  Future<void> getCurrencyRates() async {
    emit(CurrencyLoading());
    try {
      final currencyRates = await _currencyRepository.getCurrencyRates();
      if (currencyRates.isEmpty) {
        emit(CurrencyError("لا توجد بيانات متاحة"));
      } else {
        emit(CurrencySuccess(currencyRates));
      }
    } catch (e) {
      emit(CurrencyError(e.toString()));
    }
  }

  // Calculate conversion based on amount and selected currencies
  double calculateConversion({
    required double amount,
    required String fromCurrency,
    required String toCurrency,
    required bool isBuying,
  }) {
    if (state is CurrencySuccess) {
      final currencyRates = (state as CurrencySuccess).currencyRates;
      
      // Find the currency rates for the selected currencies
      final fromRate = currencyRates.firstWhere(
        (rate) => rate.currencyName == fromCurrency,
        orElse: () => CurrencyRate(currencyName: fromCurrency, sellPrice: 1, buyPrice: 1),
      );
      
      final toRate = currencyRates.firstWhere(
        (rate) => rate.currencyName == toCurrency,
        orElse: () => CurrencyRate(currencyName: toCurrency, sellPrice: 1, buyPrice: 1),
      );

      // Use sell price when buying, buy price when selling
      final fromValue = isBuying ? fromRate.sellPrice : fromRate.buyPrice;
      final toValue = isBuying ? toRate.buyPrice : toRate.sellPrice;

      // Calculate the conversion
      return amount * (fromValue / toValue);
    }
    
    return 0.0;
  }
}
