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
    this.padding = const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
    this.iconTextSpacing = 6,
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.color;
    final textColor = colorScheme.textDefaultColor;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(borderRadius),
      splashColor: Theme.of(context).colorScheme.primary.withOpacity(0.14),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: colorScheme.secondaryColor,
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(color: colorScheme.borderColor, width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            IconTheme.merge(
              data: IconThemeData(color: textColor, size: 22),
              child: icon,
            ),
            SizedBox(height: iconTextSpacing),
            Text(
              label,
              maxLines: 2,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}