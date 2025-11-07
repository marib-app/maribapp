// ================================
// File: lib/ui/screens/auth/sign_up/sign_up_main_ui.dart
// Purpose: Shared presentation for the mobile sign-up flow.
// ================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:marib/ui/screens/auth/widgets/auth_status_bar.dart';
import 'package:marib/ui/screens/widgets/blurred_dialoge_box.dart';
import 'package:marib/ui/screens/widgets/custom_text_form_field.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/ui/widgets/shimmer/shimmer_box.dart';
import 'package:marib/utils/api.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/ui_utils.dart';

class SignUpVM {
  final GlobalKey<FormState> formKey;
  final TextEditingController mobileCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController usernameCtrl;
  final TextEditingController codeCtrl;
  final TextEditingController passwordCtrl;

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
    final overlay = LoginStatusBar.overlayFor(
      context,
      baseColor: statusBarBase,
    );
    final bool showSkeleton =
        vm.isSystemSettingsLoading && !vm.isSystemSettingsReady;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay,
      child: Column(
        children: [
          LoginStatusBar.topSpacer(
            context,
            baseColor: statusBarBase,
          ),
          _SignUpAppBar(onNavigateToLogin: callbacks.onNavigateToLogin),
          Expanded(
            child: Form(
              key: vm.formKey,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: showSkeleton
                    ? const _SignUpShimmer(key: ValueKey('signup_shimmer'))
                    : _SignUpScrollContent(
                        key: const ValueKey('signup_content'),
                        vm: vm,
                        callbacks: callbacks,
                      ),
              ),
            ),
          ),
          _StickyLegalActionBar(
            agreed: vm.agreed,
            isBusy: showSkeleton,
            onSubmit: callbacks.onSubmit,
          ),
        ],
      ),
    );
  }
}

class _SignUpAppBar extends StatelessWidget {
  final VoidCallback onNavigateToLogin;

  const _SignUpAppBar({required this.onNavigateToLogin});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 12, 12),
        child: Row(
          children: [
            IconButton(
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              icon: Icon(Icons.arrow_back,
                  color: context.color.textDefaultColor),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                "signUp".translate(context),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: context.color.textDefaultColor,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            TextButton(
              onPressed: onNavigateToLogin,
              child: Text("login".translate(context))
                  .underline()
                  .color(context.color.territoryColor),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignUpScrollContent extends StatelessWidget {
  final SignUpVM vm;
  final SignUpCallbacks callbacks;

  const _SignUpScrollContent({
    super.key,
    required this.vm,
    required this.callbacks,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        _HeroSection(vm: vm),
        const SizedBox(height: 24),
        _MobileAndEmailSection(vm: vm, callbacks: callbacks),
        const SizedBox(height: 20),
        _AccountFooter(onNavigateToLogin: callbacks.onNavigateToLogin),
      ],
    );
  }
}

class _HeroSection extends StatelessWidget {
  final SignUpVM vm;

  const _HeroSection({required this.vm});

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final bool fromGoogle = vm.isFromGoogleLogin;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          fromGoogle
              ? "welcome".translate(context)
              : "signUpTomarib".translate(context),
          style: textTheme.headlineSmall?.copyWith(
            color: context.color.textDefaultColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "readytoserve".translate(context),
          style: textTheme.bodyLarge?.copyWith(
            color: context.color.textLightColor,
            height: 1.4,
          ),
        ),
        if (fromGoogle) ...[
          const SizedBox(height: 8),
          Text(
            'يرجى إكمال معلومات الحساب لإنهاء التسجيل',
            style: textTheme.bodyMedium?.copyWith(
              color: context.color.textLightColor.withOpacity(0.8),
            ),
          ),
        ],
      ],
    );
  }
}

class _AccountFooter extends StatelessWidget {
  final VoidCallback onNavigateToLogin;

  const _AccountFooter({required this.onNavigateToLogin});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text("alreadyHaveAcc".translate(context))
            .color(context.color.textColorDark.brighten(50)),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: onNavigateToLogin,
          child: Text("login".translate(context))
              .underline()
              .color(context.color.territoryColor),
        ),
      ],
    );
  }
}

class _StickyLegalActionBar extends StatelessWidget {
  final bool agreed;
  final bool isBusy;
  final Future<void> Function() onSubmit;

  const _StickyLegalActionBar({
    required this.agreed,
    required this.isBusy,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            UiUtils.buildButton(
              context,
              onPressed: onSubmit,
              buttonTitle: "continue".translate(context),
              radius: 14,
              isInProgress: isBusy,
              disabled: !agreed || isBusy,
            ),
          ],
        ),
      ),
    );
  }
}

class _SignUpShimmer extends StatelessWidget {
  const _SignUpShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 150),
      children: const [
        SizedBox(height: 12),
        ShimmerBox(height: 20, width: 160),
        SizedBox(height: 12),
        ShimmerBox(height: 18, width: 220),
        SizedBox(height: 24),
        ShimmerBox(height: 56),
        SizedBox(height: 16),
        ShimmerBox(height: 56),
        SizedBox(height: 16),
        ShimmerBox(height: 56),
        SizedBox(height: 16),
        ShimmerBox(height: 56),
        SizedBox(height: 16),
        ShimmerBox(height: 56),
      ],
    );
  }
}

class _MobileAndEmailSection extends StatelessWidget {
  final SignUpVM vm;
  final SignUpCallbacks callbacks;

  const _MobileAndEmailSection({
    required this.vm,
    required this.callbacks,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("signUpTomarib".translate(context))
            .size(context.font.large)
            .color(context.color.textColorDark),
        const SizedBox(height: 10),
        CustomTextFormField(
          controller: vm.usernameCtrl,
          isReadOnly: vm.isFromGoogleLogin,
          fillColor: context.color.secondaryColor,
          validator: CustomTextFieldValidator.nullCheck,
          hintText: "userName".translate(context),
          borderColor: context.color.borderColor.darken(10),
        ),
        const SizedBox(height: 10),
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
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8),
                  child: Text("+${vm.countryCode ?? ''}")
                      .size(context.font.large)
                      .centerAlign(),
                ),
              ),
            ),
          ),
          hintText: "mobileNumberLbl".translate(context),
        ),
        const SizedBox(height: 10),
        CustomTextFormField(
          controller: vm.emailCtrl,
          isRequired: false,
          isReadOnly: vm.isFromGoogleLogin,
          fillColor: context.color.secondaryColor,
          hintText: "emailAddress".translate(context),
          borderColor: context.color.borderColor.darken(10),
        ),
        const SizedBox(height: 10),
        ReferralCodeField(controller: vm.codeCtrl),
        const SizedBox(height: 10),
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
        AccountTypeDropdown(
          value: vm.selectedAccountType,
          onChanged: callbacks.onAccountTypeChanged,
        ),
        const SizedBox(height: 10),
        _TermsAgreement(
          agreed: vm.agreed,
          onChanged: callbacks.onAgreeChanged,
          onOpenStaticContent: callbacks.onOpenStaticContent,
        ),
      ],
    );
  }
}

class ReferralCodeField extends StatelessWidget {
  const ReferralCodeField({
    super.key,
    required this.controller,
    this.maxLength = 10,
  });

  final TextEditingController controller;
  final int maxLength;

  @override
  Widget build(BuildContext context) {
    return CustomTextFormField(
      isRequired: false,
      controller: controller,
      fillColor: context.color.secondaryColor,
      hintText: "referralCode".translate(context),
      borderColor: context.color.borderColor.darken(10),
      keyboard: TextInputType.text,
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
      suffix: IconButton(
        tooltip: "info".translate(context),
        icon: Icon(
          Icons.info_outline,
          color: context.color.textColorDark.withOpacity(0.5),
        ),
        onPressed: () {
          final locale = Localizations.maybeLocaleOf(context);
          final isArabic = locale != null &&
              locale.languageCode.toLowerCase().startsWith('ar');
          final titleKey =
              isArabic ? 'referralCodeInfoTitle_ar' : 'referralCodeInfoTitle';
          final messageKey =
              isArabic ? 'referralCodeInfoMarib_ar' : 'referralCodeInfoMarib';
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

class AccountTypeDropdown extends StatelessWidget {
  const AccountTypeDropdown({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final String? value;
  final ValueChanged<String?> onChanged;

  Map<String, (String label, IconData icon)> _defaultTypes(
          BuildContext context) =>
      {
        "1": ("individual".translate(context), Icons.person),
        "2": ("realEstate".translate(context), Icons.home_work_outlined),
        "3": ("commercial".translate(context), Icons.storefront_outlined),
      };

  @override
  Widget build(BuildContext context) {
    final options = _defaultTypes(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          initialValue: value,
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
            labelText: "accountType".translate(context),
            hintText: "chooseaccount".translate(context),
            filled: true,
            fillColor: context.color.secondaryColor,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: context.color.borderColor.darken(30),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: context.color.territoryColor,
                width: 1.5,
              ),
            ),
          ),
          items: options.entries
              .map(
                (entry) => DropdownMenuItem<String>(
                  value: entry.key,
                  child: Row(
                    children: [
                      Icon(entry.value.$2,
                          color: context.color.territoryColor),
                      const SizedBox(width: 8),
                      Text(entry.value.$1),
                    ],
                  ),
                ),
              )
              .toList(),
          onChanged: (newVal) {
            if (newVal == null) return;
            HapticFeedback.selectionClick();
            onChanged(newVal);
          },
        ),
        const SizedBox(height: 4),
        Text(
          "accountTypeHelper".translate(context),
          style: TextStyle(
            fontSize: context.font.small,
            color: context.color.textLightColor,
          ),
        ),
      ],
    );
  }
}

class _TermsAgreement extends StatelessWidget {
  final bool agreed;
  final ValueChanged<bool> onChanged;
  final Future<void> Function({required String title, required String param})
      onOpenStaticContent;

  const _TermsAgreement({
    required this.agreed,
    required this.onChanged,
    required this.onOpenStaticContent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.color.secondaryColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.color.borderColor.darken(10),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: agreed,
            activeColor: context.color.territoryColor,
            onChanged: (value) => onChanged(value ?? false),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "bySigningUpLoggingIn".translate(context),
                  style: TextStyle(
                    fontSize: context.font.small,
                    color: context.color.textDefaultColor,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    InkWell(
                      onTap: () => onOpenStaticContent(
                        title: "termsConditions".translate(context),
                        param: Api.termsAndConditions,
                      ),
                      child: Text("termsOfService".translate(context))
                          .underline()
                          .color(context.color.territoryColor)
                          .size(context.font.small),
                    ),
                    Text("andTxt".translate(context))
                        .size(context.font.small)
                        .color(context.color.textLightColor),
                    InkWell(
                      onTap: () => onOpenStaticContent(
                        title: "privacyPolicy".translate(context),
                        param: Api.privacyPolicy,
                      ),
                      child: Text("privacyPolicy".translate(context))
                          .underline()
                          .color(context.color.territoryColor)
                          .size(context.font.small),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
