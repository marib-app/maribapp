// مخصص لعرض حقل من نوع Checkbox متعدد الاختيارات

import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/responsiveSize.dart';
import 'package:marib/utils/validator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import 'package:marib/utils/ui_utils.dart';



import 'package:marib/ui/screens/item/add_item_screen/custom_filed_structure/custom_field.dart';

/// =====================
/// Logic (Controller)
/// =====================
class CustomCheckboxField extends CustomField {
  @override
  String type = "checkbox";

  /// قائمة القيم المختارة
  List checked = [];

  @override
  void init() {
    if (parameters['isEdit'] == true) {
      if (parameters['value'] != null) {
        if ((parameters['value'] as List).isNotEmpty) {
          checked = parameters['value'];
          update(() {});
        }
      }
    }
    super.init();
  }

  @override
  Widget render() {
    // بناء الواجهة عبر Presentation Widget مفصول
    return CustomValidator<List>(
      validator: (List? value) {
        if (parameters['required'] != 1) return null;
        if (value?.isNotEmpty == true) return null;
        if (checked.isNotEmpty) return null;
        return "pleaseSelectValue".translate(context);
      },
      builder: (state) {
        // قراءة بارامترات الواجهة فقط
        final String title = parameters['name'] ?? '';
        final String? notes = (parameters['notes']?.toString().isNotEmpty ?? false)
            ? parameters['notes'].toString()
            : null;
        final dynamic image = parameters['image'];
        final List values = (parameters['values'] as List?) ?? const [];

        // تمرير Callbacks فقط – بدون منطق واجهة داخل العرض
        void toggleValue(String value) {
          final bool isChecked = checked.contains(value);
          if (isChecked) {
            checked.remove(value);
          } else {
            checked.add(value);
          }
          // حفظ القيم في الحاوية العامة
          CustomField.fieldsData.addAll({
            parameters['id'].toString(): checked,
          });
          // تحديث الواجهة و الـ FormField state
          update(() {});
          state.didChange(checked);
        }

        return CustomCheckboxFieldView(
          title: title,
          notes: notes,
          image: image,
          values: values,
          checkedValues: checked.cast<String>(),
          hasError: state.hasError,
          errorText: state.errorText,
          onToggle: toggleValue,
        );
      },
    );
  }
}






















/// =====================
/// UI (Presentation Only)
/// =====================

class CustomCheckboxFieldView extends StatelessWidget {
  const CustomCheckboxFieldView({
    super.key,
    required this.title,
    required this.values,
    required this.checkedValues,
    required this.onToggle,
    this.notes,
    this.image,
    this.hasError = false,
    this.errorText,
  });

  /// بيانات العرض
  final String title;
  final String? notes;
  final dynamic image; // نفس ما يرجع من parameters['image'] لا نغيره
  final List values; // قائمة القيم المعروضة
  final List<String> checkedValues; // القيم المختارة

  /// حالة التحقق
  final bool hasError;
  final String? errorText;

  /// حدث التبديل
  final void Function(String value) onToggle;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(
            title: title,
            notes: notes,
            image: image,
            hasError: hasError,
          ),
          SizedBox(height: 14.rh(context)),
          FocusTraversalGroup(
            child: _OptionsWrap(
              values: values, // الأفضل تمرير خريطة {value,color} جاهزة
              checkedValues: checkedValues.toSet(), // <-- Set لأداء أفضل
              onToggle: (v) {
                HapticFeedback.selectionClick(); // ردّة فعل لمسية
                onToggle(v);
              },
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: hasError
                ? Padding(
              key: const ValueKey('err'),
              padding: const EdgeInsetsDirectional.only(top: 6.0, start: 8),
              child: Semantics(
                liveRegion: true, // يقرأها قارئ الشاشة فوراً
                label: errorText ?? "",
                child: Text(errorText ?? "")
                    .size(context.font.small)
                    .color(context.color.error),
              ),
            )
                : const SizedBox.shrink(key: ValueKey('noerr')),
          ),
          const SizedBox(height: 1),
        ],
      ),
    );
  }
}


/// عنوان + صورة + ملاحظات

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.hasError,
    this.notes,
    this.image,
  });

  final String title;
  final String? notes;
  final dynamic image;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (image != null) ...[
          Container(
            width: 48.rw(context),
            height: 48.rh(context),
            decoration: BoxDecoration(
              color: context.color.territoryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: SizedBox(
              height: 24,
              width: 24,
              child: FittedBox(
                fit: BoxFit.none,
                child: UiUtils.imageType(
                  image,
                  width: 24,
                  height: 24,
                  fit: BoxFit.cover,
                  color: context.color.textDefaultColor,
                ),
              ),
            ),
          ),
          SizedBox(width: 10.rw(context)),
        ],
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title)
                .size(context.font.large)
                .bold(weight: FontWeight.w500)
                .color(hasError ? context.color.error : context.color.textColorDark),
            if (notes != null) ...[
              SizedBox(height: 5.rh(context)),
              Text(notes!)
                  .size(context.font.small)
                  .color(context.color.textLightColor),
            ],
          ],
        ),
      ],
    );
  }
}











// شبكة الخيارات (Tags) مع دعم الألوان

class _OptionsWrap extends StatelessWidget {
  const _OptionsWrap({
    required this.values,
    required this.checkedValues,
    required this.onToggle,
  });

  final List values;
  final Set<String> checkedValues; // <-- Set
  final void Function(String value) onToggle;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,             // <-- بدل padding لكل عنصر
      runSpacing: 6,          // <-- تباعد رأسي أنظف
      children: List.generate(values.length, (index) {
        final value = values[index].toString();
        final isChecked = checkedValues.contains(value);

        // ⚠️ الأفضل تمرير color جاهز من الأعلى:
        final Color? valueColor = _parseColorIfHex(value);

        return Semantics(
          button: true,
          selected: isChecked,
          label: valueColor != null ? '#$value' : value,
          child: Material(
            color: isChecked
                ? context.color.territoryColor.withOpacity(0.1)
                : context.color.secondaryColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: context.color.borderColor, width: 1.5),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => onToggle(value),
              child: AnimatedPadding(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 14),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isChecked ? Icons.done : Icons.add,
                      color: isChecked
                          ? context.color.territoryColor
                          : context.color.textColorDark,
                    ),
                    const SizedBox(width: 5),
                    if (valueColor != null) ...[
                      Container(
                        width: 20, height: 20,
                        decoration: BoxDecoration(
                          color: valueColor, shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey.shade300, width: 1),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(valueColor != null ? '#$value' : value).color(
                      isChecked
                          ? context.color.territoryColor
                          : context.color.textDefaultColor.withOpacity(0.6),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Color? _parseColorIfHex(String v) {
    try {
      if (v.length == 6 || (v.length == 8 && v.startsWith('FF'))) {
        return Color(int.parse('0xFF${v.substring(v.length - 6)}'));
      }
    } catch (_) {}
    return null;
  }
}




