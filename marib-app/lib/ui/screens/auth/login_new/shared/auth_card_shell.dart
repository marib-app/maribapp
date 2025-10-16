import 'package:flutter/material.dart';

class AuthCardShell extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const AuthCardShell({
    super.key,
    required this.child,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 4,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      color: theme.colorScheme.surface,
      shadowColor: theme.colorScheme.primary.withOpacity(0.12),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(24),
        child: child,
      ),
    );
  }
}