import 'dart:async';
import 'dart:math' as math;
import 'package:marib/data/model/item/item_model.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:marib/ui/theme/theme.dart';

import 'package:marib/utils/helper_utils.dart';
import 'package:marib/utils/extensions/extensions.dart';

import 'map_repository.dart' show normalizeCategory;
import 'components/bottom_details_sheet.dart';
import 'components/horizontal_ad_strip.dart';
import 'components/map_search_types.dart';
import 'components/marker_factory.dart';
import 'components/mini_fab.dart';
import 'components/no_results_overlay.dart';
import 'components/radius_sheet.dart';
import 'components/top_info_bar.dart';
export 'components/map_search_types.dart';

// ===================================================================
// واجهة الاستخدام العامة
// ===================================================================



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
  final Future<void> Function()? onLoadMore; // طلب صفحة إضافية
  final VoidCallback? onViewportFilterCleared; // عند إلغاء مرشح النطاق
  final bool hasMoreAds; // هل يوجد المزيد للتحميل
  final bool isLoadingMore; // مؤشر تحميل المزيد
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
    this.onLoadMore,
    this.onViewportFilterCleared,
    this.hasMoreAds = false,
    this.isLoadingMore = false,
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
  late final MarkerFactory _markerFactory = MarkerFactory();

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
          radius: 120,
          // دائرة صغيرة لتأكيد الموقع
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
        infoWindow: const InfoWindow(),
        // نستخدم بطاقة التفاصيل السفلية بدل InfoWindow
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
      _selectedAd = null;
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
      _selectedAd = null;
    });
    widget.onViewportFilterCleared?.call();
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
              child: TopInfoBar(
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
        if (!hasResults) const NoResultsOverlay(),

        // بطاقات أفقية عند تفعيل أي نطاق/منطقة
        if ((_viewportFilterOn || (_radiusOn && widget.userLatLng != null)) &&
            _visibleAds.isNotEmpty &&
            !_detailsOpen)

          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                height: 140,
                child: HorizontalAdStrip(
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
                  onLoadMore: widget.onLoadMore,
                  hasMore: widget.hasMoreAds,
                  isLoadingMore: widget.isLoadingMore,
                ),
              ),
            ),
          ),

        // بطاقة التفاصيل السفلية
        BottomDetailsSheet(
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
                  MiniFab(
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
                  MiniFab(
                    icon: Icons.my_location_rounded,
                    tooltip: 'العودة لموقعي',
                    onTap: _animateToUser,
                  ),
                  if (widget.enableRadiusFilter &&
                      widget.userLatLng != null) ...[
                    const SizedBox(height: 8),
                    MiniFab(
                      icon: Icons.radio_button_checked_rounded,
                      tooltip:
                          _radiusOn ? 'تعديل نطاق البحث' : 'تفعيل نطاق البحث',
                      onTap: () async {
                        setState(() {
                          _radiusOn = true;
                          _selectedAd = null;
                        });

                        await showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor:
                              Theme.of(context).scaffoldBackgroundColor,
                          shape: const RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.vertical(top: Radius.circular(18)),
                          ),
                          builder: (_) => RadiusSheet(
                            radiusKm: _radiusKm,
                            onChanged: (v) => setState(() => _radiusKm = v),
                            onDisable: () {
                              setState(() {
                                _radiusOn = false;
                                _selectedAd = null;
                              });

                              Navigator.pop(context);
                              _rebuildMarkers();
                              HelperUtils.showSnackBarMessage(
                                  context, "تم تعطيل نطاق البحث");
                            },
                            onApply: () {
                              Navigator.pop(context);
                              setState(() => _selectedAd = null);
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
