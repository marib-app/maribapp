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
    final colorScheme = theme.colorScheme;
    final labelStyle = theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600);
    final isStockTracked = stockLimit != null;

    final valueStyle = (theme.textTheme.headlineSmall ??
        theme.textTheme.titleLarge ??
        theme.textTheme.titleMedium ??
        const TextStyle(fontSize: 20))
        .copyWith(
      fontWeight: FontWeight.w700,
      color: colorScheme.onSurface,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('الكمية', style: labelStyle),
            if (isStockTracked) ...[
              const SizedBox(width: 10),
              _QuantityPill(
                icon: Icons.inventory_2_rounded,
                label: 'متاح: ${stockLimit!.clamp(0, 9999)}',
                foreground: isOutOfStock ? colorScheme.error : colorScheme.primary,
                background: (isOutOfStock ? colorScheme.error : colorScheme.primary).withOpacity(0.12),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 320;
            final buttonSize = compact ? 44.0 : 48.0;

            return Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 12 : 16,
                vertical: compact ? 10 : 14,
              ),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colorScheme.outline.withOpacity(0.2)),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.primary.withOpacity(0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  QuantityActionButton(
                    icon: Icons.remove_rounded,
                    dimension: buttonSize,
                    onTap: canDecrement ? onDecrement : null,
                    onDisabledTap: canDecrement
                        ? null
                        : () => onRestriction(
                      'الحد الأدنى للشراء هو قطعة واحدة.',
                      color: colorScheme.primary,
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 180),
                        style: valueStyle.copyWith(
                          fontSize: compact ? 20 : valueStyle.fontSize,
                        ),
                        child: Text('$quantity'),
                      ),
                    ),
                  ),
                  QuantityActionButton(
                    icon: Icons.add_rounded,
                    dimension: buttonSize,
                    onTap: canIncrement ? onIncrement : null,
                    onDisabledTap: canIncrement
                        ? null
                        : () => onRestriction(
                      isOutOfStock
                          ? 'هذه التوليفة غير متوفرة حالياً في المخزون.'
                          : 'لقد وصلت للكمية المتاحة لهذه التوليفة.',
                      color: isOutOfStock ? colorScheme.error : colorScheme.primary,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        if (!isOutOfStock && remainingAfterSelection != null && remainingAfterSelection! > 0) ...[
          const SizedBox(height: 10),
          _QuantityPill(
            icon: Icons.timelapse_rounded,
            label: 'المتبقي بعد اختيارك: ${remainingAfterSelection!.clamp(0, 9999)}',
            foreground: theme.hintColor,
            background: theme.hintColor.withOpacity(0.14),
          ),
        ],
        if (isOutOfStock) ...[
          const SizedBox(height: 10),
          _InlineBanner(
            icon: Icons.error_outline_rounded,
            message: 'هذه التوليفة غير متوفرة حالياً في المخزون. الرجاء اختيار سمة مختلفة أو العودة لاحقاً.',
            foreground: colorScheme.error,
            background: colorScheme.error.withOpacity(0.12),
          ),
        ] else if (remainingAfterSelection != null && remainingAfterSelection! <= 0) ...[
          const SizedBox(height: 10),
          _InlineBanner(
            icon: Icons.info_rounded,
            message: 'لا يمكنك تجاوز الكمية المتاحة حالياً لهذا المنتج.',
            foreground: colorScheme.primary,
            background: colorScheme.primary.withOpacity(0.10),
          ),
        ],
      ],
    );
  }
}

class QuantityActionButton extends StatelessWidget {
  const QuantityActionButton({
    super.key,
    required this.icon,
    this.onTap,
    this.onDisabledTap,
    required this.dimension,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final VoidCallback? onDisabledTap;
  final double dimension;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bool enabled = onTap != null;

    final Color backgroundColor = enabled
        ? colorScheme.primary.withOpacity(0.12)
        : theme.disabledColor.withOpacity(0.06);
    final Color borderColor = enabled
        ? colorScheme.primary.withOpacity(0.45)
        : colorScheme.outline.withOpacity(0.35);
    final Color iconColor =
    enabled ? colorScheme.primary : theme.disabledColor.withOpacity(0.6);

    return Semantics(
      button: true,
      enabled: enabled,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : onDisabledTap,
          customBorder: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: dimension,
            height: dimension,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor, width: 1.2),
              boxShadow: enabled
                  ? [
                BoxShadow(
                  color: colorScheme.primary.withOpacity(0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ]
                  : null,
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
        ),
      ),
    );
  }
}

class _QuantityPill extends StatelessWidget {
  const _QuantityPill({
    required this.icon,
    required this.label,
    required this.foreground,
    required this.background,
  });

  final IconData icon;
  final String label;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: foreground),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w600,
            ) ??
                TextStyle(
                  color: foreground,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _InlineBanner extends StatelessWidget {
  const _InlineBanner({
    required this.icon,
    required this.message,
    required this.foreground,
    required this.background,
  });

  final IconData icon;
  final String message;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: foreground),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: foreground,
                height: 1.4,
              ) ??
                  TextStyle(
                    color: foreground,
                    height: 1.4,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}