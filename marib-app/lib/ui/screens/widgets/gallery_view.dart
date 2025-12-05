import 'package:cached_network_image/cached_network_image.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:flutter/material.dart';

import 'package:marib/utils/app_icon.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:marib/ui/widgets/shimmer/shimmer_box.dart';

class GalleryViewWidget extends StatefulWidget {
  final List images;
  final int initalIndex;

  const GalleryViewWidget({
    super.key,
    required this.images,
    required this.initalIndex,
  });

  @override
  State<GalleryViewWidget> createState() => _GalleryViewWidgetState();

/*  static Route route(RouteSettings routeSettings) {
    Map? arguments = routeSettings.arguments as Map?;
    return BlurredRouter(
        builder: (_) => GalleryViewWidget(
            images: arguments?['images'],
            initalIndex: arguments?['initalIndex']));
  }*/
}

class _GalleryViewWidgetState extends State<GalleryViewWidget> {
  late PageController controller =
      PageController(initialPage: widget.initalIndex);
  int _currentIndex = 0;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _currentIndex = controller.hasClients ? controller.page?.round() ?? 0 : 0;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: UiUtils.buildAppBar(
        context,
        showBackButton: true,
        backgroundColor: context.color.secondaryDetailsColor,
      ),
      backgroundColor: context.color.secondaryDetailsColor,
      body: Stack(
        children: [
          PageView.builder(
            controller: controller,
            itemCount: widget.images.length,
            onPageChanged: (i) => setState(() => _currentIndex = i),
            itemBuilder: (context, index) {
              return InteractiveViewer(
                scaleEnabled: true,
                maxScale: 5,
                child: CachedNetworkImage(
                  imageUrl: widget.images[index],
                  fit: BoxFit.contain,
                  placeholder: (context, url) => ShimmerBox(
                    width: double.infinity,
                    height: double.infinity,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  errorWidget: (context, url, error) => ShimmerBox(
                    width: double.infinity,
                    height: double.infinity,
                    borderRadius: BorderRadius.circular(16),
                    animate: false,
                  ),
                ),
              );
            },
          ),
          if (widget.images.length > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.0),
                        Colors.black.withOpacity(0.35),
                        Colors.black.withOpacity(0.65),
                      ],
                    ),
                  ),
                  height: 96,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: widget.images.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final bool isActive = index == _currentIndex;
                      final double size = isActive ? 78 : 66;
                      return GestureDetector(
                        onTap: () => controller.animateToPage(
                          index,
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOut,
                        ),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOut,
                          width: size,
                          height: size,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isActive
                                  ? context.color.territoryColor
                                  : Colors.white30,
                              width: isActive ? 2 : 1,
                            ),
                            boxShadow: [
                              if (isActive)
                                BoxShadow(
                                  color: context.color.territoryColor
                                      .withOpacity(0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: CachedNetworkImage(
                            imageUrl: widget.images[index],
                            fit: BoxFit.cover,
                            placeholder: (context, url) => ShimmerBox(
                              width: size,
                              height: size,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            errorWidget: (context, url, error) => ShimmerBox(
                              width: size,
                              height: size,
                              borderRadius: BorderRadius.circular(12),
                              animate: false,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

/*  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
    */ /*  appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        */ /**/ /*iconTheme: IconThemeData(color: context.color.territoryColor),*/ /**/ /*
      ),*/ /*
      backgroundColor: const Color.fromARGB(17, 0, 0, 0),
      body: ScrollConfiguration(
        behavior: RemoveGlow(),
        child: PageView.builder(
          controller: controller,
          itemBuilder: (context, index) {
            return InteractiveViewer(
              // panEnabled: true,
              scaleEnabled: true,
maxScale: 5,
              child: CachedNetworkImage(
                imageUrl: widget.images[index],
                memCacheHeight: 500,
                memCacheWidth: 500,

              ),
            );
          },
          itemCount:
              (widget.images..removeWhere((element) => (element == ""))).length,
        ),
      ),
    );
  }*/
}
