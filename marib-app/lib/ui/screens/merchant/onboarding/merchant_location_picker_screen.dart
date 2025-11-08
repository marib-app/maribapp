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
  GoogleMapController? _mapController;
  LatLng? _currentTarget;
  String? _currentAddress;
  bool _loading = true;
  bool _addressLoading = false;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    try {
      if (widget.initialPosition != null) {
        _currentTarget = widget.initialPosition;
      } else {
        final permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
          throw Exception('permission_denied');
        }
        final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
        _currentTarget = LatLng(position.latitude, position.longitude);
      }
      await _reverseGeocode(_currentTarget!);
    } catch (e) {
      HelperUtils.showSnackBarMessage(context, 'locationPermissionDenied'.translate(context), messageDuration: 3);
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
    if (_loading || _currentTarget == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('تحديد موقع المتجر')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('تحديد موقع المتجر'),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: _currentTarget!, zoom: 16),
            onMapCreated: (controller) => _mapController = controller,
            onCameraMove: _onCameraMove,
            onCameraIdle: _onCameraIdle,
            myLocationButtonEnabled: true,
            myLocationEnabled: true,
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
                'حرك الخريطة حتى يكون المؤشر في وسط موقع متجرك',
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
                          ? 'جاري تحديث العنوان...'
                          : (_currentAddress ?? 'لم يتم تحديد العنوان بعد'),
                      style: TextStyle(color: theme.textDefaultColor, fontSize: context.font.normal),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _confirmSelection,
                        child: const Text('تأكيد العنوان'),
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
