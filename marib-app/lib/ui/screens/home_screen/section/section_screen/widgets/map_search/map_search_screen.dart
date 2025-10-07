import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:async';
import 'package:marib/app/routes.dart';
import 'package:marib/utils/api.dart';
import 'package:marib/ui/screens/home_screen/section/section_screen/widgets/map_search/map_repository.dart';
import 'package:marib/ui/screens/home_screen/section/section_screen/widgets/map_search/map_ui.dart';
import 'package:marib/ui/screens/home_screen/section/section_screen/widgets/map_search/ads_google_map.dart';
import 'package:marib/utils/helper_utils.dart';

import 'package:marib/data/model/item/item_model.dart';

class MapSearchScreen extends StatefulWidget {
  const MapSearchScreen({super.key});

  @override
  State<MapSearchScreen> createState() => _MapSearchScreenState();
}

class _MapSearchScreenState extends State<MapSearchScreen> {
  // ====== Map Controllers ======
  GoogleMapController? _mapController;
  final Completer<GoogleMapController> _mapReady =
      Completer<GoogleMapController>();

  // ====== State ======
  bool _isLoading = true;
  Position? _currentPosition;
  String _currentAddress = '';
  Set<Marker> _markers = {};
  List<ItemModel> _ads = [];

  String _selectedCategory = 'الكل';
  final List<String> _categories = [
    'الكل',
    'سيارات',
    'عقارات',
    'أجهزة',
    'أخرى'
  ];

  // ====== Repository ======
  late final MapAdsRepository _repo;

  @override
  void initState() {
    super.initState();
    _repo = MapAdsRepository(endpoint: Api.getItemApi);
    _initializeData();
  }

  // ==================== Init ====================
  Future<void> _initializeData() async {
    try {
      await _getCurrentLocation();
      await _fetchAds();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _getCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) throw 'الرجاء تفعيل خدمة الموقع';

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) throw 'تم رفض إذن الموقع';
    }
    if (permission == LocationPermission.deniedForever) {
      throw 'الرجاء منح إذن الموقع من الإعدادات';
    }

    _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);

    try {
      final placemarks = await placemarkFromCoordinates(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );
      if (placemarks.isNotEmpty) {
        final p = placemarks[0];
        _currentAddress =
            "${p.street}, ${p.locality}, ${p.administrativeArea}, ${p.country}";
      }
    } catch (_) {}
  }

  Future<void> _fetchAds() async {
    try {
      final ads = await _repo.fetchAllAds();
      _ads = ads;

      final valid =
          _ads.where((a) => _isValidLatLng(a.latitude, a.longitude)).length;
      debugPrint("ADS: total=${_ads.length}, with_valid_coords=$valid");

      _updateMarkers();
    } catch (e) {
      _ads = [];
      debugPrint("Error fetching ads: $e");
    }
  }

  // ==================== Helpers ====================

  String? _categoryLabel(ItemModel ad) => ad.category?.name ?? ad.type;

  bool _isValidLatLng(double? lat, double? lng) {
    if (lat == null || lng == null) return false;
    if (lat == 0 && lng == 0) return false;
    return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
  }

  LatLngBounds _boundsFrom(List<LatLng> points) {
    double? minLat, maxLat, minLng, maxLng;
    for (final p in points) {
      minLat = (minLat == null)
          ? p.latitude
          : (p.latitude < minLat ? p.latitude : minLat);
      maxLat = (maxLat == null)
          ? p.latitude
          : (p.latitude > maxLat ? p.latitude : maxLat);
      minLng = (minLng == null)
          ? p.longitude
          : (p.longitude < minLng ? p.longitude : minLng);
      maxLng = (maxLng == null)
          ? p.longitude
          : (p.longitude > maxLng ? p.longitude : maxLng);
    }
    return LatLngBounds(
      southwest: LatLng(minLat!, minLng!),
      northeast: LatLng(maxLat!, maxLng!),
    );
  }

  Future<void> _fitToMarkers() async {
    if (_markers.isEmpty) return;
    final controller =
        _mapReady.isCompleted ? await _mapReady.future : _mapController!;
    final pts = _markers.map((m) => m.position).toList();

    try {
      if (pts.length == 1) {
        await controller
            .animateCamera(CameraUpdate.newLatLngZoom(pts.first, 14));
      } else {
        final bounds = _boundsFrom(pts);
        await controller
            .animateCamera(CameraUpdate.newLatLngBounds(bounds, 60));
      }
    } catch (_) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          if (pts.length == 1) {
            await controller
                .animateCamera(CameraUpdate.newLatLngZoom(pts.first, 14));
          } else {
            final bounds = _boundsFrom(pts);
            await controller
                .animateCamera(CameraUpdate.newLatLngBounds(bounds, 60));
          }
        } catch (_) {}
      });
    }
  }

  // ==================== Markers & Filter ====================
  void _updateMarkers() {
    final filtered = _selectedCategory == 'الكل'
        ? _ads
        : _ads
            .where((ad) =>
                normalizeCategory(_categoryLabel(ad)) == _selectedCategory)
            .toList();

    final newMarkers = <Marker>{};

    // user location
    if (_isValidLatLng(
        _currentPosition?.latitude, _currentPosition?.longitude)) {
      newMarkers.add(Marker(
        markerId: const MarkerId('current_location'),
        position:
            LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        infoWindow: const InfoWindow(title: 'موقعي الحالي'),
      ));
    }

    final usedIds = <String>{};
    int added = 0;
    for (final ad in filtered) {
      if (_isValidLatLng(ad.latitude, ad.longitude)) {
        String baseId = 'ad_${ad.id}';
        String markerId = baseId;
        int i = 1;
        while (usedIds.contains(markerId)) {
          i++;
          markerId = '${baseId}_$i';
        }
        usedIds.add(markerId);

        newMarkers.add(Marker(
          markerId: MarkerId(markerId),
          position: LatLng(ad.latitude!, ad.longitude!),
          infoWindow: InfoWindow(
            title: ad.name ?? 'إعلان',
            snippet: (ad.price != null && (ad.currency ?? '').isNotEmpty)
                ? '${ad.price} ${ad.currency}'
                : null,
          ),
        ));
        added++;
      }
    }

    setState(() => _markers = newMarkers);

    debugPrint(
        "Markers: filtered_by='$_selectedCategory', user_marker=${_isValidLatLng(_currentPosition?.latitude, _currentPosition?.longitude) ? 1 : 0}, ads_added=$added");
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitToMarkers());
  }

  Future<void> _goToUserLocation() async {
    if (_isValidLatLng(
        _currentPosition?.latitude, _currentPosition?.longitude)) {
      final controller =
          _mapReady.isCompleted ? await _mapReady.future : _mapController!;
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          14,
        ),
      );
    }
  }

  // ==================== UI ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const MinimalMapAppBar(
        title: "تصفح الإعلانات على الخريطة", // مرّر اسم القسم لو تحب
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : AdsGoogleMap(
              initialCameraPosition: CameraPosition(
                target: _isValidLatLng(
                        _currentPosition?.latitude, _currentPosition?.longitude)
                    ? LatLng(
                        _currentPosition!.latitude, _currentPosition!.longitude)
                    : const LatLng(15.3694, 44.1910),
                zoom: 12,
              ),
              // لن نستخدم markers عند تمرير ads
              markers: const {},
              onMapCreated: (c) {
                _mapController = c;
                if (!_mapReady.isCompleted) _mapReady.complete(c);
              },
              ads: _ads,
              // قائمة الإعلانات كاملة من الـ API
              activeCategory: _selectedCategory,
              // "الكل" أو اسم فئة معيّن
              userLatLng: _currentPosition != null
                  ? LatLng(
                      _currentPosition!.latitude, _currentPosition!.longitude)
                  : null,
              enableViewportSearch: true,
              // زر "بحث في هذه المنطقة"
              enableRadiusFilter: true,
              // "حدد نطاق البحث (كم)"
              initialRadiusKm: 0,
              // 0 = غير مفعّل افتراضياً
              applyAppMapStyle: true,

              // (اختياري) تنسيق عرض السعر + العملة على الماركر والكروت
              priceFormatter: (ad) {
                final formatted = HelperUtils.formatPrice(ad.price);
                final currency = (ad.currency ?? '').trim();

                if (currency.isEmpty) {
                  return formatted;
                }

                if (formatted.isEmpty) {
                  return currency;
                }

                return '$formatted $currency';
              },

              // (اختياري) فتح صفحة تفاصيل الإعلان
              onOpenAdDetails: (ad) {
                Navigator.pushNamed(
                  context,
                  Routes.adDetailsScreen,
                  arguments: {'model': ad},
                );
              },

              // (اختياري) لو حاب تستدعي API بحسب الـ bounds
              // onSearchThisArea: (bounds) { ... },
            ),

      // ملاحظة: أزلنا الـ FloatingActionButton الخارجي،
      // لأن AdsGoogleMap تعرض أزرار جانبية (منها زر "موقعي") بشكل أنيق ومتناسق.
    );
  }
}
