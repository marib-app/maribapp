import 'package:flutter/material.dart';

extension ShimmerColors on ColorScheme {
  static const _lightBase = Color(0xFFB8BEC9);
  static const _lightHighlight = Color(0xFFE4E8F0);

  Color _overlayOnSurface(Color base, double opacity) {
    return Color.alphaBlend(onSurface.withOpacity(opacity), base);
  }

  Color get shimmerBaseColor {
    if (brightness == Brightness.dark) {
      return _overlayOnSurface(surfaceVariant, 0.24);
    }
    return _lightBase;
  }

  Color get shimmerHighlightColor {
    if (brightness == Brightness.dark) {
      return _overlayOnSurface(surface, 0.48);
    }
    return _lightHighlight;
  }

  Color get shimmerContentColor {
    if (brightness == Brightness.dark) {
      return _overlayOnSurface(surfaceVariant, 0.12);
    }
    return _lightBase.withOpacity(0.60);
  }
}
