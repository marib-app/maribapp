import 'package:flutter/material.dart';

class AuthLoadingOverlay extends StatelessWidget {
  final bool isVisible;

  const AuthLoadingOverlay({
    super.key,
    required this.isVisible,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return AnimatedOpacity(
      opacity: isVisible ? 1 : 0,
      duration: const Duration(milliseconds: 180),
      child: ColoredBox(
        color: theme.colorScheme.surface.withOpacity(0.72),
        child: const Center(
          child: SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(strokeWidth: 3.5),
          ),
        ),
      ),
    );
  }
}