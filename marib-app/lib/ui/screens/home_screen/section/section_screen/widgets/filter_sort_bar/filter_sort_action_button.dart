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
    this.padding = const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
    this.iconTextSpacing = 8,
    this.borderRadius = 18,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final baseColor = scheme.primaryContainer;
    final onBaseColor = scheme.onPrimaryContainer;
    final highlightColor = scheme.primary;
    final radius = BorderRadius.circular(borderRadius);

    return Material(
        color: Colors.transparent,
        elevation: 3,
        shadowColor: highlightColor.withOpacity(0.18),
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          splashColor: highlightColor.withOpacity(0.16),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  baseColor.brighten(12),
                  baseColor.darken(8),
                ],
            ),
              border: Border.all(
                color: highlightColor.withOpacity(0.32),
                width: 1.2,
            ),
              child: Padding(
                padding: padding,
                child: IntrinsicHeight(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      IconTheme.merge(
                        data: IconThemeData(color: onBaseColor, size: 22),
                        child: icon,
                      ),
                      SizedBox(height: iconTextSpacing),
                      Text(
                        label,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: onBaseColor,
                        ),
                      ),
                    ],
                ),
                ),
            ),
        ),
      ),
            ),
    );
  }
}