// شاشة عرض الخريطة في تفاصيل الاعلان

// GoogleMapScreen — إصلاح تفعيل الأزرار + تلميح نصي فوق الماركر

import 'dart:async';
import 'package:flutter/foundation.dart' as f;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/data/model/item/item_model.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:marib/settings.dart';
import 'package:shimmer/shimmer.dart';

class GoogleMapScreen extends StatefulWidget {
  const GoogleMapScreen({
    super.key,
    required this.item,
    required CameraPosition kInitialPlace,
    required Completer<GoogleMapController> controller,
  })  : _kInitialPlace = kInitialPlace,
        _controller = controller;

  final ItemModel? item;
  final CameraPosition _kInitialPlace;
  final Completer<GoogleMapController> _controller;

  @override
  State<GoogleMapScreen> createState() => _GoogleMapScreenState();
}

class _GoogleMapScreenState extends State<GoogleMapScreen> {
  bool _mapReady = false;
  late MapType _mapType;

  bool _isPopping = false;

  Future<void> _handleBack() async {
    if (_isPopping) return; // حارس يمنع الرجوع مرتين
    _isPopping = true;
    if (mounted) setState(() => _mapReady = false);
    await Navigator.maybePop(context);
    _isPopping = false;
  }

  GoogleMapController? _mapController; // ← مرجع محلي فوري

  LatLng get _pos => LatLng(
        widget.item?.latitude ?? 0,
        widget.item?.longitude ?? 0,
      );

  bool get _hasValidLatLng =>
      (widget.item?.latitude != null && widget.item?.longitude != null);

  final Set<Marker> _markers = {};
  final Set<Circle> _circles = {};
  static const MarkerId _markerId = MarkerId('adLocation');

  @override
  void initState() {
    super.initState();
    _mapType = AppSettings.googleMapType;
    if (_hasValidLatLng) _buildMarkerAndCircle();
  }

  @override
  void didUpdateWidget(covariant GoogleMapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item?.latitude != widget.item?.latitude ||
        oldWidget.item?.longitude != widget.item?.longitude) {
      _buildMarkerAndCircle();
      _recenter();
    }
  }

  void _buildMarkerAndCircle() {
    if (!_hasValidLatLng) return;

    _markers
      ..clear()
      ..add(
        Marker(
          markerId: _markerId,
          position: _pos,
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          infoWindow: const InfoWindow(
            title: 'هذا موقع الإعلان',
          ),
        ),
      );

    _circles
      ..clear()
      ..add(
        Circle(
          circleId: const CircleId('adHalo'),
          center: _pos,
          radius: 35,
          strokeWidth: 2,
          strokeColor: Colors.orange.withOpacity(.7),
          fillColor: Colors.orange.withOpacity(.15),
        ),
      );

    if (mounted) setState(() {});
  }

  void _haptic() => HapticFeedback.selectionClick();

  void _notify(String msg) => HelperUtils.showSnackBarMessage(context, msg);

  GoogleMapController? get _ctrlNow => _mapController;

  Future<void> _recenter() async {
    if (!_hasValidLatLng) return;
    final c = _ctrlNow ??
        (widget._controller.isCompleted
            ? await widget._controller.future
            : null);
    if (c == null) return;
    await c.animateCamera(
      CameraUpdate.newCameraPosition(CameraPosition(target: _pos, zoom: 16)),
    );
    // إظهار التلميح النصّي فوق الماركر تلقائيًا
    await Future.delayed(const Duration(milliseconds: 120));
    c.showMarkerInfoWindow(_markerId);
    _haptic();
    _notify('تمت إعادة التمركز على موقع الإعلان');
  }

  Future<void> _zoomIn() async {
    final c = _ctrlNow ??
        (widget._controller.isCompleted
            ? await widget._controller.future
            : null);
    if (c == null) return;
    await c.animateCamera(CameraUpdate.zoomIn());
    _haptic();
  }

  Future<void> _zoomOut() async {
    final c = _ctrlNow ??
        (widget._controller.isCompleted
            ? await widget._controller.future
            : null);
    if (c == null) return;
    await c.animateCamera(CameraUpdate.zoomOut());
    _haptic();
  }

  Future<void> _toggleMapType() async {
    setState(() {
      _mapType = (_mapType == MapType.normal) ? MapType.hybrid : MapType.normal;
    });
    _haptic();
    _notify(_mapType == MapType.hybrid ? 'وضع هجين (قمر اصطناعي)' : 'وضع عادي');
  }

  Future<void> _openInExternalMaps() async {
    if (!_hasValidLatLng) return;
    final lat = widget.item!.latitude!;
    final lng = widget.item!.longitude!;
    final label = Uri.encodeComponent(widget.item?.name ?? 'الموقع');
    final uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$lat,$lng&query_label=$label');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      _haptic();
    } else {
      _notify('تعذّر فتح تطبيق الخرائط');
    }
  }

  @override
  Widget build(BuildContext context) {
    // AppBar موحّد للحالتين
    final appBar = UiUtils.buildAppBar(
      context,
      showBackButton: true,
      title: 'تفاصيل الموقع الجغرافي',
      onBackPress: _handleBack, // حارس يمنع الرجوع مرتين
    );

    // حالة: لا توجد إحداثيات
    if (!_hasValidLatLng) {
      return PopScope(
        canPop: true, // السماح للنظام بإدارة الرجوع
        onPopInvoked: (didPop) {
          if (didPop && mounted) {
            setState(() => _mapReady = false); // تنظيف فقط
          }
        },
        child: Scaffold(
          appBar: appBar,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(18.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.location_off, size: 48),
                  const SizedBox(height: 12),
                  const Text('لا تتوفر إحداثيات لهذا الإعلان'),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _handleBack, // بدّلناها بالحارس
                    child: const Text('رجوع'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // حالة: توجد إحداثيات
    return PopScope(
      canPop: true, // لا نعمل pop يدوي؛ النظام يتولى
      onPopInvoked: (didPop) {
        if (didPop && mounted) {
          setState(() => _mapReady = false); // تنظيف فقط
        }
      },
      child: Scaffold(
        appBar: appBar, // نفس الـ AppBar الموحد
        body: Stack(
          children: [
            GoogleMap(
              initialCameraPosition: widget._kInitialPlace,
              mapType: _mapType,
              markers: _markers,
              circles: _circles,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              compassEnabled: true,
              tiltGesturesEnabled: true,
              rotateGesturesEnabled: true,
              gestureRecognizers: <f.Factory<OneSequenceGestureRecognizer>>{
                f.Factory(() => EagerGestureRecognizer()),
              },
              onMapCreated: (GoogleMapController controller) async {
                _mapController = controller;
                if (!widget._controller.isCompleted) {
                  widget._controller.complete(controller);
                }
                await Future.delayed(const Duration(milliseconds: 120));
                if (mounted) setState(() => _mapReady = true);
                await _recenter();
              },
            ),

            // طبقة تحميل لا تمنع لمس الأزرار
            if (!_mapReady)
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: true,
                  child: Container(
                    color: Colors.black.withOpacity(.06),
                    child: Center(child: UiUtils.progress()),
                  ),
                ),
              ),

            // بطاقة علوية (صورة + اسم + سعر)
            Positioned(
              top: 14,
              left: 14,
              right: 14,
              child: SafeArea(
                child: Align(
                  alignment: AlignmentDirectional.topStart,
                  child: _HeaderCard(
                    title: widget.item?.name ?? 'إعلان',
                    priceLabel: (widget.item?.price != null)
                        ? '${widget.item!.price} ${widget.item?.currency ?? ''}'
                            .trim()
                        : '—',
                    imageUrl:
                        widget.item?.image, // عدّلها لاسم حقلك الفعلي إذا لزم
                  ),
                ),
              ),
            ),

            // أزرار التحكم (بدون زر فتح الخرائط)
            Positioned(
              right: 16,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _MapFab(
                    tooltip: 'تبديل نوع الخريطة',
                    icon: Icons.layers_outlined,
                    onPressed: _toggleMapType,
                  ),
                  const SizedBox(height: 10),
                  _MapFab(
                    tooltip: 'إعادة تمركز',
                    icon: Icons.my_location_rounded,
                    onPressed: _recenter,
                  ),
                  const SizedBox(height: 16),
                  _ZoomPill(onZoomIn: _zoomIn, onZoomOut: _zoomOut),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// زر دائري متوافق مع الثيم
class _MapFab extends StatelessWidget {
  final IconData icon;
  final String? tooltip;
  final VoidCallback onPressed;
  const _MapFab({required this.icon, required this.onPressed, this.tooltip});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final bg = isDark ? cs.surfaceContainerHighest : Colors.white;
    final fg = isDark ? Colors.white : Colors.grey[800];

    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: bg,
        elevation: 3,
        shape: const CircleBorder(),
        shadowColor: Colors.black26,
        child: InkWell(
          customBorder: const CircleBorder(),
          overlayColor: WidgetStateProperty.all(cs.primary.withOpacity(.1)),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Icon(icon, size: 20, color: fg),
          ),
        ),
      ),
    );
  }
}

// كبسولة تكبير/تصغير متوافقة مع الثيم
class _ZoomPill extends StatelessWidget {
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  const _ZoomPill({
    required this.onZoomIn,
    required this.onZoomOut,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final bg = isDark ? cs.surfaceContainerHighest : Colors.white;
    final fg = isDark ? Colors.white : Colors.grey[800];

    return Material(
      color: bg,
      elevation: 3,
      borderRadius: BorderRadius.circular(14),
      shadowColor: Colors.black26,
      child: Column(
        children: [
          Tooltip(
            message: 'تكبير الخريطة',
            waitDuration: const Duration(milliseconds: 300),
            child: InkWell(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
              overlayColor: WidgetStateProperty.all(cs.primary.withOpacity(.1)),
              onTap: onZoomIn,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Icon(Icons.add, size: 22, color: fg),
              ),
            ),
          ),
          const Divider(height: 1),
          Tooltip(
            message: 'تصغير الخريطة',
            waitDuration: const Duration(milliseconds: 300),
            child: InkWell(
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(14)),
              overlayColor: WidgetStateProperty.all(cs.primary.withOpacity(.1)),
              onTap: onZoomOut,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Icon(Icons.remove, size: 22, color: fg),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final String title;
  final String priceLabel;
  final String? imageUrl;

  const _HeaderCard({
    required this.title,
    required this.priceLabel,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final cs = t.colorScheme;

    final isDark = t.brightness == Brightness.dark;

    // الخلفية والنص حسب الثيم
    final bgCard = isDark ? cs.surface : Colors.white;
    final textColor =
        isDark ? Colors.white.withOpacity(0.95) : Colors.grey[800];

    final priceBg = context.color.territoryColor;
    final priceFg = Colors.white;

    return Material(
      color: bgCard,
      elevation: 4,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant, width: 1),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // صورة الإعلان
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 72,
                height: 72,
                child: (imageUrl == null || imageUrl!.isEmpty)
                    ? _buildShimmer(context) // ← شيمر عند عدم وجود صورة
                    : Image.network(
                        imageUrl!,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return _buildShimmer(context); // ← شيمر أثناء التحميل
                        },
                        errorBuilder: (_, __, ___) =>
                            _buildShimmer(context), // ← عند الفشل
                      ),
              ),
            ),

            const SizedBox(width: 12),

            // العنوان (سطرين)
            Expanded(
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: t.textTheme.titleMedium?.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
            ),

            const SizedBox(width: 8),

            // شارة السعر
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: priceBg,
                borderRadius: BorderRadius.circular(999),
                boxShadow: const [
                  BoxShadow(
                      color: Colors.black12,
                      blurRadius: 6,
                      offset: Offset(0, 2)),
                ],
              ),
              constraints: const BoxConstraints(minHeight: 32),
              child: Text(
                priceLabel.isEmpty ? '—' : priceLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.textTheme.labelLarge?.copyWith(
                  color: priceFg,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _buildShimmer(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;

  final baseColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
  final highlightColor = isDark ? Colors.grey[700]! : Colors.grey[100]!;

  return Shimmer.fromColors(
    baseColor: baseColor,
    highlightColor: highlightColor,
    child: Container(
      color: baseColor,
    ),
  );
}
