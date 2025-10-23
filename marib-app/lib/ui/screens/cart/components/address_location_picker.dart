import 'dart:async';
import 'package:geocoding/geocoding.dart';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:marib/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:marib/utils/ui_utils.dart';

class CartAddressLocationPicker extends StatefulWidget {
  const CartAddressLocationPicker({
    super.key,
    this.initial,
  });

  final Map<String, dynamic>? initial;

  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    Map<String, dynamic>? initial,
  }) {
    return Navigator.of(context).push<Map<String, dynamic>>(
      BlurredRouter<Map<String, dynamic>>(
        builder: (_) => CartAddressLocationPicker(initial: initial),
      ),
    );
  }

  @override
  State<CartAddressLocationPicker> createState() =>
      _CartAddressLocationPickerState();
}

class _CartAddressLocationPickerState extends State<CartAddressLocationPicker>
    with WidgetsBindingObserver {
  GoogleMapController? _controller;
  CameraPosition? _camera;
  LatLng? _currentTarget;
  MapType _mapType = MapType.normal;
  bool _initializing = true;
  bool _geocoding = false;
  bool _serviceDeniedForever = false;
  Placemark? _placemark;
  StreamSubscription<ServiceStatus>? _serviceSubscription;
  Timer? _reverseGeocodeDebounce;
  LatLng? _lastReverseGeocodeTarget;
  DateTime? _lastReverseGeocodeTime;

  static const double _reverseGeocodeMinDistanceMeters = 30;
  static const Duration _reverseGeocodeMinInterval =
      Duration(milliseconds: 500);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
    _serviceSubscription = Geolocator.getServiceStatusStream().listen((_) {
      if (!_serviceDeniedForever) {
        _initialize();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _serviceSubscription?.cancel();
    _reverseGeocodeDebounce?.cancel();
    super.dispose();
  }

  Future<void> _initialize() async {
    final LatLng? seed = _seedFromInitial();
    if (seed != null) {
      _updateCamera(seed);
      await _reverseGeocode(seed);
      if (mounted) {
        setState(() => _initializing = false);
      }
      return;
    }

    final bool allowed = await _ensurePermission();
    if (!allowed) {
      if (mounted) setState(() => _initializing = false);
      return;
    }

    try {
      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final LatLng target = LatLng(position.latitude, position.longitude);
      _updateCamera(target);
      await _reverseGeocode(target);
    } catch (_) {
      _updateCamera(const LatLng(15.3694, 44.1910));
    } finally {
      if (mounted) setState(() => _initializing = false);
    }
  }

  LatLng? _seedFromInitial() {
    final dynamic lat = widget.initial?['latitude'] ?? widget.initial?['lat'];
    final dynamic lng = widget.initial?['longitude'] ?? widget.initial?['lng'];
    final double? latValue = _asDouble(lat);
    final double? lngValue = _asDouble(lng);
    if (latValue == null || lngValue == null) {
      return null;
    }
    return LatLng(latValue, lngValue);
  }

  Future<bool> _ensurePermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.deniedForever) {
      _serviceDeniedForever = true;
      if (mounted) {
        HelperUtils.showSnackBarMessage(
          context,
          'الرجاء تفعيل صلاحية الموقع من الإعدادات.',
        );
      }
      return false;
    }

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          HelperUtils.showSnackBarMessage(
            context,
            'لم يتم منح صلاحية الموقع.',
          );
        }
        return false;
      }
    }
    return true;
  }

  void _updateCamera(LatLng target) {
    _currentTarget = target;
    _camera = CameraPosition(target: target, zoom: 15.5);
    if (_controller != null) {
      _controller!.animateCamera(CameraUpdate.newCameraPosition(_camera!));
    }
  }

  void _onCameraMove(CameraPosition position) {
    _currentTarget = position.target;
  }

  void _onCameraIdle() {
    final LatLng? target = _currentTarget;
    if (target == null) {
      return;
    }
    _reverseGeocodeDebounce?.cancel();
    _reverseGeocodeDebounce = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      if (_shouldSkipReverseGeocode(target)) {
        return;
      }
      _reverseGeocode(target);
    });
  }

  Future<void> _reverseGeocode(LatLng target) async {
    if (!mounted) return;

    _reverseGeocodeDebounce?.cancel();
    _reverseGeocodeDebounce = null;
    _lastReverseGeocodeTarget = target;
    _lastReverseGeocodeTime = DateTime.now();

    setState(() => _geocoding = true);
    try {
      final List<Placemark> placemarks = await placemarkFromCoordinates(
        target.latitude,
        target.longitude,
      );
      if (placemarks.isNotEmpty && mounted) {
        setState(() => _placemark = placemarks.first);
      }
    } catch (_) {
      if (mounted) setState(() => _placemark = null);
    } finally {
      if (mounted) setState(() => _geocoding = false);
    }
  }

  bool _shouldSkipReverseGeocode(LatLng target) {
    final DateTime? lastTime = _lastReverseGeocodeTime;
    if (lastTime != null &&
        DateTime.now().difference(lastTime) < _reverseGeocodeMinInterval) {
      return true;
    }
    final LatLng? lastTarget = _lastReverseGeocodeTarget;
    if (lastTarget == null) {
      return false;
    }
    final double distance = Geolocator.distanceBetween(
      lastTarget.latitude,
      lastTarget.longitude,
      target.latitude,
      target.longitude,
    );
    return distance < _reverseGeocodeMinDistanceMeters;
  }

  Future<void> _goToCurrentLocation() async {
    final bool allowed = await _ensurePermission();
    if (!allowed) return;
    try {
      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final LatLng target = LatLng(position.latitude, position.longitude);
      _updateCamera(target);
      await _reverseGeocode(target);
    } catch (_) {
      if (!mounted) return;
      HelperUtils.showSnackBarMessage(
        context,
        'تعذر تحديد موقعك الحالي.',
      );
    }
  }

  String _addressSummary() {
    final Placemark? mark = _placemark;
    if (mark == null) {
      return 'حدد المكان بدقة لتحسين التوصيل';
    }
    final List<String> parts = <String>[
      if ((mark.subAdministrativeArea ?? '').trim().isNotEmpty)
        mark.subAdministrativeArea!.trim(),
      if ((mark.locality ?? '').trim().isNotEmpty) mark.locality!.trim(),
      if ((mark.administrativeArea ?? '').trim().isNotEmpty)
        mark.administrativeArea!.trim(),
      if ((mark.country ?? '').trim().isNotEmpty) mark.country!.trim(),
    ];
    if (parts.isEmpty) {
      return 'تم التقاط الإحداثيات بنجاح';
    }
    return parts.join('، ');
  }

  Map<String, dynamic> _buildResult() {
    final LatLng target = _currentTarget ?? const LatLng(0, 0);
    final Placemark? mark = _placemark;
    final Map<String, dynamic> result = <String, dynamic>{
      'latitude': target.latitude,
      'longitude': target.longitude,
      'lat': target.latitude,
      'lng': target.longitude,
    };

    if (mark != null) {
      void put(String key, String? value) {
        if (value == null) return;
        final String trimmed = value.trim();
        if (trimmed.isEmpty) return;
        result[key] = trimmed;
      }

      put('area', mark.subAdministrativeArea ?? mark.locality);
      put('city', mark.locality);
      put('state', mark.administrativeArea);
      put('country', mark.country);
      final String composed = <String?>[
        mark.street,
        mark.locality,
        mark.administrativeArea,
        mark.country,
      ]
          .whereType<String>()
          .map((String e) => e.trim())
          .where((String e) => e.isNotEmpty)
          .join('، ');
      if (composed.isNotEmpty) {
        result['formatted_address'] = composed;
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;

    return Scaffold(
      backgroundColor: context.color.secondaryColor,
      appBar: UiUtils.buildAppBar(
        context,
        title: 'تحديد موقع التوصيل',
        showBackButton: true,
      ),
      body: _initializing
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: GoogleMap(
                          mapType: _mapType,
                          myLocationEnabled: true,
                          zoomControlsEnabled: false,
                          initialCameraPosition: _camera ??
                              const CameraPosition(
                                  target: LatLng(0, 0), zoom: 2),
                          onMapCreated: (GoogleMapController controller) {
                            _controller = controller;
                          },
                          onCameraMove: _onCameraMove,
                          onCameraIdle: _onCameraIdle,
                        ),
                      ),
                      Align(
                        alignment: Alignment.center,
                        child: IgnorePointer(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.place,
                                size: 48,
                                color: context.color.territoryColor,
                              ),
                              if (_geocoding) const SizedBox(height: 12),
                              if (_geocoding)
                                const CircularProgressIndicator(
                                    strokeWidth: 2.5),
                            ],
                          ),
                        ),
                      ),
                      PositionedDirectional(
                        top: 20,
                        end: 20,
                        child: Column(
                          children: [
                            _MapIconButton(
                              icon: Icons.layers_outlined,
                              tooltip: 'تبديل نوع الخريطة',
                              onPressed: () {
                                setState(() {
                                  _mapType = _mapType == MapType.normal
                                      ? MapType.hybrid
                                      : MapType.normal;
                                });
                              },
                            ),
                            const SizedBox(height: 12),
                            _MapIconButton(
                              icon: Icons.my_location,
                              tooltip: 'موقعي الحالي',
                              onPressed: _goToCurrentLocation,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: color.surface,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(24)),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 12,
                        offset: Offset(0, -4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'الموقع المختار',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: context.font.larger,
                          color: context.color.textDefaultColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _addressSummary(),
                        style: TextStyle(
                          fontSize: context.font.normal,
                          color: context.color.textLightColor,
                        ),
                      ),
                      const SizedBox(height: 20),
                      UiUtils.buildButton(
                        context,
                        buttonTitle: 'تأكيد الموقع',
                        height: 54,
                        radius: 14,
                        onPressed: () {
                          Navigator.of(context).pop(_buildResult());
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  double? _asDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}

class _MapIconButton extends StatelessWidget {
  const _MapIconButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: context.color.secondaryColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, color: context.color.territoryColor),
        ),
      ),
    );
  }
}
