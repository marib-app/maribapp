import 'package:flutter/material.dart';

class DeliverySizeDisplay extends StatelessWidget {
  const DeliverySizeDisplay({
    super.key,
    required this.valueText,
  });

  final String valueText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final labelStyle = theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600);
    final valueStyle = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w700,
      color: colorScheme.onSurface,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('حجم الطلب', style: labelStyle),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colorScheme.outline.withOpacity(0.25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.scale_rounded, size: 18, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(valueText, style: valueStyle),
            ],
          ),
        ),
      ],
    );
  }
}