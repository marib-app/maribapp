import 'package:flutter/material.dart';
import 'package:marib/utils/extensions/extensions.dart';

/// A single swatch definition from the shared color palette.
class ColorPaletteEntry {
  final String hex;
  final String labelKey;
  final String fallbackLabel;

  const ColorPaletteEntry({
    required this.hex,
    required this.labelKey,
    required this.fallbackLabel,
  });

  String get normalizedHex => ColorPaletteHelper.normalizeHex(hex);

  Color get color => Color(int.parse('0xFF$normalizedHex'));

  String label(BuildContext context) {
    final translated = labelKey.translate(context);
    if (translated.isNotEmpty && translated != labelKey) {
      return translated;
    }
    return fallbackLabel;
  }
}

/// Shared helpers to work with the normalized color palette across the app.
class ColorPaletteHelper {
  static const List<ColorPaletteEntry> entries = [
    ColorPaletteEntry(
      hex: 'FFFFFF',
      labelKey: 'colorPaletteWhite',
      fallbackLabel: 'أبيض',
    ),
    ColorPaletteEntry(
      hex: '000000',
      labelKey: 'colorPaletteBlack',
      fallbackLabel: 'أسود',
    ),
    ColorPaletteEntry(
      hex: '808080',
      labelKey: 'colorPaletteGray',
      fallbackLabel: 'رمادي',
    ),
    ColorPaletteEntry(
      hex: 'C0C0C0',
      labelKey: 'colorPaletteSilver',
      fallbackLabel: 'فضي',
    ),
    ColorPaletteEntry(
      hex: 'D4AF37',
      labelKey: 'colorPaletteGold',
      fallbackLabel: 'ذهبي',
    ),
    ColorPaletteEntry(
      hex: 'FF0000',
      labelKey: 'colorPaletteRed',
      fallbackLabel: 'أحمر',
    ),
    ColorPaletteEntry(
      hex: '800000',
      labelKey: 'colorPaletteMaroon',
      fallbackLabel: 'خمري',
    ),
    ColorPaletteEntry(
      hex: 'FFC0CB',
      labelKey: 'colorPalettePink',
      fallbackLabel: 'وردي',
    ),
    ColorPaletteEntry(
      hex: 'FFA500',
      labelKey: 'colorPaletteOrange',
      fallbackLabel: 'برتقالي',
    ),
    ColorPaletteEntry(
      hex: 'FFFF00',
      labelKey: 'colorPaletteYellow',
      fallbackLabel: 'أصفر',
    ),
    ColorPaletteEntry(
      hex: '00A651',
      labelKey: 'colorPaletteGreen',
      fallbackLabel: 'أخضر',
    ),
    ColorPaletteEntry(
      hex: '32CD32',
      labelKey: 'colorPaletteLime',
      fallbackLabel: 'ليموني',
    ),
    ColorPaletteEntry(
      hex: '40E0D0',
      labelKey: 'colorPaletteTurquoise',
      fallbackLabel: 'تركواز',
    ),
    ColorPaletteEntry(
      hex: '00CED1',
      labelKey: 'colorPaletteCyan',
      fallbackLabel: 'سماوي',
    ),
    ColorPaletteEntry(
      hex: '0000FF',
      labelKey: 'colorPaletteBlue',
      fallbackLabel: 'أزرق',
    ),
    ColorPaletteEntry(
      hex: '000080',
      labelKey: 'colorPaletteNavy',
      fallbackLabel: 'كحلي',
    ),
    ColorPaletteEntry(
      hex: '3F51B5',
      labelKey: 'colorPaletteIndigo',
      fallbackLabel: 'نيلي',
    ),
    ColorPaletteEntry(
      hex: '800080',
      labelKey: 'colorPalettePurple',
      fallbackLabel: 'بنفسجي',
    ),
    ColorPaletteEntry(
      hex: '9370DB',
      labelKey: 'colorPaletteMauve',
      fallbackLabel: 'موف',
    ),
    ColorPaletteEntry(
      hex: 'F5F5DC',
      labelKey: 'colorPaletteBeige',
      fallbackLabel: 'بيج',
    ),
    ColorPaletteEntry(
      hex: '8B4513',
      labelKey: 'colorPaletteBrown',
      fallbackLabel: 'بني',
    ),
    ColorPaletteEntry(
      hex: 'C3B091',
      labelKey: 'colorPaletteKhaki',
      fallbackLabel: 'كاكي',
    ),
    ColorPaletteEntry(
      hex: '556B2F',
      labelKey: 'colorPaletteOlive',
      fallbackLabel: 'زيتي',
    ),
    ColorPaletteEntry(
      hex: 'B2BEB5',
      labelKey: 'colorPaletteCement',
      fallbackLabel: 'سمنتي',
    ),
    ColorPaletteEntry(
      hex: 'FFFFF0',
      labelKey: 'colorPaletteIvory',
      fallbackLabel: 'عاجي',
    ),
    ColorPaletteEntry(
      hex: 'B87333',
      labelKey: 'colorPaletteCopper',
      fallbackLabel: 'نحاسي',
    ),
    ColorPaletteEntry(
      hex: '36454F',
      labelKey: 'colorPaletteCharcoal',
      fallbackLabel: 'فحمي',
    ),
    ColorPaletteEntry(
      hex: 'ADD8E6',
      labelKey: 'colorPaletteLightBlue',
      fallbackLabel: 'أزرق فاتح',
    ),
    ColorPaletteEntry(
      hex: '90EE90',
      labelKey: 'colorPaletteLightGreen',
      fallbackLabel: 'أخضر فاتح',
    ),
    ColorPaletteEntry(
      hex: 'CD7F32',
      labelKey: 'colorPaletteBronze',
      fallbackLabel: 'برونزي',
    ),
    ColorPaletteEntry(
      hex: 'FF7F50',
      labelKey: 'colorPaletteCoral',
      fallbackLabel: 'مرجاني',
    ),
    ColorPaletteEntry(
      hex: '98FF98',
      labelKey: 'colorPaletteMint',
      fallbackLabel: 'نعناعي',
    ),
    ColorPaletteEntry(
      hex: '87CEEB',
      labelKey: 'colorPaletteSkyBlue',
      fallbackLabel: 'سماوي فاتح',
    ),
    ColorPaletteEntry(
      hex: '800020',
      labelKey: 'colorPaletteBurgundy',
      fallbackLabel: 'عنابي',
    ),
  ];

  static final Map<String, ColorPaletteEntry> _entriesByHex = {
    for (final entry in entries) entry.normalizedHex: entry,
  };

  static final List<Map<String, String>> basePaletteForPicker = [
    for (final entry in entries)
      {'name': entry.fallbackLabel, 'hex': entry.normalizedHex},
  ];

  static String normalizeHex(String hex) =>
      hex.replaceAll('#', '').trim().toUpperCase();

  static Color? tryParseColor(String hex) {
    final normalized = normalizeHex(hex);
    if (!_isValidHex(normalized)) return null;
    return Color(int.parse('0xFF$normalized'));
  }

  static ColorPaletteEntry? entryForHex(String hex) =>
      _entriesByHex[normalizeHex(hex)];

  static String labelForHex(BuildContext context, String hex) {
    final normalized = normalizeHex(hex);
    final entry = entryForHex(normalized);
    if (entry != null) {
      final label = entry.label(context);
      if (label.isNotEmpty) {
        return label;
      }
    }

    if (normalized.isEmpty) {
      return '—';
    }

    return '#$normalized';
  }

  static bool _isValidHex(String hex) =>
      RegExp(r'^[0-9A-F]{6}$').hasMatch(hex.toUpperCase());
}