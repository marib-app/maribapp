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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.scale_rounded, size: 18, color: colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'حجم هذا المنتج هو $valueText',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'حجم المنتج قد يؤثر أحياناً على تكلفة التوصيل.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.hintColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
