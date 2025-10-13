import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marib/data/model/currency_rate.dart';
import 'package:marib/data/repositories/currency_repository.dart';
import 'package:marib/data/model/currency_rates_bundle.dart';
import 'package:marib/data/model/governorate.dart';
import 'package:marib/data/repositories/preferences/governorate_preference_repository.dart';
import 'package:marib/data/repositories/metal_repository.dart';
import 'package:marib/data/model/metal_rate.dart';
import 'package:marib/data/model/metal_rates_bundle.dart';
import 'package:marib/data/model/preference_option.dart';
import 'package:marib/data/model/user_preferences.dart';
import 'package:marib/data/repositories/currency_repository.dart';
import 'package:marib/data/repositories/metal_repository.dart';
import 'package:marib/data/repositories/preferences/user_preference_repository.dart';
import 'package:marib/utils/hive_utils.dart';




part 'currency_state.dart';

class CurrencyCubit extends Cubit<CurrencyState> {
  CurrencyCubit(
      this._currencyRepository,
      this._preferenceRepository,
      this._metalRepository,
      ) : super(CurrencyInitial());

  final UserPreferenceRepository _preferenceRepository;

  final CurrencyRepository _currencyRepository;
  final MetalRepository _metalRepository;

  UserPreferences _preferences = const UserPreferences();
  List<PreferenceOption> _notificationOptions = const <PreferenceOption>[];
  bool _showWatchlistOnly = false;

  Future<void> initialize() async {
    _preferences = await _preferenceRepository.loadLocalPreferences();
    _showWatchlistOnly = await _preferenceRepository.loadWatchlistFilter();

    if (HiveUtils.isUserAuthenticated() &&
        await _preferenceRepository.hasPendingSync()) {
      final UserPreferences? remote =
      await _preferenceRepository.updateRemotePreferences(_preferences);
      if (remote != null) {
        _preferences = remote;
      }
    }

    await getCurrencyRates(
      governorateCode: _preferences.favoriteGovernorateCode,
    );
  }

  Future<void> getCurrencyRates({
    String? governorateCode,
    bool persistSelection = false,
  }) async {
    final String? requestedCode =
        governorateCode ?? _preferences.favoriteGovernorateCode;


    emit(CurrencyLoading());
    try {
      final CurrencyRatesBundle bundle = await _currencyRepository
          .getCurrencyRates(governorateCode: requestedCode);
      final MetalRatesBundle metalBundle = await _metalRepository.getMetalRates();


      if (bundle.rates.isEmpty) {
        emit(CurrencyError('لا توجد بيانات متاحة'));

        return;
      }

      final bool hasPendingSync = await _preferenceRepository.hasPendingSync();
      if (bundle.preferences != null) {
        if (HiveUtils.isUserAuthenticated() && !hasPendingSync) {
          _preferences = bundle.preferences!;
          await _preferenceRepository.saveLocalPreferences(
            _preferences,
            markPendingSync: false,
          );
        } else if (!HiveUtils.isUserAuthenticated()) {
          _preferences = bundle.preferences!;
          await _preferenceRepository.saveLocalPreferences(
            _preferences,
            markPendingSync: false,
          );
        }
      }

      _notificationOptions = bundle.notificationOptions;

      String? resolvedGovernorateCode = requestedCode ??


          bundle.requestedGovernorateCode ??
          bundle.appliedGovernorate?.code ??
          bundle.requestedGovernorate?.code;

      if (persistSelection) {
        final UserPreferences updated =
        _preferences.copyWith(favoriteGovernorateCode: resolvedGovernorateCode);
        await _persistPreferences(updated, syncRemote: true);
      }

      final List<CurrencyRate> currencyRates = bundle.rates
          .map((CurrencyRate rate) => rate.copyWith(
        isWatchlisted:
        _preferences.currencyWatchlist.contains(rate.id),
      ))
          .toList(growable: false);

      final List<MetalRate> metalRates = metalBundle.rates
          .map((MetalRate rate) => rate.copyWith(
        isWatchlisted:
        _preferences.metalWatchlist.contains(rate.id),
      ))
          .toList(growable: false);

      emit(CurrencySuccess(
        currencyRates: currencyRates,
        visibleCurrencyRates: _filterCurrencyRates(currencyRates),
        metalRates: metalRates,
        visibleMetalRates: _filterMetalRates(metalRates),
        metalsLastUpdatedAt: metalBundle.lastUpdatedAt,
        governorates: bundle.governorates,
        requestedGovernorate: bundle.requestedGovernorate,
        appliedGovernorate: bundle.appliedGovernorate,
        usedFallback: bundle.usedFallback,
        requestedGovernorateCode:
        resolvedGovernorateCode ?? bundle.requestedGovernorateCode,
        preferences: _preferences,
        notificationOptions: _notificationOptions,
        showWatchlistOnly: _showWatchlistOnly,

      ));
    } catch (error) {
      emit(CurrencyError(error.toString()));
    }
  }

  List<CurrencyRate> _filterCurrencyRates(List<CurrencyRate> rates) {
    if (!_showWatchlistOnly) {
      return rates;
    }
    final Set<int> watchlist = _preferences.currencyWatchlist;
    return rates
        .where((CurrencyRate rate) => watchlist.contains(rate.id))
        .toList(growable: false);
  }

  List<MetalRate> _filterMetalRates(List<MetalRate> rates) {
    if (!_showWatchlistOnly) {
      return rates;
    }
    final Set<int> watchlist = _preferences.metalWatchlist;
    return rates
        .where((MetalRate rate) => watchlist.contains(rate.id))
        .toList(growable: false);
  }

  Future<void> changeGovernorate(String? governorateCode) async {
    final String? trimmed =
    governorateCode != null && governorateCode.isNotEmpty
        ? governorateCode
        : null;
    await getCurrencyRates(
      governorateCode: trimmed,
      persistSelection: true,
    );
  }

  Future<void> toggleWatchlistFilter(bool enabled) async {
    _showWatchlistOnly = enabled;
    await _preferenceRepository.saveWatchlistFilter(enabled);
    _refreshSuccessState();
  }

  Future<void> toggleCurrencyWatchlist(int currencyId) async {
    final Set<int> updated = Set<int>.from(_preferences.currencyWatchlist);
    if (updated.contains(currencyId)) {
      updated.remove(currencyId);
    } else {
      updated.add(currencyId);
    }

    await _persistPreferences(
      _preferences.copyWith(currencyWatchlist: updated),
      syncRemote: true,
    );
    _refreshSuccessState();
  }

  Future<void> toggleMetalWatchlist(int metalId) async {
    final Set<int> updated = Set<int>.from(_preferences.metalWatchlist);
    if (updated.contains(metalId)) {
      updated.remove(metalId);
    } else {
      updated.add(metalId);
    }

    await _persistPreferences(
      _preferences.copyWith(metalWatchlist: updated),
      syncRemote: true,
    );
    _refreshSuccessState();
  }

  Future<void> changeNotificationFrequency(String value) async {
    if (value.isEmpty || value == _preferences.notificationFrequency) {
      return;
    }

    await _persistPreferences(
      _preferences.copyWith(notificationFrequency: value),
      syncRemote: true,
    );
    _refreshSuccessState();
  }

  Future<void> _persistPreferences(
      UserPreferences preferences, {
        required bool syncRemote,
      }) async {
    _preferences = preferences;
    final bool isAuthenticated = HiveUtils.isUserAuthenticated();

    await _preferenceRepository.saveLocalPreferences(
      _preferences,
      markPendingSync: syncRemote && !isAuthenticated,
    );

    if (syncRemote && isAuthenticated) {
      final UserPreferences? remote =
      await _preferenceRepository.updateRemotePreferences(_preferences);
      if (remote != null) {
        _preferences = remote;
      }
    }
  }

  void _refreshSuccessState() {
    final CurrencyState currentState = state;
    if (currentState is! CurrencySuccess) {
      return;
    }

    final List<CurrencyRate> updatedCurrency = currentState.currencyRates
        .map((CurrencyRate rate) => rate.copyWith(
      isWatchlisted:
      _preferences.currencyWatchlist.contains(rate.id),
    ))
        .toList(growable: false);

    final List<MetalRate> updatedMetal = currentState.metalRates
        .map((MetalRate rate) => rate.copyWith(
      isWatchlisted:
      _preferences.metalWatchlist.contains(rate.id),
    ))
        .toList(growable: false);

    emit(CurrencySuccess(
      currencyRates: updatedCurrency,
      visibleCurrencyRates: _filterCurrencyRates(updatedCurrency),
      metalRates: updatedMetal,
      visibleMetalRates: _filterMetalRates(updatedMetal),
      metalsLastUpdatedAt: currentState.metalsLastUpdatedAt,
      governorates: currentState.governorates,
      requestedGovernorate: currentState.requestedGovernorate,
      appliedGovernorate: currentState.appliedGovernorate,
      usedFallback: currentState.usedFallback,
      requestedGovernorateCode: currentState.requestedGovernorateCode,
      preferences: _preferences,
      notificationOptions: _notificationOptions,
      showWatchlistOnly: _showWatchlistOnly,
    ));
  }

  double calculateConversion({
    required double amount,
    required String fromCurrency,
    required String toCurrency,
    required bool isBuying,
  }) {
    if (state is CurrencySuccess) {
      final List<CurrencyRate> currencyRates =
          (state as CurrencySuccess).currencyRates;

      final CurrencyRate fromRate = currencyRates.firstWhere(
            (CurrencyRate rate) => rate.currencyName == fromCurrency,
        orElse: () => CurrencyRate(
          id: 0,
          currencyName: fromCurrency,
          sellPrice: 1,
          buyPrice: 1,
        ),
      );

      final CurrencyRate toRate = currencyRates.firstWhere(
            (CurrencyRate rate) => rate.currencyName == toCurrency,
        orElse: () => CurrencyRate(
          id: 0,
          currencyName: toCurrency,
          sellPrice: 1,
          buyPrice: 1,
        ),
      );

      final double fromValue =
      isBuying ? fromRate.sellPrice : fromRate.buyPrice;
      final double toValue =
      isBuying ? toRate.buyPrice : toRate.sellPrice;

      // Calculate the conversion
      return amount * (fromValue / toValue);
    }
    
    return 0.0;
  }
}
