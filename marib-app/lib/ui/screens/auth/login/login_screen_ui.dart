// ================================
// File: lib/ui/screens/auth/login/sign_in_main_ui.dart
// Purpose: Pure presentation for Login. Matches the same look & feel as sign_up_main_ui.dart
//          Uses SliverAppBar header + elegant form card. No business logic here.
// ================================

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/constant.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:marib/utils/app_icon.dart';
import 'package:sms_autofill/sms_autofill.dart';
import 'package:marib/ui/screens/widgets/custom_text_form_field.dart';
import 'package:marib/utils/login/lib/payloads.dart';

// ============= ViewModel & Callbacks =============

// lib/ui/screens/auth/login/login_screen_ui.dart

import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:sms_autofill/sms_autofill.dart';

import 'package:marib/ui/screens/widgets/custom_text_form_field.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:marib/utils/login/lib/payloads.dart';
import 'package:marib/utils/app_icon.dart';
import 'package:marib/utils/constant.dart';
import '../widgets/auth_status_bar.dart';

// =================== ثوابت ===================
const double kSidePadding = 20.0;

// =====================================================
// LoginScreenFrame (محفوظ للتوافق - غير مستخدم هنا افتراضياً)
// يبقى كما هو لو كنت تستخدمه في أماكن ثانية.
// =====================================================
class LoginScreenFrame extends StatelessWidget {
  final Widget child;
  final String logoAsset;
  final String titleKey;

  final String? backgroundSvgAsset;
  final double backgroundSvgOpacity;
  final BoxFit backgroundSvgFit;
  final Alignment backgroundSvgAlignment;
  final EdgeInsets backgroundSvgPadding;

  final double? headerHeight;
  final double backgroundSvgFactor;

  final double? backgroundSvgWidth;
  final double? backgroundSvgHeight;
  final Offset backgroundSvgOffset;

  final double maxWidth;
  final double logoSize;
  final EdgeInsetsGeometry contentPadding;
  final double edgeFadeSoftness;
  final bool showPattern;

  final bool randomizeBackground;
  final int? randomSeed;
  final double randomOpacityMin;
  final double randomOpacityMax;
  final double randomSizeMinFactor;
  final double randomSizeMaxFactor;
  final double randomOffsetMax;
  final double randomPaddingMax;
  final List<Alignment> randomAlignments;
  final List<BoxFit> randomFits;

  const LoginScreenFrame({
    super.key,
    required this.child,
    this.logoAsset = 'assets/svg/Logo.svg',
    this.titleKey = 'readytoserve',
    this.backgroundSvgAsset,
    this.backgroundSvgOpacity = 0.20,
    this.backgroundSvgFit = BoxFit.contain,
    this.backgroundSvgAlignment = Alignment.center,
    this.backgroundSvgPadding = EdgeInsets.zero,
    this.headerHeight,
    this.backgroundSvgFactor = 10.0,
    this.backgroundSvgWidth = 900,
    this.backgroundSvgHeight,
    this.backgroundSvgOffset = Offset.zero,
    this.maxWidth = 560,
    this.logoSize = 90,
    this.contentPadding = const EdgeInsets.all(1),
    this.edgeFadeSoftness = 0.07,
    this.showPattern = false,
    this.randomizeBackground = false,
    this.randomSeed,
    this.randomOpacityMin = 0.20,
    this.randomOpacityMax = 0.22,
    this.randomSizeMinFactor = 0.9,
    this.randomSizeMaxFactor = 1.6,
    this.randomOffsetMax = 18,
    this.randomPaddingMax = 12,
    this.randomAlignments = const [
      Alignment.center,
      Alignment.topLeft,
      Alignment.topRight,
      Alignment.bottomLeft,
      Alignment.bottomRight,
      Alignment.centerLeft,
      Alignment.centerRight,
      Alignment.topCenter,
      Alignment.bottomCenter,
    ],
    this.randomFits = const [BoxFit.contain, BoxFit.cover, BoxFit.scaleDown],
  });

  @override
  Widget build(BuildContext context) {
    // لو فيه Scroll فوقنا → لا نضيف Scroll هنا
    final hasAncestorScroll = Scrollable.of(context) != null;
    final Widget scrollableChild = hasAncestorScroll
        ? child
        : SingleChildScrollView(
            child: child,
          );

    // ملاحظة: لن نعرض الهيدر إلا إذا كان له ارتفاع صريح > 0
    final double h = (headerHeight ?? 0) > 0 ? headerHeight! : 0;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Column(
          children: [
            // ===== الهيدر (اختياري) =====
            if (h > 0)
              SizedBox(
                height: h,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SvgPicture.asset(
                          logoAsset,
                          height: logoSize,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 10),
                        Text(titleKey.translate(context))
                            .size(context.font.large)
                            .color(Colors.white),
                      ],
                    ),
                  ],
                ),
              ),

            if (h > 0) const SizedBox(height: 10),

            // ===== لوحة المحتوى (فقط) =====
            _EdgeFade(
              vSoft: edgeFadeSoftness,
              child: SizedBox(
                width: double.infinity,
                child: _FrostPanel(
                  padding: contentPadding,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 1),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    child: scrollableChild,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================
// Frost & EdgeFade (باقية للتوافق واستخدامات إضافية)
// =====================================================
class _FrostPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double blurSigma;
  final double tintOpacity;
  final double depthOpacity;

  const _FrostPanel({
    required this.child,
    this.padding = const EdgeInsets.all(300),
    this.blurSigma = 0,
    this.tintOpacity = 0.0,
    this.depthOpacity = 0,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c1 =
        scheme.primary.withOpacity(isDark ? tintOpacity : tintOpacity * 0.0);
    final c2 = scheme.secondary
        .withOpacity(isDark ? tintOpacity * 0.8 : tintOpacity * 0.0);
    final c3 =
        scheme.surface.withOpacity(isDark ? depthOpacity : depthOpacity * 0.0);

    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: const [0.0, 0.0, 0.0],
              colors: [c1, c2, c3],
            ),
          ),
          child: Padding(
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}

class _EdgeFade extends StatelessWidget {
  final Widget child;
  final double vSoft;
  final double hSoft;

  const _EdgeFade({
    required this.child,
    this.vSoft = 0.0,
    this.hSoft = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    if (vSoft <= 0 && hSoft <= 0) return child;

    final v = vSoft.clamp(0.0, 0.0);
    final h = hSoft.clamp(0.0, 0.0);

    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [
          Colors.transparent,
          Colors.white,
          Colors.white,
          Colors.transparent
        ],
        stops: [0.0, v, 1 - v, 0.0],
      ).createShader(rect),
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (rect) => LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: const [
            Colors.transparent,
            Colors.white,
            Colors.white,
            Colors.transparent
          ],
          stops: [0.0, h, 1 - h, 0.0],
        ).createShader(rect),
        child: child,
      ),
    );
  }
}

// =====================================================
// LoginHeaderSection — نفس الاسم والـ API
// تم تحويله لاستخدام SliverAppBar ويحتوي child داخل SliverToBoxAdapter
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
    // ارتفاع الكيبورد السفلي للحشو أسفل المحتوى
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final statusBarHeight = MediaQuery.of(context).padding.top;

    // [محايد لشريط الحالة] نختار لون ثابت من الثيم (لا يتبع لون الصفحة/الهيدر)
    final Color statusBarBase =
        LoginStatusBar.resolveBaseColor(context); // لون محايد ومتسق

    // [ستايل شريط الحالة] لون محايد + أيقونات داكنة/فاتحة تلقائيًا
    final SystemUiOverlayStyle overlay =
        LoginStatusBar.overlayFor(context, baseColor: statusBarBase);

    return SafeArea(
      top: false,
      // [مهم] نرسم نحن منطقة شريط الحالة، ثم نلوّنها يدويًا بالسليفِر الأول
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: PopScope(
          canPop: isBack,
          onPopInvoked: (didPop) {
            // منطق الرجوع الأصلي — بدون تغيير
            if (isDeleteAccount) {
              Navigator.pop(context);
            } else {
              if (isOtpSent) {
                onResetOTP();
              } else if (sendMailClicked) {
                onBack();
              } else {
                updateBackState(true);
                return;
              }
            }
            updateBackState(false);
            return;
          },
          child: AnnotatedRegion<SystemUiOverlayStyle>(
            value: overlay, // [تثبيت] نمرّر ستايل شريط الحالة المحايد
            child: Scaffold(
              backgroundColor: context.color.backgroundColor,
              body: DecoratedBox(
                // الخلفية العامة كما هي (البرتقالي للهيدر لاحقًا داخل الـ AppBar)
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    colors: [
                      context.color.territoryColor,
                      context.color.territoryColor,
                    ],
                  ),
                ),
                child: CustomScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  slivers: [
                    // [جديد] نلوّن مساحة شريط الحالة فقط بلون محايد مستقل عن الهيدر
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _LoginStatusBarHeader(
                        statusBarHeight,
                        statusBarBase,
                      ),
                    ),

                    // الهيدر (يبقى بتدرّجه البرتقالي وبحوافه الدائرية)
                    SliverAppBar(
                      pinned: true,
                      floating: false,
                      expandedHeight: 160,
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      automaticallyImplyLeading: false,
                      systemOverlayStyle: null,
                      // [مهم] نتركه null لأننا ضبطنا الـ overlay أعلاه
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
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(28),
                              bottomRight: Radius.circular(28),
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Semantics(
                                label: 'App Logo',
                                child: SvgPicture.asset(
                                  'assets/svg/Logo.svg',
                                  height: 84,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text("readytoserve".translate(context))
                                  .size(context.font.large)
                                  .color(Colors.white.withOpacity(0.95)),
                            ],
                          ),
                        ),
                      ),
                      shadowColor: Colors.black26,
                      surfaceTintColor: Colors.transparent,
                    ),
                    // محتوى الصفحة
                    SliverToBoxAdapter(
                      child: Padding(
                        padding:
                            EdgeInsets.fromLTRB(2, 12, 2, 16 + bottomInset),
                        child: child,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =====================================================
// LoginScreenUI — نفس الاسم والـ API
// تم تحويلها لبطاقة أنيقة (بدون رأس) — الرأس يأتي من LoginHeaderSection
// =====================================================
class LoginScreenUI extends StatelessWidget {
  // حالة العرض
  final bool isOtpSent;
  final bool sendMailClicked;
  final bool isMobileNumberField;
  final bool isLoading;
  final bool isObscure;

  // أخطاء
  final String? phoneEmailError;
  final String? passwordError;

  // مدخلات
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final String? countryCode;
  final String? flagEmoji;

  // OTP
  final PhoneLoginPayload? phoneLoginPayload;
  final String? currentOtp;
  final ValueChanged<String?> onOtpChanged;

  // أفعال وأزرار
  final VoidCallback onSkip;
  final VoidCallback onShowCountryPicker;
  final VoidCallback onToggleObscure;
  final VoidCallback onForgotPassword;
  final VoidCallback onChangeLoginMode;
  final VoidCallback onResendOtp;
  final VoidCallback onVerifyOtp;
  final void Function(String input, String pass, bool asPhone)
      onSubmitCredentials;
  final VoidCallback onGoogleLogin;
  final VoidCallback onAppleLogin;
  final VoidCallback onTapContinue;
  final VoidCallback onGoToSignup;

  // إظهار/إخفاء خيارات
  final bool showMobileAuth;
  final bool showEmailAuth;
  final bool showGoogle;
  final bool showApple;

  // إدخال التغيير
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
    // بطاقة أنيقة بنفس أسلوب التسجيل
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
      padding: const EdgeInsets.fromLTRB(14, 20, 14, 18),
      child: Form(
        child: isOtpSent && phoneLoginPayload != null
            ? _VerifyOtpView(
                phoneLoginPayload: phoneLoginPayload!,
                currentOtp: currentOtp,
                onOtpChanged: onOtpChanged,
                onResendOtp: onResendOtp,
                onVerifyOtp: onVerifyOtp,
                onSkip: onSkip,
                onChangeLoginMode: onChangeLoginMode,
              )
            : sendMailClicked
                ? _EnterPasswordEmailView(
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
                  )
                : _LoginOptionsView(
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
          const SizedBox(height: 6),
          Text("welcomeback".translate(context))
              .size(context.font.extraLarge)
              .color(context.color.textDefaultColor),
          const SizedBox(height: 8),
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

              // تأثير ضغط + رِبل (Ripple)
              Material(
                // مهم لو ما عندك Material مباشر في الأب
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
          onPressed: isLoading ? () {} : onSubmit,
          prefixWidget: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : null,
          buttonTitle: isLoading ? "" : "signIn".translate(context),
          radius: 8,
        ),
        const SizedBox(height: 2),
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
          ),
        ],
      ),
    );
  }
}

class _LoginStatusBarHeader extends SliverPersistentHeaderDelegate {
  _LoginStatusBarHeader(this.height, this.baseColor);

  final double height;
  final Color baseColor;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    if (height <= 0) {
      return const SizedBox.shrink();
    }

    final color = LoginStatusBar.resolveBaseColor(context, override: baseColor);
    return SizedBox.expand(
      child: Container(color: color),
    );
  }

  @override
  bool shouldRebuild(covariant _LoginStatusBarHeader oldDelegate) {
    return oldDelegate.height != height || oldDelegate.baseColor != baseColor;
  }
}
