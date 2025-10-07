import 'package:flutter/material.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';

class CustomDropdownFormField<T> extends StatelessWidget {
  final String? hintText;
  final T? value;
  final List<T> items;
  final Function(T?)? onChanged;
  final bool? isRequired;
  final Color? fillColor;
  final Color? borderColor;
  final Widget? prefix;
  final Widget? suffix;
  final TextStyle? hintTextStyle;
  final TextStyle? textStyle;

  final Widget? fixedPrefix;
  final bool? dense;

  const CustomDropdownFormField({
    super.key,
    required this.items,
    this.value,
    this.onChanged,
    this.hintText,
    this.isRequired,
    this.fillColor,
    this.borderColor,
    this.prefix,
    this.suffix,
    this.hintTextStyle,
    this.fixedPrefix,
    this.dense,
    this.textStyle,

  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      value: value,
      onChanged: onChanged,
      validator: (T? selectedValue) {
        if (isRequired == true && selectedValue == null) {
          return "This field is required";
        }
        return null;
      },
      items: items
          .map((T item) => DropdownMenuItem<T>(
                value: item,
                child: Text(
                  item.toString(),
                  style: textStyle ??
                      TextStyle(
                          fontSize: context.font.large,
                          color: context.color.textDefaultColor),
                ),
              ))
          .toList(),
      decoration: InputDecoration(
        prefix: prefix,
        isDense: dense,
        prefixIcon: fixedPrefix,
        suffixIcon: suffix,
        hintText: value == null ? hintText : null, // Show hint text when no value is selected
        hintStyle: hintTextStyle ??
            TextStyle(
                color: context.color.textColorDark.withOpacity(0.7),
                fontSize: context.font.large),
        filled: true,
        fillColor: fillColor ?? context.color.secondaryColor,
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(width: 1.5, color: context.color.territoryColor),
          borderRadius: BorderRadius.circular(10),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(
              width: 1.5,
              color: borderColor ?? context.color.borderColor.darken(50)),
          borderRadius: BorderRadius.circular(10),
        ),
        border: OutlineInputBorder(
          borderSide: BorderSide(
              width: 1.5, color: borderColor ?? context.color.borderColor),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}
