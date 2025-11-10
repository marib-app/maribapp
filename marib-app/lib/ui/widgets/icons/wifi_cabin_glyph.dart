import 'dart:math' as math;

import 'package:flutter/material.dart';

class WifiCabinGlyph extends StatelessWidget {
  const WifiCabinGlyph({
    super.key,
    this.size = 36,
    this.color = Colors.white,
    this.strokeFactor,
  });

  final double size;
  final Color color;
  final double? strokeFactor;

  @override
  Widget build(BuildContext context) {
    final double effectiveStroke = strokeFactor != null
        ? size * strokeFactor!.clamp(0.02, 0.2)
        : size * 0.09;

    return SizedBox(
      height: size,
      width: size,
      child: CustomPaint(
        painter: _WifiCabinPainter(
          color: color,
          strokeWidth: effectiveStroke,
        ),
      ),
    );
  }
}

class _WifiCabinPainter extends CustomPainter {
  const _WifiCabinPainter({
    required this.color,
    required this.strokeWidth,
  });

  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = strokeWidth;

    final Offset arcCenter = Offset(size.width / 2, size.height * 0.38);

    void drawWifiArc(double radiusFactor, double start, double sweep) {
      final double radius = (size.width / 2) * radiusFactor;
      final Rect rect = Rect.fromCircle(center: arcCenter, radius: radius);
      canvas.drawArc(rect, start, sweep, false, strokePaint);
    }

    drawWifiArc(0.85, math.pi * 0.85, math.pi * 0.3);
    drawWifiArc(0.6, math.pi * 0.88, math.pi * 0.26);
    drawWifiArc(0.4, math.pi * 0.9, math.pi * 0.22);

    final Paint fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(arcCenter.dx, arcCenter.dy + size.height * 0.05),
      strokeWidth * 0.65,
      fillPaint,
    );

    final double houseWidth = size.width * 0.7;
    final double houseHeight = size.height * 0.32;
    final Rect houseRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.74),
      width: houseWidth,
      height: houseHeight,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(houseRect, Radius.circular(houseWidth * 0.12)),
      strokePaint,
    );

    final Path roof = Path()
      ..moveTo(size.width / 2, houseRect.top - houseHeight * 0.45)
      ..lineTo(houseRect.left, houseRect.top)
      ..lineTo(houseRect.right, houseRect.top)
      ..close();
    canvas.drawPath(roof, strokePaint);

    final double doorWidth = houseWidth * 0.26;
    final double doorHeight = houseHeight * 0.68;
    final Rect doorRect = Rect.fromCenter(
      center: Offset(size.width / 2, houseRect.bottom - doorHeight / 2),
      width: doorWidth,
      height: doorHeight,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(doorRect, Radius.circular(doorWidth * 0.3)),
      strokePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
