import 'package:flutter/material.dart';

class AuthErrorNotice extends StatelessWidget {
  final String message;
  final bool isWarning;

  const AuthErrorNotice({
    super.key,
    required this.message,
    this.isWarning = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final Color background = isWarning
        ? colorScheme.secondaryContainer
        : colorScheme.errorContainer;
    final Color foreground = isWarning
        ? colorScheme.onSecondaryContainer
        : colorScheme.onErrorContainer;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isWarning ? Icons.info_outline : Icons.error_outline,
            color: foreground,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}