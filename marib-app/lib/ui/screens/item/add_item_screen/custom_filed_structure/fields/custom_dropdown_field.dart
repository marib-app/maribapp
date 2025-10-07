import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/responsiveSize.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

import 'package:marib/utils/app_icon.dart';
import 'package:marib/utils/ui_utils.dart';

import 'package:marib/ui/screens/item/add_item_screen/custom_filed_structure/custom_field.dart';

/// =====================
/// Logic (Controller)
/// =====================
/// - يبقي منطق الحقل كما هو (قراءة/كتابة القيمة، التخزين في AbstractField.fieldsData)
/// - يمرّر الحالة و callbacks إلى واجهة تقديمية CustomFieldDropdownView
class CustomFieldDropdown extends CustomField {
  @override
  String type = "dropdown";

  /// القيمة المختارة (سلسلة فارغة "" تعني "لا شيء/غير محدد")
  String? selected;

  @override
  void init() {
    // وضع التعديل: إذا فيه قيمة محفوظة من قبل، خذ أول قيمة
    if (parameters['isEdit'] == true) {
      if (parameters['value'] != null) {
        if ((parameters['value'] as List).isNotEmpty) {
          selected = parameters['value'][0].toString();
        }
      }
    } else {
      // وضع الإضافة: نبدأ بخيار فارغ (غير محدد)
      selected = "";
      // (اختياري) لو تحتاج إدراج خيار فارغ في القيم نفسها، نقدر نضيفه هنا
      // لكن نحن سنضيفه على مستوى الواجهة فقط.
    }

    update(() {});
    super.init();
  }

  @override
  Widget render() {
    // قراءة بارامترات العرض
    final String title = parameters['name'] ?? '';
    final String? notes = (parameters['notes']?.toString().isNotEmpty ?? false)
        ? parameters['notes'].toString()
        : null;
    final dynamic image = parameters['image'];
    final List<dynamic> values =
        (parameters['values'] as List<dynamic>? ?? const []);

    final bool requiredField = parameters['required'] == 1;

    // تحديث القيمة عند تغيّر الاختيار
    void handleChanged(dynamic v) {
      // نخزن "" عندما يريد المستخدم "لا شيء"
      selected = (v == null || v.toString().isEmpty) ? "" : v.toString();

      // تحديث الحالة في الواجهة
      update(() {});

      // حفظ في الحاوية العامة للحقول
      CustomField.fieldsData.addAll({
        parameters['id'].toString(): [selected],
      });
    }

    return CustomFieldDropdownView(
      title: title,
      notes: notes,
      image: image,
      values: values,
      selected: selected,
      requiredField: requiredField,
      onChanged: handleChanged,
    );
  }
}

/// =====================
/// UI (Presentation Only)
/// =====================
/// - واجهة تقديمية فقط (بدون منطق تخزين)
/// - تحتوي تحسينات UI/UX + خيار فارغ لإلغاء التحديد
class CustomFieldDropdownView extends StatefulWidget {
  const CustomFieldDropdownView({
    super.key,
    required this.title,
    required this.values,
    required this.selected,
    required this.requiredField,
    required this.onChanged,
    this.notes,
    this.image,
  });

  // بيانات العرض
  final String title;
  final String? notes;
  final dynamic image;
  final List<dynamic> values;

  // حالة الاختيار
  final String? selected;

  // التحقق
  final bool requiredField;

  // الأحداث
  final ValueChanged<dynamic> onChanged;

  @override
  State<CustomFieldDropdownView> createState() =>
      _CustomFieldDropdownViewState();
}

class _CustomFieldDropdownViewState extends State<CustomFieldDropdownView> {
  /// لإبراز التركيز (لون الحدود + ظل)
  final _focus = FocusNode();

  /// حالة فتح/إغلاق القائمة لتحريك السهم
  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = context.color.borderColor.darken(30);
    final hasSelection = widget.selected != null && widget.selected!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DropdownHeader(
          title: widget.title,
          notes: widget.notes,
          image: widget.image,
          requiredField: widget.requiredField,
        ),
        SizedBox(height: 14.rh(context)),

        /// وعاء الحقل مع انميشن حدود/ظل عند التركيز
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: context.color.secondaryColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              width: 1.2,
              color:
                  _focus.hasFocus ? context.color.territoryColor : borderColor,
            ),
            boxShadow: _focus.hasFocus
                ? [
                    BoxShadow(
                      blurRadius: 8,
                      color: context.color.territoryColor.withOpacity(.07),
                    )
                  ]
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            child: DropdownButtonFormField<dynamic>(
              focusNode: _focus,

              /// التحقق:
              /// - إذا الحقل إجباري → يمنع الخيار الفارغ
              /// - إذا غير إجباري → يسمح بالخيار الفارغ
              validator: (value) {
                if (!widget.requiredField) return null;
                if (value == null || value.toString().isEmpty) {
                  return "هذا الحقل مطلوب";
                }
                return null;
              },

              /// القيمة المعروضة:
              /// - null = يعرض الـ hint
              /// - قيمة نصية = يعرض القيمة المختارة
              initialValue: (hasSelection ? widget.selected : null),

              isExpanded: true,
              dropdownColor: context.color.secondaryColor,
              borderRadius: BorderRadius.circular(10),

              /// أيقونة السهم مع دوران عند الفتح
              icon: AnimatedRotation(
                duration: const Duration(milliseconds: 180),
                turns: _isOpen ? 0.5 : 0,
                child: SvgPicture.asset(
                  AppIcons.downArrow,
                  colorFilter: ColorFilter.mode(
                    context.color.textDefaultColor,
                    BlendMode.srcIn,
                  ),
                ),
              ),

              /// نص القائمة المختارة
              style: TextStyle(
                color: context.color.textDefaultColor.withOpacity(0.8),
                fontSize: context.font.large,
              ),

              /// Placeholder واضح
              hint: Text(
                "اختر من القائمة",
                style: TextStyle(
                  color: context.color.textDefaultColor.withOpacity(0.5),
                ),
              ),

              /// عناصر القائمة:
              /// أوّل عنصر = خيار فارغ لإلغاء التحديد ("— لا شيء —")
              items: <DropdownMenuItem<dynamic>>[
                DropdownMenuItem<dynamic>(
                  value: "",
                  child: Text(
                    "— لا شيء —",
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: context.color.textDefaultColor.withOpacity(0.6),
                    ),
                  ),
                ),
                ...widget.values.map<DropdownMenuItem<dynamic>>((dynamic e) {
                  final label = e.toString();
                  return DropdownMenuItem<dynamic>(
                    value: e,
                    child: SizedBox(
                      height: 44, // مساحة لمس مريحة
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  );
                }),
              ],

              /// تحسين عرض النص المختار (قصّ جميل)
              selectedItemBuilder: (_) => <Widget>[
                // للعنصر الفارغ
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    "— لا شيء —",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ).color(context.color.textDefaultColor.withOpacity(0.6)),
                ),
                // لبقية العناصر
                ...widget.values.map((e) {
                  final label = e.toString();
                  return Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ).color(context.color.textDefaultColor),
                  );
                }).toList(),
              ],

              /// تتبع حالة الفتح لإدارة دوران السهم
              onTap: () => setState(() => _isOpen = !_isOpen),

              /// عند الاختيار:
              /// - لو اختار "لا شيء" نخزّن ""
              /// - غير ذلك نخزّن القيمة كنص
              onChanged: (v) {
                final value = (v == null || v.toString().isEmpty) ? "" : v;
                widget.onChanged(value);
                setState(() => _isOpen = false);
              },
            ),
          ),
        ),

        /// رسالة خطأ ناعمة الظهور/الاختفاء
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 150),
          child: (!widget.requiredField || hasSelection)
              ? const SizedBox.shrink(key: ValueKey('noerr'))
              : Padding(
                  key: const ValueKey('err'),
                  padding: const EdgeInsetsDirectional.only(top: 6.0, start: 8),
                  child: Text(
                    "هذا الحقل مطلوب",
                    style: TextStyle(
                      fontSize: context.font.small,
                      color: context.color.error,
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

/// =====================
/// Header (Presentation)
/// =====================
/// - يعرض صورة اختيارية + عنوان + ملاحظات
/// - يضيف نجمة * إذا الحقل Required
class _DropdownHeader extends StatelessWidget {
  const _DropdownHeader({
    required this.title,
    required this.requiredField,
    this.notes,
    this.image,
  });

  final String title;
  final bool requiredField;
  final String? notes;
  final dynamic image;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (image != null) ...[
          Container(
            width: 32.rw(context),
            height: 32.rh(context),
            decoration: BoxDecoration(
              color: context.color.territoryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: FittedBox(
                fit: BoxFit.none,
                child: UiUtils.imageType(
                  image,
                  width: 20,
                  height: 20,
                  fit: BoxFit.cover,
                  color: context.color.textDefaultColor,
                ),
              ),
            ),
          ),
          SizedBox(width: 10.rw(context)),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // عنوان مع نجمة عند الإلزام
              Text(
                "$title${requiredField ? ' *' : ''}",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
                  .size(context.font.large)
                  .bold(weight: FontWeight.w500)
                  .color(context.color.textColorDark),

              // ملاحظات اختيارية
              if (notes != null && notes!.isNotEmpty) ...[
                SizedBox(height: 5.rh(context)),
                Text(
                  notes!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ).size(context.font.small).color(context.color.textLightColor),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
