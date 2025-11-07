import 'package:flutter/material.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/ui/theme/theme.dart';

class SubscriptionPackagesIndicator extends StatelessWidget {
  const SubscriptionPackagesIndicator({
    super.key,
    required this.count,
    required this.index,
    required this.activeColor,
    this.color,
  });

  final int count;
  final int index;
  final Color activeColor;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    if (count <= 1) {
      return const SizedBox.shrink();
    }
    final Color inactiveColor =
        color ?? context.color.borderColor.withOpacity(0.45);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final bool isActive = i == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          height: 8,
          width: isActive ? 22 : 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: isActive ? null : inactiveColor,
            gradient: isActive
                ? LinearGradient(
                    colors: [
                      activeColor,
                      activeColor.withOpacity(0.7),
                    ],
                  )
                : null,
          ),
        );
      }),
    );
  }
}