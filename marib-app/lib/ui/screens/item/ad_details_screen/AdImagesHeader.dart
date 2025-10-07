import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:marib/ui/screens/item/ad_details_screen/fullscreen_gallery.dart';
import 'package:marib/ui/screens/widgets/shimmerLoadingContainer.dart';

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
  final List<String> images;
  final String? modelId;
  final PageController? pageController;
  final int currentImageIndex;
  final ValueChanged<int>? onImagePageChanged;
  final VoidCallback? onBack;
  final VoidCallback? onShare;
  final VoidCallback? onReport;
  final Widget? likeButton;
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
  });

  static Widget sliver({
    required BuildContext context,
    required List<String> images,
    required int currentIndex,
    required int currentImageIndex,
    required bool isFavorite,
    Function()? onToggleFavorite,
    dynamic model,
    bool isAddedByMe = false,
    String safeModelId = '',
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
  late int currentImageIndex;

  @override
  void initState() {
    super.initState();
    currentImageIndex = widget.currentImageIndex;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 300,
      child: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FullscreenGalleryPage(
                    images: widget.images,
                    initialIndex: currentImageIndex,
                    heroTagBuilder: (index) => widget.modelId != null
                        ? 'ad-image-${widget.modelId}-$index'
                        : 'ad-image-$index',
                  ),
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
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: _buildTopButtons(context),
              ),
            ),
          if (widget.images.length > 1)
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(widget.images.length, (index) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: currentImageIndex == index ? 20 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: currentImageIndex == index
                ? Theme.of(context).colorScheme.primary
                : Colors.white.withOpacity(0.7),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }

  Widget _buildImageSlider() {
    return PageView.builder(
      controller: widget.pageController,
      itemCount: widget.images.length,
      onPageChanged: (index) {
        if (widget.onImagePageChanged != null) {
          widget.onImagePageChanged!(index);
        }
        setState(() {
          currentImageIndex = index;
        });
      },
      physics: const BouncingScrollPhysics(),
      itemBuilder: (context, index) {
        return Hero(
          tag: widget.modelId != null
              ? 'ad-image-${widget.modelId}-$index'
              : 'ad-image-$index',
          child: CachedNetworkImage(
            imageUrl: widget.images[index],
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(color: Colors.grey[200]),
            errorWidget: (context, url, error) => const Icon(Icons.error),
          ),
        );
      },
    );
  }

  Widget _buildTopButtons(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        textDirection: TextDirection.ltr, // 👈 يسار دائمًا
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
    final cs = Theme.of(context).colorScheme;
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
