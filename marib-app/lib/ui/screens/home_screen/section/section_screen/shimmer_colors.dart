import 'package:flutter/material.dart';

extension ShimmerColors on ColorScheme {
  Color get shimmerBaseColor =>
      surfaceVariant.withOpacity(brightness == Brightness.dark ? 0.20 : 0.40);

  Color get shimmerHighlightColor =>
      surface.withOpacity(brightness == Brightness.dark ? 0.30 : 0.60);

  Color get shimmerContentColor =>
      onSurface.withOpacity(brightness == Brightness.dark ? 0.05 : 0.08);
}
