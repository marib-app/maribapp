// معرض الصور المحسّن – تكبير سلس + سحب احترافي للإغلاق + شريط علوي ومصغّرات
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

class FullscreenGalleryPage extends StatefulWidget {
  final List<String?> images;
  final int initialIndex;
  // اختياري: هيرو تاج للانتقال السلس من القائمة
  final String Function(int index)? heroTagBuilder;

  const FullscreenGalleryPage({
    super.key,
    required this.images,
    this.initialIndex = 0,
    this.heroTagBuilder,
  });

  @override
  State<FullscreenGalleryPage> createState() => _FullscreenGalleryPageState();
}

class _FullscreenGalleryPageState extends State<FullscreenGalleryPage> {
  late final PageController _controller;
  final ScrollController _thumbCtrl = ScrollController();

  int _currentIndex = 0;

  // سحب للإغلاق لأعلى/أسفل
  double _dragOffset = 0;

  // ===== خصائص شريط المصغّرات (كما في النسخة الطويلة) =====
  static const double _thumbSpacing = 8.0;
  double _lastThumbExtent = 0; // itemExtent الأخير
  EdgeInsets _lastThumbPadding = EdgeInsets.zero;
  bool _thumbDragging = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.images.isEmpty
        ? 0
        : widget.initialIndex.clamp(0, widget.images.length - 1);
    _controller = PageController(initialPage: _currentIndex);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.images.isEmpty) return;
      _ensureThumbVisible(_currentIndex,
          jump: true, itemExtent: _lastThumbExtent);
      _prefetchNeighbors(_currentIndex);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _thumbCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ===== السحب للإغلاق + معرض بزووم جاهز =====
          GestureDetector(
            onVerticalDragUpdate: (details) {
              setState(() => _dragOffset += details.delta.dy);
            },
            onVerticalDragEnd: (_) {
              if (_dragOffset.abs() > 100) {
                Navigator.pop(context);
              } else {
                setState(() => _dragOffset = 0);
              }
            },
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: 1.0 - (_dragOffset.abs() / 200).clamp(0.0, 0.5),
              child: Transform.translate(
                offset: Offset(0, _dragOffset),
                child: PhotoViewGallery.builder(
                  itemCount: widget.images.length,
                  pageController: _controller,
                  backgroundDecoration:
                      const BoxDecoration(color: Colors.transparent),
                  onPageChanged: (index) {
                    setState(() => _currentIndex = index);
                    _ensureThumbVisible(index, itemExtent: _lastThumbExtent);
                    _prefetchNeighbors(index);
                  },
                  builder: (context, index) {
                    final url = widget.images[index]!;
                    final tag = widget.heroTagBuilder?.call(index);
                    return PhotoViewGalleryPageOptions(
                      imageProvider: CachedNetworkImageProvider(url),
                      heroAttributes: tag != null
                          ? PhotoViewHeroAttributes(tag: tag)
                          : null,
                      minScale: PhotoViewComputedScale.contained,
                      maxScale: PhotoViewComputedScale.covered * 3.0,
                      initialScale: PhotoViewComputedScale.contained,
                      filterQuality: FilterQuality.high,
                    );
                  },
                ),
              ),
            ),
          ),

          // ===== شريط علوي (إغلاق + عدّاد) =====
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.black.withOpacity(0.5)
                        : Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Spacer(),
                      Text(
                        "${_currentIndex + 1} / ${widget.images.length}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ===== شريط المصغّرات (النسخة الاحترافية) =====
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              top: false,
              minimum: const EdgeInsets.only(bottom: 12),
              child: LayoutBuilder(
                builder: (context, cons) {
                  final l = _thumbLayout(cons); // يحسب أبعاد العناصر ديناميكيًا
                  _lastThumbExtent = l.itemExtent;
                  _lastThumbPadding = l.padding;

                  final stripHeight =
                      l.itemH + l.padding.vertical + 12; // مؤشر أسفل المصغّر

                  return Container(
                    height: stripHeight,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(.30),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(.25),
                          blurRadius: 16,
                          spreadRadius: 2,
                        )
                      ],
                    ),
                    child: Stack(
                      children: [
                        const IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(14)),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Color(0x22000000), Colors.transparent],
                              ),
                            ),
                          ),
                        ),
                        NotificationListener<ScrollNotification>(
                          onNotification: (n) {
                            if (!_thumbCtrl.hasClients) return false;
                            if (n is ScrollStartNotification) {
                              _thumbDragging = true;
                            } else if (n is ScrollEndNotification) {
                              if (_thumbDragging) {
                                _thumbDragging = false;
                                _snapThumbsToNearest();
                              }
                            }
                            return false;
                          },
                          child: ListView.builder(
                            controller: _thumbCtrl,
                            padding: l.padding,
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            itemExtent: l.itemExtent,
                            itemCount: widget.images.length,
                            itemBuilder: (_, i) =>
                                _thumb(i, w: l.itemW, h: l.itemH),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ======= تخطيط المصغّرات ديناميكيًا =======
  ({double itemW, double itemH, double itemExtent, EdgeInsets padding})
      _thumbLayout(BoxConstraints c) {
    final w = c.maxWidth;

    // عدد المصغّرات الظاهر تقريبياً حسب العرض
    final visible = w < 360
        ? 4.5
        : w < 480
            ? 5.5
            : w < 768
                ? 6.5
                : 8.5;

    const gap = 8.0;
    const hPad = 10.0;
    const vPad = 8.0;

    final innerW = w - (hPad * 2);
    final rawItemW = (innerW - gap * (visible - 1)) / visible;

    // حدود منطقية حتى ما تصغر/تكبر زيادة
    final itemW = rawItemW.clamp(50.0, 88.0);
    final itemH = (itemW * 0.78).clamp(42.0, 80.0);
    final itemExtent = itemW + gap;

    return (
      itemW: itemW,
      itemH: itemH,
      itemExtent: itemExtent,
      padding: const EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
    );
  }

  // ======= عنصر المصغّر =======
  Widget _thumb(int i, {required double w, required double h}) {
    final selected = i == _currentIndex;
    final url = widget.images[i]!;
    final selColor = Theme.of(context).colorScheme.primary;

    return GestureDetector(
      onTap: () {
        _controller.animateToPage(
          i,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
        // HapticFeedback.selectionClick(); // فعّلها لو تبغى نبضة
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: selected ? 0 : 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: selected ? 1.0 : 0.92,
              duration: const Duration(milliseconds: 160),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: selColor.withOpacity(.40),
                            blurRadius: 14,
                            spreadRadius: 1,
                          ),
                          BoxShadow(
                            color: Colors.black.withOpacity(.30),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: Colors.black.withOpacity(.22),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                ),
                child: Container(
                  width: w,
                  height: h,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected ? selColor : Colors.white24,
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: CachedNetworkImage(
                      imageUrl: url,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(color: Colors.white10),
                      errorWidget: (_, __, ___) => const Icon(
                          Icons.broken_image_outlined,
                          color: Colors.white54),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            AnimatedOpacity(
              opacity: selected ? 1 : 0,
              duration: const Duration(milliseconds: 160),
              child: Container(
                width: 22,
                height: 3,
                decoration: BoxDecoration(
                  color: selColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ======= Snap + تمركز المصغّر المحدد =======
  void _snapThumbsToNearest() {
    if (!_thumbCtrl.hasClients || _lastThumbExtent == 0) return;
    final rawIndex = _thumbCtrl.offset / _lastThumbExtent;
    final nearest = rawIndex.round().clamp(0, widget.images.length - 1);
    _thumbCtrl.animateTo(
      nearest * _lastThumbExtent,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  void _ensureThumbVisible(int i, {bool jump = false, double? itemExtent}) {
    if (!_thumbCtrl.hasClients) return;
    final extent = itemExtent ?? _lastThumbExtent;
    if (extent == 0) return;

    final viewport = _thumbCtrl.position.viewportDimension;
    final targetOffset = (i * extent) -
        (viewport - (extent - _thumbSpacing)) / 2; // تمركز العنصر

    final clamped = targetOffset
        .clamp(_thumbCtrl.position.minScrollExtent,
            _thumbCtrl.position.maxScrollExtent)
        .toDouble();

    if (jump) {
      _thumbCtrl.jumpTo(clamped);
    } else {
      _thumbCtrl.animateTo(
        clamped,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeInOut,
      );
    }
  }

  // تهيئة تحميل صور الجيران لانتقال أنعم
  void _prefetchNeighbors(int i) {
    Future<void> prefetch(String url) async {
      try {
        await precacheImage(CachedNetworkImageProvider(url), context);
      } catch (_) {}
    }

    if (i - 1 >= 0) prefetch(widget.images[i - 1]!);
    if (i + 1 < widget.images.length) prefetch(widget.images[i + 1]!);
  }
}
