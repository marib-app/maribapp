import 'package:flutter/material.dart';

extension ShimmerColors on ColorScheme {
  static const _lightBase = Color(0xFFB8BEC9);
  static const _lightHighlight = Color(0xFFE4E8F0);

  Color get shimmerBaseColor {
    if (brightness == Brightness.dark) {
      return surfaceVariant.withOpacity(0.32);
    }
    return _lightBase;
  }

  Color get shimmerHighlightColor {
    if (brightness == Brightness.dark) {
      return onSurface.withOpacity(0.20);
    }
    return _lightHighlight;
  }

  Color get shimmerContentColor {
    if (brightness == Brightness.dark) {
      return onSurface.withOpacity(0.14);
    }
    return _lightBase.withOpacity(0.60);
  }
}
