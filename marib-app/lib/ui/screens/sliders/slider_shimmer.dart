// ملف: slider_shimmer.dart

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'slider_constants.dart';

class SliderShimmer extends StatelessWidget {
  const SliderShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final baseColor = Colors.grey.shade300;
    final highlightColor = Colors.grey.shade100;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            height: kSliderBannerHeight,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(color: baseColor),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(4, (index) {
                final bool isActive = index == 1;
                final BorderRadius borderRadius = BorderRadius.circular(8);

                if (isActive) {
                  return Container(
                    width: 18,
                    height: 10,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      borderRadius: borderRadius,
                      gradient: LinearGradient(
                        colors: [
                          baseColor,
                          highlightColor,
                        ],
                      ),
                    ),
                    child: Center(
                      child: Container(
                        width: 16,
                        height: 8,
                        decoration: BoxDecoration(
                          color: baseColor,
                          borderRadius: borderRadius,
                        ),
                      ),
                    ),
                  );
                }


                return Container(
                  width: 16,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: baseColor,
                    borderRadius: borderRadius,
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
