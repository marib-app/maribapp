import 'package:flutter/material.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/ui/theme/theme.dart';

class FilterSortActionButton extends StatelessWidget {
  final VoidCallback onTap;
  final Widget icon;
  final String label;
  final EdgeInsetsGeometry padding;
  final double iconTextSpacing;
  final double borderRadius;

  const FilterSortActionButton({
    super.key,
    required this.onTap,
    required this.icon,
    required this.label,
    this.padding = const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
    this.iconTextSpacing = 8,
    this.borderRadius = 18,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.color;
    final backgroundColor = colors.secondaryColor;
    final borderColor = colors.borderColor.withOpacity(theme.brightness == Brightness.dark ? 0.7 : 0.5);
    final contentColor = colors.textDefaultColor;
    final radius = BorderRadius.circular(borderRadius);
    final textDirection = Directionality.of(context);
    final iconWidget = IconTheme.merge(
      data: IconThemeData(color: contentColor, size: 22),
      child: icon,
    );

    final labelStyle = theme.textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w600,
      color: contentColor,
    ) ??
        TextStyle(
          fontSize: theme.textTheme.labelLarge?.fontSize ?? 14,
          fontWeight: FontWeight.w600,
          color: contentColor,
        );

    final labelWidget = Flexible(
      child: Text(
        label,
        maxLines: 2,
        softWrap: true,
        textAlign: TextAlign.center,
        style: labelStyle,

      ),
    );


    return Material(
      color: Colors.transparent,

      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        splashColor: colors.territoryColor.withOpacity(0.12),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: radius,
            color: backgroundColor,

            border: Border.all(
              color: borderColor,
              width: 1,
            ),
          ),
          child: Padding(
            padding: padding,
            child: Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              textDirection: textDirection,
              children: [
                iconWidget,
                if (iconTextSpacing > 0)
                  SizedBox(width: iconTextSpacing),
                labelWidget,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
