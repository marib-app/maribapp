import 'package:flutter/material.dart';
import 'package:marib/utils/screen_scaler.dart';

class OnboardingDots extends StatelessWidget {
  const OnboardingDots({
    super.key,
    required this.itemCount,
    required this.currentPage,
  });

  final int itemCount;
  final double currentPage;

  double _lerp(double start, double end, double t) {
    final clampedT = t.clamp(0.0, 1.0).toDouble();
    return start + (end - start) * clampedT;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(itemCount, (index) {
        final clampedDifference =
            (currentPage - index).abs().clamp(0.0, 1.0).toDouble();
        final selectedness = 1.0 - clampedDifference;
        final width = _lerp(8, 18, selectedness);
        final color = Color.lerp(
          Colors.white38,
          Colors.white,
          selectedness,
        );

        return Container(
          margin: EdgeInsets.symmetric(horizontal: ScreenScaler.s(4)),
          width: ScreenScaler.s(width),
          height: ScreenScaler.s(8),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(ScreenScaler.s(8)),
          ),
        );
      }),
    );
  }
}