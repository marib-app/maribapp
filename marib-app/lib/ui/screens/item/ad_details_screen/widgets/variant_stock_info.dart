import 'package:flutter/material.dart';

class VariantStockInfo extends StatelessWidget {
  const VariantStockInfo({
    super.key,
    this.availableStock,
    this.hasVariantStocks = false,
  });

  final int? availableStock;
  final bool hasVariantStocks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (availableStock != null) {
      final stock = availableStock!.clamp(-999999, 999999);
      return Text(
        'الكمية المتاحة: $stock',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: stock > 0 ? Colors.green : Colors.red,
        ),
      );
    }

    if (hasVariantStocks) {
      return Text(
        'اختر التوليفة المناسبة لمعرفة الكمية المتوفرة في المخزون.',
        style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
      );
    }

    return const SizedBox.shrink();
  }
}