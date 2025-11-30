import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/helper_utils.dart';

class MerchantLocationPickerResult {
  final double latitude;
  final double longitude;
  final String? address;

  MerchantLocationPickerResult({
    required this.latitude,
    required this.longitude,
    this.address,
  });
}

class MerchantLocationPickerScreen extends StatefulWidget {
  final LatLng? initialPosition;

  const MerchantLocationPickerScreen({super.key, this.initialPosition});

  @override
  State<MerchantLocationPickerScreen> createState() => _MerchantLocationPickerScreenState();
}

class _MerchantLocationPickerScreenState extends State<MerchantLocationPickerScreen> {
  static const LatLng _fallback = LatLng(15.3694, 44.1910); // Marib fallback
  GoogleMapController? _mapController;
  LatLng? _currentTarget;
  String? _currentAddress;
  bool _loading = true;
  bool _addressLoading = false;
  bool _myLocationAllowed = true;

  @override
  void initState() {
    super.initState();
    _currentTarget = widget.initialPosition ?? _fallback;
    _initLocation();
  }

  Future<bool> _ensurePermissionAndService() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        HelperUtils.showSnackBarMessage(
          context,
          'الرجاء تفعيل خدمة الموقع (GPS) أولاً.',
          messageDuration: 3,
        );
        _myLocationAllowed = false;
        return false;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        HelperUtils.showSnackBarMessage(
          context,
          'تم رفض إذن تحديد الموقع، الرجاء السماح بالوصول.',
          messageDuration: 3,
        );
        _myLocationAllowed = false;
        return false;
      }

      if (permission == LocationPermission.deniedForever) {
        HelperUtils.showSnackBarMessage(
          context,
          'تم رفض الإذن نهائياً، فعّل صلاحية الموقع من إعدادات الجهاز.',
          messageDuration: 4,
        );
        _myLocationAllowed = false;
        return false;
      }

      _myLocationAllowed = true;
      return true;
    } catch (_) {
      HelperUtils.showSnackBarMessage(
        context,
        'تعذر التحقق من الإذن، يمكنك اختيار الموقع يدويًا.',
        messageDuration: 3,
      );
      _myLocationAllowed = false;
      return false;
    }
  }

  Future<void> _initLocation() async {
    try {
      if (widget.initialPosition == null) {
        final allowed = await _ensurePermissionAndService();
        if (!allowed) {
          _currentTarget = _fallback;
          _addressLoading = false;
          if (mounted) setState(() => _loading = false);
          return;
        }
        try {
          final position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
          ).timeout(const Duration(seconds: 8));
          _currentTarget = LatLng(position.latitude, position.longitude);
        } catch (_) {
          _currentTarget = _fallback;
        }
      }

      if (_currentTarget != null) {
        await _reverseGeocode(_currentTarget!);
      }
    } catch (_) {
      _currentTarget ??= _fallback;
      if (mounted) {
        HelperUtils.showSnackBarMessage(
          context,
          'تعذر الحصول على موقعك، يمكنك تحديده يدويًا على الخريطة.',
          messageDuration: 3,
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reverseGeocode(LatLng target) async {
    try {
      setState(() => _addressLoading = true);
      final placemarks = await placemarkFromCoordinates(target.latitude, target.longitude);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        _currentAddress = '${p.street}, ${p.locality}, ${p.country}';
      }
    } catch (_) {
      _currentAddress = null;
    } finally {
      if (mounted) setState(() => _addressLoading = false);
    }
  }

  void _onCameraIdle() {
    if (_currentTarget != null) {
      _reverseGeocode(_currentTarget!);
    }
  }

  void _onCameraMove(CameraPosition position) {
    _currentTarget = position.target;
  }

  void _confirmSelection() {
    if (_currentTarget == null) return;
    Navigator.of(context).pop(
      MerchantLocationPickerResult(
        latitude: _currentTarget!.latitude,
        longitude: _currentTarget!.longitude,
        address: _currentAddress,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.color;
    final LatLng target = _currentTarget ?? _fallback;

    return Scaffold(
      appBar: AppBar(
        title: const Text('تحديد موقع المتجر'),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: target, zoom: 16),
            onMapCreated: (controller) => _mapController = controller,
            onCameraMove: _onCameraMove,
            onCameraIdle: _onCameraIdle,
            myLocationButtonEnabled: _myLocationAllowed,
            myLocationEnabled: _myLocationAllowed,
          ),
          if (_loading)
            const Center(
              child: CircularProgressIndicator(),
            ),
          const IgnorePointer(
            child: Center(
              child: Icon(Icons.location_pin, size: 40, color: Colors.redAccent),
            ),
          ),
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.primaryColor.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'حرّك الخريطة لتحديد الموقع بدقة، ثم اضغط تأكيد.',
                style: TextStyle(color: theme.textDefaultColor),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withOpacity(0.95),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _addressLoading
                          ? 'جاري جلب العنوان...'
                          : (_currentAddress ?? 'لم يتم العثور على عنوان دقيق لهذا الموقع'),
                      style: TextStyle(color: theme.textDefaultColor, fontSize: context.font.normal),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _confirmSelection,
                        child: const Text('تأكيد الموقع'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
