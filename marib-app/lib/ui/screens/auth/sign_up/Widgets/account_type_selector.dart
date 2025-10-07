
// ==========================
// FILE: lib/ui/screens/auth/sign_up/account_type_selector.dart
// Purpose: منتقي نوع الحساب لمرة واحدة (بدون منطق)
// ==========================
import 'package:flutter/material.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';

class AccountTypeSelector extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;
  final VoidCallback onContinue;
  const AccountTypeSelector({super.key, required this.value, required this.onChanged, required this.onContinue});

  @override
  Widget build(BuildContext context) {
    final accountTypes = {
      "1": "individual".translate(context),
      "2": "realEstate".translate(context),
      "3": "commercial".translate(context),
    };

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text("chooseAccountType".translate(context)).size(context.font.large).color(context.color.textDefaultColor),
      const SizedBox(height: 12),
      Text("mustSelectAccountType".translate(context)).size(context.font.small).color(context.color.textColorDark.withOpacity(0.7)),
      const SizedBox(height: 16),
      ...accountTypes.entries.map((e) {
        final isSelected = value == e.key;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? context.color.territoryColor : context.color.borderColor.darken(30), width: isSelected ? 2 : 1),
            color: isSelected ? context.color.territoryColor.withOpacity(0.1) : context.color.secondaryColor,
          ),
          child: RadioListTile<String>(
            title: Text(e.value, style: TextStyle(fontSize: context.font.normal, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal, color: context.color.textDefaultColor)),
            value: e.key,
            groupValue: value,
            activeColor: context.color.territoryColor,
            onChanged: onChanged,
          ),
        );
      }).toList(),
      const SizedBox(height: 16),
      if (value != null)
        SizedBox(
          height: 46,
          width: double.infinity,
          child: ElevatedButton(
            onPressed: onContinue,
            style: ElevatedButton.styleFrom(backgroundColor: context.color.territoryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: Text("continue".translate(context)),
          ),
        ),
    ]);
  }
}