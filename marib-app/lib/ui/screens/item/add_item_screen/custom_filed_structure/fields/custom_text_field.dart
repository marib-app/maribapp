// lib/ui/screens/item/add_item_screen/custom_filed_structure/fields/custom_text_field.dart

import 'package:flutter/material.dart';

import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/responsiveSize.dart';

import 'package:marib/utils/ui_utils.dart';
import 'package:marib/ui/screens/widgets/dynamic_field/dynamic_field.dart';
import 'package:marib/ui/screens/widgets/custom_text_form_field.dart';

import 'package:marib/ui/screens/item/add_item_screen/custom_filed_structure/custom_field.dart';

/// -------------------------
/// Helpers
/// -------------------------

/// يكتشف وجود أحرف عربية لتحديد RTL/LTR
TextDirection _autoDir(String s) {
  final hasArabic = RegExp(r'[\u0600-\u06FF]').hasMatch(s);
  return hasArabic ? TextDirection.rtl : TextDirection.ltr;
}

/// اتجاه افتراضي يعتمد على النص الابتدائي أو لغة الواجهة عند الفراغ
TextDirection _dirFor(BuildContext context, String initial) {
  if (initial.trim().isNotEmpty) return _autoDir(initial);
  final lang = Localizations.localeOf(context).languageCode.toLowerCase();
  const rtlLangs = ['ar', 'fa', 'ur', 'he', 'ps'];
  return rtlLangs.any((l) => lang.startsWith(l))
      ? TextDirection.rtl
      : TextDirection.ltr;
}

/// تطبيع Map إلى Map<String, dynamic> بلا كراش
Map<String, dynamic> _asStringDynamicMap(Map? m) {
  if (m == null) return <String, dynamic>{};
  if (m is Map<String, dynamic>) return m;
  return m.map((k, v) => MapEntry(k.toString(), v));
}

/// -------------------------
/// المنطق (Controller)
/// -------------------------
class TextFieldController {
  final String name;
  final String? notes;
  final String? image;
  final bool isRequired;
  final int? maxLen; // حد صلب (يمنع الإدخال بعده)
  final int? minLen;
  final int? softMaxLen; // حد ناعم (تحذير فقط)
  final dynamic id;

  final bool initController;
  final String initialValue;

  const TextFieldController({
    required this.name,
    required this.isRequired,
    required this.id,
    this.notes,
    this.image,
    this.maxLen,
    this.minLen,
    this.softMaxLen,
    this.initController = false,
    this.initialValue = "",
  });

  factory TextFieldController.fromParams(Map<String, dynamic> params) {
    final bool isEdit = params['isEdit'] == true;
    String initVal = "";

    if (isEdit && params['value'] != null) {
      final v = params['value'];
      if (v is List && v.isNotEmpty) {
        initVal = v.first?.toString() ?? "";
      } else if (v is String) {
        initVal = v;
      }
    }

    return TextFieldController(
      name: (params['name'] ?? "").toString(),
      notes: params['notes']?.toString(),
      image: params['image']?.toString(),
      isRequired: params['required'] == 1 || params['required'] == true,
      maxLen: (params['max_length'] as num?)?.toInt(),
      minLen: (params['min_length'] as num?)?.toInt(),
      softMaxLen: (params['soft_max_length'] as num?)?.toInt(),
      id: params['id'],
      initController: params['value'] != null,
      initialValue: initVal,
    );
  }

  bool get hasImage => (image != null && image!.isNotEmpty);
}

/// -------------------------
/// الواجهة (View)
/// -------------------------
class TextFieldView extends StatelessWidget {
  const TextFieldView({super.key, required this.controller});
  final TextFieldController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final dir = _dirFor(context, c.initialValue); // اتجاه وفق النص/الواجهة

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // عنوان الحقل + صورة/أيقونة على يسار/يمين العنوان حسب الاتجاه
        Row(
          children: [
            if (c.hasImage) ...[
              // بطاقة الأيقونة/الصورة (48x48) — لا نكبر البطاقة نفسها
              Container(
                width: 48.rw(context),
                height: 48.rh(context),
                decoration: BoxDecoration(
                  color: context.color.territoryColor.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                clipBehavior: Clip.antiAlias,
                child: Center(
                  // نجعل الصورة/الأيقونة واضحة وكبيرة داخل البطاقة
                  child: UiUtils.imageType(
                    c.image!, // آمن لأننا داخل if (c.hasImage)
                    width: 36, // مقاس واضح داخل بطاقة 48px
                    height: 36,
                    fit: BoxFit.contain,
                    // لا نمرر color حتى لا نفقد ألوان الصورة الأصلية
                  ),
                ),
              ),
              SizedBox(width: 10.rw(context)),
            ],
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.name)
                    .size(context.font.large)
                    .bold(weight: FontWeight.w500)
                    .color(context.color.textColorDark),
                if ((c.notes ?? "").isNotEmpty) ...[
                  SizedBox(height: 5.rh(context)),
                  Text(c.notes!)
                      .size(context.font.small)
                      .color(context.color.textLightColor),
                ],
              ],
            ),
          ],
        ),

        SizedBox(height: 14.rh(context)),

        // ✅ سطر واحد فقط + اتجاه الكتابة حسب النص/الواجهة
        Directionality(
          textDirection: dir,
          child: CustomTextFieldDynamic(
            // سطر واحد فقط — يمنع إدخال سطر جديد
            maxLine: 1,
            keyboardType: TextInputType.text,
            action: TextInputAction.done,
            capitalization: TextCapitalization.none,

            // قيمك الأساسية كما هي
            initController: c.initController,
            value: c.initialValue,
            hintText: "",
            required: c.isRequired,
            id: c.id,
            maxLen: c.maxLen,
            minLen: c.minLen,
            validator: CustomTextFieldValidator.minAndMixLen,
          ),
        ),
      ],
    );
  }
}

/// -------------------------
/// الموصّل: يفصل المنطق عن الواجهة
/// -------------------------
class CustomFieldText extends CustomField {
  @override
  String type = "textbox";

  late TextFieldController _controller;

  @override
  void init() {
    _controller =
        TextFieldController.fromParams(_asStringDynamicMap(parameters));
    update(() {}); // يحافظ على السلوك السابق (تهيئة ثم إعادة بناء)
    super.init();
  }

  @override
  Widget render() {
    return TextFieldView(controller: _controller);
  }
}
