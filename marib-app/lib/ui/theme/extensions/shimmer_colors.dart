import 'package:flutter/material.dart';

extension ShimmerColors on ColorScheme {
  Color get shimmerBaseColor => surfaceVariant.withOpacity(
    brightness == Brightness.dark ? 0.24 : 0.40,
  );

  Color get shimmerHighlightColor => brightness == Brightness.dark
      ? onSurface.withOpacity(0.12)
      : surface.withOpacity(0.85);

  Color get shimmerContentColor =>
      onSurface.withOpacity(brightness == Brightness.dark ? 0.05 : 0.08);
}
