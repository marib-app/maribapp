import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class AuthShimmerPlaceholder extends StatelessWidget {
  final double height;
  final double borderRadius;

  const AuthShimmerPlaceholder({
    super.key,
    this.height = 52,
    this.borderRadius = 18,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Shimmer.fromColors(
      baseColor: theme.colorScheme.surfaceVariant.withOpacity(0.4),
      highlightColor: theme.colorScheme.surfaceVariant.withOpacity(0.8),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          color: theme.colorScheme.surfaceVariant,
        ),
      ),
    );
  }
}