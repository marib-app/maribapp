import 'package:flutter/material.dart';
import 'package:marib/utils/extensions/extensions.dart';

import 'package:marib/ui/theme/theme.dart';

class MiniFab extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const MiniFab({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: '${icon.codePoint}_fab',
      mini: true,
      tooltip: tooltip,
      onPressed: onTap,
      backgroundColor: Theme.of(context).cardColor,
      foregroundColor: context.color.textDefaultColor,
      elevation: 2,
      child: Icon(icon),
    );
  }
}