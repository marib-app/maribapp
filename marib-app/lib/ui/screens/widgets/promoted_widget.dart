import 'package:marib/ui/theme/theme.dart';
import 'package:flutter/material.dart';

import 'package:marib/utils/extensions/extensions.dart';

enum PromoteCardType { text, icon }

class PromotedCard extends StatelessWidget {
  final PromoteCardType type;
  final Color? color;
  final EdgeInsetsGeometry? padding;
  final List<BoxShadow>? boxShadow;

  const PromotedCard({
    super.key,
    required this.type,
    this.color,
    this.padding,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    final Color background = color ?? context.color.territoryColor;
    final TextStyle labelStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Colors.white,
      fontWeight: FontWeight.w700,
      fontSize: 12,
    ) ??
        const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        );

    final List<BoxShadow> resolvedShadow =
        boxShadow ?? const [BoxShadow(color: Colors.black26, blurRadius: 8)];

    final EdgeInsets resolvedPadding =
    (padding ?? const EdgeInsets.symmetric(horizontal: 8, vertical: 6))
        .resolve(Directionality.of(context));

    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        boxShadow: resolvedShadow,
      ),
      child: Padding(
        padding: resolvedPadding,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (type == PromoteCardType.icon) ...[
              const Icon(
                Icons.local_fire_department,
                size: 14,
                color: Colors.white,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              "مميز".translate(context),
              style: labelStyle,
            ),
          ],
        ),
      ),
    );
  }
}
