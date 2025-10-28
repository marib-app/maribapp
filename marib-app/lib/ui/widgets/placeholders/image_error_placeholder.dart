import 'dart:math' as math;

import 'package:flutter/material.dart';

class ImageErrorPlaceholder extends StatelessWidget {
  const ImageErrorPlaceholder({
    super.key,
    this.width,
    this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.icon,
  });

  final double? width;
  final double? height;
  final BorderRadius borderRadius;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final double? constrainedSide = _smallestSide(width, height);
    final double iconSize = constrainedSide != null
        ? math.min(constrainedSide * 0.6, 40)
        : 32;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant.withOpacity(0.35),
        borderRadius: borderRadius,
      ),
      alignment: Alignment.center,
      child: Icon(
        icon ?? Icons.broken_image_outlined,
        color: colorScheme.onSurfaceVariant.withOpacity(0.65),
        size: iconSize,
      ),
    );
  }

  double? _smallestSide(double? width, double? height) {
    final bool hasWidth = width != null && width > 0 && width.isFinite;
    final bool hasHeight = height != null && height > 0 && height.isFinite;

    if (hasWidth && hasHeight) {
      return math.min(width!, height!);
    }
    if (hasWidth) {
      return width;
    }
    if (hasHeight) {
      return height;
    }
    return null;
  }
}