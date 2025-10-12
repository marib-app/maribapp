import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marib/data/model/currency_rate.dart';
import 'package:marib/data/repositories/currency_repository.dart';
import 'package:marib/data/model/currency_rates_bundle.dart';
import 'package:marib/data/model/governorate.dart';
import 'package:marib/data/repositories/preferences/governorate_preference_repository.dart';

part 'currency_state.dart';

class CurrencyCubit extends Cubit<CurrencyState> {
  final CurrencyRepository _currencyRepository;
  final GovernoratePreferenceRepository _preferenceRepository;
  String? _cachedGovernorateCode;
  CurrencyCubit(
      this._currencyRepository,
      this._preferenceRepository,
      ) : super(CurrencyInitial());

  Future<void> initialize() async {
    final saved = await _preferenceRepository.loadPreferredGovernorate();
    _cachedGovernorateCode = saved;
    await getCurrencyRates(governorateCode: saved);
  }

  Future<void> getCurrencyRates({String? governorateCode, bool persistSelection = false}) async {
    final requestedCode = governorateCode ?? _cachedGovernorateCode;


    emit(CurrencyLoading());
    try {
      final CurrencyRatesBundle bundle = await _currencyRepository.getCurrencyRates(
        governorateCode: requestedCode,
      );

      if (bundle.rates.isEmpty) {
        if (persistSelection) {
          await _preferenceRepository.clearPreferredGovernorate();
        }
        emit(CurrencyError("لا توجد بيانات متاحة"));
        return;
      }

      final resolvedCode = requestedCode ??
          bundle.requestedGovernorateCode ??
          bundle.appliedGovernorate?.code ??
          bundle.requestedGovernorate?.code;

      if (persistSelection) {
        if (resolvedCode != null && resolvedCode.isNotEmpty) {
          await _preferenceRepository.savePreferredGovernorate(resolvedCode);
        } else {
          await _preferenceRepository.clearPreferredGovernorate();
        }
      }

      _cachedGovernorateCode = resolvedCode;

      emit(CurrencySuccess(
        currencyRates: bundle.rates,
        governorates: bundle.governorates,
        requestedGovernorate: bundle.requestedGovernorate,
        appliedGovernorate: bundle.appliedGovernorate,
        usedFallback: bundle.usedFallback,
        requestedGovernorateCode: bundle.requestedGovernorateCode ?? requestedCode,
      ));
    } catch (e) {
      emit(CurrencyError(e.toString()));
    }
  }

  Future<void> changeGovernorate(String? governorateCode) async {
    final trimmed = governorateCode != null && governorateCode.isNotEmpty
        ? governorateCode
        : null;
    await getCurrencyRates(
      governorateCode: trimmed,
      persistSelection: true,
    );
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
