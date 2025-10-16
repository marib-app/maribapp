import 'package:flutter/material.dart';

import 'package:marib/utils/extensions/extensions.dart';

class AuthFormShell extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double maxWidth;
  final Widget? footer;

  const AuthFormShell({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
    this.maxWidth = 480,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: context.color.secondaryColor,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: scheme.shadow.withOpacity(0.08),
                blurRadius: 32,
                spreadRadius: 0,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: padding,
                child: child,
              ),
              if (footer != null) footer!,
            ],
          ),
        ),
      ),
    );
  }
}