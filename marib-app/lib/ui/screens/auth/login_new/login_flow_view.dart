import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:sms_autofill/sms_autofill.dart';

import 'package:marib/ui/screens/auth/shared/auth_form_shell.dart';
import 'package:marib/ui/screens/auth/shared/auth_header.dart';
import 'package:marib/ui/screens/auth/shared/auth_scaffold.dart';
import 'package:marib/ui/screens/widgets/custom_text_form_field.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/app_icon.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:marib/utils/login/lib/payloads.dart';

const double _kSidePadding = 20.0;

class LoginFlowView extends StatelessWidget {
  final Widget form;
  final bool showBackButton;
  final VoidCallback? onBack;
  final List<Widget> footer;

  const LoginFlowView({
    super.key,
    required this.form,
    this.showBackButton = false,
    this.onBack,
    this.footer = const [],
  });

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      header: AuthHeader(
        title: "readytoserve".translate(context),
        subtitle: "welcomeback".translate(context),
        assetName: 'assets/svg/Logo.svg',
        onBack: showBackButton ? onBack : null,
      ),
      body: form,
      footer: footer,
    );
  }
}

class LoginFlowForm extends StatelessWidget {
  final bool isOtpSent;
  final bool sendMailClicked;
  final bool isMobileNumberField;
  final bool isLoading;
  final bool isObscure;

  final String? phoneEmailError;
  final String? passwordError;

  final TextEditingController emailController;
  final TextEditingController passwordController;
  final String? countryCode;
  final String? flagEmoji;

  final PhoneLoginPayload? phoneLoginPayload;
  final String? currentOtp;
  final ValueChanged<String?> onOtpChanged;

  final VoidCallback onSkip;
  final VoidCallback onShowCountryPicker;
  final VoidCallback onToggleObscure;
  final VoidCallback onForgotPassword;
  final VoidCallback onChangeLoginMode;
  final VoidCallback onResendOtp;
  final VoidCallback onVerifyOtp;
  final void Function(String input, String password, bool asPhone)
  onSubmitCredentials;
  final VoidCallback onGoogleLogin;
  final VoidCallback onAppleLogin;
  final VoidCallback onTapContinue;
  final VoidCallback onGoToSignup;

  final bool showMobileAuth;
  final bool showEmailAuth;
  final bool showGoogle;
  final bool showApple;

  final ValueChanged<String> onChangedNumberOrEmail;

  const LoginFlowForm({
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
    required this.onGoToSignup,
    required this.showMobileAuth,
    required this.showEmailAuth,
    required this.showGoogle,
    required this.showApple,
    required this.onChangedNumberOrEmail,
  });

  @override
  Widget build(BuildContext context) {
    final contentKey = isOtpSent
        ? const ValueKey('otp')
        : sendMailClicked
        ? const ValueKey('email-password')
        : const ValueKey('login-options');

    final Widget view;
    if (isOtpSent && phoneLoginPayload != null) {
      view = _VerifyOtpView(
        key: contentKey,
        phoneLoginPayload: phoneLoginPayload!,
        currentOtp: currentOtp,
        onOtpChanged: onOtpChanged,
        onResendOtp: onResendOtp,
        onVerifyOtp: onVerifyOtp,
        onSkip: onSkip,
        onChangeLoginMode: onChangeLoginMode,
      );
    } else if (sendMailClicked) {
      view = _EnterPasswordEmailView(
        key: contentKey,
        emailValue: emailController.text,
        passwordController: passwordController,
        isObscure: isObscure,
        onToggleObscure: onToggleObscure,
        onSubmitEmailPassword: () => onSubmitCredentials(
          emailController.text,
          passwordController.text,
          false,
        ),
        onSkip: onSkip,
        onChangeLoginMode: onChangeLoginMode,
      );
    } else {
      view = _LoginOptionsView(
        key: contentKey,
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
          isMobileNumberField,
        ),
        onTapContinue: onTapContinue,
        showMobileAuth: showMobileAuth,
        showEmailAuth: showEmailAuth,
        showGoogle: showGoogle,
        showApple: showApple,
        onGoogleLogin: onGoogleLogin,
        onAppleLogin: onAppleLogin,
        onGoToSignup: onGoToSignup,
        onSkip: onSkip,
      );
    }

    return AuthFormShell(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: view,
      ),
    );
  }
}

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
    super.key,
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
    final message = widget.phoneEmailError ?? widget.passwordError;
    if (message == null || message.trim().isEmpty || message == _lastErrorShown) {
      return;
    }

    _lastErrorShown = message;
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
                  child: Text(
                    message,
                    style: TextStyle(color: scheme.onError),
                  ),
                ),
              ],
            ),
            backgroundColor: scheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 80),
            duration: const Duration(seconds: 3),
          ),
        );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AbsorbPointer(
      absorbing: widget.isLoading,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "welcomeback".translate(context),
            style: theme.textTheme.headlineSmall?.copyWith(
              color: colorScheme.onBackground,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "login".translate(context),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onBackground.withOpacity(0.72),
            ),
          ),
          const SizedBox(height: 24),
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
            onTapContinue: widget.onTapContinue,
          ),
          const SizedBox(height: 20),
          if (widget.showMobileAuth && widget.showEmailAuth)
            Row(
              children: [
                Expanded(child: Divider(color: colorScheme.outline.withOpacity(0.3))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    "or".translate(context),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onBackground.withOpacity(0.7),
                    ),
                  ),
                ),
                Expanded(child: Divider(color: colorScheme.outline.withOpacity(0.3))),
              ],
            ),
          if (widget.showMobileAuth && widget.showEmailAuth)
            const SizedBox(height: 20),
          if (widget.showGoogle)
            UiUtils.buildButton(
              context,
              onPressed: widget.onGoogleLogin,
              prefixWidget: SvgPicture.asset(
                AppIcons.googleIcon,
                width: 24,
              ),
              buttonTitle: "continueWithGoogle".translate(context),
              radius: 12,
              buttonColor: context.color.secondaryColor,
              textColor: context.color.textColorDark,
              border: BorderSide(color: context.color.borderColor),
              disabled: widget.isLoading,
            ),
          if (widget.showGoogle) const SizedBox(height: 12),
          if (widget.showApple && Platform.isIOS)
            UiUtils.buildButton(
              context,
              onPressed: widget.onAppleLogin,
              prefixWidget: SvgPicture.asset(
                AppIcons.appleIcon,
                width: 24,
              ),
              buttonTitle: "continueWithApple".translate(context),
              radius: 12,
              buttonColor: context.color.secondaryColor,
              textColor: textDarkColor,
              disabled: widget.isLoading,
            ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "dontHaveAcc".translate(context),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onBackground.withOpacity(0.72),
                ),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: widget.onGoToSignup,
                child: Text(
                  "signUp".translate(context),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: context.color.territoryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonal(
              onPressed: widget.onSkip,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text("skip".translate(context)),
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
  final VoidCallback onTapContinue;

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
    required this.onTapContinue,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
          onChange: (value) => onChangedNumberOrEmail((value ?? '').toString()),
          keyboard: isMobileNumberField
              ? TextInputType.number
              : TextInputType.emailAddress,
          prefix: isMobileNumberField
              ? InkWell(
            onTap: onShowCountryPicker,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if ((flagEmoji ?? '').isNotEmpty)
                    Text(flagEmoji!, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 6),
                  Text('+${countryCode ?? ''}')
                      .size(context.font.large)
                      .centerAlign(),
                ],
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
              style: TextStyle(
                color: Colors.red,
                fontSize: context.font.small,
              ),
            ),
          ),
        const SizedBox(height: 12),
        CustomTextFormField(
          isRequired: true,
          hintText: "${"password".translate(context)}*",
          controller: passwordController,
          validator: CustomTextFieldValidator.nullCheck,
          fillColor: context.color.secondaryColor,
          borderColor: passwordError != null
              ? Colors.red
              : context.color.borderColor.darken(30),
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
              style: TextStyle(
                color: Colors.red,
                fontSize: context.font.small,
              ),
            ),
          ),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: TextButton(
            onPressed: onForgotPassword,
            child: Text("${"forgotPassword".translate(context)}"),
          ),
        ),
        const SizedBox(height: 12),
        UiUtils.buildButton(
          context,
          onPressed: onSubmit,
          prefixWidget: isLoading
              ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
              : null,
          buttonTitle: isLoading ? "" : "signIn".translate(context),
          radius: 12,
          isInProgress: isLoading,
        ),
        const SizedBox(height: 12),
        FilledButton.tonal(
          onPressed: isLoading ? null : onTapContinue,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text("continue".translate(context)),
        ),
      ],
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
    super.key,
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _kSidePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: FilledButton.tonal(
              onPressed: onSkip,
              style: FilledButton.styleFrom(
                minimumSize: const Size(64, 32),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text("skip".translate(context)),
            ),
          ),
          Text(
            "verifyYourNumber".translate(context),
            style: theme.textTheme.headlineSmall?.copyWith(
              color: colorScheme.onBackground,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "${"weSentCodeOnNumber".translate(context)} ${phoneLoginPayload.phoneNumber}",
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onBackground.withOpacity(0.72),
            ),
          ),
          const SizedBox(height: 24),
          PinFieldAutoFill(
            decoration: UnderlineDecoration(
              textStyle: TextStyle(
                fontSize: 20,
                color: colorScheme.onBackground,
              ),
              colorBuilder: FixedColorBuilder(context.color.territoryColor),
            ),
            currentCode: currentOtp,
            codeLength: 6,
            onCodeChanged: onOtpChanged,
            onCodeSubmitted: onOtpChanged,
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              onPressed: onResendOtp,
              child: Text("resendOTP".translate(context)),
            ),
          ),
          const SizedBox(height: 12),
          UiUtils.buildButton(
            context,
            onPressed: onVerifyOtp,
            buttonTitle: "signIn".translate(context),
            radius: 12,
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: onChangeLoginMode,
            child: Text("change".translate(context)),
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
    super.key,
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _kSidePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: FilledButton.tonal(
              onPressed: onSkip,
              style: FilledButton.styleFrom(
                minimumSize: const Size(64, 32),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text("skip".translate(context)),
            ),
          ),
          Text(
            "signInWithEmail".translate(context),
            style: theme.textTheme.headlineSmall?.copyWith(
              color: colorScheme.onBackground,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  emailValue,
                  style: theme.textTheme.bodyLarge,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(
                onPressed: onChangeLoginMode,
                child: Text("change".translate(context)),
              ),
            ],
          ),
          const SizedBox(height: 16),
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
            child: TextButton(
              onPressed: () {},
              child: Text("${"forgotPassword".translate(context)}?"),
            ),
          ),
          const SizedBox(height: 16),
          UiUtils.buildButton(
            context,
            onPressed: onSubmitEmailPassword,
            buttonTitle: "signIn".translate(context),
            radius: 12,
          ),
        ],
      ),
    );
  }
}