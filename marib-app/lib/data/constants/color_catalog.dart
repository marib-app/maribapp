import 'package:flutter/material.dart';
import 'package:marib/utils/color_palette_utils.dart';

/// Shared catalog of known colors and helpers for sanitizing/looking up names.
class ColorCatalog {
  /// Base palette exposed for pickers and other selectors.
  static final List<Map<String, String>> basePalette = [
    for (final entry in ColorPaletteHelper.entries)
      {
        'name': entry.fallbackLabel,
        'hex': entry.normalizedHex,
      },
  ];

  /// Sanitizes a hex value by removing leading hashes and uppercasing.
  static String sanitizeHex(String hex) =>
      ColorPaletteHelper.normalizeHex(hex);

  /// Resolves the display name for a hex value using the known palette.
  ///
  /// If [context] is provided, localized labels are preferred.
  static String nameForHex(String hex, {BuildContext? context}) {
    final normalized = sanitizeHex(hex);
    if (normalized.isEmpty) return '';

    final entry = ColorPaletteHelper.entryForHex(normalized);
    if (entry != null) {
      if (context != null) {
        final localized = entry.label(context);
        if (localized.isNotEmpty) {
          return localized;
        }
      }
      return entry.fallbackLabel;
    }

    return '#$normalized';
  }
}