import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

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

    return CachedNetworkImage(
      imageUrl: imageUrl,
      cacheKey: cacheKey,
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      fadeInDuration: fadeInDuration,
      fadeOutDuration: fadeOutDuration,
      placeholder: (_, __) => placeholder ?? _defaultPlaceholder(context),
      errorWidget: (_, __, ___) => errorWidget ?? _defaultError(context),
    );
  }

  Widget _defaultPlaceholder(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.2),
    );
  }

  Widget _defaultError(BuildContext context) {
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.35),
      child: Icon(
        Icons.broken_image_outlined,
        color: Theme.of(context).disabledColor,
        size: (width != null && height != null)
            ? (width!.clamp(16, 48))
            : 24,
      ),
    );
  }
}