import 'package:flutter/material.dart';

extension ShimmerColors on ColorScheme {
  static const _lightBase = Color(0xFFDADFE7);
  static const _lightHighlight = Color(0xFFF4F6FB);
  static const _lightContent = Color(0xFFE8ECF3);

  static Color _blendOnSurface(ColorScheme scheme, Color base, double opacity) {
    return Color.alphaBlend(scheme.onSurface.withOpacity(opacity), base);
  }

  Color get shimmerBaseColor {
    if (brightness == Brightness.dark) {
      return Color.alphaBlend(Colors.white.withOpacity(0.18), surfaceVariant);
    }
    return _lightBase;
  }

  Color get shimmerHighlightColor {
    if (brightness == Brightness.dark) {
      return Color.alphaBlend(Colors.white.withOpacity(0.32), surface);
    }
    return _lightHighlight;
  }

  Color get shimmerContentColor {
    if (brightness == Brightness.dark) {
      return Color.alphaBlend(Colors.white.withOpacity(0.14), surfaceVariant);
    }
    return _blendOnSurface(this, _lightContent, 0.08);
  }
}
