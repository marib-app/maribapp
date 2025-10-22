import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:marib/utils/extensions/extensions.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MarkerFactory {
  static const int _maxCacheSize = 96;

  final LinkedHashMap<String, BitmapDescriptor> _cache = LinkedHashMap();
  int _generatedCount = 0;

  Future<BitmapDescriptor> realEstateMarker({
    required BuildContext context,
    required String priceLabel,
    required bool selected,
    required Color brand,
  }) async {
    final brightness = Theme.of(context).brightness;
    final key = _buildCacheKey(
      priceLabel: priceLabel,
      selected: selected,
      brand: brand,
      brightness: brightness,
    );

    final cached = _getFromCache(key);
    if (cached != null) return cached;

    const double pinH = 66;
    const double pinW = 46;
    const double badgeH = 24;
    const double badgePad = 6;
    const double pinToBadgeSpace = 6;

    final ui.ParagraphBuilder pb = ui.ParagraphBuilder(
      ui.ParagraphStyle(fontSize: 12, textDirection: ui.TextDirection.rtl),
    )
      ..pushStyle(
        ui.TextStyle(
          color: ui.Color(0xffffffff),
          fontWeight: ui.FontWeight.w700,
        ),
      )
      ..addText(priceLabel);
    final ui.Paragraph paragraph = pb.build()
      ..layout(const ui.ParagraphConstraints(width: 140));
    final double textW = paragraph.maxIntrinsicWidth.clamp(32, 140);

    final totalW = pinW + pinToBadgeSpace + textW + badgePad * 2;
    final totalH = math.max(pinH, badgeH);

    final recorder = ui.PictureRecorder();
    final canvas =
        Canvas(recorder, Rect.fromLTWH(0, 0, totalW, totalH.toDouble()));

    final isDark = brightness == Brightness.dark;
    final pinColor = selected
        ? brand
        : (isDark ? const Color(0xFF2a7bff) : const Color(0xFF1e88e5));
    final badgeColor = selected
        ? brand
        : (isDark ? const Color(0xFF333333) : const Color(0xCC000000));

    final pinRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, pinW, pinH - 10),
      const Radius.circular(14),
    );
    final paintPin = Paint()..color = pinColor;
    canvas.drawRRect(pinRect, paintPin);

    final path = Path()
      ..moveTo(pinW / 2 - 8, pinH - 10)
      ..lineTo(pinW / 2, pinH)
      ..lineTo(pinW / 2 + 8, pinH - 10)
      ..close();
    canvas.drawPath(path, paintPin);

    final double houseX = pinW / 2 - 10;
    const double houseY = 10.0;
    final roof = Path()
      ..moveTo(houseX + 10, houseY)
      ..lineTo(houseX + 20, houseY + 12)
      ..lineTo(houseX, houseY + 12)
      ..close();
    final housePaint = Paint()..color = Colors.white;
    canvas.drawPath(roof, housePaint);
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(houseX + 2, houseY + 12, 16, 14),
      const Radius.circular(3),
    );
    canvas.drawRRect(body, housePaint);

    final badgeLeft = pinW + pinToBadgeSpace;
    final badgeRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        badgeLeft,
        (totalH - badgeH) / 2,
        textW + badgePad * 2,
        badgeH,
      ),
      const Radius.circular(20),
    );
    final paintBadge = Paint()..color = badgeColor;
    canvas.drawRRect(badgeRect, paintBadge);

    canvas.drawParagraph(
      paragraph,
      Offset(badgeLeft + badgePad, (totalH - paragraph.height) / 2),
    );

    final picture = recorder.endRecording();
    final img = await picture.toImage(totalW.ceil(), totalH.ceil());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    final desc = BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
    _addToCache(key, desc);
    _generatedCount++;
    _debugCacheStats();
    return desc;
  }

  BitmapDescriptor? _getFromCache(String key) {
    final existing = _cache.remove(key);
    if (existing != null) {
      _cache[key] = existing;
    }
    return existing;
  }

  void _addToCache(String key, BitmapDescriptor descriptor) {
    _cache[key] = descriptor;
    if (_cache.length > _maxCacheSize) {
      final oldestKey = _cache.keys.first;
      _cache.remove(oldestKey);
    }
  }

  String _buildCacheKey({
    required String priceLabel,
    required bool selected,
    required Color brand,
    required Brightness brightness,
  }) {
    final normalizedPrice = _normalizePriceLabel(priceLabel);
    final selectionKey = selected ? 'sel' : 'nor';
    final brightnessKey = brightness == Brightness.dark ? 'dark' : 'light';
    final brandKey = brand.value.toRadixString(16);
    return '$normalizedPrice|$selectionKey|$brandKey|$brightnessKey';
  }

  String _normalizePriceLabel(String priceLabel) {
    final trimmed = priceLabel.trim();
    if (trimmed.isEmpty || trimmed == '—') {
      return 'na';
    }

    final currencyTokens = RegExp(r'[A-Za-z]{2,}')
        .allMatches(trimmed)
        .map((m) => m.group(0)!.toUpperCase())
        .join('-');
    final currency = currencyTokens.isEmpty ? 'GEN' : currencyTokens;

    final numericCandidate = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
    if (numericCandidate.isEmpty) {
      return '${currency}_TXT_${trimmed.toLowerCase()}';
    }

    final normalizedNumber = double.tryParse(numericCandidate);

    if (normalizedNumber == null) {
      return '${currency}_TXT_${trimmed.toLowerCase()}';
    }

    final bucketSize = _bucketStepFor(normalizedNumber);
    final bucketed =
        ((normalizedNumber / bucketSize).round() * bucketSize).round();
    return '${currency}_$bucketed';
  }

  double _bucketStepFor(double value) {
    if (value <= 0) return 1;
    if (value < 5000) return 250;
    if (value < 20000) return 1000;
    if (value < 100000) return 5000;
    if (value < 500000) return 25000;
    if (value < 2000000) return 100000;
    return 500000;
  }

  void _debugCacheStats() {
    if (kDebugMode) {
      debugPrint(
        '[MarkerFactory] generated=$_generatedCount cacheSize=${_cache.length}/$_maxCacheSize',
      );
    }
  }
}
