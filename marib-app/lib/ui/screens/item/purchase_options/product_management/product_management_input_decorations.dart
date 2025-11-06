import 'package:flutter/material.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/ui/theme/theme.dart';


class ProductManagementInputDecorations {
  const ProductManagementInputDecorations._();

  static InputDecoration themed(
    BuildContext context, {
    String? label,
    String? hint,
    String? helperText,
    String? suffixText,
    String? errorText,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    final color = context.color;
    return InputDecoration(
      labelText: label,
      hintText: hint,
      helperText: helperText,
      suffixText: suffixText,
      errorText: errorText,
      filled: true,
      fillColor: color.secondaryColor,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: color.borderColor.withOpacity(0.5)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: color.borderColor.withOpacity(0.5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: color.territoryColor),
      ),
    );
  }
}