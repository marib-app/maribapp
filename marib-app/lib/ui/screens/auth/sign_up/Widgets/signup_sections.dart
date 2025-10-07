/*
// ==========================
// FILE: lib/ui/screens/auth/sign_up/signup_sections.dart
// Purpose: جميع Widgets الخاصة بالعرض فقط (بدون منطق)، تُستقبل عبر Props من signup_screen.dart
// ==========================
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:marib/ui/screens/widgets/custom_text_form_field.dart';
import 'package:marib/ui/screens/widgets/shimmerLoadingContainer.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';


enum AccountUIType { realEstate, business }



// ===== Shared, stateless sub-widgets =====










enum AccountUIType { realEstate, business }

class RealEstateLogoPicker extends StatelessWidget {
  final File? image;
  final VoidCallback onTap;
  const RealEstateLogoPicker({super.key, this.image, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _BaseLogoPicker(
      image: image,
      onTap: onTap,
      title: "officeLogo".translate(context),
      hint: null, // بدون ملاحظة إضافية هنا
      // تخصيص العقاري
      size: const Size(120, 120),
      borderRadius: 16,
      dashed: false,
      badge: null,
    );
  }
}

class BusinessLogoPicker extends StatelessWidget {
  final File? image;
  final VoidCallback onTap;
  const BusinessLogoPicker({super.key, this.image, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _BaseLogoPicker(
      image: image,
      onTap: onTap,
      title: "businessLogo".translate(context),
      hint: "chooseLogoCarefully".translate(context),
      // تخصيص التجاري
      size: const Size(140, 140),
      borderRadius: 20,
      dashed: true, // إطار متقطع تمييزًا للتجاري
      badge: Icon(Icons.storefront_rounded, size: 20, color: context.color.territoryColor),
    );
  }
}

/// نواة مشتركة، لا تُستخدم مباشرة خارج هذا الملف
class _BaseLogoPicker extends StatelessWidget {
  final File? image;
  final VoidCallback onTap;
  final String title;
  final String? hint;
  final Size size;
  final double borderRadius;
  final bool dashed;
  final Widget? badge;

  const _BaseLogoPicker({
    required this.image,
    required this.onTap,
    required this.title,
    required this.hint,
    required this.size,
    required this.borderRadius,
    required this.dashed,
    required this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final border = dashed
        ? Border.all(color: context.color.borderColor.darken(10), width: 1.5, style: BorderStyle.solid)
        : Border.all(color: context.color.borderColor.darken(10), width: 1.5);

    return Column(
      children: [
        Text("$title (${"optional".translate(context)})")
            .size(context.font.normal)
            .color(context.color.textDefaultColor),
        const SizedBox(height: 8),
        Stack(
          clipBehavior: Clip.none,
          children: [
            GestureDetector(
              onTap: onTap,
              child: Container(
                height: size.height,
                width: size.width,
                decoration: BoxDecoration(
                  color: context.color.secondaryColor,
                  borderRadius: BorderRadius.circular(borderRadius),
                  border: border,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: image != null
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(borderRadius),
                  child: Image.file(image!, fit: BoxFit.cover),
                )
                    : Icon(Icons.add_photo_alternate_outlined, size: 50, color: context.color.territoryColor),
              ),
            ),
            if (badge != null)
              Positioned(
                right: -6,
                top: -6,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: context.color.backgroundColor,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: context.color.borderColor, width: 1),
                  ),
                  child: badge,
                ),
              ),
          ],
        ),
        if (hint != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              hint!,
              style: TextStyle(fontSize: context.font.small, color: context.color.textColorDark.withOpacity(0.7)),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }
}



















class FilePickerTile extends StatelessWidget {
  final File? file;
  final VoidCallback onTap;
  final String title;
  final String placeholder;
  const FilePickerTile({super.key, required this.file, required this.onTap, required this.title, required this.placeholder});

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
              border: Border.all(color: context.color.borderColor.darken(10), width: 1.5),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: file != null
                ? Row(children: [
              const SizedBox(width: 16),
              Icon(Icons.picture_as_pdf, size: 40, color: context.color.territoryColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  file!.path.split('/').last,
                  style: TextStyle(fontSize: context.font.normal, color: context.color.textDefaultColor),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 16),
            ])
                : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.upload_file, size: 30, color: context.color.territoryColor),
              const SizedBox(width: 8),
              Text(placeholder, style: TextStyle(fontSize: context.font.normal, color: context.color.territoryColor)),
            ]),
          ),
        ),
      ],
    );
  }
}











class WorkingHoursPicker extends StatelessWidget {
  final TimeOfDay? openingTime;
  final TimeOfDay? closingTime;
  final VoidCallback onPickOpening;
  final VoidCallback onPickClosing;
  const WorkingHoursPicker({super.key, this.openingTime, this.closingTime, required this.onPickOpening, required this.onPickClosing});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text("workingHours".translate(context)).size(context.font.normal).color(context.color.textDefaultColor),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _tile(context,
            title: openingTime != null ? "من ${openingTime!.format(context)}" : "fromTime".translate(context),
            onTap: onPickOpening)),
        const SizedBox(width: 12),
        Expanded(child: _tile(context,
            title: closingTime != null ? "إلى ${closingTime!.format(context)}" : "toTime".translate(context),
            onTap: onPickClosing)),
      ]),
      const SizedBox(height: 16),
    ]);
  }













  Widget _tile(BuildContext context, {required String title, required VoidCallback onTap}) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: context.color.borderColor.darken(30)),
        borderRadius: BorderRadius.circular(10),
        color: context.color.secondaryColor,
      ),
      child: ListTile(
        leading: Icon(Icons.access_time, color: context.color.territoryColor),
        title: Text(title, style: TextStyle(color: context.color.textDefaultColor)),
        onTap: onTap,
      ),
    );
  }
}






class PhoneFieldsRow extends StatelessWidget {
  final TextEditingController phoneController;
  final TextEditingController whatsappController;
  final String prefixText;
  final VoidCallback onPickCountry;
  const PhoneFieldsRow({super.key, required this.phoneController, required this.whatsappController, required this.prefixText, required this.onPickCountry});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: _phoneField(context, label: "contactNumber".translate(context), controller: phoneController)),
      const SizedBox(width: 12),
      Expanded(child: _phoneField(context, label: "whatsappNumber".translate(context), controller: whatsappController)),
    ]);
  }







  Widget _phoneField(BuildContext context, {required String label, required TextEditingController controller}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label).size(context.font.normal).color(context.color.textDefaultColor),
      const SizedBox(height: 8),
      CustomTextFormField(
        controller: controller,
        validator: CustomTextFieldValidator.phoneNumber,
        fillColor: context.color.secondaryColor,
        borderColor: context.color.borderColor.darken(30),
        keyboard: TextInputType.phone,
        fixedPrefix: InkWell(
          onTap: onPickCountry,
          child: Container(
            width: 80,
            height: 48,
            decoration: BoxDecoration(border: Border(right: BorderSide(color: context.color.borderColor, width: 1.5))),
            child: Center(child: Text(prefixText, style: TextStyle(fontSize: context.font.normal, color: context.color.textDefaultColor))),
          ),
        ),
        hintText: label,
      ),
    ]);
  }
}








class CategoriesShimmer extends StatelessWidget {
  const CategoriesShimmer({super.key});
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(8, (index) {
        final widths = [80.0, 120.0, 100.0, 90.0, 110.0, 85.0, 95.0, 105.0];
        return CustomShimmer(height: 35, width: widths[index % widths.length], borderRadius: 20);
      }),
    );
  }
}















class CategoriesChips extends StatelessWidget {
  final List<dynamic> categories; // List<CategoryModel> لكن بدون اعتماد مباشر
  final List<int> selectedIds;
  final ValueChanged<int> onToggle;
  const CategoriesChips({super.key, required this.categories, required this.selectedIds, required this.onToggle});

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
        final name = (c.name ?? '') as String;
        final id = (c.id ?? 0) as int;
        final isSelected = selectedIds.contains(id);
        return FilterChip(
          label: Text(name, style: TextStyle(fontSize: context.font.normal, color: isSelected ? context.color.territoryColor : context.color.textDefaultColor)),
          selected: isSelected,
          onSelected: (_) => onToggle(id),
          selectedColor: context.color.territoryColor.withOpacity(0.15),
          backgroundColor: context.color.backgroundColor,
          checkmarkColor: context.color.territoryColor,
          side: BorderSide(color: isSelected ? context.color.territoryColor : context.color.borderColor, width: 1.0),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        );
      }).toList(),
    );
  }
}
















class PaymentMethodsSelector extends StatelessWidget {
  final Map<String, String> paymentMethods; // key => i18n key
  final List<String> selected;
  final Map<String, TextEditingController> controllers;
  final void Function(String key, bool selected) onToggle;
  final String Function(String key) getAccountHint;
  const PaymentMethodsSelector({super.key, required this.paymentMethods, required this.selected, required this.controllers, required this.onToggle, required this.getAccountHint});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: context.color.borderColor.darken(20))),
      child: Column(
        children: paymentMethods.entries.map((entry) {
          final isSelected = selected.contains(entry.key);
          return Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CheckboxListTile(
                value: isSelected,
                title: Text(entry.value.translate(context), style: TextStyle(fontSize: context.font.normal, fontWeight: FontWeight.w500, color: context.color.textDefaultColor)),
                activeColor: const Color(0xFFF35A00),
                onChanged: (checked) => onToggle(entry.key, checked ?? false),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              if (isSelected)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: CustomTextFormField(
                    controller: controllers[entry.key],
                    fillColor: context.color.backgroundColor,
                    borderColor: context.color.borderColor.darken(30),
                    hintText: getAccountHint(entry.key),
                    validator: CustomTextFieldValidator.nullCheck,
                  ),
                ),
            ]),
          );
        }).toList(),
      ),
    );
  }
}












// ===== Sections (pure UI) =====
class RealEstateSection extends StatelessWidget {
  final File? logo;
  final VoidCallback onPickLogo;

  final TextEditingController officeName;
  final TextEditingController officePhone;
  final TextEditingController officeWhatsapp;
  final TextEditingController officeLocation;

  final String prefixText; // "🇾🇪 +967" إلخ
  final VoidCallback onPickCountry;

  final bool isLocationLoading;
  final VoidCallback onGetLocation;

  const RealEstateSection({
    super.key,
    required this.logo,
    required this.onPickLogo,
    required this.officeName,
    required this.officePhone,
    required this.officeWhatsapp,
    required this.officeLocation,
    required this.prefixText,
    required this.onPickCountry,
    required this.isLocationLoading,
    required this.onGetLocation,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Center(
        child: RealEstateLogoPicker(
          image: logo,
          onTap: onPickLogo,
          title: "officeLogo".translate(context),
        ),
      ),
      const SizedBox(height: 24),

      CustomTextFormField(
        controller: officeName,
        isRequired: false,
        fillColor: context.color.secondaryColor,
        hintText: "officeName".translate(context),
        borderColor: context.color.borderColor.darken(10),
      ),
      const SizedBox(height: 16),
      CustomTextFormField(
        controller: officeLocation,
        isRequired: false,
        fillColor: context.color.secondaryColor,
        hintText: "officeLocationDetailed".translate(context),
        borderColor: context.color.borderColor.darken(10),
        maxLine: 2,
      ),
      const SizedBox(height: 8),
      _locationBtn(context),
      const SizedBox(height: 20),
      PhoneFieldsRow(
        phoneController: officePhone,
        whatsappController: officeWhatsapp,
        prefixText: prefixText,
        onPickCountry: onPickCountry,
      ),
    ]);
  }

  Widget _locationBtn(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onGetLocation,
      icon: isLocationLoading
          ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : const Icon(Icons.my_location, color: Colors.white, size: 20),
      style: ElevatedButton.styleFrom(
        backgroundColor: context.color.territoryColor,
        minimumSize: const Size.fromHeight(46),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      label: Text(isLocationLoading ? "gettingLocation".translate(context) : "selectLocationOnMap".translate(context)),
    );
  }
}














class BusinessSection extends StatelessWidget {
  final File? logo;
  final VoidCallback onPickLogo;
  final File? commercialFile;
  final VoidCallback onPickFile;

  final TextEditingController name;
  final TextEditingController phone;
  final TextEditingController whatsapp;
  final TextEditingController location;

  final String prefixText;
  final VoidCallback onPickCountry;

  final bool isLocationLoading;
  final VoidCallback onGetLocation;

  final List<dynamic> categories; // List<CategoryModel>
  final List<int> selectedCategoryIds;
  final ValueChanged<int> onToggleCategory;

  final TimeOfDay? openingTime;
  final TimeOfDay? closingTime;
  final VoidCallback onPickOpening;
  final VoidCallback onPickClosing;

  final Map<String, String> paymentMethods;
  final List<String> selectedPaymentMethods;
  final Map<String, TextEditingController> paymentControllers;
  final void Function(String, bool) onTogglePayment;
  final String Function(String) getAccountHint;

  const BusinessSection({
    super.key,
    required this.logo,
    required this.onPickLogo,
    required this.commercialFile,
    required this.onPickFile,
    required this.name,
    required this.phone,
    required this.whatsapp,
    required this.location,
    required this.prefixText,
    required this.onPickCountry,
    required this.isLocationLoading,
    required this.onGetLocation,
    required this.categories,
    required this.selectedCategoryIds,
    required this.onToggleCategory,
    required this.openingTime,
    required this.closingTime,
    required this.onPickOpening,
    required this.onPickClosing,
    required this.paymentMethods,
    required this.selectedPaymentMethods,
    required this.paymentControllers,
    required this.onTogglePayment,
    required this.getAccountHint,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Center(child: LogoPicker(image: logo, onTap: onPickLogo, title: "businessLogo".translate(context), hint: "chooseLogoCarefully".translate(context))),
      const SizedBox(height: 24),
      FilePickerTile(
        file: commercialFile,
        onTap: onPickFile,
        title: "commercialRegister".translate(context),
        placeholder: "uploadCommercialRegister".translate(context),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text("uploadCommercialRegisterHint".translate(context), style: TextStyle(fontSize: context.font.small, color: context.color.textColorDark.withOpacity(0.7))),
      ),
      const SizedBox(height: 16),
      CustomTextFormField(
        controller: name,
        validator: CustomTextFieldValidator.nullCheck,
        fillColor: context.color.secondaryColor,
        hintText: "businessName".translate(context),
        borderColor: context.color.borderColor.darken(10),
      ),
      const SizedBox(height: 16),
      CustomTextFormField(
        controller: location,
        validator: CustomTextFieldValidator.nullCheck,
        fillColor: context.color.secondaryColor,
        hintText: "businessLocationDetailed".translate(context),
        borderColor: context.color.borderColor.darken(10),
        maxLine: 2,
      ),
      const SizedBox(height: 8),
      _locationBtn(context),
      const SizedBox(height: 20),
      PhoneFieldsRow(
        phoneController: phone,
        whatsappController: whatsapp,
        prefixText: prefixText,
        onPickCountry: onPickCountry,
      ),
      const SizedBox(height: 16),
      Text("selectCategory".translate(context)).size(context.font.normal).color(context.color.textDefaultColor),
      const SizedBox(height: 6),
      CategoriesChips(categories: categories, selectedIds: selectedCategoryIds, onToggle: onToggleCategory),
      const SizedBox(height: 16),
      WorkingHoursPicker(
        openingTime: openingTime,
        closingTime: closingTime,
        onPickOpening: onPickOpening,
        onPickClosing: onPickClosing,
      ),
      Text("paymentReceivingMethods".translate(context)).size(context.font.normal).color(context.color.textDefaultColor),
      const SizedBox(height: 10),
      PaymentMethodsSelector(
        paymentMethods: paymentMethods,
        selected: selectedPaymentMethods,
        controllers: paymentControllers,
        onToggle: onTogglePayment,
        getAccountHint: getAccountHint,
      ),
    ]);
  }







  Widget _locationBtn(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onGetLocation,
      icon: isLocationLoading
          ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : const Icon(Icons.my_location, color: Colors.white, size: 20),
      style: ElevatedButton.styleFrom(
        backgroundColor: context.color.territoryColor,
        minimumSize: const Size.fromHeight(46),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      label: Text(isLocationLoading ? "gettingLocation".translate(context) : "selectLocationOnMap".translate(context)),
    );
  }
}

class EmailOnlySection extends StatelessWidget {
  final TextEditingController emailController;
  const EmailOnlySection({super.key, required this.emailController});
  @override
  Widget build(BuildContext context) {
    return CustomTextFormField(
      controller: emailController,
      isRequired: false,
      fillColor: context.color.secondaryColor,
      validator: CustomTextFieldValidator.email,
      hintText: "emailAddress".translate(context),
      borderColor: context.color.borderColor.darken(10),
    );
  }
}
 */
