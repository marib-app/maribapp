import 'package:flutter/material.dart';

import 'package:marib/utils/app_icon.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/ui_utils.dart';

/// A reusable badge to highlight verified sellers across the app.
///
/// The badge adapts its padding and typography so it can be used in both
/// compact (icon-only) and extended (icon + label) contexts.
class SellerVerifiedBadge extends StatelessWidget {
  const SellerVerifiedBadge({
    super.key,
    this.showLabel = true,
    this.iconSize = 14,
    this.padding,
  });

  /// Whether to render the textual label next to the icon.
  final bool showLabel;

  /// The size of the check icon inside the badge.
  final double iconSize;

  /// Overrides the default padding when provided.
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final colors = context.color;
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    final Color accent = colors.secondaryColor;
    final Gradient gradient = LinearGradient(
      colors: <Color>[
        accent.withOpacity(isDark ? 0.24 : 0.18),
        accent.withOpacity(isDark ? 0.12 : 0.10),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    final EdgeInsetsGeometry resolvedPadding = padding ??
        EdgeInsets.symmetric(
          horizontal: showLabel ? 8 : 6,
          vertical: showLabel ? 4 : 3,
        );

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: accent.withOpacity(isDark ? 0.35 : 0.25),
          width: 0.7,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: accent.withOpacity(isDark ? 0.22 : 0.15),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: resolvedPadding,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: iconSize + 6,
              height: iconSize + 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withOpacity(isDark ? 0.28 : 0.20),
              ),
              alignment: Alignment.center,
              child: UiUtils.getSvg(
                AppIcons.verifiedIcon,
                width: iconSize,
                height: iconSize,
                color: accent,
              ),
            ),
            if (showLabel) ...<Widget>[
              const SizedBox(width: 6),
              Text('verifiedLbl'.translate(context))
                  .color(accent)
                  .bold(weight: FontWeight.w600)
                  .size(context.font.small),
            ],
          ],
        ),
      ),
    );
  }
}