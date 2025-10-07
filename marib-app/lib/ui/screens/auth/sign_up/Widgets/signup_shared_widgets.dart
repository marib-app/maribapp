// lib/ui/screens/auth_sign_up/widgets/signup_shared_widgets.dart
//
// الهدف: تجميـع الودجتس "المشتركة" بين واجهات التسجيل
// (العقاري والتجاري) بدون أي منطق أعمال—عرض فقط.
// - RealEstateLogoPicker: مُلتقط شعار مخصص للعقاري.
// - BusinessLogoPicker: مُلتقط شعار مخصص للتجاري.
// - PhoneFieldsRow: صف حقلي هاتف/واتساب مع بادئة الدولة.
// - WorkingHoursPicker: اختيار وقتي الفتح والإغلاق.
// - FilePickerTile: مربع رفع ملف (مثل السجل التجاري).
// - CategoriesShimmer: هيكل تحميل للأقسام.
// - CategoriesChips: شـيبس لاختيار الأقسام (تتعامل مع dynamic لتجنُّب اعتماد مباشر).

import 'dart:io';
import 'package:flutter/material.dart';

// عناصر من مشروعك (أكوادك):
import 'package:marib/ui/screens/widgets/custom_text_form_field.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';

/// ------------------------------------------------------------
/// RealEstateLogoPicker
/// ------------------------------------------------------------
/// مُلتقط شعار مخصص لواجهة "العقاري".
/// - [image]: ملف الصورة الحالي (إن وجد).
/// - [onTap]: إجراء عند الضغط لاختيار صورة.
/// - [title]: عنوان يظهر فوق المربع (مثلاً: "شعار المكتب").
/// - [hint]: ملاحظة اختيارية أسفل المربع.
class RealEstateLogoPicker extends StatelessWidget {
  final File? image;
  final VoidCallback onTap;
  final String title;
  final String? hint;

  const RealEstateLogoPicker({
    super.key,
    this.image,
    required this.onTap,
    required this.title,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // العنوان + (اختياري)
        Text("$title (${"optional".translate(context)})")
            .size(context.font.normal)
            .color(context.color.textDefaultColor),
        const SizedBox(height: 8),

        // صندوق الصورة/الأيقونة—عند الضغط يستدعي onTap لاختيار صورة
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: 120,
            width: 120, // عرض مناسب لإظهار الشعار بشكل مربع
            decoration: BoxDecoration(
              color: context.color.secondaryColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: context.color.borderColor.darken(10), width: 1.5),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2)),
              ],
            ),
            child: image != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.file(image!, fit: BoxFit.cover),
                  )
                : Icon(Icons.add_photo_alternate_outlined,
                    size: 50, color: context.color.territoryColor),
          ),
        ),

        // ملاحظة اختيارية
        if (hint != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              hint!,
              style: TextStyle(
                  fontSize: context.font.small,
                  color: context.color.textColorDark.withOpacity(0.7)),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }
}

/// ------------------------------------------------------------
/// BusinessLogoPicker
/// ------------------------------------------------------------
/// مُلتقط شعار مخصص لواجهة "التجاري" (حجم/زوايا مختلفة للتفريق البصري).
class BusinessLogoPicker extends StatelessWidget {
  final File? image;
  final VoidCallback onTap;
  final String title;
  final String? hint;

  const BusinessLogoPicker({
    super.key,
    this.image,
    required this.onTap,
    required this.title,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text("$title (${"optional".translate(context)})")
            .size(context.font.normal)
            .color(context.color.textDefaultColor),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: 140,
            width: 140, // أكبر قليلًا من العقاري للتمييز
            decoration: BoxDecoration(
              color: context.color.secondaryColor,
              borderRadius: BorderRadius.circular(20), // زوايا أكبر
              border: Border.all(
                  color: context.color.borderColor.darken(10), width: 1.5),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2)),
              ],
            ),
            child: image != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.file(image!, fit: BoxFit.cover),
                  )
                : Icon(Icons.add_photo_alternate_outlined,
                    size: 56, color: context.color.territoryColor),
          ),
        ),
        if (hint != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              hint!,
              style: TextStyle(
                  fontSize: context.font.small,
                  color: context.color.textColorDark.withOpacity(0.7)),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }
}

/// ------------------------------------------------------------
/// PhoneFieldsRow
/// ------------------------------------------------------------
/// صف يضم حقلي "هاتف" و"واتساب" مع بادئة (علم + كود).
/// - م intentionally بدون validator لتجاوز التحقق مؤقتًا كما طلبت.
/// - يمكنك لاحقًا إعادة التحقق من خلال تمرير validators في CustomTextFormField.
class PhoneFieldsRow extends StatelessWidget {
  final TextEditingController phoneController;
  final TextEditingController whatsappController;
  final String prefixText; // مثال: "🇾🇪 +967"
  final VoidCallback onPickCountry; // اختيار الدولة عند الضغط على البادئة

  const PhoneFieldsRow({
    super.key,
    required this.phoneController,
    required this.whatsappController,
    required this.prefixText,
    required this.onPickCountry,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // حقل رقم الاتصال
        Expanded(
            child: _phoneField(context,
                label: "contactNumber".translate(context),
                controller: phoneController)),
        const SizedBox(width: 12),
        // حقل رقم واتساب
        Expanded(
            child: _phoneField(context,
                label: "whatsappNumber".translate(context),
                controller: whatsappController)),
      ],
    );
  }

  // ودجت خاص لحقل الهاتف/الواتساب ليُستخدم في العمودين
  Widget _phoneField(BuildContext context,
      {required String label, required TextEditingController controller}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label)
            .size(context.font.normal)
            .color(context.color.textDefaultColor),
        const SizedBox(height: 8),
        CustomTextFormField(
          controller: controller,
          // لا يوجد validator هنا لتكون الحقول اختيارية مؤقتًا
          fillColor: context.color.secondaryColor,
          borderColor: context.color.borderColor.darken(30),
          keyboard: TextInputType.phone,
          fixedPrefix: InkWell(
            onTap: onPickCountry,
            child: Container(
              width: 80,
              height: 48,
              decoration: BoxDecoration(
                border: Border(
                    right: BorderSide(
                        color: context.color.borderColor, width: 1.5)),
              ),
              child: Center(
                child: Text(
                  prefixText,
                  style: TextStyle(
                      fontSize: context.font.normal,
                      color: context.color.textDefaultColor),
                ),
              ),
            ),
          ),
          hintText: label,
        ),
      ],
    );
  }
}

/// ------------------------------------------------------------
/// WorkingHoursPicker
/// ------------------------------------------------------------
/// محدد لأوقات العمل (من/إلى). يستقبل التوقيتين ودوال فتح الـ TimePicker.
/// لاحظ: لا يفتح الـ picker من نفسه—أنت تمرر onPickOpening/onPickClosing.
class WorkingHoursPicker extends StatelessWidget {
  final TimeOfDay? openingTime;
  final TimeOfDay? closingTime;
  final VoidCallback onPickOpening;
  final VoidCallback onPickClosing;

  const WorkingHoursPicker({
    super.key,
    this.openingTime,
    this.closingTime,
    required this.onPickOpening,
    required this.onPickClosing,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("workingHours".translate(context))
            .size(context.font.normal)
            .color(context.color.textDefaultColor),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
                child: _tile(context,
                    title: openingTime != null
                        ? "من ${openingTime!.format(context)}"
                        : "fromTime".translate(context),
                    onTap: onPickOpening)),
            const SizedBox(width: 12),
            Expanded(
                child: _tile(context,
                    title: closingTime != null
                        ? "إلى ${closingTime!.format(context)}"
                        : "toTime".translate(context),
                    onTap: onPickClosing)),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // بطاقة أنيقة بضغطة تفتح الـ time picker (أنت توفر الدالة من الخارج)
  Widget _tile(BuildContext context,
      {required String title, required VoidCallback onTap}) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: context.color.borderColor.darken(30)),
        borderRadius: BorderRadius.circular(10),
        color: context.color.secondaryColor,
      ),
      child: ListTile(
        leading: Icon(Icons.access_time, color: context.color.territoryColor),
        title: Text(
          title,
          style: TextStyle(color: context.color.textDefaultColor),
        ),
        onTap: onTap,
      ),
    );
  }
}

/// ------------------------------------------------------------
/// FilePickerTile
/// ------------------------------------------------------------
/// عنصر رفع ملف (مثل السجل التجاري). يُظهر اسم الملف عند اختياره.
/// - [placeholder]: نص مبدئي داخل الصندوق قبل الاختيار.
/// - [hint]: ملاحظة صغيرة أسفل المربع (اختيارية).
class FilePickerTile extends StatelessWidget {
  final File? file;
  final VoidCallback onTap;
  final String title;
  final String placeholder;
  final String? hint;

  const FilePickerTile({
    super.key,
    required this.file,
    required this.onTap,
    required this.title,
    required this.placeholder,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("$title (${"optional".translate(context)})")
            .size(context.font.normal)
            .color(context.color.textDefaultColor),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: 80,
            width: double.infinity,
            decoration: BoxDecoration(
              color: context.color.secondaryColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: context.color.borderColor.darken(10), width: 1.5),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2))
              ],
            ),
            child: file != null
                ? Row(
                    children: [
                      const SizedBox(width: 16),
                      Icon(Icons.picture_as_pdf,
                          size: 40, color: context.color.territoryColor),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          file!.path.split('/').last, // اسم الملف فقط
                          style: TextStyle(
                              fontSize: context.font.normal,
                              color: context.color.textDefaultColor),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 16),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.upload_file,
                          size: 30, color: context.color.territoryColor),
                      const SizedBox(width: 8),
                      Text(
                        placeholder,
                        style: TextStyle(
                            fontSize: context.font.normal,
                            color: context.color.territoryColor),
                      ),
                    ],
                  ),
          ),
        ),
        if (hint != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              hint!,
              style: TextStyle(
                  fontSize: context.font.small,
                  color: context.color.textColorDark.withOpacity(0.7)),
            ),
          ),
      ],
    );
  }
}

/// ------------------------------------------------------------
/// CategoriesShimmer
/// ------------------------------------------------------------
/// عنصر “تحميل” يظهر مكان الشيبس أثناء جلب الأقسام من السيرفر.
class CategoriesShimmer extends StatelessWidget {
  const CategoriesShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(8, (i) {
        // أحجام مختلفة لمحاكاة أقسام بطول نص مختلف
        final widths = [80.0, 120.0, 100.0, 90.0, 110.0, 85.0, 95.0, 105.0];
        return Container(
          height: 35,
          width: widths[i % widths.length],
          decoration: BoxDecoration(
            color: context.color.backgroundColor,
            borderRadius: BorderRadius.circular(20),
          ),
        );
      }),
    );
  }
}

/// ------------------------------------------------------------
/// CategoriesChips
/// ------------------------------------------------------------
/// شيبس لاختيار الأقسام. استُخدم dynamic بدل استيراد مباشر لـ CategoryModel
/// حتى يبقى هذا الملف “مشتركات” خفيف.
/// المتطلبات:
/// - كل عنصر في [categories] يحتوي حقلي: name, id (مثل CategoryModel).
class CategoriesChips extends StatelessWidget {
  final List<dynamic> categories; // مثال: List<CategoryModel>
  final List<int> selectedIds; // المعرّفات المختارة
  final ValueChanged<int> onToggle;

  const CategoriesChips({
    super.key,
    required this.categories,
    required this.selectedIds,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return Text("noCategoriesAvailable".translate(context))
          .size(context.font.normal)
          .color(context.color.textDefaultColor.withOpacity(0.7));
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: categories.map((c) {
        // الوصول الديناميكي للاسم والآي دي
        final String name = (c.name ?? '') as String;
        final int id = (c.id ?? 0) as int;
        final bool isSelected = selectedIds.contains(id);

        return FilterChip(
          label: Text(
            name,
            style: TextStyle(
              fontSize: context.font.normal,
              color: isSelected
                  ? context.color.territoryColor
                  : context.color.textDefaultColor,
            ),
          ),
          selected: isSelected,
          onSelected: (_) => onToggle(id), // قلب/إلغاء الاختيار
          selectedColor: context.color.territoryColor.withOpacity(0.15),
          backgroundColor: context.color.backgroundColor,
          checkmarkColor: context.color.territoryColor,
          side: BorderSide(
            color: isSelected
                ? context.color.territoryColor
                : context.color.borderColor,
            width: 1.0,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        );
      }).toList(),
    );
  }
}

// ===== Email Only Section (for individual accounts) =====
class EmailOnlySection extends StatelessWidget {
  final TextEditingController emailController;

  const EmailOnlySection({
    super.key,
    required this.emailController,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CustomTextFormField(
          controller: emailController,
          isRequired: false, // اختياري مؤقتاً
          fillColor: context.color.secondaryColor,
          hintText: "email".translate(context),
          borderColor: context.color.borderColor.darken(10),
          keyboard: TextInputType.emailAddress,
        ),
      ],
    );
  }
}
