// ملف: slider_shimmer.dart

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'slider_constants.dart';
import 'package:marib/ui/theme/extensions/shimmer_colors.dart';

class SliderShimmer extends StatelessWidget {
  const SliderShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final baseColor = colorScheme.shimmerBaseColor;
    final highlightColor = colorScheme.shimmerHighlightColor;
    final contentColor = colorScheme.shimmerContentColor;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: kSliderBannerSpacing / 2,
            ),
            child: SizedBox(
              width: double.infinity,
              height: kSliderBannerHeight,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(color: contentColor),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(4, (index) {
                final isActive = index == 1;
                return Container(
                  width: isActive ? 16 : 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: contentColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
