import 'package:flutter/material.dart';

/// يعرض الكمية المتبقية للتشكيلة المحددة (لون/مقاس).
class VariantStockInfo extends StatelessWidget {
  const VariantStockInfo({
    super.key,
    required this.availableStock,
    required this.selectedQuantity,
    required this.hasVariantStocks,
  });

  /// إجمالي المتاح للتشكيلة الحالية.
  final int? availableStock;

  /// الكمية التي حددها المستخدم حالياً.
  final int selectedQuantity;

  /// هل يوجد مخزون متنوع يعتمد على السمات؟
  final bool hasVariantStocks;

  @override
  Widget build(BuildContext context) {
    if (!hasVariantStocks || availableStock == null) {
      return const SizedBox.shrink();
    }

    final int available = availableStock!.clamp(0, 999999);
    final int remaining = (available - selectedQuantity).clamp(0, 999999);
    final colors = Theme.of(context).colorScheme;
    final textStyle = Theme.of(context)
        .textTheme
        .bodyMedium
        ?.copyWith(fontWeight: FontWeight.w700, color: colors.onSurface);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surfaceVariant.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outline.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.inventory_2_rounded,
              size: 18, color: colors.primary.withOpacity(0.9)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('المتاح: $available', style: textStyle),
                if (remaining >= 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'المتبقي بعد اختيارك: $remaining',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colors.onSurface.withOpacity(0.7),
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
