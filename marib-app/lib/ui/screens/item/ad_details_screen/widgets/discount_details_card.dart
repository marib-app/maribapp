import 'package:flutter/material.dart';

class DiscountDetailsCard extends StatelessWidget {
  const DiscountDetailsCard({
    super.key,
    required this.finalPriceText,
    required this.basePriceText,
    required this.isActive,
  });

  final String finalPriceText;
  final String basePriceText;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'تفاصيل الخصم',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'السعر بعد الخصم: $finalPriceText',
            style: theme.textTheme.bodyMedium,
          ),
          Text(
            'السعر الأساسي: $basePriceText',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
          ),
          const SizedBox(height: 8),
          Text(
            isActive ? 'الخصم مفعل حالياً.' : 'الخصم غير مفعل في الوقت الحالي.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: isActive ? Colors.green : theme.hintColor,
            ),
          ),
        ],
      ),
    );
  }
}