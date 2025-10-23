import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/ui/theme/theme.dart';

class MarkerFactory {
  static const int _maxCacheSize = 96;

  final LinkedHashMap<String, BitmapDescriptor> _cache = LinkedHashMap();
  int _generatedCount = 0;

  Future<BitmapDescriptor> buildMarkerForAd({
    required BuildContext context,
    required String priceLabel,
    required bool selected,
    required Color brand,
    required String? sectionLabel,
    required double zoomLevel,
  }) async {
    final brightness = Theme.of(context).brightness;
    final normalizedSection = _resolveSectionKey(sectionLabel);
    final zoomBucket = _zoomBucketFor(zoomLevel);
    final isDark = brightness == Brightness.dark;

    final key = _buildCacheKey(
      priceLabel: priceLabel,
      selected: selected,
      brand: brand,
      brightness: brightness,
      sectionKey: normalizedSection,
      zoomBucket: zoomBucket,
    );

    final cached = _getFromCache(key);
    if (cached != null) return cached;

    const double basePinHeight = 66;
    const double basePinWidth = 46;
    const double badgeHeight = 26;
    const double badgePadding = 8;
    const double pinToBadgeSpace = 6;
    const double glyphDiameter = 22;
    const double glyphSpacing = 6;

    final resolvedPrice = priceLabel.trim().isEmpty ? '—' : priceLabel.trim();

    final visibility = _visibilityFactorForZoom(zoomLevel);
    final overallScale = ui.lerpDouble(0.78, 1.1, visibility)!;
    final badgeScale = ui.lerpDouble(0.72, 1.05, visibility)!;
    final badgeOpacity =
        selected ? 1.0 : ui.lerpDouble(0.35, 0.95, visibility)!;
    final glyphOpacity =
        selected ? 1.0 : ui.lerpDouble(0.45, 0.95, visibility)!;
    final textOpacity = selected ? 1.0 : ui.lerpDouble(0.6, 1.0, visibility)!;

    final ui.ParagraphBuilder pb = ui.ParagraphBuilder(
      ui.ParagraphStyle(fontSize: 12, textDirection: ui.TextDirection.rtl),
    )
      ..pushStyle(
        ui.TextStyle(
          color: Colors.white.withOpacity(textOpacity),
          fontWeight: ui.FontWeight.w700,
        ),
      )
      ..addText(resolvedPrice);
    final ui.Paragraph paragraph = pb.build()
      ..layout(const ui.ParagraphConstraints(width: 160));
    final double textWidth = paragraph.maxIntrinsicWidth.clamp(32, 160);

    final badgeWidth =
        textWidth + badgePadding * 2 + glyphDiameter + glyphSpacing;
    final totalWidth = basePinWidth + pinToBadgeSpace + badgeWidth;
    final totalHeight = math.max(basePinHeight, badgeHeight).toDouble();

    final scaledWidth = totalWidth * overallScale;
    final scaledHeight = totalHeight * overallScale;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, scaledWidth, scaledHeight),
    );

    canvas.scale(overallScale);

    final basePinColor = selected
        ? brand
        : (isDark ? const Color(0xFF2a7bff) : const Color(0xFF1e88e5));
    final baseBadgeColor = selected
        ? brand
        : (isDark ? const Color(0xFF333333) : const Color(0xCC000000));

    final pinRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, basePinWidth, basePinHeight - 10),
      const Radius.circular(14),
    );
    final paintPin = Paint()..color = basePinColor;
    canvas.drawRRect(pinRect, paintPin);

    final pinTail = Path()
      ..moveTo(basePinWidth / 2 - 8, basePinHeight - 10)
      ..lineTo(basePinWidth / 2, basePinHeight)
      ..lineTo(basePinWidth / 2 + 8, basePinHeight - 10)
      ..close();
    canvas.drawPath(pinTail, paintPin);

    final glyphRect = Rect.fromCircle(
      center: Offset(basePinWidth / 2, 24),
      radius: 14,
    );
    final glyphBackgroundPaint = Paint()
      ..color = Colors.white.withOpacity(glyphOpacity);
    canvas.drawOval(glyphRect, glyphBackgroundPaint);
    _drawGlyph(
      canvas,
      glyphRect.deflate(5),
      _glyphForSection(normalizedSection),
      selected ? brand : basePinColor.withOpacity(.9),
    );
    final badgeLeft = basePinWidth + pinToBadgeSpace;

    final badgeRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        badgeLeft,
        (totalHeight - badgeHeight) / 2,
        badgeWidth,
        badgeHeight,
      ),
      const Radius.circular(20),
    );
    canvas.save();
    final badgeCenter = Offset(
      badgeLeft + badgeWidth / 2,
      totalHeight / 2,
    );
    canvas.translate(badgeCenter.dx, badgeCenter.dy);
    canvas.scale(badgeScale);
    canvas.translate(-badgeCenter.dx, -badgeCenter.dy);

    final badgePaint = Paint()
      ..color = baseBadgeColor.withOpacity(badgeOpacity);
    canvas.drawRRect(badgeRect, badgePaint);

    final iconCircleRect = Rect.fromLTWH(
      badgeLeft + badgePadding,
      (totalHeight - glyphDiameter) / 2,
      glyphDiameter,
      glyphDiameter,
    );
    final iconCirclePaint = Paint()
      ..color = Colors.white.withOpacity(glyphOpacity);
    canvas.drawOval(iconCircleRect, iconCirclePaint);

    _drawGlyph(
      canvas,
      iconCircleRect.deflate(5),
      _glyphForSection(normalizedSection),
      selected ? brand : basePinColor.withOpacity(.92),
    );

    final textOffset = Offset(
      iconCircleRect.right + glyphSpacing,
      (totalHeight - paragraph.height) / 2,
    );
    canvas.drawParagraph(paragraph, textOffset);

    canvas.restore();

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      scaledWidth.ceil(),
      scaledHeight.ceil(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final descriptor = BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
    _addToCache(key, descriptor);
    _generatedCount++;
    _debugCacheStats();
    return descriptor;
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
    required String sectionKey,
    required int zoomBucket,
  }) {
    final normalizedPrice = _normalizePriceLabel(priceLabel);
    final selectionKey = selected ? 'sel' : 'nor';
    final brightnessKey = brightness == Brightness.dark ? 'dark' : 'light';
    final brandKey = brand.value.toRadixString(16);
    return '$normalizedPrice|$selectionKey|$brandKey|$brightnessKey|$sectionKey|z$zoomBucket';
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

  double _visibilityFactorForZoom(double zoom) {
    const double minZoom = 5.5;
    const double maxZoom = 18.0;
    if (zoom <= minZoom) return 0;
    if (zoom >= maxZoom) return 1;
    return (zoom - minZoom) / (maxZoom - minZoom);
  }

  int _zoomBucketFor(double zoom) => (zoom * 2).round();

  String _resolveSectionKey(String? sectionLabel) {
    if (sectionLabel == null || sectionLabel.trim().isEmpty) {
      return 'general';
    }
    var normalized = sectionLabel.toLowerCase();
    normalized = normalized
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي');
    if (normalized.contains('سيار') ||
        normalized.contains('car') ||
        normalized.contains('vehicle')) {
      return 'cars';
    }
    if (normalized.contains('عقار') ||
        normalized.contains('real') ||
        normalized.contains('property') ||
        normalized.contains('home')) {
      return 'real_estate';
    }
    if (normalized.contains('الكترون') ||
        normalized.contains('elect') ||
        normalized.contains('tech')) {
      return 'electronics';
    }
    if (normalized.contains('وظ') ||
        normalized.contains('job') ||
        normalized.contains('work')) {
      return 'jobs';
    }
    if (normalized.contains('خدم') ||
        normalized.contains('service') ||
        normalized.contains('خدمه') ||
        normalized.contains('خدمات')) {
      return 'services';
    }
    return 'general';
  }

  _MarkerGlyph _glyphForSection(String sectionKey) {
    switch (sectionKey) {
      case 'real_estate':
        return _MarkerGlyph.realEstate;
      case 'cars':
        return _MarkerGlyph.car;
      case 'electronics':
        return _MarkerGlyph.electronics;
      case 'jobs':
        return _MarkerGlyph.briefcase;
      case 'services':
        return _MarkerGlyph.wrench;
      default:
        return _MarkerGlyph.general;
    }
  }

  void _drawGlyph(
    Canvas canvas,
    Rect rect,
    _MarkerGlyph glyph,
    Color color,
  ) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = color;

    switch (glyph) {
      case _MarkerGlyph.realEstate:
        final roof = Path()
          ..moveTo(rect.left + rect.width / 2, rect.top)
          ..lineTo(rect.right, rect.top + rect.height * 0.45)
          ..lineTo(rect.left, rect.top + rect.height * 0.45)
          ..close();
        canvas.drawPath(roof, paint);
        final body = RRect.fromRectAndRadius(
          Rect.fromLTWH(
            rect.left + rect.width * 0.12,
            rect.top + rect.height * 0.45,
            rect.width * 0.76,
            rect.height * 0.48,
          ),
          const Radius.circular(2.5),
        );
        canvas.drawRRect(body, paint);
        final doorPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;
        final doorRect = Rect.fromLTWH(
          rect.left + rect.width * 0.42,
          rect.top + rect.height * 0.58,
          rect.width * 0.2,
          rect.height * 0.35,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(doorRect, const Radius.circular(1.5)),
          doorPaint,
        );
        break;
      case _MarkerGlyph.car:
        final carBody = RRect.fromRectAndRadius(
          Rect.fromLTWH(
            rect.left,
            rect.top + rect.height * 0.35,
            rect.width,
            rect.height * 0.45,
          ),
          const Radius.circular(3),
        );
        canvas.drawRRect(carBody, paint);
        final topBody = Path()
          ..moveTo(rect.left + rect.width * 0.2, rect.top + rect.height * 0.35)
          ..lineTo(rect.left + rect.width * 0.35, rect.top)
          ..lineTo(rect.right - rect.width * 0.35, rect.top)
          ..lineTo(rect.right - rect.width * 0.2, rect.top + rect.height * 0.35)
          ..close();
        canvas.drawPath(topBody, paint);
        final wheelPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;
        final leftWheel = Rect.fromCircle(
          center: Offset(rect.left + rect.width * 0.25, rect.bottom),
          radius: rect.width * 0.16,
        );
        final rightWheel = Rect.fromCircle(
          center: Offset(rect.right - rect.width * 0.25, rect.bottom),
          radius: rect.width * 0.16,
        );
        canvas.drawOval(leftWheel, wheelPaint);
        canvas.drawOval(rightWheel, wheelPaint);
        break;
      case _MarkerGlyph.electronics:
        final screenRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(
            rect.left,
            rect.top,
            rect.width,
            rect.height * 0.7,
          ),
          const Radius.circular(2.5),
        );
        canvas.drawRRect(screenRect, paint);
        final standPaint = Paint()
          ..color = color.withOpacity(.9)
          ..style = PaintingStyle.fill;
        final standRect = Rect.fromLTWH(
          rect.left + rect.width * 0.35,
          rect.top + rect.height * 0.72,
          rect.width * 0.3,
          rect.height * 0.1,
        );
        canvas.drawRect(standRect, standPaint);
        final baseRect = Rect.fromLTWH(
          rect.left + rect.width * 0.2,
          rect.bottom - rect.height * 0.12,
          rect.width * 0.6,
          rect.height * 0.12,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(baseRect, const Radius.circular(1.5)),
          standPaint,
        );
        break;
      case _MarkerGlyph.briefcase:
        final bodyRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(
            rect.left,
            rect.top + rect.height * 0.2,
            rect.width,
            rect.height * 0.6,
          ),
          const Radius.circular(2.5),
        );
        canvas.drawRRect(bodyRect, paint);
        final handleRect = Rect.fromLTWH(
          rect.left + rect.width * 0.25,
          rect.top,
          rect.width * 0.5,
          rect.height * 0.25,
        );
        final handlePaint = Paint()
          ..color = paint.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = rect.width * 0.12;
        canvas.drawRRect(
          RRect.fromRectAndRadius(handleRect, const Radius.circular(1.5)),
          handlePaint,
        );
        final claspPaint = Paint()
          ..color = Colors.white
          ..strokeWidth = rect.height * 0.08
          ..style = PaintingStyle.stroke;
        canvas.drawLine(
          Offset(rect.left + rect.width * 0.18, rect.top + rect.height * 0.5),
          Offset(rect.right - rect.width * 0.18, rect.top + rect.height * 0.5),
          claspPaint,
        );
        break;
      case _MarkerGlyph.wrench:
        final path = Path();
        final center = rect.center;
        path.moveTo(center.dx, rect.top);
        path.cubicTo(
          rect.right,
          rect.top + rect.height * 0.15,
          rect.right,
          rect.top + rect.height * 0.45,
          center.dx,
          rect.top + rect.height * 0.55,
        );
        path.lineTo(center.dx, rect.bottom);
        path.cubicTo(
          rect.left + rect.width * 0.45,
          rect.bottom,
          rect.left + rect.width * 0.45,
          rect.top + rect.height * 0.65,
          center.dx,
          rect.top + rect.height * 0.55,
        );
        path.close();
        canvas.drawPath(path, paint);
        break;
      case _MarkerGlyph.general:
        final circlePaint = Paint()
          ..color = color
          ..style = PaintingStyle.fill;
        canvas.drawCircle(rect.center, rect.width / 2, circlePaint);
        final highlightPaint = Paint()..color = Colors.white.withOpacity(.6);
        canvas.drawCircle(
          Offset(rect.center.dx - rect.width * 0.15,
              rect.center.dy - rect.height * 0.15),
          rect.width * 0.18,
          highlightPaint,
        );
        break;
    }
  }

  void _debugCacheStats() {
    if (kDebugMode) {
      debugPrint(
        '[MarkerFactory] generated=$_generatedCount cacheSize=${_cache.length}/$_maxCacheSize',
      );
    }
  }
}

enum _MarkerGlyph {
  realEstate,
  car,
  electronics,
  briefcase,
  wrench,
  general,
}
