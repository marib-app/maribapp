import 'package:flutter/material.dart';

import 'package:marib/utils/extensions/extensions.dart';

class StandardBottomSheetScaffold extends StatelessWidget {
  const StandardBottomSheetScaffold({
    super.key,
    required this.header,
    required this.body,
    this.footer,
    this.backgroundColor,
    this.borderRadius = 28,
    this.showDivider = true,
    this.expandBody = true,
    this.useSafeArea = true,
    this.safeAreaMinimum = EdgeInsets.zero,
  });

  final StandardBottomSheetHeader header;
  final Widget body;
  final Widget? footer;
  final Color? backgroundColor;
  final double borderRadius;
  final bool showDivider;
  final bool expandBody;
  final bool useSafeArea;
  final EdgeInsetsGeometry safeAreaMinimum;

  @override
  Widget build(BuildContext context) {
    final resolvedBackgroundColor =
        backgroundColor ?? Theme.of(context).colorScheme.surface;

    final children = <Widget>[
      header,
      if (showDivider) const Divider(height: 1),
      if (expandBody) Expanded(child: body) else body,
    ];

    if (footer != null) {
      final footerWidget = useSafeArea
          ? SafeArea(
        top: false,
        minimum: safeAreaMinimum,
        child: footer!,
      )
          : footer!;
      children.add(footerWidget);
    }

    return ClipRRect(
      borderRadius: BorderRadius.vertical(top: Radius.circular(borderRadius)),
      child: Material(
        color: resolvedBackgroundColor,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
      ),
    );
  }
}

class StandardBottomSheetHeader extends StatelessWidget {
  const StandardBottomSheetHeader({
    super.key,
    required this.content,
    this.showHandle = true,
    this.showCloseButton = false,
    this.onClosePressed,
    this.closeTooltip,
    this.closeIcon,
    this.closeButtonBackgroundColor,
    this.closeIconColor,
    this.padding = const EdgeInsets.fromLTRB(20, 16, 20, 12),
    this.handleColor,
    this.handleSize = const Size(44, 4),
    this.handleRadius = 8,
    this.spacingAfterHandle = 18,
    this.spacingBetweenContentAndClose = 12,
    this.backgroundColor,
  }) : assert(!showCloseButton || onClosePressed != null,
  'onClosePressed must be provided when showCloseButton is true.');

  final Widget content;
  final bool showHandle;
  final bool showCloseButton;
  final VoidCallback? onClosePressed;
  final String? closeTooltip;
  final Widget? closeIcon;
  final Color? closeButtonBackgroundColor;
  final Color? closeIconColor;
  final EdgeInsetsGeometry padding;
  final Color? handleColor;
  final Size handleSize;
  final double handleRadius;
  final double spacingAfterHandle;
  final double spacingBetweenContentAndClose;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final accent = context.color.territoryColor;

    final resolvedHandleColor = handleColor ?? onSurface.withOpacity(.18);
    final resolvedCloseBackgroundColor =
        closeButtonBackgroundColor ?? accent.withOpacity(.12);
    final resolvedCloseIconColor = closeIconColor ?? accent;

    final children = <Widget>[
      if (showHandle)
        Container(
          width: handleSize.width,
          height: handleSize.height,
          decoration: BoxDecoration(
            color: resolvedHandleColor,
            borderRadius: BorderRadius.circular(handleRadius),
          ),
        ),
      if (showHandle)
        SizedBox(
          height: spacingAfterHandle,
        ),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: content),
          if (showCloseButton) ...[
            SizedBox(width: spacingBetweenContentAndClose),
            DecoratedBox(
              decoration: BoxDecoration(
                color: resolvedCloseBackgroundColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                tooltip: closeTooltip ?? 'إغلاق',
                onPressed: onClosePressed,
                icon: IconTheme.merge(
                  data: IconThemeData(color: resolvedCloseIconColor),
                  child: closeIcon ?? const Icon(Icons.close_rounded),
                ),
              ),
            ),
          ],
        ],
      ),
    ];

    return Container(
      width: double.infinity,
      color: backgroundColor ?? theme.colorScheme.surface,
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
}