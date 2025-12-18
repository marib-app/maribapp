import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:marib/ui/screens/widgets/video_view_screen.dart';
import 'package:marib/ui/theme/extensions/shimmer_colors.dart';
import 'package:marib/ui/widgets/shimmer/shimmer_box.dart';

import 'ad_image_source.dart';

class FullscreenGalleryPage extends StatefulWidget {
  final String? videoUrl;
  final String? videoThumbnail;
  final List<AdImageSource> images;

  final int initialIndex;
  final String Function(int index)? heroTagBuilder;

  const FullscreenGalleryPage({
    super.key,
    required this.images,
    this.videoUrl,
    this.videoThumbnail,
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
  double _dragOffset = 0;

  static const double _thumbSpacing = 8.0;
  double _lastThumbExtent = 0;
  bool _thumbDragging = false;

  bool get _hasVideo => (widget.videoUrl?.trim().isNotEmpty ?? false);
  int get _totalCount => widget.images.length + (_hasVideo ? 1 : 0);

  @override
  void initState() {
    super.initState();
    _currentIndex =
        _totalCount == 0 ? 0 : widget.initialIndex.clamp(0, _totalCount - 1);
    _controller = PageController(initialPage: _currentIndex);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _totalCount == 0) return;
      _ensureThumbVisible(_currentIndex, jump: true, itemExtent: _lastThumbExtent);
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
                  itemCount: _totalCount,
                  pageController: _controller,
                  backgroundDecoration:
                      const BoxDecoration(color: Colors.transparent),
                  onPageChanged: (index) {
                    setState(() => _currentIndex = index);
                    _ensureThumbVisible(index, itemExtent: _lastThumbExtent);
                    _prefetchNeighbors(index);
                  },
                  builder: (context, index) {
                    final bool isVideoIndex =
                        _hasVideo && index == _totalCount - 1;
                    if (isVideoIndex) {
                      return PhotoViewGalleryPageOptions.customChild(
                        child: _buildVideoSlide(),
                        minScale: PhotoViewComputedScale.contained,
                        maxScale: PhotoViewComputedScale.contained,
                      );
                    }

                    final int imageIndex = index;
                    final AdImageSource image = widget.images[imageIndex];
                    final String? tag = widget.heroTagBuilder?.call(imageIndex);
                    return PhotoViewGalleryPageOptions(
                      imageProvider: image.buildFullScreenProvider(),
                      heroAttributes:
                          tag != null ? PhotoViewHeroAttributes(tag: tag) : null,
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
                        "${_currentIndex + 1} / $_totalCount",
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
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              top: false,
              minimum: const EdgeInsets.only(bottom: 12),
              child: LayoutBuilder(
                builder: (context, cons) {
                  final l = _thumbLayout(cons);
                  _lastThumbExtent = l.itemExtent;

                  final stripHeight = l.itemH + l.padding.vertical + 12;

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
                              borderRadius: BorderRadius.all(Radius.circular(14)),
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
                            itemExtent: l.itemExtent,
                            itemCount: _totalCount,
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

  ({double itemW, double itemH, double itemExtent, EdgeInsets padding})
      _thumbLayout(BoxConstraints c) {
    final w = c.maxWidth;

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

  Widget _thumb(int i, {required double w, required double h}) {
    final selected = i == _currentIndex;
    final selColor = Theme.of(context).colorScheme.primary;

    Widget child;
    if (_hasVideo && i == _totalCount - 1) {
      final bool hasThumb =
          widget.videoThumbnail != null && widget.videoThumbnail!.isNotEmpty;
      child = Stack(
        fit: StackFit.expand,
        children: [
          if (hasThumb)
            CachedNetworkImage(
              imageUrl: widget.videoThumbnail!,
              fit: BoxFit.cover,
              placeholder: (_, __) => ShimmerBox(
                width: w,
                height: h,
                borderRadius: BorderRadius.circular(12),
              ),
              errorWidget: (_, __, ___) => Container(
                color: Colors.black26,
                child: const Icon(Icons.videocam_rounded,
                    color: Colors.white70, size: 22),
              ),
            ) 
          else
            Container(
              color: Colors.black26,
              child: const Icon(Icons.videocam_rounded,
                  color: Colors.white70, size: 22),
            ),
          const Center(
            child: Icon(Icons.play_arrow_rounded,
                color: Colors.white, size: 28),
          ),
        ],
      );
    } else {
      final int imageIndex = i;
      final AdImageSource image = widget.images[imageIndex];
      final String url = image.displayUrl;
      child = CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        memCacheWidth: kAdDetailImageMaxEdge,
        memCacheHeight: kAdDetailImageMaxEdge,
        maxWidthDiskCache: kAdDetailImageMaxEdge,
        maxHeightDiskCache: kAdDetailImageMaxEdge,
        placeholder: (_, __) => const ShimmerBox(
          width: double.infinity,
          height: double.infinity,
          borderRadius: BorderRadius.zero,
        ),
        errorWidget: (_, __, ___) => ShimmerBox(
          width: double.infinity,
          height: double.infinity,
          borderRadius: BorderRadius.zero,
          animate: false,
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        _controller.animateToPage(
          i,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
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
                    borderRadius: BorderRadius.circular(12),
                    child: child,
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

  Widget _buildVideoSlide() {
    final bool hasThumb =
        widget.videoThumbnail != null && widget.videoThumbnail!.isNotEmpty;

    Widget base;
    if (hasThumb) {
      base = CachedNetworkImage(
        imageUrl: widget.videoThumbnail!,
        fit: BoxFit.cover,
        placeholder: (_, __) => const ShimmerBox(
          width: double.infinity,
          height: double.infinity,
          borderRadius: BorderRadius.zero,
        ),
        errorWidget: (_, __, ___) => Container(
          color: Colors.black45,
          child: const Icon(Icons.videocam_rounded,
              color: Colors.white70, size: 56),
        ),
      );
    } else {
      base = Container(
        color: Colors.black45,
        child:
            const Icon(Icons.videocam_rounded, color: Colors.white70, size: 56),
      );
    }

    return GestureDetector(
      onTap: _openVideo,
      child: Stack(
        fit: StackFit.expand,
        children: [
          base,
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black38, Colors.transparent, Colors.black54],
              ),
            ),
          ),
          Center(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white70, width: 1.6),
              ),
              child: const Icon(Icons.play_arrow_rounded,
                  color: Colors.white, size: 48),
            ),
          ),
        ],
      ),
    );
  }

  void _openVideo() {
    final String? url = widget.videoUrl?.trim();
    if (url == null || url.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VideoViewScreen(videoUrl: url),
      ),
    );
  }

  void _snapThumbsToNearest() {
    if (!_thumbCtrl.hasClients || _lastThumbExtent == 0) return;
    final rawIndex = _thumbCtrl.offset / _lastThumbExtent;
    final nearest = rawIndex.round().clamp(0, _totalCount - 1);
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
    final targetOffset =
        (i * extent) - (viewport - (extent - _thumbSpacing)) / 2;

    final clamped = targetOffset
        .clamp(
          _thumbCtrl.position.minScrollExtent,
          _thumbCtrl.position.maxScrollExtent,
        )
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

  void _prefetchNeighbors(int i) {
    Future<void> prefetch(AdImageSource image) async {
      try {
        await precacheImage(image.buildFullScreenProvider(), context);
      } catch (_) {}
    }

    void tryPrefetch(int galleryIndex) {
      if (_hasVideo && galleryIndex == _totalCount - 1) return;
      final int imageIndex = galleryIndex;
      if (imageIndex < 0 || imageIndex >= widget.images.length) return;
      prefetch(widget.images[imageIndex]);
    }

    tryPrefetch(i - 1);
    tryPrefetch(i + 1);
  }
}
