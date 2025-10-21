import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ConvertAmountInput extends StatelessWidget {
  const ConvertAmountInput({
    super.key,
    required this.controller,
    required this.inputFormatters,
    required this.onChanged,
  });

  final TextEditingController controller;
  final List<TextInputFormatter> inputFormatters;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color onBackground = isDark ? Colors.white : Colors.black;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'المبلغ',
          style: TextStyle(
            color: onBackground.withOpacity(0.72),
            fontWeight: FontWeight.w700,
          ),
          textDirection: TextDirection.rtl,

        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          inputFormatters: inputFormatters,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: 'ادخل المبلغ',
            border: _border(context),
            enabledBorder: _border(context),
            focusedBorder: _border(context),
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
      ],
    );
  }

  OutlineInputBorder _border(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color color = isDark ? Colors.white12 : Colors.black12;
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color),
    );
  }
}