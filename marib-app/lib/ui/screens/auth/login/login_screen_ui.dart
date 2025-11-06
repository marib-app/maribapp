// ================================
// File: lib/ui/screens/auth/login/login_screen_ui.dart
// Purpose: Pure presentation for Login. Matches the same look & feel as sign_up_main_ui.dart
// ================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:sms_autofill/sms_autofill.dart';

import 'package:marib/ui/screens/widgets/custom_text_form_field.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/app_icon.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:marib/utils/login/lib/payloads.dart';
import 'package:marib/utils/ui_utils.dart';

import 'package:marib/ui/screens/auth/widgets/auth_status_bar.dart';

// =================== ط·آ·ط¢آ«ط·آ¸ط«â€ ط·آ·ط¢آ§ط·آ·ط¢آ¨ط·آ·ط¹آ¾ ===================
const double kSidePadding = 20.0;

// =====================================================
// LoginScreenFrame أ¢â‚¬â€‌ unified hero + form container
// =====================================================
class LoginScreenFrame extends StatelessWidget {
  final Widget child;
  final String logoAsset;
  final String titleKey;
  final double maxWidth;
  final double logoSize;

  const LoginScreenFrame({
    super.key,
    required this.child,
    this.logoAsset = 'assets/svg/Logo.svg',
    this.titleKey = 'readytoserve',
    this.maxWidth = 640,
    this.logoSize = 92,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasAncestorScroll = Scrollable.maybeOf(context) != null;
    final Widget scrollableChild =
        hasAncestorScroll ? child : SingleChildScrollView(child: child);

    final Size size = MediaQuery.of(context).size;
    final bool isWide = size.width >= 640;
    final theme = Theme.of(context);
    final Color surface = theme.colorScheme.surface;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeInOutCubic,
          decoration: BoxDecoration(
            color: surface.withOpacity(
              theme.brightness == Brightness.dark ? 0.95 : 0.98,
            ),
            borderRadius: BorderRadius.circular(isWide ? 40 : 28),
            border: Border.all(
              color: context.color.territoryColor.withOpacity(
                theme.brightness == Brightness.dark ? 0.18 : 0.12,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 38,
                offset: const Offset(0, 24),
              ),
            ],
          ),
          padding: EdgeInsets.symmetric(
            horizontal: isWide ? 44 : 22,
            vertical: isWide ? 36 : 22,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _LoginHeroHeader(
                logoAsset: logoAsset,
                titleKey: titleKey,
                logoSize: logoSize,
              ),
              const SizedBox(height: 24),
              Divider(
                height: 1,
                thickness: 0.8,
                color: context.color.textLightColor.withOpacity(0.2),
              ),
              const SizedBox(height: 24),
              scrollableChild,
            ],
          ),
        ),
      ),
    );
  }
}

class _LoginHeroHeader extends StatelessWidget {
  final String logoAsset;
  final String titleKey;
  final double logoSize;

  const _LoginHeroHeader({
    required this.logoAsset,
    required this.titleKey,
    required this.logoSize,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Semantics(
          label: 'App Logo',
          image: true,
          child: SvgPicture.asset(
            logoAsset,
            height: logoSize,
            color: context.color.territoryColor,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          "welcomeback".translate(context),
          textAlign: TextAlign.center,
          style: textTheme.headlineSmall?.copyWith(
            color: context.color.textColorDark,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          titleKey.translate(context),
          textAlign: TextAlign.center,
          style: textTheme.bodyLarge?.copyWith(
            letterSpacing: 0.3,
            color: context.color.textLightColor.withOpacity(0.8),
          ),
        ),
      ],
    );
  }
}
// =====================================================
// LoginScreenUI ط£آ¢أ¢â€ڑآ¬أ¢â‚¬â€Œ ط·آ¸أ¢â‚¬آ ط·آ¸ط¸آ¾ط·آ·ط¢آ³ ط·آ·ط¢آ§ط·آ¸أ¢â‚¬â€چط·آ·ط¢آ§ط·آ·ط¢آ³ط·آ¸أ¢â‚¬آ¦ ط·آ¸ط«â€ ط·آ·ط¢آ§ط·آ¸أ¢â‚¬â€چط·آ¸أ¢â€ڑآ¬ API
// ط·آ·ط¹آ¾ط·آ¸أ¢â‚¬آ¦ ط·آ·ط¹آ¾ط·آ·ط¢آ­ط·آ¸ط«â€ ط·آ¸ط¸آ¹ط·آ¸أ¢â‚¬â€چط·آ¸أ¢â‚¬طŒط·آ·ط¢آ§ ط·آ¸أ¢â‚¬â€چط·آ·ط¢آ¨ط·آ·ط¢آ·ط·آ·ط¢آ§ط·آ¸أ¢â‚¬ع‘ط·آ·ط¢آ© ط·آ·ط¢آ£ط·آ¸أ¢â‚¬آ ط·آ¸ط¸آ¹ط·آ¸أ¢â‚¬ع‘ط·آ·ط¢آ© (ط·آ·ط¢آ¨ط·آ·ط¢آ¯ط·آ¸ط«â€ ط·آ¸أ¢â‚¬آ  ط·آ·ط¢آ±ط·آ·ط¢آ£ط·آ·ط¢آ³) ط£آ¢أ¢â€ڑآ¬أ¢â‚¬â€Œ ط·آ·ط¢آ§ط·آ¸أ¢â‚¬â€چط·آ·ط¢آ±ط·آ·ط¢آ£ط·آ·ط¢آ³ ط·آ¸ط¸آ¹ط·آ·ط¢آ£ط·آ·ط¹آ¾ط·آ¸ط¸آ¹ ط·آ¸أ¢â‚¬آ¦ط·آ¸أ¢â‚¬آ  LoginHeaderSection
// =====================================================
class LoginScreenUI extends StatelessWidget {
  // ط·آ·ط¢آ­ط·آ·ط¢آ§ط·آ¸أ¢â‚¬â€چط·آ·ط¢آ© ط·آ·ط¢آ§ط·آ¸أ¢â‚¬â€چط·آ·ط¢آ¹ط·آ·ط¢آ±ط·آ·ط¢آ¶
  final bool isOtpSent;
  final bool sendMailClicked;
  final bool isMobileNumberField;
  final bool isLoading;
  final bool isObscure;

  // ط·آ·ط¢آ£ط·آ·ط¢آ®ط·آ·ط¢آ·ط·آ·ط¢آ§ط·آ·ط·إ’
  final String? phoneEmailError;
  final String? passwordError;

  // ط·آ¸أ¢â‚¬آ¦ط·آ·ط¢آ¯ط·آ·ط¢آ®ط·آ¸أ¢â‚¬â€چط·آ·ط¢آ§ط·آ·ط¹آ¾
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final String? countryCode;
  final String? flagEmoji;

  // OTP
  final PhoneLoginPayload? phoneLoginPayload;
  final String? currentOtp;
  final ValueChanged<String?> onOtpChanged;

  // ط·آ·ط¢آ£ط·آ¸ط¸آ¾ط·آ·ط¢آ¹ط·آ·ط¢آ§ط·آ¸أ¢â‚¬â€چ ط·آ¸ط«â€ ط·آ·ط¢آ£ط·آ·ط¢آ²ط·آ·ط¢آ±ط·آ·ط¢آ§ط·آ·ط¢آ±
  final VoidCallback onSkip;
  final VoidCallback onShowCountryPicker;
  final VoidCallback onToggleObscure;
  final VoidCallback onForgotPassword;
  final VoidCallback onChangeLoginMode;
  final VoidCallback onResendOtp;
  final VoidCallback onVerifyOtp;
  final void Function(String input, String pass) onSubmitCredentials;

  final VoidCallback onGoogleLogin;
  final VoidCallback onAppleLogin;
  final VoidCallback onTapContinue;
  final VoidCallback onGoToSignup;

  // ط·آ·ط¢آ¥ط·آ·ط¢آ¸ط·آ¸أ¢â‚¬طŒط·آ·ط¢آ§ط·آ·ط¢آ±/ط·آ·ط¢آ¥ط·آ·ط¢آ®ط·آ¸ط¸آ¾ط·آ·ط¢آ§ط·آ·ط·إ’ ط·آ·ط¢آ®ط·آ¸ط¸آ¹ط·آ·ط¢آ§ط·آ·ط¢آ±ط·آ·ط¢آ§ط·آ·ط¹آ¾
  final bool showMobileAuth;
  final bool showEmailAuth;
  final bool showGoogle;
  final bool showApple;

  // ط·آ·ط¢آ¥ط·آ·ط¢آ¯ط·آ·ط¢آ®ط·آ·ط¢آ§ط·آ¸أ¢â‚¬â€چ ط·آ·ط¢آ§ط·آ¸أ¢â‚¬â€چط·آ·ط¹آ¾ط·آ·ط·â€؛ط·آ¸ط¸آ¹ط·آ¸ط¸آ¹ط·آ·ط¢آ±
  final ValueChanged<String> onChangedNumberOrEmail;

  const LoginScreenUI({
    super.key,
    required this.isOtpSent,
    required this.sendMailClicked,
    required this.isMobileNumberField,
    required this.isLoading,
    required this.isObscure,
    required this.phoneEmailError,
    required this.passwordError,
    required this.emailController,
    required this.passwordController,
    required this.countryCode,
    required this.flagEmoji,
    required this.phoneLoginPayload,
    required this.currentOtp,
    required this.onOtpChanged,
    required this.onSkip,
    required this.onShowCountryPicker,
    required this.onToggleObscure,
    required this.onForgotPassword,
    required this.onChangeLoginMode,
    required this.onResendOtp,
    required this.onVerifyOtp,
    required this.onSubmitCredentials,
    required this.onGoogleLogin,
    required this.onAppleLogin,
    required this.onTapContinue,
    required this.showMobileAuth,
    required this.showEmailAuth,
    required this.showGoogle,
    required this.showApple,
    required this.onChangedNumberOrEmail,
    required this.onGoToSignup,
  });

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (isOtpSent && phoneLoginPayload != null) {
      content = KeyedSubtree(
        key: const ValueKey('otp-view'),
        child: _VerifyOtpView(
          phoneLoginPayload: phoneLoginPayload!,
          currentOtp: currentOtp,
          onOtpChanged: onOtpChanged,
          onResendOtp: onResendOtp,
          onVerifyOtp: onVerifyOtp,
          onSkip: onSkip,
          onChangeLoginMode: onChangeLoginMode,
        ),
      );
    } else if (sendMailClicked) {
      content = KeyedSubtree(
        key: const ValueKey('email-password-view'),
        child: _EnterPasswordEmailView(
          emailValue: emailController.text,
          passwordController: passwordController,
          isObscure: isObscure,
          onToggleObscure: onToggleObscure,
          onSubmitEmailPassword: () => onSubmitCredentials(
            emailController.text,
            passwordController.text,
          ),
          onSkip: onSkip,
          onChangeLoginMode: onChangeLoginMode,
        ),
      );
    } else {
      content = KeyedSubtree(
        key: const ValueKey('login-options-view'),
        child: _LoginOptionsView(
          isMobileNumberField: isMobileNumberField,
          isLoading: isLoading,
          isObscure: isObscure,
          phoneEmailError: phoneEmailError,
          passwordError: passwordError,
          emailController: emailController,
          passwordController: passwordController,
          countryCode: countryCode,
          flagEmoji: flagEmoji,
          onChangedNumberOrEmail: onChangedNumberOrEmail,
          onShowCountryPicker: onShowCountryPicker,
          onToggleObscure: onToggleObscure,
          onForgotPassword: onForgotPassword,
          onSubmit: () => onSubmitCredentials(
            emailController.text,
            passwordController.text,
          ),
          showMobileAuth: showMobileAuth,
          showEmailAuth: showEmailAuth,
          showGoogle: showGoogle,
          showApple: showApple,
          onGoogleLogin: onGoogleLogin,
          onAppleLogin: onAppleLogin,
          onTapContinue: onTapContinue,
          onGoToSignup: onGoToSignup,
          onSkip: onSkip,
        ),
      );
    }

    return Form(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: content,
      ),
    );
  }
}

// ==================== Sub-Views ====================
class _LoginOptionsView extends StatefulWidget {
  final bool isMobileNumberField;
  final bool isLoading;
  final bool isObscure;

  final String? phoneEmailError;
  final String? passwordError;

  final TextEditingController emailController;
  final TextEditingController passwordController;

  final String? countryCode;
  final String? flagEmoji;

  final ValueChanged<String> onChangedNumberOrEmail;
  final VoidCallback onShowCountryPicker;
  final VoidCallback onToggleObscure;
  final VoidCallback onForgotPassword;
  final VoidCallback onSubmit;

  final bool showMobileAuth;
  final bool showEmailAuth;
  final bool showGoogle;
  final bool showApple;
  final VoidCallback onGoogleLogin;
  final VoidCallback onAppleLogin;

  final VoidCallback onTapContinue;
  final VoidCallback onGoToSignup;
  final VoidCallback onSkip;

  const _LoginOptionsView({
    required this.isMobileNumberField,
    required this.isLoading,
    required this.isObscure,
    required this.phoneEmailError,
    required this.passwordError,
    required this.emailController,
    required this.passwordController,
    required this.countryCode,
    required this.flagEmoji,
    required this.onChangedNumberOrEmail,
    required this.onShowCountryPicker,
    required this.onToggleObscure,
    required this.onForgotPassword,
    required this.onSubmit,
    required this.showMobileAuth,
    required this.showEmailAuth,
    required this.showGoogle,
    required this.showApple,
    required this.onGoogleLogin,
    required this.onAppleLogin,
    required this.onTapContinue,
    required this.onGoToSignup,
    required this.onSkip,
  });

  @override
  State<_LoginOptionsView> createState() => _LoginOptionsViewState();
}

class _LoginOptionsViewState extends State<_LoginOptionsView> {
  String? _lastErrorShown;

  @override
  void initState() {
    super.initState();
    _maybeShowErrorToast();
  }

  @override
  void didUpdateWidget(covariant _LoginOptionsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _maybeShowErrorToast();
  }

  void _maybeShowErrorToast() {
    final msg = widget.phoneEmailError ?? widget.passwordError;
    if (msg == null || msg.trim().isEmpty || msg == _lastErrorShown) return;
    _lastErrorShown = msg;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final scheme = Theme.of(context).colorScheme;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: scheme.onError),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(msg, style: TextStyle(color: scheme.onError))),
              ],
            ),
            backgroundColor: scheme.error,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 80),
            duration: const Duration(seconds: 3),
          ),
        );
    });
  }

  @override
  Widget build(BuildContext context) {
    return AbsorbPointer(
      absorbing: widget.isLoading,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          _MobileOrEmailForm(
            isMobileNumberField: widget.isMobileNumberField,
            isLoading: widget.isLoading,
            isObscure: widget.isObscure,
            phoneEmailError: widget.phoneEmailError,
            passwordError: widget.passwordError,
            emailController: widget.emailController,
            passwordController: widget.passwordController,
            countryCode: widget.countryCode,
            flagEmoji: widget.flagEmoji,
            onChangedNumberOrEmail: widget.onChangedNumberOrEmail,
            onShowCountryPicker: widget.onShowCountryPicker,
            onToggleObscure: widget.onToggleObscure,
            onForgotPassword: widget.onForgotPassword,
            onSubmit: widget.onSubmit,
          ),
          if ((widget.showMobileAuth || widget.showEmailAuth) &&
              (widget.showGoogle || widget.showApple))
            const SizedBox(height: 20),
          if (widget.showGoogle)
            SizedBox(
              width: double.infinity,
              child: UiUtils.buildButton(
                context,
                prefixWidget: Padding(
                  padding: const EdgeInsetsDirectional.only(end: 10.0),
                  child: UiUtils.getSvg(AppIcons.googleIcon,
                      width: 22, height: 22),
                ),
                showElevation: false,
                buttonColor: secondaryColor_,
                border: Theme.of(context).brightness != Brightness.dark
                    ? BorderSide(
                        color: context.color.onBackground.withOpacity(0.5))
                    : null,
                textColor: textDarkColor,
                onPressed: widget.onGoogleLogin,
                radius: 10,
                height: 48,
                buttonTitle: "continueWithGoogle".translate(context),
              ),
            ),
          if (widget.showGoogle) const SizedBox(height: 8),
          if (widget.showApple)
            SizedBox(
              width: double.infinity,
              child: UiUtils.buildButton(
                context,
                prefixWidget: Padding(
                  padding: const EdgeInsetsDirectional.only(end: 10.0),
                  child:
                      UiUtils.getSvg(AppIcons.appleIcon, width: 22, height: 22),
                ),
                showElevation: false,
                buttonColor: secondaryColor_,
                border: Theme.of(context).brightness != Brightness.dark
                    ? BorderSide(
                        color: context.color.onBackground.withOpacity(0.5))
                    : null,
                textColor: textDarkColor,
                onPressed: widget.onAppleLogin,
                height: 48,
                radius: 10,
                buttonTitle: "continueWithApple".translate(context),
              ),
            ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("dontHaveAcc".translate(context))
                  .color(context.color.textColorDark.brighten(50)),
              const SizedBox(width: 30),

              // ط·آ·ط¹آ¾ط·آ·ط¢آ£ط·آ·ط¢آ«ط·آ¸ط¸آ¹ط·آ·ط¢آ± ط·آ·ط¢آ¶ط·آ·ط·â€؛ط·آ·ط¢آ· + ط·آ·ط¢آ±ط·آ¸ط¹آ¯ط·آ·ط¢آ¨ط·آ¸أ¢â‚¬â€چ (Ripple)
              Material(
                // ط·آ¸أ¢â‚¬آ¦ط·آ¸أ¢â‚¬طŒط·آ¸أ¢â‚¬آ¦ ط·آ¸أ¢â‚¬â€چط·آ¸ط«â€  ط·آ¸أ¢â‚¬آ¦ط·آ·ط¢آ§ ط·آ·ط¢آ¹ط·آ¸أ¢â‚¬آ ط·آ·ط¢آ¯ط·آ¸ط¦â€™ Material ط·آ¸أ¢â‚¬آ¦ط·آ·ط¢آ¨ط·آ·ط¢آ§ط·آ·ط¢آ´ط·آ·ط¢آ± ط·آ¸ط¸آ¾ط·آ¸ط¸آ¹ ط·آ·ط¢آ§ط·آ¸أ¢â‚¬â€چط·آ·ط¢آ£ط·آ·ط¢آ¨
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.onGoToSignup,
                  borderRadius: BorderRadius.circular(6),
                  splashColor: context.color.territoryColor.withOpacity(.20),
                  highlightColor: context.color.territoryColor.withOpacity(.10),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Text("signUp".translate(context))
                        .underline()
                        .color(context.color.territoryColor),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 130),
          SizedBox(
            width: double.infinity,
            child: MaterialButton(
              onPressed: widget.onSkip,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0,
              height: 50,
              child: Text("skip".translate(context))
                  .color(context.color.buttonColor),
              color: const Color.fromARGB(255, 104, 102, 106),
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileOrEmailForm extends StatelessWidget {
  final bool isMobileNumberField;
  final bool isLoading;
  final bool isObscure;

  final String? phoneEmailError;
  final String? passwordError;

  final TextEditingController emailController;
  final TextEditingController passwordController;

  final String? countryCode;
  final String? flagEmoji;

  final ValueChanged<String> onChangedNumberOrEmail;
  final VoidCallback onShowCountryPicker;
  final VoidCallback onToggleObscure;
  final VoidCallback onForgotPassword;
  final VoidCallback onSubmit;

  const _MobileOrEmailForm({
    required this.isMobileNumberField,
    required this.isLoading,
    required this.isObscure,
    required this.phoneEmailError,
    required this.passwordError,
    required this.emailController,
    required this.passwordController,
    required this.countryCode,
    required this.flagEmoji,
    required this.onChangedNumberOrEmail,
    required this.onShowCountryPicker,
    required this.onToggleObscure,
    required this.onForgotPassword,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("login".translate(context))
            .size(context.font.large)
            .color(context.color.textColorDark),
        const SizedBox(height: 24),
        CustomTextFormField(
          isRequired: true,
          validator: isMobileNumberField
              ? CustomTextFieldValidator.nullCheck
              : CustomTextFieldValidator.email,
          controller: emailController,
          fillColor: context.color.secondaryColor,
          borderColor: phoneEmailError != null
              ? Colors.red
              : context.color.borderColor.darken(30),
          onChange: (v) => onChangedNumberOrEmail((v ?? '').toString()),
          keyboard: isMobileNumberField
              ? TextInputType.phone
              : TextInputType.emailAddress,
          fixedPrefix: isMobileNumberField
              ? SizedBox(
                  width: 55,
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: GestureDetector(
                      onTap: onShowCountryPicker,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8.0, vertical: 8),
                        child: Center(
                          child: Text("+${countryCode ?? ''}")
                              .size(context.font.large)
                              .centerAlign(),
                        ),
                      ),
                    ),
                  ),
                )
              : null,
          hintText: isMobileNumberField
              ? "mobileNumberLbl".translate(context)
              : "emailAddress".translate(context),
        ),
        if (phoneEmailError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              phoneEmailError!,
              style: TextStyle(color: Colors.red, fontSize: context.font.small),
            ),
          ),
        const SizedBox(height: 5),
        CustomTextFormField(
          isRequired: true,
          hintText: "${"password".translate(context)}*",
          controller: passwordController,
          validator: CustomTextFieldValidator.nullCheck,
          fillColor: context.color.secondaryColor,
          borderColor: passwordError != null
              ? Colors.red
              : context.color.borderColor.darken(30),
          onChange: (_) {},
          obscureText: isObscure,
          suffix: IconButton(
            onPressed: onToggleObscure,
            icon: Icon(
              !isObscure ? Icons.visibility : Icons.visibility_off,
              color: context.color.textColorDark.withOpacity(0.3),
            ),
          ),
        ),
        if (passwordError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              passwordError!,
              style: TextStyle(color: Colors.red, fontSize: context.font.small),
            ),
          ),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: MaterialButton(
            onPressed: onForgotPassword,
            child: Text("${"forgotPassword".translate(context)}")
                .color(context.color.textLightColor)
                .size(context.font.normal),
          ),
        ),
        const SizedBox(height: 10),
        UiUtils.buildButton(
          context,
          onPressed: onSubmit,
          buttonTitle: "signIn".translate(context),
          radius: 8,
          isInProgress: isLoading,
          requiredTextControllers: [
            emailController,
            passwordController,
          ],
        ),
        const SizedBox(height: 2),
      ],
    );
  }
}

// =====================================================
// LoginHeaderSection أ¢â‚¬â€‌ background + safe insets + gestures
// =====================================================
class LoginHeaderSection extends StatelessWidget {
  final bool isBack;
  final bool isOtpSent;
  final bool sendMailClicked;
  final bool isDeleteAccount;
  final VoidCallback onResetOTP;
  final VoidCallback onBack;
  final void Function(bool) updateBackState;
  final Widget child;

  const LoginHeaderSection({
    super.key,
    required this.isBack,
    required this.isOtpSent,
    required this.sendMailClicked,
    required this.isDeleteAccount,
    required this.onResetOTP,
    required this.onBack,
    required this.updateBackState,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final double bottomInset = mediaQuery.viewInsets.bottom;

    final Color statusBarBase = LoginStatusBar.resolveBaseColor(context);
    final SystemUiOverlayStyle overlay =
        LoginStatusBar.overlayFor(context, baseColor: statusBarBase);

    return SafeArea(
      top: false,
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: PopScope(
          canPop: isBack,
          onPopInvoked: (didPop) {
            if (didPop) {
              updateBackState(false);
              return;
            }

            if (isDeleteAccount) {
              Navigator.pop(context);
              updateBackState(false);
              return;
            }
            if (isOtpSent) {
              onResetOTP();
              updateBackState(false);
              return;
            }
            if (sendMailClicked) {
              onBack();
              updateBackState(false);
              return;
            }

            HelperUtils.showSnackBarMessage(
              context,
              'ط·آ§ط·آ¶ط·ط›ط·آ· ط¸â€¦ط·آ±ط·آ© ط·آ£ط·آ®ط·آ±ط¸â€° ط¸â€‍ط¸â€‍ط·ع¾ط·آ£ط¸ئ’ط¸ظ¹ط·آ¯',
            );
            updateBackState(true);
          },
          child: AnnotatedRegion<SystemUiOverlayStyle>(
            value: overlay,
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      context.color.territoryColor,
                      context.color.territoryColor.withOpacity(0.92),
                      context.color.backgroundColor,
                    ],
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(
                      20,
                      24,
                      20,
                      16 + bottomInset,
                    ),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VerifyOtpView extends StatelessWidget {
  final PhoneLoginPayload phoneLoginPayload;
  final String? currentOtp;
  final ValueChanged<String?> onOtpChanged;
  final VoidCallback onResendOtp;
  final VoidCallback onVerifyOtp;
  final VoidCallback onSkip;
  final VoidCallback onChangeLoginMode;

  const _VerifyOtpView({
    required this.phoneLoginPayload,
    required this.currentOtp,
    required this.onOtpChanged,
    required this.onResendOtp,
    required this.onVerifyOtp,
    required this.onSkip,
    required this.onChangeLoginMode,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kSidePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: AlignmentDirectional.bottomEnd,
            child: FittedBox(
              fit: BoxFit.none,
              child: MaterialButton(
                onPressed: onSkip,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                color: context.color.forthColor.withOpacity(0.102),
                elevation: 0,
                height: 28,
                minWidth: 64,
                child: Text("skip".translate(context))
                    .color(context.color.forthColor),
              ),
            ),
          ),
          Text("signInWithMob".translate(context))
              .size(context.font.extraLarge),
          const SizedBox(height: 8),
          Row(
            children: [
              Text("+${phoneLoginPayload.countryCode} ${phoneLoginPayload.phoneNumber}")
                  .size(context.font.large),
              const SizedBox(width: 5),
              InkWell(
                onTap: onChangeLoginMode,
                child: Text("change".translate(context))
                    .underline()
                    .color(context.color.territoryColor)
                    .size(context.font.large),
              ),
            ],
          ),
          Center(
            child: PinFieldAutoFill(
              decoration: UnderlineDecoration(
                textStyle:
                    TextStyle(fontSize: 20, color: context.color.textColorDark),
                colorBuilder: FixedColorBuilder(context.color.territoryColor),
              ),
              currentCode: currentOtp,
              codeLength: 6,
              onCodeChanged: onOtpChanged,
              onCodeSubmitted: (code) => onOtpChanged(code),
            ),
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: MaterialButton(
              onPressed: onResendOtp,
              child: Text("resendOTP".translate(context))
                  .color(context.color.textColorDark.withOpacity(0.7)),
            ),
          ),
          UiUtils.buildButton(
            context,
            onPressed: onVerifyOtp,
            buttonTitle: "signIn".translate(context),
            radius: 8,
          ),
        ],
      ),
    );
  }
}

class _EnterPasswordEmailView extends StatelessWidget {
  final String emailValue;
  final TextEditingController passwordController;
  final bool isObscure;
  final VoidCallback onToggleObscure;
  final VoidCallback onSubmitEmailPassword;
  final VoidCallback onSkip;
  final VoidCallback onChangeLoginMode;

  const _EnterPasswordEmailView({
    required this.emailValue,
    required this.passwordController,
    required this.isObscure,
    required this.onToggleObscure,
    required this.onSubmitEmailPassword,
    required this.onSkip,
    required this.onChangeLoginMode,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kSidePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: AlignmentDirectional.bottomEnd,
            child: FittedBox(
              fit: BoxFit.none,
              child: MaterialButton(
                onPressed: onSkip,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                color: context.color.forthColor.withOpacity(0.102),
                elevation: 0,
                height: 28,
                minWidth: 64,
                child: Text("skip".translate(context))
                    .color(context.color.forthColor),
              ),
            ),
          ),
          Text("signInWithEmail".translate(context))
              .size(context.font.extraLarge),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(emailValue).size(context.font.large),
              const SizedBox(width: 5),
              InkWell(
                onTap: onChangeLoginMode,
                child: Text("change".translate(context))
                    .underline()
                    .color(context.color.territoryColor)
                    .size(context.font.large),
              ),
            ],
          ),
          CustomTextFormField(
            hintText: "${"password".translate(context)}*",
            controller: passwordController,
            obscureText: isObscure,
            suffix: IconButton(
              onPressed: onToggleObscure,
              icon: Icon(
                !isObscure ? Icons.visibility : Icons.visibility_off,
                color: context.color.textColorDark.withOpacity(0.3),
              ),
            ),
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: MaterialButton(
              onPressed: () {},
              child: Text("${"forgotPassword".translate(context)}?")
                  .color(context.color.textLightColor)
                  .size(context.font.normal),
            ),
          ),
          UiUtils.buildButton(
            context,
            onPressed: onSubmitEmailPassword,
            buttonTitle: "signIn".translate(context),
            radius: 8,
            requiredTextControllers: [passwordController],
          ),
        ],
      ),
    );
  }
}



