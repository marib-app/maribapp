import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:marib/ui/widgets/shimmer/shimmer_box.dart';
import 'dart:math' as math;
import 'package:marib/ui/widgets/placeholders/image_error_placeholder.dart';

class LazyNetworkImage extends StatelessWidget {
  const LazyNetworkImage({
    super.key,
    required this.imageUrl,
    this.cacheKey,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.placeholder,
    this.errorWidget,
    this.fadeInDuration = const Duration(milliseconds: 250),
    this.fadeOutDuration = const Duration(milliseconds: 150),
  });

  final String imageUrl;
  final String? cacheKey;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Alignment alignment;
  final Widget? placeholder;
  final Widget? errorWidget;
  final Duration fadeInDuration;
  final Duration fadeOutDuration;

  @override
  Widget build(BuildContext context) {
    if (imageUrl.trim().isEmpty) {
      return placeholder ?? _defaultPlaceholder(context);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final double pixelRatio =
            MediaQuery.maybeOf(context)?.devicePixelRatio ?? 1.0;

        final double? effectiveWidth =
            width ?? _resolveConstraint(constraints.maxWidth);
        final double? effectiveHeight =
            height ?? _resolveConstraint(constraints.maxHeight);

        final int? memCacheWidth =
            _toCacheDimension(effectiveWidth, pixelRatio);
        final int? memCacheHeight =
            _toCacheDimension(effectiveHeight, pixelRatio);

        return CachedNetworkImage(
          imageUrl: imageUrl,
          cacheKey: cacheKey,
          width: width,
          height: height,
          fit: fit,
          alignment: alignment,
          fadeInDuration: fadeInDuration,
          fadeOutDuration: fadeOutDuration,
          memCacheWidth: memCacheWidth,
          memCacheHeight: memCacheHeight,
          maxWidthDiskCache: memCacheWidth,
          maxHeightDiskCache: memCacheHeight,
          placeholder: (_, __) => placeholder ?? _defaultPlaceholder(context),
          errorWidget: (_, __, ___) => errorWidget ?? _defaultError(context),
        );
      },
    );
  }

  Widget _defaultPlaceholder(BuildContext context) {
    return ShimmerBox(
      width: width,
      height: height,
      borderRadius: BorderRadius.circular(12),
    );
  }

  Widget _defaultError(BuildContext context) {
    return ImageErrorPlaceholder(
      width: width,
      height: height,

    );
  }
}

double? _resolveConstraint(double constraint) {
  if (constraint.isFinite && constraint > 0) {
    return constraint;
  }
  return null;
}

int? _toCacheDimension(double? logicalSize, double pixelRatio) {
  if (logicalSize == null || logicalSize.isInfinite || logicalSize <= 0) {
    return null;
  }
  final int scaled = (logicalSize * pixelRatio).round();
  // حصر القيمة لحماية الذاكرة وتقليل الضغط على GPU أثناء التحميل الأولي.
  return math.min(scaled, 4096);
}
