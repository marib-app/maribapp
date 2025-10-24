import 'package:lottie/lottie.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/responsiveSize.dart';
import 'package:marib/utils/ui_utils.dart';

abstract mixin class BlurDialoge {}

///This dialoge box will blur background of screen
///This is normaly a screen which blurs its background we don't show builtin dialog box here instead we push to new route and show container in middle of screen
class BlurredDialogBox extends StatelessWidget implements BlurDialoge {
  final String? cancelButtonName;
  final bool? divider;
  final String? acceptButtonName;
  final VoidCallback? onCancel;
  final String? svgImagePath;
  final Color? svgImageColor;
  final Future<dynamic> Function()? onAccept;
  final String? title;
  final Widget content;
  final Color? cancelButtonColor;
  final Color? cancelTextColor;
  final Color? acceptButtonColor;
  final Color? acceptTextColor;
  final bool? backAllowedButton;
  final bool? showCancleButton;
  final bool? barrierDismissable;
  final bool? isAcceptContainesPush;

  const BlurredDialogBox({
    super.key,
    this.cancelButtonName,
    this.acceptButtonName,
    this.onCancel,
    this.onAccept,
    this.title,
    required this.content,
    this.cancelButtonColor,
    this.cancelTextColor,
    this.acceptButtonColor,
    this.acceptTextColor,
    this.backAllowedButton,
    this.showCancleButton,
    this.svgImagePath,
    this.svgImageColor,
    this.barrierDismissable,
    this.isAcceptContainesPush,
    this.divider,
  });

  @override
  Widget build(BuildContext context) {
    bool isBack = true;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    ///This backAllowedButton will help us to prevent back presses from sensitive dialoges
    return AnnotatedRegion(
      value: SystemUiOverlayStyle(
          systemNavigationBarDividerColor: Colors.transparent,
          statusBarColor: Colors.black.withOpacity(0)),
      child: Stack(
        children: [
          //Make dialoge box's background lighter black
          GestureDetector(
            onTap: () {
              if (barrierDismissable ?? false) {
                Navigator.pop(context);
              }
            },
            child: Container(
              color: Colors.black.withOpacity(0.14),
            ),
          ),
          PopScope(
            canPop: isBack,
            onPopInvoked: (didPop) {
              if (backAllowedButton == false) {
                isBack = false;
                return;
              }
              isBack = true;
              return;
            },
            /*onWillPop: () async {
              if (backAllowedButton == false) {
                return false;
              }
              return true;
            },*/

            child: LayoutBuilder(
              builder: (dialogContext, constraints) {
                final List<Widget> titleWidgets = [];

                if (svgImagePath != null) {
                  titleWidgets
                    ..add(
                      CircleAvatar(
                        radius: 93,
                        backgroundColor:
                            context.color.territoryColor.withOpacity(0.1),
                        child: SizedBox(
                          child: Lottie.asset(
                            svgImagePath!,
                            width: 500,
                            height: 370,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    )
                    ..add(const SizedBox(height: 20));
                }

                if (title != null) {
                  titleWidgets.add(
                    Text(
                      title!.firstUpperCase(),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  );
                }
                if (divider == true) {
                  if (titleWidgets.isNotEmpty) {
                    titleWidgets.add(const SizedBox(height: 16));
                  }
                  titleWidgets.add(const Divider());
                }

                return AlertDialog(
                  backgroundColor: colorScheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  title: titleWidgets.isEmpty
                      ? null
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: titleWidgets,
                        ),
                  content: content,
                  actionsAlignment: MainAxisAlignment.end,
                  actions: [
                    if (showCancleButton ?? true)
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor:
                              cancelTextColor ?? colorScheme.onSurface,
                          backgroundColor: cancelButtonColor,
                        ),
                        onPressed: () {
                          onCancel?.call();
                          Navigator.of(dialogContext).pop();
                        },
                        child: Text(
                          cancelButtonName ??
                              "cancelBtnLbl".translate(dialogContext),
                        ),
                      ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        foregroundColor: acceptTextColor,
                        backgroundColor: acceptButtonColor,
                      ),
                      onPressed: () async {
                        await onAccept?.call();
                        if (isAcceptContainesPush == false ||
                            isAcceptContainesPush == null) {
                          Future.delayed(
                            Duration.zero,
                            () {
                              Navigator.of(dialogContext).pop(true);
                            },
                          );
                        }
                      },
                      child: Text(
                        acceptButtonName ?? "ok".translate(dialogContext),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

///This dialoge box will blur background of screen
///This is normaly a screen which blurs its background we don't show builtin dialog box here instead we push to new route and show container in middle of screen
class BlurredDialogBuilderBox extends StatelessWidget implements BlurDialoge {
  final String? cancelButtonName;
  final String? acceptButtonName;
  final VoidCallback? onCancel;
  final String? svgImagePath;
  final Color? svgImageColor;
  final Future<dynamic> Function()? onAccept;
  final String title;
  final Widget? Function(BuildContext context, BoxConstraints constrains)
      contentBuilder;
  final Color? cancelButtonColor;
  final Color? cancelTextColor;
  final Color? acceptButtonColor;
  final Color? acceptTextColor;
  final bool? backAllowedButton;
  final bool? showCancleButton;
  final bool? isAcceptContainesPush;
  final bool? divider;

  const BlurredDialogBuilderBox({
    super.key,
    this.cancelButtonName,
    this.acceptButtonName,
    this.onCancel,
    this.onAccept,
    required this.title,
    required this.contentBuilder,
    this.cancelButtonColor,
    this.cancelTextColor,
    this.acceptButtonColor,
    this.acceptTextColor,
    this.backAllowedButton,
    this.showCancleButton,
    this.svgImagePath,
    this.svgImageColor,
    this.isAcceptContainesPush,
    this.divider,
  });

  @override
  Widget build(BuildContext context) {
    bool isBack = true;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    ///This backAllowedButton will help us to prevent back presses from sensitive dialoges
    return AnnotatedRegion(
      value: SystemUiOverlayStyle(
          systemNavigationBarDividerColor: Colors.transparent,
          statusBarColor: Colors.black.withOpacity(0)),
      child: Stack(
        children: [
          //Make dialoge box's background lighter black
          Container(
            color: Colors.black.withOpacity(0.14),
          ),

          PopScope(
            canPop: isBack,
            onPopInvoked: (didPop) async {
              if (backAllowedButton == false) {
                isBack = false;
                return;
              }
              isBack = true;
              return;
            },
            child: LayoutBuilder(builder: (context, constraints) {
              final List<Widget> titleWidgets = [];

              if (svgImagePath != null) {
                titleWidgets
                  ..add(
                    CircleAvatar(
                      radius: 49,
                      backgroundColor:
                      context.color.territoryColor.withOpacity(0.1),
                      child: SizedBox(
                        width: 43.5,
                        height: 43.5,
                        child: UiUtils.getSvg(
                          svgImagePath!,
                          color: svgImageColor,
                        ),
                      ),
                    ),
                  )
                  ..add(const SizedBox(height: 20));
              }

              titleWidgets.add(
                Text(
                  title.firstUpperCase(),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
              );

              if (divider == true) {
                if (titleWidgets.isNotEmpty) {
                  titleWidgets.add(const SizedBox(height: 16));
                }
                titleWidgets.add(const Divider());
              }

              return AlertDialog(
                backgroundColor: colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: titleWidgets,
                ),
                content: contentBuilder.call(context, constraints),
                actionsAlignment: MainAxisAlignment.end,

                actions: [
                  if (showCancleButton ?? true)
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor:
                        cancelTextColor ?? colorScheme.onSurface,
                        backgroundColor: cancelButtonColor,
                      ),
                      onPressed: () {
                        onCancel?.call();
                        Navigator.pop(context);
                      },
                      child: Text(
                        cancelButtonName ??
                            "cancelBtnLbl".translate(context),
                      ),
                    ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      foregroundColor: acceptTextColor,
                      backgroundColor: acceptButtonColor,
                    ),
                    onPressed: () async {
                      await onAccept?.call();
                      if (isAcceptContainesPush == false ||
                          isAcceptContainesPush == null) {
                        Future.delayed(
                          Duration.zero,
                              () {
                            Navigator.pop(context, true);
                          },
                        );
                      }
                    },
                    child: Text(
                      acceptButtonName ?? "ok".translate(context),
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}

class EmptyDialogBox extends StatelessWidget with BlurDialoge {
  final Widget child;
  final bool? barrierDismisable;

  const EmptyDialogBox(
      {super.key, required this.child, this.barrierDismisable});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
        child: Stack(
      children: [
        GestureDetector(
          onTap: () {
            if (barrierDismisable ?? true) Navigator.pop(context);
          },
          child: Container(
            color: Colors.black.withOpacity(0.3),
          ),
        ),
        Center(child: child),
      ],
    ));
  }
}
