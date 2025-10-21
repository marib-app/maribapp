// ملف: slider_shimmer.dart

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

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
        height: 150,
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
                final isActive = index == 1;
                return Container(
                  width: isActive ? 16 : 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: baseColor,
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
