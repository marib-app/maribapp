import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';


import 'fullscreen_gallery.dart';
import 'package:marib/ui/screens/widgets/shimmerLoadingContainer.dart';
import 'ad_image_source.dart';
import 'package:marib/ui/widgets/shimmer/shimmer_box.dart';
import 'package:marib/app/navigation/app_page_route.dart';
import 'package:marib/app/navigation/motion/route_motion.dart';


class AdImagesHeaderShimmer extends StatelessWidget {
  const AdImagesHeaderShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 300,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(
            child: CustomShimmer(height: 300, borderRadius: 0),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const _HeaderCircleShimmer(),
                    Row(
                      children: List.generate(3, (index) {
                        return Padding(
                          padding: EdgeInsetsDirectional.only(
                              end: index == 2 ? 0 : 8),
                          child: const _HeaderCircleShimmer(size: 40),
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                final width = index == 0 ? 20.0 : 10.0;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: CustomShimmer(
                    width: width,
                    height: 8,
                    borderRadius: 8,
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderCircleShimmer extends StatelessWidget {
  final double size;

  const _HeaderCircleShimmer({this.size = 44});

  @override
  Widget build(BuildContext context) {
    return CustomShimmer(
      height: size,
      width: size,
      borderRadius: size / 2,
    );
  }
}



class AdImageHeader extends StatefulWidget {
  final List<AdImageSource> images;
  final String? modelId;
  final PageController? pageController;
  final int currentImageIndex;
  final ValueChanged<int>? onImagePageChanged;
  final VoidCallback? onBack;
  final VoidCallback? onShare;
  final VoidCallback? onReport;
  final Widget? likeButton;
  final String? videoUrl;
  final String? videoThumbnail;
  final VoidCallback? onVideoTap;
  final Future<void> Function(BuildContext context)? openShareSheet;
  final Future<void> Function(BuildContext context)? openReportDialog;
  final Widget Function(BuildContext, int, int)? pageIndicatorBuilder;

  final int currentIndex;
  final Function(int)? onPageChanged;
  final bool isFavorite;
  final Function()? onToggleFavorite;
  final dynamic model;
  final bool isAddedByMe;
  final String safeModelId;

  const AdImageHeader({
    super.key,
    required this.images,
    this.modelId,
    this.pageController,
    required this.currentImageIndex,
    this.onImagePageChanged,
    this.onBack,
    this.onShare,
    this.onReport,
    this.likeButton,
    this.openShareSheet,
    this.openReportDialog,
    this.pageIndicatorBuilder,
    required this.currentIndex,
    this.onPageChanged,
    required this.isFavorite,
    this.onToggleFavorite,
    required this.model,
    required this.isAddedByMe,
    required this.safeModelId,
    this.videoUrl,
    this.videoThumbnail,
    this.onVideoTap,
  });

  static Widget sliver({
    required BuildContext context,
    required List<AdImageSource> images,
    required int currentIndex,
    required int currentImageIndex,
    required bool isFavorite,
    Function()? onToggleFavorite,
    dynamic model,
    bool isAddedByMe = false,
    String safeModelId = '',
    String? videoUrl,
    String? videoThumbnail,
    VoidCallback? onVideoTap,
    String? modelId,
    PageController? pageController,
    ValueChanged<int>? onImagePageChanged,
    VoidCallback? onBack,
    VoidCallback? onShare,
    VoidCallback? onReport,
    Widget? likeButton,
    Future<void> Function(BuildContext context)? openShareSheet,
    Future<void> Function(BuildContext context)? openReportDialog,
    Widget Function(BuildContext, int, int)? pageIndicatorBuilder,
  }) {
    return SliverToBoxAdapter(
      child: AdImageHeader(
        currentIndex: currentIndex,
        currentImageIndex: currentImageIndex,
        isFavorite: isFavorite,
        onToggleFavorite: onToggleFavorite,
        model: model,
        isAddedByMe: isAddedByMe,
        safeModelId: safeModelId,
        videoUrl: videoUrl,
        videoThumbnail: videoThumbnail,
        onVideoTap: onVideoTap,
        images: images,
        modelId: modelId,
        pageController: pageController,
        onImagePageChanged: onImagePageChanged,
        onBack: onBack,
        onShare: onShare,
        onReport: onReport,
        likeButton: likeButton,
        openShareSheet: openShareSheet,
        openReportDialog: openReportDialog,
        pageIndicatorBuilder: pageIndicatorBuilder,
      ),
    );
  }

  @override
  State<AdImageHeader> createState() => _AdImageHeaderState();
}

class _AdImageHeaderState extends State<AdImageHeader> {
  late PageController _controller;
  bool _ownsController = false;
  late int currentImageIndex;

  bool get _hasImages => widget.images.isNotEmpty;
  bool get _hasVideo => (widget.videoUrl?.trim().isNotEmpty ?? false);
  bool get _hasMedia => _hasImages || _hasVideo;
  int get _totalCount => widget.images.length + (_hasVideo ? 1 : 0);

  @override
  void initState() {
    super.initState();
    _setupController();
    currentImageIndex = _normalizeIndex(widget.currentImageIndex, _totalCount);
  }

  @override
  void dispose() {
    _controller.removeListener(_handlePagePosition);
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }
  @override
  void didUpdateWidget(covariant AdImageHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pageController != widget.pageController) {
      _swapController(widget.pageController);
    }
    final int normalizedIndex = _normalizeIndex(
      widget.currentImageIndex,
      _totalCount,
    );
    if (normalizedIndex != currentImageIndex) {
      setState(() {
        currentImageIndex = normalizedIndex;
      });
    }
  }

  void _setupController() {
    final int initial =
        _normalizeIndex(widget.currentImageIndex, _totalCount);
    if (widget.pageController != null) {
      _controller = widget.pageController!;
      _ownsController = false;
    } else {
      _controller = PageController(initialPage: initial);
      _ownsController = true;
    }
    _controller.addListener(_handlePagePosition);
  }

  void _swapController(PageController? newController) {
    _controller.removeListener(_handlePagePosition);
    if (_ownsController) {
      _controller.dispose();
    }
    if (newController != null) {
      _controller = newController;
      _ownsController = false;
    } else {
      _controller = PageController(initialPage: currentImageIndex);
      _ownsController = true;
    }
    _controller.addListener(_handlePagePosition);
  }

  void _handlePagePosition() {
    if (!_controller.hasClients || _totalCount <= 0) return;
    final double? page = _controller.page;
    if (page == null) return;
    final int pageIndex = page.round().clamp(0, _totalCount - 1);
    if (pageIndex != currentImageIndex) {
      setState(() {
        currentImageIndex = pageIndex;
      });
    }
  }

  int _normalizeIndex(int index, int itemCount) {
    if (itemCount <= 0) {
      return 0;
    }
    if (index < 0) {
      return 0;
    }
    if (index >= itemCount) {
      return itemCount - 1;
    }
    return index;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 300,
      child: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            onTap: !_hasMedia
                ? null
                : () {
                    final bool isVideoSlide =
                        _hasVideo && currentImageIndex == _totalCount - 1;
                    if (isVideoSlide) {
                      widget.onVideoTap?.call();
                      return;
                    }
                    if (widget.images.isEmpty) return;
                    Navigator.push(
                      context,
                      AppPageRoute.build(
                        builder: (context) => FullscreenGalleryPage(
                          videoUrl: widget.videoUrl,
                          videoThumbnail: widget.videoThumbnail,
                          images: widget.images,
                          initialIndex:
                              currentImageIndex.clamp(0, _totalCount - 1),
                          heroTagBuilder: (index) => widget.modelId != null
                              ? 'ad-image-${widget.modelId}-$index'
                              : 'ad-image-$index',
                        ),
                        motionPattern: AppMotionPattern.glide,
                      ),
                    );
                  },
            child: _buildImageSlider(),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.3),
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withOpacity(0.1),
                    ],
                    stops: const [0.0, 0.15, 0.85, 1.0],
                  ),
                ),
              ),
            ),
          ),
          if (widget.onBack != null ||
              widget.onShare != null ||
              widget.onReport != null ||
              widget.likeButton != null)
            Positioned(
              top: 0, left: 0, right: 0,
              child: SafeArea(
                child: _buildTopButtons(context),
              ),
            ),




          if (_totalCount > 1)
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: _buildImageIndicator(),
            ),
        ],
      ),
    );
  }

  Widget _buildImageIndicator() {
    final int total = _totalCount;
    if (total <= 1) return const SizedBox.shrink();

    if (widget.pageIndicatorBuilder != null) {
      return widget.pageIndicatorBuilder!(context, currentImageIndex, total);
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (index) {
        final bool isActive = currentImageIndex == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 20 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive
                ? Theme.of(context).colorScheme.primary
                : Colors.white.withOpacity(0.7),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }

  Widget _buildImageSlider() {
    if (!_hasMedia) {
      return _buildPlaceholder();
    }
    return PageView.builder(
      controller: _controller,
      itemCount: _totalCount,
      onPageChanged: (index) {
        if (widget.onImagePageChanged != null) {
          widget.onImagePageChanged!(index);
        }
        setState(() {
          currentImageIndex = index;
        });
      },

      itemBuilder: (context, index) {
        if (_hasVideo && index == _totalCount - 1) {
          return _buildVideoSlide();
        }

        final int imageIndex = index;
        final AdImageSource imageSource = widget.images[imageIndex];
        final String imageUrl = imageSource.detailUrl;
        return Hero(
          tag: widget.modelId != null
              ? 'ad-image-${widget.modelId}-$imageIndex'
              : 'ad-image-$imageIndex',
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            memCacheWidth: kAdDetailImageMaxEdge,
            memCacheHeight: kAdDetailImageMaxEdge,
            maxWidthDiskCache: kAdDetailImageMaxEdge,
            maxHeightDiskCache: kAdDetailImageMaxEdge,
            imageBuilder: (context, imageProvider) => Image(
              image: imageProvider,
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,

              filterQuality: FilterQuality.high,
            ),
            placeholder: (context, url) => const ShimmerBox(
              width: double.infinity,
              height: double.infinity,
              borderRadius: BorderRadius.zero,
            ),
            errorWidget: (context, url, error) {
              if (imageSource.hasOptimizedVariant) {
                return CachedNetworkImage(
                  imageUrl: imageSource.fallbackDisplayUrl,
                  fit: BoxFit.cover,
                  memCacheWidth: kAdDetailImageMaxEdge,
                  memCacheHeight: kAdDetailImageMaxEdge,
                  maxWidthDiskCache: kAdDetailImageMaxEdge,
                  maxHeightDiskCache: kAdDetailImageMaxEdge,
                  imageBuilder: (context, imageProvider) => Image(
                    image: imageProvider,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,

                    filterQuality: FilterQuality.high,
                  ),
                  placeholder: (context, _) => const ShimmerBox(
                    width: double.infinity,
                    height: double.infinity,
                    borderRadius: BorderRadius.zero,
                  ),
                  errorWidget: (context, _, __) => _buildImageErrorPlaceholder(),

                );
              }
              return _buildImageErrorPlaceholder();

            },
          ),
        );
      },
    );
  }

  Widget _buildVideoSlide() {
    final String? thumb = widget.videoThumbnail;
    final bool hasThumb = thumb != null && thumb.isNotEmpty;

    Widget base;
    if (hasThumb) {
      base = CachedNetworkImage(
        imageUrl: thumb!,
        fit: BoxFit.cover,
        placeholder: (context, url) => const ShimmerBox(
          width: double.infinity,
          height: double.infinity,
          borderRadius: BorderRadius.zero,
        ),
        errorWidget: (context, url, error) => _buildShimmerFallback(
          icon: Icons.videocam_rounded,
          animate: false,
        ),
      );
    } else {
      base = _buildShimmerFallback(
        icon: Icons.videocam_rounded,
        animate: true,
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        base,
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.black.withOpacity(0.1),
                Colors.black.withOpacity(0.4),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        Center(
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black54,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.85),
                width: 1.5,
              ),
            ),
            child: const Icon(
              Icons.play_arrow_rounded,
              size: 42,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }


  Widget _buildPlaceholder() {
    return _buildShimmerFallback(
      icon: Icons.image_not_supported_outlined,
      animate: true,
    );
  }

  Widget _buildImageErrorPlaceholder() {
    return _buildShimmerFallback(
      icon: Icons.broken_image_outlined,
      animate: false,
    );
  }

  Widget _buildShimmerFallback({
    required IconData icon,
    required bool animate,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final Color iconColor = colorScheme.onSurface.withOpacity(0.65);

    return Stack(
      fit: StackFit.expand,
      children: [
      ShimmerBox(
      width: double.infinity,
      height: double.infinity,
      borderRadius: BorderRadius.zero,
      animate: animate,
        ),
        Center(
          child: Icon(
            icon,
            size: 56,
            color: iconColor,
          ),
        ),
      ],
    );
  }

  Widget _buildTopButtons(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        textDirection: TextDirection.ltr,            // 👈 يسار دائمًا
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.onBack != null) ...[
            CircleAvatar(
              backgroundColor: Colors.black54,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: widget.onBack,
              ),
            ),
            const SizedBox(width: 8),
          ],


          if (widget.onShare != null) ...[
            CircleAvatar(
              backgroundColor: Colors.black54,
              child: IconButton(
                icon: const Icon(Icons.share, color: Colors.white),
                onPressed: () async {
                  if (widget.openShareSheet != null) {
                    await widget.openShareSheet!(context);
                  } else {
                    widget.onShare!();
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
          ],
          if (widget.onReport != null) ...[
            CircleAvatar(
              backgroundColor: Colors.black54,
              child: IconButton(
                icon: const Icon(Icons.flag, color: Colors.white),
                onPressed: () async {
                  if (widget.openReportDialog != null) {
                    await widget.openReportDialog!(context);
                  } else {
                    widget.onReport!();
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
          ],
          if (widget.likeButton != null) widget.likeButton!,
        ],
      ),
    );
  }






// دالة مساعدة لبناء مؤشر الصور (يمكن استخدامها خارجيًا)
  Widget buildPageIndicator(BuildContext context, int total, int current) {
    final cs = Theme
        .of(context)
        .colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final bool active = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          height: 6,
          width: active ? 16 : 6,
          decoration: BoxDecoration(
            color: active ? cs.primary : Colors.white.withOpacity(0.6),
            borderRadius: BorderRadius.circular(6),
          ),
        );
      }),
    );
  }
}
