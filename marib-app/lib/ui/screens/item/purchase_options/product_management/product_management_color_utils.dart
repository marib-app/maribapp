import 'package:flutter/material.dart';
import 'package:marib/data/model/item/purchase_options.dart';

class ProductManagementColorUtils {
  const ProductManagementColorUtils._();

  static bool isColorAttribute(ItemPurchaseAttributeOption attribute) {
    final String normalizedKey = attribute.key.toLowerCase();
    final String normalizedName = attribute.name.toLowerCase();
    final String? type = attribute.type?.toLowerCase();
    final String? uiType = attribute.uiType?.toLowerCase();

    if (type == 'color' || uiType == 'color') {
      return true;
    }

    const List<String> arabicColorKeywords = <String>[
      'لون',
      'اللون',
      'الوان',
      'ألوان',
      'الالوان'
    ];

    bool containsArabicColorKeyword(String value) {
      for (final String keyword in arabicColorKeywords) {
        if (value.contains(keyword)) {
          return true;
        }
      }
      return false;
    }

    if (normalizedKey.contains('color') ||
        normalizedKey.contains('colour') ||
        containsArabicColorKeyword(normalizedKey)) {
      return true;
    }

    if (normalizedName.contains('color') ||
        normalizedName.contains('colour') ||
        containsArabicColorKeyword(normalizedName)) {
      return true;
    }

    return false;
  }

  static String? normalizeColorValue(String? value) {
    if (value == null) {
      return null;
    }
    final String normalized = value.replaceAll('#', '').trim().toUpperCase();
    final RegExp pattern = RegExp(r'^[0-9A-F]{6}$');
    return pattern.hasMatch(normalized) ? normalized : null;
  }

  static Color? colorFromHex(String value) {
    final String? normalized = normalizeColorValue(value);
    if (normalized == null) {
      return null;
    }
    return Color(int.parse('0xFF$normalized'));
  }
}