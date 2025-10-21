// ================================
// File: lib/ui/screens/auth/signup/sign_up_main_ui.dart
// Purpose: Pure presentation. Receives ViewModel and Callbacks from the Screen.
// ================================

import 'dart:io';
import 'package:marib/ui/screens/auth/sign_up/sign_up_main_ui.dart'; // ✅
import 'package:marib/utils/ui_utils.dart';
import 'package:marib/ui/screens/widgets/blurred_dialoge_box.dart';
import 'dart:ui' show ImageFilter;
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/ui_utils.dart'; // لو تحتاج ألوان/مساعدات
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:marib/app/routes.dart';
import 'package:marib/utils/api.dart';
import 'package:marib/app/app_theme.dart';
import 'package:marib/data/cubits/system/app_theme_cubit.dart';
import 'package:marib/ui/screens/widgets/blurred_dialoge_box.dart';
import 'package:marib/ui/screens/widgets/custom_text_form_field.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/app_icon.dart';
import 'package:marib/utils/constant.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:flutter/services.dart';
import '../widgets/auth_status_bar.dart';



class SignUpVM {
  // Inputs/controllers
  final GlobalKey<FormState> formKey;
  final TextEditingController mobileCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController usernameCtrl;
  final TextEditingController codeCtrl;
  final TextEditingController passwordCtrl;

  // Values/state
  final String? countryCode;
  final String? countryName;
  final String? flagEmoji;
  final bool isFromGoogleLogin;
  final Map<String, dynamic>? googleData;
  final bool isObscure;
  final bool agreed;
  final String? selectedAccountType;
  final bool isSystemSettingsReady;
  final bool isSystemSettingsLoading;



  const SignUpVM({
    required this.formKey,
    required this.mobileCtrl,
    required this.emailCtrl,
    required this.usernameCtrl,
    required this.codeCtrl,
    required this.passwordCtrl,
    required this.countryCode,
    required this.countryName,
    required this.flagEmoji,
    required this.isFromGoogleLogin,
    required this.googleData,
    required this.isObscure,
    required this.agreed,
    required this.selectedAccountType,

    required this.isSystemSettingsReady,
    required this.isSystemSettingsLoading,






  });
}




class SignUpCallbacks {
  final VoidCallback onToggleObscure;
  final ValueChanged<bool> onAgreeChanged;
  final ValueChanged<String?> onAccountTypeChanged;
  final VoidCallback onShowCountryPicker;
  final Future<void> Function() onSubmit;
  final VoidCallback onNavigateToLogin;
  final VoidCallback onGoogleAuth;
  final VoidCallback onAppleAuth;
  final Future<void> Function({required String title, required String param})
  onOpenStaticContent;



  const SignUpCallbacks({
    required this.onToggleObscure,
    required this.onAgreeChanged,
    required this.onAccountTypeChanged,
    required this.onShowCountryPicker,
    required this.onSubmit,
    required this.onNavigateToLogin,
    required this.onGoogleAuth,
    required this.onAppleAuth,
    required this.onOpenStaticContent,


  });
}




class SignUpMainUI extends StatelessWidget {
  final SignUpVM vm;
  final SignUpCallbacks callbacks;
  final Color statusBarBase;

  const SignUpMainUI({
    super.key,
    required this.vm,
    required this.callbacks,
    required this.statusBarBase,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final statusBarHeight = MediaQuery.of(context).padding.top;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          colors: [
            context.color.territoryColor,
            context.color.territoryColor,
          ],
        ),
      ),
      child: Form(
        key: vm.formKey, // ✅ صار عندنا vm في النطاق
        child: CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverPersistentHeader(
              pinned: true,
              delegate: _SignUpStatusBarHeader(
                height: statusBarHeight,
                baseColor: statusBarBase,
              ),
            ),
            _HeaderAppBar(vm: vm), // ✅
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(2, 12, 2, 16 + bottomInset),
                child: _FormCard(vm: vm, callbacks: callbacks), // ✅
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _SignUpStatusBarHeader extends SliverPersistentHeaderDelegate {
  const _SignUpStatusBarHeader({
    required this.height,
    required this.baseColor,
  });

  final double height;
  final Color baseColor;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
      BuildContext context,
      double shrinkOffset,
      bool overlapsContent,
      ) {
    if (height <= 0) {
      return const SizedBox.shrink();
    }

    return LoginStatusBar.topSpacer(
      context,
      baseColor: baseColor,
    );
  }

  @override
  bool shouldRebuild(covariant _SignUpStatusBarHeader oldDelegate) {
    return oldDelegate.height != height || oldDelegate.baseColor != baseColor;
  }
}



class _HeaderAppBar extends StatelessWidget {
  const _HeaderAppBar({required this.vm});
  final SignUpVM vm;

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      floating: false,
      expandedHeight: 160,
      backgroundColor: Colors.transparent,
      elevation: 0,
      automaticallyImplyLeading: false,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.only(top: 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                context.color.territoryColor,
                context.color.territoryColor.withOpacity(0.92),
              ],
            ),
            // تقويس سفلي أنيق يندمج مع بطاقة الفورم
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(28),
              bottomRight: Radius.circular(28),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // شعار
              Semantics(
                label: 'App Logo',
                child: SvgPicture.asset(
                  'assets/svg/Logo.svg',
                  height: 84,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              Text("readytoserve".translate(context))
                  .size(context.font.large)
                  .color(Colors.white.withOpacity(0.95)),
            ],
          ),
        ),
      ),
      // ظل خفيف تحت الشريط
      shadowColor: Colors.black26,
      surfaceTintColor: Colors.transparent,
    );
  }
}




class _FormCard extends StatelessWidget {
  const _FormCard({required this.vm, required this.callbacks});
  final SignUpVM vm;
  final SignUpCallbacks callbacks;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: context.color.primaryColor,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // عنوان رئيسي
          Text(vm.isFromGoogleLogin ? "إكمال حساب Google" : "welcome".translate(context))
              .size(context.font.extraLarge)
              .color(context.color.textDefaultColor),

          if (vm.isSystemSettingsLoading && !vm.isSystemSettingsReady)
            Padding(
              padding: const EdgeInsets.only(top: 12.0),
              child: SizedBox(
                height: 3,
                child: LinearProgressIndicator(
                  minHeight: 3,
                  backgroundColor:
                  context.color.secondaryColor.withOpacity(0.5),
                ),
              ),
            ),


          // سطر توضيحي متبدّل بسلاسة
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: vm.isFromGoogleLogin
                ? Padding(
              key: const ValueKey('google_note'),
              padding: const EdgeInsets.only(top: 6.0),
              child: Text("يرجى إكمال معلومات الحساب لإنهاء التسجيل")
                  .size(context.font.normal)
                  .color(context.color.textLightColor),
            )
                : const SizedBox.shrink(key: ValueKey('empty_note')),
          ),

          const SizedBox(height: 14),

          if (Constant.mobileAuthentication == "1" || Constant.emailAuthentication == "1")
            _MobileAndEmailSection(vm: vm, callbacks: callbacks),

          const SizedBox(height: 16),

          if (!vm.isFromGoogleLogin)
            Center(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text("alreadyHaveAcc".translate(context))
                      .color(context.color.textColorDark.brighten(50)),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: callbacks.onNavigateToLogin,
                    child: Text("login".translate(context))
                        .underline()
                        .color(context.color.territoryColor),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}











class _MobileAndEmailSection extends StatelessWidget {
  final SignUpVM vm;
  final SignUpCallbacks callbacks;

  const _MobileAndEmailSection({required this.vm, required this.callbacks});

  @override
  Widget build(BuildContext context) {
    final accountTypes = {
      "1": "individual".translate(context),
      "2": "realEstate".translate(context),
      "3": "commercial".translate(context),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("signUpTomarib".translate(context))
            .size(context.font.large)
            .color(context.color.textColorDark),
        const SizedBox(height: 10),

        // Username
        CustomTextFormField(
          controller: vm.usernameCtrl,
          isReadOnly: vm.isFromGoogleLogin,

          fillColor: context.color.secondaryColor,
          validator: CustomTextFieldValidator.nullCheck,
          hintText: "userName".translate(context),
          borderColor: context.color.borderColor.darken(10),
        ),
        const SizedBox(height: 10),

        // Mobile with country code
        CustomTextFormField(
          controller: vm.mobileCtrl,
          validator: CustomTextFieldValidator.phoneNumber,
          fillColor: context.color.secondaryColor,
          borderColor: context.color.borderColor.darken(30),
          keyboard: TextInputType.phone,
          fixedPrefix: SizedBox(
            width: 55,
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: GestureDetector(
                onTap: callbacks.onShowCountryPicker,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8),
                  child: Center(
                    child: Text("+${vm.countryCode ?? ''}")
                        .size(context.font.large)
                        .centerAlign(),
                  ),
                ),
              ),
            ),
          ),
          hintText: "mobileNumberLbl".translate(context),
        ),
        const SizedBox(height: 10),

        // Email
        CustomTextFormField(
          controller: vm.emailCtrl,
          isRequired: false,
          isReadOnly: vm.isFromGoogleLogin,
          fillColor: context.color.secondaryColor,
          hintText: "emailAddress".translate(context),
          borderColor: context.color.borderColor.darken(10),
        ),
        const SizedBox(height: 10),

        // Code
        ReferralCodeField(controller: vm.codeCtrl),
        const SizedBox(height: 10),

        // Password
        CustomTextFormField(
          controller: vm.passwordCtrl,
          fillColor: context.color.secondaryColor,
          obscureText: vm.isObscure,
          suffix: IconButton(
            onPressed: callbacks.onToggleObscure,
            icon: Icon(
              vm.isObscure ? Icons.visibility_off : Icons.visibility,
              color: context.color.textColorDark.withOpacity(0.3),
            ),
          ),
          hintText: "password".translate(context),
          validator: CustomTextFieldValidator.password,
          borderColor: context.color.borderColor.darken(10),
        ),
        const SizedBox(height: 14),

        // Account type dropdown (مختصر كويدجت مستقل)
        AccountTypeDropdown(
          value: vm.selectedAccountType,
          onChanged: callbacks.onAccountTypeChanged,
        ),

        const SizedBox(height: 10),

        // Agree with terms
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Checkbox(
              activeColor: context.color.territoryColor,
              value: vm.agreed,
              onChanged: (value) => callbacks.onAgreeChanged(value ?? false),
            ),
            Expanded(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 1,
                runSpacing: 2,
                children: [
                  Text("bySigningUpLoggingIn".translate(context)).size(context.font.small),
                  InkWell(
                    onTap: () => callbacks.onOpenStaticContent(
                      title: "termsConditions".translate(context),
                      param: Api.termsAndConditions,
                    ),
                    child: Text(" ${"termsOfService".translate(context)} ")
                        .underline()
                        .color(context.color.territoryColor)
                        .size(context.font.smaller),
                  ),
                  Text(" ${"and".translate(context)} ").size(context.font.smaller),
                  InkWell(
                    onTap: () => callbacks.onOpenStaticContent(
                      title: "privacyPolicy".translate(context),
                      param: Api.privacyPolicy,
                    ),
                    child: Text("privacyPolicy".translate(context))
                        .underline()
                        .color(context.color.territoryColor)
                        .size(context.font.smaller),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),

        // ===== زر الإرسال مع انميشن تحميل + منع التكرار (إضافة فقط) =====
        Builder(
          builder: (context) {
            bool _busy = false;
            return StatefulBuilder(
              builder: (context, setSBState) {
                return Column(
                  children: [
                    UiUtils.buildButton(
                      context,
                      onPressed: () {
                        if (_busy) return; // منع التكرار داخل الدالة
                        setSBState(() => _busy = true);

                        // تشغيل العملية بشكل async بدون تغيير توقيع onPressed
                        Future<void>(() async {
                          try {
                            final result = callbacks.onSubmit();
                            if (result is Future) {
                              await result;
                            }
                          } finally {
                            if (context.mounted) {
                              setSBState(() => _busy = false);
                            }
                          }
                        });
                      },
                      // مؤشر تحميل داخل الزر أثناء الانشغال
                      prefixWidget: _busy
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                          : null,
                      buttonTitle: "continue".translate(context),
                      radius: 10,
                      disabledColor: const Color.fromARGB(255, 104, 102, 106),
                    ),

                    const SizedBox(height: 16),
                  ],
                );
              },
            );
          },
        ),
      ],
    );
  }
}















// ================== Extracted Widgets ==================

// لازم طلب صلاحيات الموقع هنا

class ReferralCodeField extends StatelessWidget {
  const ReferralCodeField({
    super.key,
    required this.controller,
    this.maxLength = 10, // عدّل الطول المناسب لكود الإحالة
  });

  final TextEditingController controller;
  final int maxLength;

  @override
  Widget build(BuildContext context) {
    return CustomTextFormField(
      isRequired: false,
      controller: controller,
      fillColor: context.color.secondaryColor,
      hintText: "referralCode".translate(context), // أو "code"
      borderColor: context.color.borderColor.darken(10),
      keyboard: TextInputType.text,

      // تنظيف الإدخال: أحرف كبيرة + أرقام + شرطة فقط + حد طول
      onChange: (v) {
        final raw = (v ?? '').toString();
        String t = raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9-]'), '');
        if (t.length > maxLength) t = t.substring(0, maxLength);
        if (t != controller.text) {
          controller.value = TextEditingValue(
            text: t,
            selection: TextSelection.collapsed(offset: t.length),
          );
        }
      },

      // زر معلومات عن الحقل
      suffix: IconButton(
        tooltip: "info".translate(context),
        icon: Icon(
          Icons.info_outline,
          color: context.color.textColorDark.withOpacity(0.5),
        ),
        onPressed: () {
          final locale = Localizations.maybeLocaleOf(context);
          final isArabic =
              locale != null && locale.languageCode.toLowerCase().startsWith('ar');
          final titleKey =
          isArabic ? 'referralCodeInfoTitle_ar' : 'referralCodeInfoTitle';
          final messageKey = isArabic
              ? 'referralCodeInfoMarib_ar'
              : 'referralCodeInfoMarib';
          UiUtils.showBlurredDialoge(
            context,
            dialoge: BlurredDialogBox(
              showCancleButton: false,
              title: titleKey.translate(context),
              content: Text(
                messageKey.translate(context),
                textAlign: isArabic ? TextAlign.right : TextAlign.start,
              ),
              acceptButtonName: "ok".translate(context),
              isAcceptContainesPush: true,
              onAccept: () async {
                Navigator.of(context).pop();
              },
            ),
          );
        },
      ),
    );
  }
}








///////






// Dropdown احترافي لاختيار "نوع الحساب"
// - يتحقق تلقائياً أن المستخدم اختار قيمة.
// - تنسيق متناسق مع الثيم.
// - دعم تعطيل الحقل.
//
// - يمكن تمرير عناصر مخصّصة (id -> label).
// - زر معلومات اختياري يستدعي كولباك خارجي (بدون أي bottom sheet داخل الكلاس).




class AccountTypeDropdown extends StatelessWidget {
  const AccountTypeDropdown({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.items,
    this.labelKey,
    this.helperKey,
    this.onInfoTap,
  });

  final String? value;
  final ValueChanged<String?> onChanged;

  final bool enabled;
  final Map<String, String>? items;
  final String? labelKey;
  final String? helperKey;
  final VoidCallback? onInfoTap;

  /// العناصر الافتراضية مع الأيقونات
  Map<String, (String label, IconData icon)> _defaultItems(BuildContext context) => {
    "1": ("individual".translate(context), Icons.person),
    "2": ("realEstate".translate(context), Icons.home_work_outlined),
    "3": ("commercial".translate(context), Icons.storefront_outlined),
  };

  @override
  Widget build(BuildContext context) {
    final accountTypes = items != null
        ? items!.map((k, v) => MapEntry(k, (v, Icons.circle))) // لو جاب من برا وما عطينا أيقونات
        : _defaultItems(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (labelKey != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: 6),
            child: Text(labelKey!.translate(context))
                .size(context.font.large)
                .color(context.color.textDefaultColor),
          ),

        DropdownButtonFormField<String>(
          value: value,
          isExpanded: true,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: context.color.textDefaultColor.withOpacity(0.7),
          ),
          validator: (v) {
            if (v == null || v.isEmpty) {
              return "mustSelectAccountType".translate(context);
            }
            return null;
          },
          decoration: InputDecoration(
            hintText: "chooseaccount".translate(context),
            filled: true,
            enabled: enabled,
            fillColor: context.color.secondaryColor,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            suffixIcon: onInfoTap != null
                ? IconButton(
              tooltip: "info".translate(context),
              icon: Icon(
                Icons.info_outline,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
              onPressed: onInfoTap,
            )
                : null,
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(width: 1.5, color: context.color.territoryColor),
              borderRadius: BorderRadius.circular(10),
            ),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(width: 1.5, color: context.color.borderColor.darken(50)),
              borderRadius: BorderRadius.circular(10),
            ),
            disabledBorder: OutlineInputBorder(
              borderSide: BorderSide(width: 1.5, color: context.color.borderColor.darken(70)),
              borderRadius: BorderRadius.circular(10),
            ),
            border: OutlineInputBorder(
              borderSide: BorderSide(width: 1.5, color: context.color.borderColor),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          dropdownColor: context.color.secondaryColor,

          // العناصر مع أيقونات
          items: accountTypes.entries.map<DropdownMenuItem<String>>((entry) {
            final (label, icon) = entry.value;
            return DropdownMenuItem<String>(
              value: entry.key,
              child: Row(
                children: [
                  Icon(icon,
                      color: enabled
                          ? context.color.textDefaultColor
                          : context.color.textDefaultColor.withOpacity(0.5)),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: context.font.large,
                      color: enabled
                          ? context.color.textDefaultColor
                          : context.color.textDefaultColor.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: enabled
              ? (newVal) {
            if (newVal == null) return;
            HapticFeedback.selectionClick();
            onChanged(newVal);
          }
              : null,
        ),

        if (helperKey != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(top: 6, start: 4),
            child: Text(helperKey!.translate(context))
                .size(context.font.small)
                .color(context.color.textLightColor),
          ),
      ],
    );
  }
}



