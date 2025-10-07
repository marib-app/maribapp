// lib/ui/screens/home/section/Items_List/widgets/map_search/ads_google_map.dart
//
// AdsGoogleMap (نسخة عقارات) — خريطة مع:
// - ماركرات مخصصة بشكل منزل + شارة سعر/عملة
// - دائرة موقع المستخدم + دائرة نطاق البحث (بلون الهوية)
// - "بحث في هذه المنطقة" + تخفيض النتائج مع عدّاد
// - بطاقات أفقية متزامنة مع الماركرات عند تفعيل نطاق/منطقة
// - بطاقة تفاصيل سفلية بعرض الشاشة (صورة + اسم متحرّك + سعر/عملة + زر التفاصيل)
// - شاشة "حدد نطاق البحث (كم)" محسّنة (Draggable)
//

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/helper_utils.dart';

// context.color.*
// HelperUtils.showSnackBarMessage

import 'package:marib/ui/screens/home_screen/section/section_screen/widgets/map_search/map_repository.dart'
    show normalizeCategory;
import 'package:marib/data/model/item/item_model.dart';

// ===================================================================
// واجهة الاستخدام العامة
// ===================================================================

typedef PriceFormatter = String Function(ItemModel ad);
typedef ImageUrlResolver = String? Function(ItemModel ad);

class AdsGoogleMap extends StatefulWidget {
  // الأساسيات
  final CameraPosition initialCameraPosition;
  final void Function(GoogleMapController) onMapCreated;

  // مصدر البيانات (يوصى بتمرير ads لاستخدام الفلاتر/البطاقات)
  final List<ItemModel>? ads;
  final Set<Marker> markers; // بديل إذا لم تُمرّر ads

  // فلاتر/خيارات
  final String? activeCategory; // 'الكل' أو null
  final LatLng? userLatLng; // موقع المستخدم (للتمركز والنطاق)
  final bool enableViewportSearch; // تفعيل "بحث في هذه المنطقة"
  final bool enableRadiusFilter; // تفعيل "نطاق البحث"
  final double initialRadiusKm; // 0 = غير مفعّل افتراضياً
  final Function(LatLngBounds)?
      onSearchThisArea; // (اختياري) نداء API مع bounds
  final bool applyAppMapStyle; // لو عندك JSON لستايل الخريطة

  // تهيئة العرض
  final PriceFormatter? priceFormatter;
  final ImageUrlResolver? imageUrlResolver;
  final void Function(ItemModel ad)? onOpenAdDetails;

  const AdsGoogleMap({
    super.key,
    required this.initialCameraPosition,
    required this.onMapCreated,
    this.ads,
    this.markers = const {},
    this.activeCategory,
    this.userLatLng,
    this.enableViewportSearch = true,
    this.enableRadiusFilter = true,
    this.initialRadiusKm = 0,
    this.onSearchThisArea,
    this.applyAppMapStyle = true,
    this.priceFormatter,
    this.imageUrlResolver,
    this.onOpenAdDetails,
  });

  @override
  State<AdsGoogleMap> createState() => _AdsGoogleMapState();
}

// ===================================================================
// الحالة الرئيسية + منطق التطبيق
// ===================================================================

class _AdsGoogleMapState extends State<AdsGoogleMap> {
  GoogleMapController? _controller;

  // حالة الخريطة
  MapType _mapType = MapType.normal;
  final Set<Marker> _markers = {};
  final Set<Circle> _circles = {};

  // فلاتر
  bool _viewportFilterOn = false;
  LatLngBounds? _lastViewportBounds;

  bool _radiusOn = false;
  double _radiusKm = 0;

  // حالة إظهار زر "بحث في هذه المنطقة"
  Timer? _idleTimer;
  bool _showSearchAreaBtn = false;

  // Pin مؤقت بالضغط المطوّل
  Marker? _tempPin;

  // نتائج، وعدّادات
  int _totalValidAds = 0;
  int _currentShownCount = 0;
  List<ItemModel> _visibleAds = [];

  // بطاقة التفاصيل السفلية
  ItemModel? _selectedAd;
  bool get _detailsOpen => _selectedAd != null;

  // ستايل الخريطة
  Brightness? _cachedBrightness;

  // مصنع الماركرات (يرسم المنزل + شارة السعر)
  late final _MarkerFactory _markerFactory = _MarkerFactory();

  @override
  void initState() {
    super.initState();
    _radiusOn = widget.enableRadiusFilter && widget.initialRadiusKm > 0;
    _radiusKm = widget.initialRadiusKm;

    // إن لم تُمرّر ads، نستخدم markers كما هي (بدون فلاتر وواجهات إضافية)
    if (widget.ads == null) {
      _markers
        ..clear()
        ..addAll(widget.markers);
      _currentShownCount =
          _markers.where((m) => m.markerId.value.startsWith('ad_')).length;
      _totalValidAds = _currentShownCount;
    }
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    super.dispose();
  }

  // ----------------- Helpers عامة -----------------
  String? _categoryLabel(ItemModel ad) => ad.category?.name ?? ad.type;

  bool _isValidLatLng(LatLng? p) {
    if (p == null) return false;
    if (p.latitude == 0 && p.longitude == 0) return false;
    return p.latitude >= -90 &&
        p.latitude <= 90 &&
        p.longitude >= -180 &&
        p.longitude <= 180;
  }

  double _deg2rad(double deg) => deg * (math.pi / 180.0);

  double _distanceKm(LatLng a, LatLng b) {
    const R = 6371.0;
    final dLat = _deg2rad(b.latitude - a.latitude);
    final dLon = _deg2rad(b.longitude - a.longitude);
    final s1 = math.sin(dLat / 2);
    final s2 = math.sin(dLon / 2);
    final aa = s1 * s1 +
        math.cos(_deg2rad(a.latitude)) *
            math.cos(_deg2rad(b.latitude)) *
            s2 *
            s2;
    final c = 2 * math.atan2(math.sqrt(aa), math.sqrt(1 - aa));
    return R * c;
  }

  Future<LatLngBounds?> _getVisibleRegion() async {
    try {
      return await _controller?.getVisibleRegion();
    } catch (_) {
      return null;
    }
  }

  bool _boundsContains(LatLngBounds b, LatLng p) {
    final sw = b.southwest;
    final ne = b.northeast;
    final inLat = p.latitude >= sw.latitude && p.latitude <= ne.latitude;
    final inLng = p.longitude >= sw.longitude && p.longitude <= ne.longitude;
    return inLat && inLng;
  }

  String _formatPrice(ItemModel a) {
    if (widget.priceFormatter != null) return widget.priceFormatter!(a);
    final formatted = HelperUtils.formatPrice(a.price);
    final currency = (a.currency ?? '').trim();

    if (currency.isEmpty) {
      return formatted;
    }
    if (formatted.isEmpty) {
      return currency;
    }

    return '$formatted $currency';
  }

  String? _imageOf(ItemModel ad) => widget.imageUrlResolver?.call(ad);

  Future<void> _applyMapStyle() async {
    if (!widget.applyAppMapStyle || _controller == null) return;
    final brightness = Theme.of(context).brightness;
    if (_cachedBrightness == brightness) return;
    _cachedBrightness = brightness;
    await _controller?.setMapStyle(null); // ضع JSON لستايل مخصّص إن رغبت
  }

  Future<void> _animateToUser({double zoom = 14}) async {
    if (_isValidLatLng(widget.userLatLng)) {
      await _controller?.animateCamera(
        CameraUpdate.newLatLngZoom(widget.userLatLng!, zoom),
      );
      HelperUtils.showSnackBarMessage(context, "تم التمركز حول موقعك");
    } else {
      HelperUtils.showSnackBarMessage(context, "موقعك غير متاح حاليًا");
    }
  }

  Future<void> _fitToMarkers() async {
    if (_markers.isEmpty || _controller == null) return;
    final pts = _markers.map((m) => m.position).toList();
    if (pts.length == 1) {
      await _controller!
          .animateCamera(CameraUpdate.newLatLngZoom(pts.first, 14));
      return;
    }
    double? minLat, maxLat, minLng, maxLng;
    for (final p in pts) {
      minLat = (minLat == null) ? p.latitude : math.min(minLat, p.latitude);
      maxLat = (maxLat == null) ? p.latitude : math.max(maxLat, p.latitude);
      minLng = (minLng == null) ? p.longitude : math.min(minLng, p.longitude);
      maxLng = (maxLng == null) ? p.longitude : math.max(maxLng, p.longitude);
    }
    final bounds = LatLngBounds(
      southwest: LatLng(minLat!, minLng!),
      northeast: LatLng(maxLat!, maxLng!),
    );
    await _controller!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60));
  }

  // ----------------- إعادة بناء الماركرات/الدوائر حسب الفلاتر -----------------

  Future<void> _rebuildMarkers() async {
    final brand = context.color.territoryColor;

    if (widget.ads == null) {
      // لا يوجد ads: استخدم markers كما هي، وأضِف دائرة موقع المستخدم
      _circles..clear();
      if (_isValidLatLng(widget.userLatLng)) {
        _circles.add(Circle(
          circleId: const CircleId('user_circle'),
          center: widget.userLatLng!,
          radius: 120, // دائرة صغيرة لتأكيد الموقع
          fillColor: Colors.blueAccent.withOpacity(.18),
          strokeColor: Colors.blueAccent.withOpacity(.45),
          strokeWidth: 2,
        ));
      }
      setState(() {});
      return;
    }

    final ads = widget.ads!;
    _totalValidAds =
        ads.where((a) => a.latitude != null && a.longitude != null).length;

    // فلتر الفئة
    final byCat = (widget.activeCategory == null ||
            widget.activeCategory == 'الكل')
        ? ads
        : ads
            .where((a) =>
                normalizeCategory(_categoryLabel(a)) == widget.activeCategory)
            .toList();

    // فلتر نطاق البحث
    List<ItemModel> afterRadius = byCat;
    if (_radiusOn && widget.userLatLng != null) {
      afterRadius = byCat.where((a) {
        if (a.latitude == null || a.longitude == null) return false;
        return _distanceKm(
                widget.userLatLng!, LatLng(a.latitude!, a.longitude!)) <=
            _radiusKm;
      }).toList();
    }

    // فلتر المنطقة الظاهرة على الشاشة
    List<ItemModel> afterViewport = afterRadius;
    if (_viewportFilterOn && _lastViewportBounds != null) {
      final b = _lastViewportBounds!;
      afterViewport = afterRadius.where((a) {
        if (a.latitude == null || a.longitude == null) return false;
        return _boundsContains(b, LatLng(a.latitude!, a.longitude!));
      }).toList();
    }

    // بناء الماركرات
    final used = <String>{};
    final built = <Marker>{};

    // دائرة موقع المستخدم
    final cs = <Circle>{};
    if (_isValidLatLng(widget.userLatLng)) {
      cs.add(Circle(
        circleId: const CircleId('user_circle'),
        center: widget.userLatLng!,
        radius: 120,
        fillColor: Colors.blueAccent.withOpacity(.18),
        strokeColor: Colors.blueAccent.withOpacity(.45),
        strokeWidth: 2,
      ));
    }
    // دائرة نطاق البحث (مميّزة بلون الهوية)
    if (_radiusOn && _isValidLatLng(widget.userLatLng)) {
      cs.add(Circle(
        circleId: const CircleId('search_radius'),
        center: widget.userLatLng!,
        radius: _radiusKm * 1000,
        fillColor: brand.withOpacity(.12),
        strokeColor: brand.withOpacity(.55),
        strokeWidth: 3,
      ));
    }

    final selectedId = _selectedAd?.id;

    for (final ad in afterViewport) {
      if (ad.latitude == null || ad.longitude == null) continue;
      final pos = LatLng(ad.latitude!, ad.longitude!);

      var id = 'ad_${ad.id}';
      int idx = 0;
      while (used.contains(id)) {
        idx++;
        id = 'ad_${ad.id}_$idx';
      }
      used.add(id);

      final priceLabel = _formatPrice(ad).isEmpty ? '—' : _formatPrice(ad);
      final icon = await _markerFactory.realEstateMarker(
        context: context,
        priceLabel: priceLabel,
        selected: (selectedId != null && ad.id == selectedId),
        brand: brand,
      );

      built.add(Marker(
        markerId: MarkerId(id),
        position: pos,
        icon: icon,
        infoWindow:
            const InfoWindow(), // نستخدم بطاقة التفاصيل السفلية بدل InfoWindow
        onTap: () {
          setState(() => _selectedAd = ad);
          HelperUtils.showSnackBarMessage(
            context,
            "تم اختيار إعلان • اسحب لأعلى البطاقة لعرض التفاصيل",
            messageDuration: 2,
          );
        },
      ));
    }

    // Pin مؤقت
    if (_tempPin != null) built.add(_tempPin!);

    setState(() {
      _markers
        ..clear()
        ..addAll(built);
      _circles
        ..clear()
        ..addAll(cs);

      _currentShownCount = afterViewport
          .where((a) => a.latitude != null && a.longitude != null)
          .length;
      _visibleAds = afterViewport;
    });
  }

  // ----------------- أفعال الفلاتر -----------------

  Future<void> _applyViewportSearch() async {
    _lastViewportBounds = await _getVisibleRegion();
    if (widget.onSearchThisArea != null && _lastViewportBounds != null) {
      widget.onSearchThisArea!(_lastViewportBounds!);
    }
    setState(() {
      _viewportFilterOn = true;
      _showSearchAreaBtn = false;
    });
    await _rebuildMarkers();

    HelperUtils.showSnackBarMessage(
      context,
      "تم تفعيل \"بحث في هذه المنطقة\" • المعروض: $_currentShownCount / $_totalValidAds\n"
      "النتائج الآن حسب النطاق المرئي. لإلغاء التصفية استخدم زر (إلغاء) بجوار العداد.",
      messageDuration: 4,
    );
  }

  Future<void> _clearViewportFilter({bool withSnack = true}) async {
    setState(() {
      _viewportFilterOn = false;
    });
    await _rebuildMarkers();
    if (withSnack) {
      HelperUtils.showSnackBarMessage(context, "تم إلغاء بحث في هذه المنطقة");
    }
  }

  void _handleLongPress(LatLng at) async {
    _tempPin = Marker(
      markerId: const MarkerId('temp_pin'),
      position: at,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      infoWindow: const InfoWindow(title: 'نقطة مختارة'),
    );
    await _rebuildMarkers();
    HelperUtils.showSnackBarMessage(context, "تم تحديد نقطة على الخريطة");
  }

  // ===================================================================
  // البناء
  // ===================================================================

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _applyMapStyle());

    final brand = context.color.territoryColor;
    final hasResults =
        (widget.ads != null) ? _currentShownCount > 0 : _markers.isNotEmpty;

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: widget.initialCameraPosition,
          onMapCreated: (c) async {
            _controller = c;
            widget.onMapCreated(c);

            await _applyMapStyle();
            await _rebuildMarkers();

            // تمركز أولي على موقع المستخدم إن وُجد
            if (_isValidLatLng(widget.userLatLng)) {
              await _controller!.moveCamera(
                CameraUpdate.newLatLngZoom(widget.userLatLng!, 13),
              );
            } else {
              await _fitToMarkers();
            }
          },
          markers: _markers,
          circles: _circles,
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          compassEnabled: true,
          mapToolbarEnabled: false,
          mapType: _mapType,
          onLongPress: _handleLongPress,
          onCameraIdle: () async {
            if (!widget.enableViewportSearch) return;
            _idleTimer?.cancel();
            _idleTimer = Timer(const Duration(milliseconds: 450), () async {
              final b = await _getVisibleRegion();
              if (b == null) return;
              setState(() => _showSearchAreaBtn = true);
            });
          },
        ),

        // شريط علوي: عدّاد + فلاتر + زر إلغاء
        SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _TopInfoBar(
                totalValidAds: _totalValidAds,
                currentShownCount: _currentShownCount,
                activeCategory: widget.activeCategory,
                viewportOn: _viewportFilterOn,
                radiusOn: _radiusOn && widget.userLatLng != null,
                radiusKm: _radiusKm,
                onClearAll: () async {
                  await _clearViewportFilter(withSnack: false);
                  setState(() => _radiusOn = false);
                  await _rebuildMarkers();
                  HelperUtils.showSnackBarMessage(
                      context, "تم إلغاء جميع محددات النطاق");
                },
              ),
            ),
          ),
        ),

        // زر "بحث في هذه المنطقة"
        if (_showSearchAreaBtn && widget.enableViewportSearch)
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 52),
                child: ElevatedButton.icon(
                  onPressed: _applyViewportSearch,
                  icon: const Icon(Icons.manage_search_rounded),
                  label: const Text('بحث في هذه المنطقة'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brand,
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                  ),
                ),
              ),
            ),
          ),

        // لا توجد نتائج
        if (!hasResults) const _NoResultsOverlay(),

        // بطاقات أفقية عند تفعيل أي نطاق/منطقة
        if ((_viewportFilterOn || (_radiusOn && widget.userLatLng != null)) &&
            _visibleAds.isNotEmpty)
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                height: 140,
                child: _HorizontalAdStrip(
                  ads: _visibleAds,
                  imageUrlResolver: _imageOf,
                  priceFormatter: _formatPrice,
                  onTapCard: (ad) async {
                    if (ad.latitude != null && ad.longitude != null) {
                      await _controller?.animateCamera(
                        CameraUpdate.newLatLngZoom(
                            LatLng(ad.latitude!, ad.longitude!), 15),
                      );
                      setState(() => _selectedAd = ad);
                    }
                  },
                ),
              ),
            ),
          ),

        // بطاقة التفاصيل السفلية
        _BottomDetailsSheet(
          open: _detailsOpen,
          ad: _selectedAd,
          imageUrlResolver: _imageOf,
          priceFormatter: _formatPrice,
          onClose: () => setState(() => _selectedAd = null),
          onOpenDetails: () {
            if (_selectedAd == null) return;
            if (widget.onOpenAdDetails != null) {
              widget.onOpenAdDetails!(_selectedAd!);
            } else {
              HelperUtils.showSnackBarMessage(
                  context, "اربط onOpenAdDetails لفتح صفحة التفاصيل");
            }
          },
        ),

        // أزرار يمين-أسفل: نوع الخريطة، موقعي، نطاق البحث
        SafeArea(
          child: Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 12, bottom: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _MiniFab(
                    icon: Icons.layers_rounded,
                    tooltip: 'نوع الخريطة',
                    onTap: () {
                      setState(() {
                        switch (_mapType) {
                          case MapType.normal:
                            _mapType = MapType.hybrid;
                            break;
                          case MapType.hybrid:
                            _mapType = MapType.terrain;
                            break;
                          case MapType.terrain:
                            _mapType = MapType.normal;
                            break;
                          default:
                            _mapType = MapType.normal;
                        }
                      });
                      HelperUtils.showSnackBarMessage(
                          context, "تم تغيير نوع الخريطة");
                    },
                  ),
                  const SizedBox(height: 8),
                  _MiniFab(
                    icon: Icons.my_location_rounded,
                    tooltip: 'العودة لموقعي',
                    onTap: _animateToUser,
                  ),
                  if (widget.enableRadiusFilter &&
                      widget.userLatLng != null) ...[
                    const SizedBox(height: 8),
                    _MiniFab(
                      icon: Icons.radio_button_checked_rounded,
                      tooltip:
                          _radiusOn ? 'تعديل نطاق البحث' : 'تفعيل نطاق البحث',
                      onTap: () async {
                        _radiusOn = true;
                        await showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor:
                              Theme.of(context).scaffoldBackgroundColor,
                          shape: const RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.vertical(top: Radius.circular(18)),
                          ),
                          builder: (_) => _RadiusSheet(
                            radiusKm: _radiusKm,
                            onChanged: (v) => setState(() => _radiusKm = v),
                            onDisable: () {
                              setState(() => _radiusOn = false);
                              Navigator.pop(context);
                              _rebuildMarkers();
                              HelperUtils.showSnackBarMessage(
                                  context, "تم تعطيل نطاق البحث");
                            },
                            onApply: () {
                              Navigator.pop(context);
                              _rebuildMarkers();
                              HelperUtils.showSnackBarMessage(
                                context,
                                "تم تطبيق نطاق ${_radiusKm.toStringAsFixed(0)} كم • المعروض: $_currentShownCount / $_totalValidAds\n"
                                "النتائج الآن حسب النطاق المحدد. لإلغاء، استخدم زر (إلغاء) بجوار العداد.",
                                messageDuration: 4,
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ===================================================================
// مكونات UI صغيرة (Top bar / FAB / No results / Bottom sheet / Strip)
// ===================================================================

class _TopInfoBar extends StatelessWidget {
  final int totalValidAds;
  final int currentShownCount;
  final String? activeCategory;
  final bool viewportOn;
  final bool radiusOn;
  final double radiusKm;
  final VoidCallback onClearAll;

  const _TopInfoBar({
    required this.totalValidAds,
    required this.currentShownCount,
    required this.activeCategory,
    required this.viewportOn,
    required this.radiusOn,
    required this.radiusKm,
    required this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    final text = 'المعروض: $currentShownCount / $totalValidAds';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withOpacity(.96),
        borderRadius: BorderRadius.circular(24),
        border:
            Border.all(color: Theme.of(context).dividerColor.withOpacity(.25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 4,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.apartment_rounded,
                  size: 16, color: context.color.textDefaultColor),
              const SizedBox(width: 6),
              Text(
                text,
                style: TextStyle(
                  color: context.color.textDefaultColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          if (activeCategory != null && activeCategory != 'الكل')
            _chip(context, activeCategory!),
          if (viewportOn) _chip(context, 'بحث في هذه المنطقة'),
          if (radiusOn)
            _chip(context, 'نطاق ${radiusKm.toStringAsFixed(0)} كم'),
          if (viewportOn || radiusOn) _cancelChip(context, onTap: onClearAll),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).chipTheme.backgroundColor ??
              Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
              color: Theme.of(context).dividerColor.withOpacity(.25)),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 11.5,
            color: context.color.textDefaultColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      );

  Widget _cancelChip(BuildContext context, {required VoidCallback onTap}) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: context.color.territoryColor.withOpacity(.65), width: 1),
          ),
          child: Text(
            'إلغاء',
            style: TextStyle(
              color: context.color.territoryColor,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
      );
}

class _MiniFab extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _MiniFab(
      {required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: '${icon.codePoint}_fab',
      mini: true,
      tooltip: tooltip,
      onPressed: onTap,
      backgroundColor: Theme.of(context).cardColor,
      foregroundColor: context.color.textDefaultColor,
      elevation: 2,
      child: Icon(icon),
    );
  }
}

class _NoResultsOverlay extends StatelessWidget {
  const _NoResultsOverlay();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor.withOpacity(.98),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: Theme.of(context).dividerColor.withOpacity(.25)),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, size: 32),
            SizedBox(height: 8),
            Text('لا توجد إعلانات ضمن الإعدادات الحالية'),
          ],
        ),
      ),
    );
  }
}

class _BottomDetailsSheet extends StatelessWidget {
  final bool open;
  final ItemModel? ad;
  final ImageUrlResolver? imageUrlResolver;
  final PriceFormatter priceFormatter;
  final VoidCallback onClose;
  final VoidCallback onOpenDetails;

  const _BottomDetailsSheet({
    required this.open,
    required this.ad,
    required this.imageUrlResolver,
    required this.priceFormatter,
    required this.onClose,
    required this.onOpenDetails,
  });

  @override
  Widget build(BuildContext context) {
    final brand = context.color.territoryColor;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      left: 0,
      right: 0,
      bottom: open ? 0 : -240,
      child: SafeArea(
        top: false,
        child: Container(
          height: 200,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor.withOpacity(.98),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.12),
                blurRadius: 12,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: (ad == null)
              ? const SizedBox.shrink()
              : Row(
                  children: [
                    // صورة
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: _previewImage(context, ad),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // نصوص + أزرار
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _AutoScrollText(
                            text: ad!.name ?? 'إعلان عقاري',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: context.color.textDefaultColor,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            priceFormatter(ad!),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: brand,
                              fontSize: 14,
                            ),
                          ),
                          const Spacer(),
                          Row(
                            children: [
                              OutlinedButton.icon(
                                onPressed: onClose,
                                icon: const Icon(Icons.close),
                                label: const Text('إغلاق'),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: onOpenDetails,
                                icon: const Icon(Icons.open_in_new_rounded),
                                label: const Text('تفاصيل الإعلان'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: brand,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _previewImage(BuildContext context, ItemModel? ad) {
    final url = (ad == null) ? null : imageUrlResolver?.call(ad);
    if (url != null && url.isNotEmpty) {
      return Image.network(url, fit: BoxFit.cover);
    }
    return Container(
      color: Theme.of(context).dividerColor.withOpacity(.15),
      child: const Icon(Icons.image, size: 36),
    );
  }
}

class _HorizontalAdStrip extends StatelessWidget {
  final List<ItemModel> ads;
  final ImageUrlResolver? imageUrlResolver;
  final PriceFormatter priceFormatter;
  final ValueChanged<ItemModel> onTapCard;

  const _HorizontalAdStrip({
    required this.ads,
    required this.imageUrlResolver,
    required this.priceFormatter,
    required this.onTapCard,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemBuilder: (_, i) {
        final ad = ads[i];
        return _AdThumbCard(
          ad: ad,
          imageUrl: imageUrlResolver?.call(ad),
          price: priceFormatter(ad),
          onTap: () => onTapCard(ad),
        );
      },
      separatorBuilder: (_, __) => const SizedBox(width: 10),
      itemCount: ads.length.clamp(0, 30),
    );
  }
}

class _AdThumbCard extends StatelessWidget {
  final ItemModel ad;
  final String? imageUrl;
  final String price;
  final VoidCallback onTap;

  const _AdThumbCard({
    required this.ad,
    required this.imageUrl,
    required this.price,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final brand = context.color.territoryColor;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor.withOpacity(.98),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: Theme.of(context).dividerColor.withOpacity(.25)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: AspectRatio(
                aspectRatio: 1,
                child: (imageUrl != null && imageUrl!.isNotEmpty)
                    ? Image.network(imageUrl!, fit: BoxFit.cover)
                    : Container(
                        color: Theme.of(context).dividerColor.withOpacity(.15),
                        child: const Icon(Icons.image, size: 28),
                      ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _AutoScrollText(
                    text: ad.name ?? 'إعلان عقاري',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    gap: 30,
                  ),
                  const Spacer(),
                  Text(
                    price.isEmpty ? '—' : price,
                    style: TextStyle(fontWeight: FontWeight.w700, color: brand),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===================================================================
// شاشة "حدد نطاق البحث (كم)" — DraggableScrollableSheet
// ===================================================================

class _RadiusSheet extends StatelessWidget {
  final double radiusKm;
  final ValueChanged<double> onChanged;
  final VoidCallback onDisable;
  final VoidCallback onApply;

  const _RadiusSheet({
    required this.radiusKm,
    required this.onChanged,
    required this.onDisable,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    final brand = context.color.territoryColor;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.36,
      minChildSize: 0.28,
      maxChildSize: 0.6,
      builder: (_, controller) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          ),
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).dividerColor.withOpacity(.4),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text('حدد نطاق البحث (كم)',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.onSurface,
                  )),
              const SizedBox(height: 12),
              Slider(
                value: radiusKm.clamp(1, 50),
                onChanged: onChanged,
                min: 1,
                max: 50,
                divisions: 49,
                label: '${radiusKm.toStringAsFixed(0)} كم',
                activeColor: brand,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('1 كم',
                      style: TextStyle(color: Theme.of(context).hintColor)),
                  Text('${radiusKm.toStringAsFixed(0)} كم',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, color: brand)),
                  Text('50 كم',
                      style: TextStyle(color: Theme.of(context).hintColor)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onDisable,
                      child: const Text('تعطيل'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onApply,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: brand,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('تطبيق'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ===================================================================
// نص متحرّك تلقائي إذا كان أطول من العرض
// ===================================================================

class _AutoScrollText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final double gap;

  const _AutoScrollText(
      {required this.text, this.style, this.gap = 40, Key? key})
      : super(key: key);

  @override
  State<_AutoScrollText> createState() => _AutoScrollTextState();
}

class _AutoScrollTextState extends State<_AutoScrollText> {
  final _ctrl = ScrollController();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _kickoff());
  }

  void _kickoff() {
    if (!_ctrl.hasClients) return;
    if (_ctrl.position.maxScrollExtent <= 0) return;

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (!_ctrl.hasClients) return;
      await _ctrl.animateTo(_ctrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 1200),
          curve: Curves.easeInOut);
      await Future.delayed(const Duration(milliseconds: 400));
      if (!_ctrl.hasClients) return;
      await _ctrl.animateTo(0,
          duration: const Duration(milliseconds: 1200),
          curve: Curves.easeInOut);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _ctrl,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Row(
        children: [
          Text(widget.text, style: widget.style, maxLines: 1),
          SizedBox(width: widget.gap),
          Text(widget.text, style: widget.style, maxLines: 1),
        ],
      ),
    );
  }
}

// ===================================================================
/* مصنع الماركرات: يرسم Pin منزل + شارة السعر على Canvas ثم يحولها Bitmap */
// ===================================================================

class _MarkerFactory {
  final Map<String, BitmapDescriptor> _cache = {};

  Future<BitmapDescriptor> realEstateMarker({
    required BuildContext context,
    required String priceLabel,
    required bool selected,
    required Color brand,
  }) async {
    // ✅ هنا كان الخطأ: selected_ -> selected
    final key =
        '${priceLabel}_${selected}_${brand.value}_${Theme.of(context).brightness}';

    if (_cache.containsKey(key)) return _cache[key]!;

    // أبعاد الرسم
    const double pinH = 66;
    const double pinW = 46;
    const double badgeH = 24;
    const double badgePad = 6;
    const double pinToBadgeSpace = 6;

    // قياس نص الشارة
    final ui.ParagraphBuilder pb = ui.ParagraphBuilder(
      ui.ParagraphStyle(fontSize: 12, textDirection: ui.TextDirection.rtl),
    )
      ..pushStyle(
        ui.TextStyle(
          color: const ui.Color(0xffffffff),
          fontWeight: ui.FontWeight.w700,
        ),
      )
      ..addText(priceLabel);
    final ui.Paragraph paragraph = pb.build()
      ..layout(const ui.ParagraphConstraints(width: 140));
    final double textW = paragraph.maxIntrinsicWidth.clamp(32, 140);

    final totalW = pinW + pinToBadgeSpace + textW + badgePad * 2;
    final totalH = math.max(pinH, badgeH);

    final recorder = ui.PictureRecorder();
    final canvas =
        Canvas(recorder, Rect.fromLTWH(0, 0, totalW, totalH.toDouble()));

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pinColor = selected
        ? brand
        : (isDark ? const Color(0xFF2a7bff) : const Color(0xFF1e88e5));
    final badgeColor = selected
        ? brand
        : (isDark ? const Color(0xFF333333) : const Color(0xCC000000));

    // جسم الـ Pin
    final pinRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, pinW, pinH - 10),
      const Radius.circular(14),
    );
    final paintPin = Paint()..color = pinColor;
    canvas.drawRRect(pinRect, paintPin);

    // سنّة الـ Pin
    final path = Path()
      ..moveTo(pinW / 2 - 8, pinH - 10)
      ..lineTo(pinW / 2, pinH)
      ..lineTo(pinW / 2 + 8, pinH - 10)
      ..close();
    canvas.drawPath(path, paintPin);

    // أيقونة منزل
    final double houseX = pinW / 2 - 10;
    const double houseY = 10.0; // ✅ تأكد أنها double
    final roof = Path()
      ..moveTo(houseX + 10, houseY)
      ..lineTo(houseX + 20, houseY + 12)
      ..lineTo(houseX, houseY + 12)
      ..close();
    final housePaint = Paint()..color = Colors.white;
    canvas.drawPath(roof, housePaint);
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(houseX + 2, houseY + 12, 16, 14),
      const Radius.circular(3),
    );
    canvas.drawRRect(body, housePaint);

    // شارة السعر
    final badgeLeft = pinW + pinToBadgeSpace;
    final badgeRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
          badgeLeft, (totalH - badgeH) / 2, textW + badgePad * 2, badgeH),
      const Radius.circular(20),
    );
    final paintBadge = Paint()..color = badgeColor;
    canvas.drawRRect(badgeRect, paintBadge);

    // نص الشارة
    canvas.drawParagraph(
      paragraph,
      Offset(badgeLeft + badgePad, (totalH - paragraph.height) / 2),
    );

    final picture = recorder.endRecording();
    final img = await picture.toImage(totalW.ceil(), totalH.ceil());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    final desc = BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
    _cache[key] = desc;
    return desc;
  }
}
