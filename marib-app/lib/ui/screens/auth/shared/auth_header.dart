import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AuthHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? assetName;
  final double assetSize;
  final VoidCallback? onBack;
  final Widget? bottom;

  const AuthHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.assetName,
    this.assetSize = 96,
    this.onBack,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (onBack != null)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: IconButton(
              onPressed: onBack,
              icon: Icon(
                Icons.arrow_back_rounded,
                color: colorScheme.onBackground.withOpacity(0.8),
              ),
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            ),
          ),
        if (assetName != null) ...[
          const SizedBox(height: 8),
          Semantics(
            image: true,
            label: title,
            child: SvgPicture.asset(
              assetName!,
              height: assetSize,
            ),
          ),
          const SizedBox(height: 16),
        ],
        Text(
          title,
          style: textTheme.headlineSmall?.copyWith(
            color: colorScheme.onBackground,
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center,
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            subtitle!,
            style: textTheme.bodyLarge?.copyWith(
              color: colorScheme.onBackground.withOpacity(0.72),
            ),
            textAlign: TextAlign.center,
          ),
        ],
        if (bottom != null) ...[
          const SizedBox(height: 24),
          bottom!,
        ],
      ],
    );
  }
}