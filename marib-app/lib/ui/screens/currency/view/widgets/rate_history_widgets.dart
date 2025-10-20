import 'package:flutter/material.dart';

class HistoryRangeSelector extends StatelessWidget {
  const HistoryRangeSelector({
    super.key,
    required this.availableRanges,
    required this.selectedRange,
    required this.onSelectRange,
    required this.brand,
    required this.onBackground,
    required this.textTheme,
  });

  final Set<int> availableRanges;
  final int? selectedRange;
  final ValueChanged<int> onSelectRange;
  final Color brand;
  final Color onBackground;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    const List<int> options = <int>[1, 3, 7];
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: options.map((int days) {
          final bool enabled = availableRanges.contains(days);
          final bool selected = enabled && selectedRange == days;
          final String label = days == 1 ? 'آخر يوم' : 'آخر $days أيام';
          final Color labelColor = selected
              ? Colors.white
              : onBackground.withOpacity(enabled ? 0.85 : 0.35);

          return ChoiceChip(
            label: Text(label),
            selected: selected,
            onSelected: enabled
                ? (bool value) {
                    if (value) {
                      onSelectRange(days);
                    }
                  }
                : null,
            labelStyle: textTheme.labelSmall?.copyWith(
                  color: labelColor,
                  fontWeight: FontWeight.w700,
                ) ??
                TextStyle(
                  color: labelColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
            selectedColor: brand,
            backgroundColor: onBackground.withOpacity(0.05),
            disabledColor: onBackground.withOpacity(0.06),
            shape: StadiumBorder(
              side: BorderSide(
                color: selected ? brand : onBackground.withOpacity(0.12),
              ),
            ),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          );
        }).toList(growable: false),
      ),
    );
  }
}

class MiniTrendChart extends StatelessWidget {
  const MiniTrendChart({
    super.key,
    required this.values,
    required this.color,
  });

  final List<double> values;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (values.length < 2) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Theme.of(context).dividerColor.withOpacity(0.12),
          ),
        ),
      );
    }

    return CustomPaint(
      painter: _MiniTrendChartPainter(
        values: values,
        color: color,
        background: Theme.of(context).canvasColor,
      ),
    );
  }
}

class _MiniTrendChartPainter extends CustomPainter {
  _MiniTrendChartPainter({
    required this.values,
    required this.color,
    required this.background,
  });

  final List<double> values;
  final Color color;
  final Color background;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) {
      return;
    }

    final double minValue =
        values.reduce((double a, double b) => a < b ? a : b);
    final double maxValue =
        values.reduce((double a, double b) => a > b ? a : b);
    final double range =
        (maxValue - minValue).abs() < 0.0001 ? 1 : maxValue - minValue;

    final Paint backgroundPaint = Paint()
      ..color = background
      ..style = PaintingStyle.fill;
    final RRect rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(10),
    );
    canvas.drawRRect(rect, backgroundPaint);

    final Paint borderPaint = Paint()
      ..color = color.withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawRRect(rect, borderPaint);

    final Path path = Path();
    for (int i = 0; i < values.length; i++) {
      final double x = size.width * (i / (values.length - 1));
      final double normalized = (values[i] - minValue) / range;
      final double y = size.height - (normalized * size.height);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final Paint linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
