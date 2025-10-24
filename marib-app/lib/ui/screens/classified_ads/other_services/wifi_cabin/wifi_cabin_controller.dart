import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:marib/data/model/wifi/wifi_network.dart';
import 'package:marib/data/wifi/wifi_repository.dart';

enum WifiCabinLoadStatus { loading, success, failure }

class WifiCabinViewState {
  const WifiCabinViewState({
    required this.status,
    this.networks = const <WifiNetwork>[],
    this.errorMessage,
  });

  const WifiCabinViewState.loading({List<WifiNetwork> previous = const []})
      : this(status: WifiCabinLoadStatus.loading, networks: previous);

  const WifiCabinViewState.success(List<WifiNetwork> networks)
      : this(status: WifiCabinLoadStatus.success, networks: networks);

  const WifiCabinViewState.failure(String? message)
      : this(status: WifiCabinLoadStatus.failure, errorMessage: message);

  final WifiCabinLoadStatus status;
  final List<WifiNetwork> networks;
  final String? errorMessage;

  bool get hasData => networks.isNotEmpty;
}

class WifiCabinController extends ChangeNotifier {
  WifiCabinController({WifiRepository? repository})
      : _repository = repository ?? const WifiRepository();

  static const int _defaultLimit = 60;
  static const Duration _debounceDuration = Duration(milliseconds: 350);

  final WifiRepository _repository;
  WifiCabinViewState _viewState = const WifiCabinViewState.loading();
  String _query = '';
  bool _hasBootstrapped = false;

  Timer? _refreshDebounce;
  bool _isDisposed = false;

  WifiCabinViewState get viewState => _viewState;
  String get query => _query;
  bool get isBootstrapped => _hasBootstrapped;

  Future<void> bootstrap() async {
    if (_hasBootstrapped) return;
    _hasBootstrapped = true;
    await refreshNetworks(force: true);
  }

  Future<void> refreshNetworks({bool force = false}) async {

    if (_isDisposed) return;
    final List<WifiNetwork> previous =
    force ? const <WifiNetwork>[] : _viewState.networks;
    _setState(WifiCabinViewState.loading(previous: previous));

    try {
      final networks = await _repository.searchNetworks(
        query: _query.trim().isEmpty ? null : _query.trim(),
        limit: _defaultLimit,
      );

      _setState(WifiCabinViewState.success(networks));

    } catch (error) {
      final String message = error.toString().isEmpty

          ? 'حدث خطأ غير متوقع أثناء جلب الشبكات.'
          : error.toString();
      _setState(WifiCabinViewState.failure(message));
    }
  }

  void updateQuery(String value, {bool immediate = false}) {
    if (_isDisposed) return;
    _query = value;
    _safeNotify();
    _refreshDebounce?.cancel();
    if (immediate) {
      refreshNetworks();
      return;
    }

    _refreshDebounce = Timer(_debounceDuration, () {
      if (_isDisposed) return;
      refreshNetworks();
    });
  }

  void clearQuery() {
    if (_isDisposed || _query.isEmpty) return;
    _query = '';
    _safeNotify();
    refreshNetworks();

  }

  void _setState(WifiCabinViewState state) {
    if (_isDisposed) return;
    _viewState = state;
    _safeNotify();
  }

  void _safeNotify() {
    if (_isDisposed) return;
    notifyListeners();
  }



  @override
  void dispose() {
    _isDisposed = true;
    _refreshDebounce?.cancel();
    super.dispose();
  }
}