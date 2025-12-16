import 'package:flutter/material.dart';

class QuantitySelector extends StatelessWidget {
  const QuantitySelector({
    super.key,
    required this.quantity,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRestriction,
    this.stockLimit,
    this.remainingAfterSelection,
    this.canIncrement = true,
    this.canDecrement = true,
    this.isOutOfStock = false,
  });

  final int quantity;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final void Function(String message, {Color? color}) onRestriction;
  final int? stockLimit;
  final int? remainingAfterSelection;
  final bool canIncrement;
  final bool canDecrement;
  final bool isOutOfStock;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isTracked = stockLimit != null;

    final String? availableText =
        isTracked ? 'المتاح: ${stockLimit!.clamp(0, 9999)}' : null;
    final String? remainingText = (!isOutOfStock &&
            remainingAfterSelection != null &&
            remainingAfterSelection! >= 0)
        ? 'المتبقي بعد اختيارك: ${remainingAfterSelection!.clamp(0, 9999)}'
        : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outline.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'الكمية',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              if (availableText != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: colors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: colors.primary.withOpacity(0.25)),
                  ),
                  child: Text(
                    availableText,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isOutOfStock ? colors.error : colors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _QuantityActionButton(
                icon: Icons.remove_rounded,
                onTap: canDecrement ? onDecrement : null,
                onDisabledTap: canDecrement
                    ? null
                    : () => onRestriction(
                          'لا يمكن تقليل الكمية أكثر.',
                          color: colors.primary,
                        ),
              ),
              Expanded(
                child: Center(
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 180),
                    style: (theme.textTheme.headlineSmall ??
                            theme.textTheme.titleLarge ??
                            theme.textTheme.titleMedium ??
                            const TextStyle(fontSize: 22))
                        .copyWith(
                      fontWeight: FontWeight.w700,
                      color: colors.onSurface,
                    ),
                    child: Text('$quantity'),
                  ),
                ),
              ),
              _QuantityActionButton(
                icon: Icons.add_rounded,
                onTap: canIncrement ? onIncrement : null,
                onDisabledTap: canIncrement
                    ? null
                    : () => onRestriction(
                          isOutOfStock
                              ? 'نفد المخزون لهذا المنتج.'
                              : 'تجاوزت الكمية المتاحة في المخزون.',
                          color: isOutOfStock ? colors.error : colors.primary,
                        ),
              ),
            ],
          ),
          if (!isOutOfStock && remainingText != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: colors.surfaceVariant.withOpacity(0.6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                remainingText,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.hintColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          if (isOutOfStock) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                color: colors.error.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline_rounded,
                      size: 18, color: colors.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'نفد المخزون لهذا المنتج.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _QuantityActionButton extends StatelessWidget {
  const _QuantityActionButton({
    required this.icon,
    required this.onTap,
    this.onDisabledTap,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final VoidCallback? onDisabledTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final bool enabled = onTap != null;
    const double size = 48;

    final Color backgroundColor = enabled
        ? colors.primary.withOpacity(0.12)
        : theme.disabledColor.withOpacity(0.06);
    final Color borderColor = enabled
        ? colors.primary.withOpacity(0.45)
        : colors.outline.withOpacity(0.35);
    final Color iconColor =
        enabled ? colors.primary : theme.disabledColor.withOpacity(0.6);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : onDisabledTap,
        customBorder: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: backgroundColor,
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            icon,
            color: iconColor,
          ),
        ),
      ),
    );
  }
}
