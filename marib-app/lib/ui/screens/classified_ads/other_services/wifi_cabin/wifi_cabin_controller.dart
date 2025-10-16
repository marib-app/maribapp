import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:marib/data/model/wifi/wifi_network.dart';
import 'package:marib/data/wifi/wifi_repository.dart';
import 'package:marib/utils/constant.dart';

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
  LatLng? _currentCenter;
  bool _locationDenied = false;
  double _maxKm = 10;
  Timer? _refreshDebounce;
  bool _isDisposed = false;

  WifiCabinViewState get viewState => _viewState;
  LatLng? get currentCenter => _currentCenter;
  bool get locationDenied => _locationDenied;
  double get maxKm => _maxKm;

  Future<void> bootstrap() async {
    await _resolveLocation();
    if (_currentCenter == null) {
      _setState(const WifiCabinViewState.failure(
        'تعذّر تحديد موقعك الحالي. فعّل خدمات الموقع وحاول من جديد.',
      ));
      return;
    }
    await refreshNetworks();
  }

  Future<void> refreshNetworks() async {
    if (_isDisposed) return;
    final center = _currentCenter;
    if (center == null) {
      _setState(const WifiCabinViewState.failure(
        'تعذّر تحديد موقعك الحالي. فعّل خدمات الموقع وحاول من جديد.',
      ));
      return;
    }

    _setState(WifiCabinViewState.loading(previous: _viewState.networks));

    try {
      final networks = await _repository.fetchNearbyNetworks(
        latitude: center.latitude,
        longitude: center.longitude,
        radiusKm: _maxKm,
        limit: _defaultLimit,
      );

      final decorated = networks
          .map((network) {
        final distance = network.distanceKm ??
            _haversineKm(center, LatLng(network.latitude, network.longitude));
        return network.copyWith(distanceKm: distance);
      })
          .toList()
        ..sort(
              (a, b) => (a.distanceKm ?? double.infinity)
              .compareTo(b.distanceKm ?? double.infinity),
        );

      _setState(WifiCabinViewState.success(decorated));
    } catch (error) {
      final message = error.toString().isEmpty
          ? 'حدث خطأ غير متوقع أثناء جلب الشبكات.'
          : error.toString();
      _setState(WifiCabinViewState.failure(message));
    }
  }

  void updateMaxKm(double value) {
    if (_maxKm == value || _isDisposed) return;
    _maxKm = value;
    _safeNotify();
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(_debounceDuration, () {
      if (_isDisposed) return;
      refreshNetworks();
    });
  }

  Future<void> enableLocation() async {
    if (_isDisposed) return;
    await _resolveLocation();
    if (_isDisposed) return;
    await refreshNetworks();
  }

  Future<void> _resolveLocation() async {
    bool denied = false;
    LatLng? resolved = _currentCenter;

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        denied = true;
        resolved ??= _fallbackLatLng();
      } else {
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          denied = true;
          resolved ??= _fallbackLatLng();
        } else {
          final position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.medium,
          );
          resolved = LatLng(position.latitude, position.longitude);
        }
      }
    } catch (_) {
      denied = true;
      resolved ??= _fallbackLatLng();
    }

    _locationDenied = denied;
    _currentCenter = resolved;
    _safeNotify();
  }

  LatLng? _fallbackLatLng() {
    final lat = double.tryParse(Constant.defaultLatitude);
    final lng = double.tryParse(Constant.defaultLongitude);
    if (lat == null || lng == null) {
      return null;
    }
    return LatLng(lat, lng);
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

  double _haversineKm(LatLng a, LatLng b) {
    const r = 6371.0;
    final dLat = _deg2rad(b.latitude - a.latitude);
    final dLon = _deg2rad(b.longitude - a.longitude);
    final la1 = _deg2rad(a.latitude);
    final la2 = _deg2rad(b.latitude);

    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(la1) * math.cos(la2) * math.sin(dLon / 2) * math.sin(dLon / 2);
    final c = 2 * math.asin(math.sqrt(h));
    return r * c;
  }

  double _deg2rad(double value) => value * (math.pi / 180.0);

  @override
  void dispose() {
    _isDisposed = true;
    _refreshDebounce?.cancel();
    super.dispose();
  }
}