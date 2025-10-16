import 'package:flutter/material.dart';

class AuthTextField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final TextInputType keyboardType;
  final String label;
  final String? hint;
  final bool obscureText;
  final Widget? leading;
  final Widget? trailing;
  final ValueChanged<String>? onChanged;
  final TextInputAction textInputAction;
  final VoidCallback? onSubmitted;
  final bool enabled;

  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    this.focusNode,
    this.keyboardType = TextInputType.text,
    this.hint,
    this.obscureText = false,
    this.leading,
    this.trailing,
    this.onChanged,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.72),
            letterSpacing: 0.1,
          ),
        ),
        const SizedBox(height: 8),
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: theme.colorScheme.surfaceVariant.withOpacity(0.35),
          ),
          child: Row(
            children: [
              if (leading != null) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: leading!,
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  keyboardType: keyboardType,
                  obscureText: obscureText,
                  onChanged: onChanged,
                  textInputAction: textInputAction,
                  onSubmitted: (_) => onSubmitted?.call(),
                  enabled: enabled,
                  decoration: InputDecoration(
                    hintText: hint,
                    border: InputBorder.none,
                    contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 12),
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: trailing!,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}