import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:marib/ui/theme/theme.dart';

class ShimmerBox extends StatelessWidget {
  const ShimmerBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
    this.baseColor,
    this.highlightColor,
    this.animate = true,
  });

  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final Color? baseColor;
  final Color? highlightColor;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final Color resolvedBase =
        baseColor ?? colorScheme.shimmerBaseColor;
    final Color resolvedHighlight =
        highlightColor ?? colorScheme.shimmerHighlightColor;

    final Widget child = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: colorScheme.shimmerContentColor,
        borderRadius: borderRadius ?? BorderRadius.circular(12),
      ),
    );

    if (!animate) {
      return child;
    }

    return Shimmer.fromColors(
      baseColor: resolvedBase,
      highlightColor: resolvedHighlight,
      period: const Duration(milliseconds: 1300),
      child: child,
    );
  }
}