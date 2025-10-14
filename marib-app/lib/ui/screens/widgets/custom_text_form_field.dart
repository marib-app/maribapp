import 'package:marib/ui/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/validator.dart';

enum CustomTextFieldValidator {
  nullCheck,
  phoneNumber,
  email,
  password,
  maxFifty,
  otpSix,
  minAndMixLen,
  url,
  slug
}

class CustomTextFormField extends StatelessWidget {
  final String? hintText;
  final TextEditingController? controller;
  final int? minLine;
  final int? maxLine;
  final bool? isReadOnly;
  final List<TextInputFormatter>? inputFormatters;


  final CustomTextFieldValidator? validator;
  final Color? fillColor;
  final Function(dynamic value)? onChange;
  final Widget? prefix;
  final TextInputAction? action;
  final TextInputType? keyboard;
  final Widget? suffix;
  final bool? dense;
  final Color? borderColor;
  final Widget? fixedPrefix;
  final bool? obscureText;
  final int? maxLength;
  final int? minLength;
  final TextStyle? hintTextStyle;
  final TextCapitalization? capitalization;
  final bool? isRequired;
  final bool? isMobileRequired;
  final bool isCustomStyle;
  final TextAlign? textAlign;
  final EdgeInsetsGeometry? contentPadding;
  final bool autofocus;
  final FocusNode? focusNode;

  const CustomTextFormField({
    super.key,
    this.hintText,
    this.controller,
    this.minLine,
    this.maxLine,
    this.inputFormatters,
    this.autofocus = false,
    this.focusNode,
    this.isReadOnly,
    this.validator,
    this.fillColor,
    this.onChange,
    this.prefix,
    this.keyboard,
    this.action,
    this.suffix,
    this.dense,
    this.borderColor,
    this.fixedPrefix,
    this.obscureText,
    this.maxLength,
    this.hintTextStyle,
    this.minLength,
    this.capitalization,
    this.isRequired,
    this.isMobileRequired = true,
    this.isCustomStyle = false,
    this.textAlign,
    this.contentPadding,


  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      autofocus: autofocus,
      focusNode: focusNode,
      controller: controller,
      inputFormatters: inputFormatters,
      obscureText: obscureText ?? false,
      textInputAction: action,
      textAlign: textAlign ?? TextAlign.start,

      onTapOutside: (PointerDownEvent event) {
        FocusManager.instance.primaryFocus?.unfocus();
      },
      keyboardAppearance: Brightness.light,
      textCapitalization: capitalization ?? TextCapitalization.none,
      readOnly: isReadOnly ?? false,
      style: TextStyle(
        fontSize: context.font.large,
        color: context.color.textDefaultColor,
      ),
      minLines: minLine ?? 1,
      maxLines: maxLine ?? 1,
      onChanged: onChange,
      validator: (String? value) {
        if (validator == CustomTextFieldValidator.nullCheck) {
          return Validator.nullCheckValidator(value, context: context);
        }

        if (validator == CustomTextFieldValidator.maxFifty) {
          final String textValue = value ?? '';
          final int effectiveMaxLength = maxLength ?? 50;
          final String? maxLengthError = Validator.validateMaxLength(
            value: textValue,
            maxLength: effectiveMaxLength,
            context: context,
          );

          if (maxLengthError != null) {
            return maxLengthError;
          } else if (textValue.isEmpty) {
            return "fieldMustNotBeEmpty".translate(context);
          } else {
            return null;
          }
        }

        if (validator == CustomTextFieldValidator.minAndMixLen) {
          if (isRequired == true && value == "") {
            return Validator.nullCheckValidator(value, context: context);
          }

          if (isRequired == true &&
              (maxLength != null && value!.length > maxLength!)) {
            return "${"youCanAdd".translate(context)} \t $maxLength \t ${"maximumNumbersOnly".translate(context)}";
          }

          if (isRequired == true &&
              (minLength != null && value!.length < minLength!)) {
            return "$minLength \t ${"numMinRequired".translate(context)}";
          }
          return null;
        }

        if (validator == CustomTextFieldValidator.otpSix) {
          if ((value ??= "").length != 6) {
            return 'pleaseEnterSixDigits'.translate(context);
          }
          return null;
        }
        if (validator == CustomTextFieldValidator.email) {
          return Validator.validateEmail(email: value, context: context);
        }
        if (validator == CustomTextFieldValidator.slug) {
          return Validator.validateSlug(value, context: context);
        }
        if (validator == CustomTextFieldValidator.phoneNumber) {
          return Validator.validatePhoneNumber(
              value: value, context: context, isRequired: isMobileRequired!);
        }
        if (validator == CustomTextFieldValidator.url) {
          return Validator.urlValidation(value: value, context: context);
        }
        if (validator == CustomTextFieldValidator.password) {
          return Validator.validatePassword(value, context: context);
        }
        return null;
      },
      keyboardType: keyboard,
      maxLength: maxLength,
      decoration: isCustomStyle
          ? InputDecoration(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
        contentPadding: contentPadding ??
            const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              prefixIcon: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      hintText ?? '',
                      style: TextStyle(
                        color: context.color.forthColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: 8),
                    Container(
                      width: 2,
                      height: 24,
                      color: context.color.chatSenderColor,
                    ),
                    SizedBox(width: 8),
                  ],
                ),
              ),
              prefixIconConstraints: BoxConstraints(minWidth: 0, minHeight: 0),
              hintText: "enter".translate(context) + " " + (hintText ?? ''),
            )
          : InputDecoration(
              prefix: prefix,
              isDense: dense,
              prefixIcon: fixedPrefix,
              suffixIcon: suffix,
        contentPadding: contentPadding ??
            const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              hintText: hintText,
              hintStyle: hintTextStyle ??
                  TextStyle(
                    color: context.color.textColorDark.withOpacity(0.7),
                    fontSize: context.font.large,
                  ),
              filled: true,
              fillColor: fillColor ?? context.color.secondaryColor,
              focusedBorder: OutlineInputBorder(
                borderSide:
                    BorderSide(width: 1.5, color: context.color.territoryColor),
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
                    width: 1.5,
                    color: borderColor ?? context.color.borderColor),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
    );
  }
}
