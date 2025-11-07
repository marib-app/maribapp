import 'dart:async';
import 'dart:io';

import 'package:country_picker/country_picker.dart';
import 'package:device_region/device_region.dart';
import 'package:marib/app/app_theme.dart';
import 'package:marib/app/routes.dart';
import 'package:marib/data/cubits/system/app_theme_cubit.dart';
import 'package:marib/data/cubits/system/fetch_system_settings_cubit.dart';
import 'package:marib/data/helper/widgets.dart';
import 'package:marib/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/app_icon.dart';
import 'package:marib/utils/constant.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/helper_utils.dart';

import 'package:marib/utils/login/lib/login_status.dart';
import 'package:marib/utils/api.dart';
import 'package:marib/data/cubits/auth/authentication_cubit.dart';
import 'package:marib/utils/login/lib/payloads.dart';
import 'package:marib/utils/ui_utils.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sms_autofill/sms_autofill.dart';
import 'package:marib/ui/screens/auth/widgets/auth_status_bar.dart';
import 'package:marib/ui/widgets/shimmer/shimmer_box.dart';

class MobileSignUpScreen extends StatefulWidget {
  final String? mobile;
  final String? countryCode;

  const MobileSignUpScreen({super.key, this.mobile, this.countryCode});

  @override
  State<MobileSignUpScreen> createState() => MobileSignUpScreenState();

  static Route route(RouteSettings routeSettings) {
    Map? args = routeSettings.arguments as Map?;
    return BlurredRouter(
        builder: (_) => MobileSignUpScreen(
              mobile: args?['mobile'],
              countryCode: args?['countryCode'],
            ));
  }
}

class MobileSignUpScreenState extends State<MobileSignUpScreen> {
  // final TextEditingController mobileTextController = TextEditingController();
  // bool isOtpSent = false;
  String? phone, otp, countryName, flagEmoji, countryCode;

  // Timer? timer;
  CountryService countryCodeService = CountryService();
  bool isLoginButtonDisabled = true;
  final _formKey = GlobalKey<FormState>();

  //TextEditingController _otpController = TextEditingController();

  bool isObscure = true;
  late PhoneLoginPayload phoneLoginPayload =
      PhoneLoginPayload(widget.mobile!, widget.countryCode!);
  bool isBack = false;
  bool _isBootstrapping = true;
  String signature = "";
  VoidCallback? _authenticationListenerDisposer;

  @override
  void initState() {
    super.initState();
    countryCode = widget.countryCode ?? Constant.defaultCountryCode;
    phoneLoginPayload = PhoneLoginPayload(
      widget.mobile ?? '',
      countryCode ?? Constant.defaultCountryCode,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _lazyInit();
    });
  }

  void _lazyInit() {
    final authCubit = context.read<AuthenticationCubit>();
    authCubit.init();

    _authenticationListenerDisposer?.call();
    _authenticationListenerDisposer = authCubit.listen((MLoginState state) {
      if (!mounted) return;
      if (state is MFail) {
        //Widgets.hideLoder(context);

        //if (!isOtpSent && isMobileNumberField) {
        Widgets.hideLoder(context);
        //}
      }
    });
    getSignature();

    getSimCountry().then((value) {
      if (!mounted) return;

      setState(() {
        countryCode = value.phoneCode;
        flagEmoji = value.flagEmoji;
        phoneLoginPayload = PhoneLoginPayload(
          widget.mobile ?? '',
          countryCode ?? Constant.defaultCountryCode,
        );
        _isBootstrapping = false;
      });
    }).catchError((_) {
      if (!mounted) return;
      setState(() {
        _isBootstrapping = false;
      });
    });
  }

  Future<void> getSignature() async {
    signature = await SmsAutoFill().getAppSignature;
    SmsAutoFill().listenForCode;
    if (!mounted) return;

    setState(() {});
  }

  Future<bool> _ensureSystemSettingsAvailable() async {
    final cubit = context.read<FetchSystemSettingsCubit>();
    final currentState = cubit.state;
    if (currentState is FetchSystemSettingsSuccess) {
      return true;
    }

    Widgets.showLoader(context);
    FetchSystemSettingsState? resolvedState;
    try {
      if (currentState is FetchSystemSettingsInProgress) {
        resolvedState = await cubit.stream.firstWhere(
          (state) =>
              state is FetchSystemSettingsSuccess ||
              state is FetchSystemSettingsFailure,
        );
      } else {
        await cubit.fetchSettings();
        resolvedState = cubit.state;
      }
    } finally {
      Widgets.hideLoder(context);
    }

    if (resolvedState is FetchSystemSettingsFailure) {
      if (mounted) {
        HelperUtils.showSnackBarMessage(
          context,
          resolvedState.errorMessage,
          type: MessageType.error,
        );
      }
      return false;
    }

    return resolvedState is FetchSystemSettingsSuccess;
  }

  Future<void> _openStaticContent({
    required String title,
    required String param,
  }) async {
    final ready = await _ensureSystemSettingsAvailable();
    if (!ready || !mounted) {
      return;
    }

    Navigator.pushNamed(
      context,
      Routes.profileSettings,
      arguments: {
        'title': title,
        'param': param,
      },
    );
  }

  /// it will return user's sim cards country code
  Future<Country> getSimCountry() async {
    List<Country> countryList = countryCodeService.getAll();
    String? simCountryCode;

    try {
      simCountryCode = await DeviceRegion.getSIMCountryCode();
    } catch (e) {}

    final normalizedSimCode = simCountryCode?.toUpperCase();
    final Country fallback = countryList.firstWhere(
      (element) => element.phoneCode == Constant.defaultCountryCode,
      orElse: () => countryList.first,
    );

    Country simCountry = fallback;

    if (normalizedSimCode != null && normalizedSimCode.isNotEmpty) {
      simCountry = countryList.firstWhere(
        (element) => element.countryCode.toUpperCase() == normalizedSimCode,
        orElse: () => fallback,
      );
    }

    if (Constant.isDemoModeOn) {
      return countryList.firstWhere(
        (element) => element.phoneCode == Constant.demoCountryCode,
        orElse: () => fallback,
      );
    }

    return simCountry;
  }

  @override
  void dispose() {
    _authenticationListenerDisposer?.call();
    _authenticationListenerDisposer = null;
    // if (timer != null) {
    //   timer!.cancel();
    // }

    //mobileTextController.dispose();
    SmsAutoFill().unregisterListener();

    super.dispose();
  }

  void _onTapContinue() {
    final resolvedCode =
        countryCode ?? widget.countryCode ?? Constant.defaultCountryCode;
    phoneLoginPayload = PhoneLoginPayload(
      widget.mobile ?? '',
      resolvedCode,
    );

    context
        .read<AuthenticationCubit>()
        .setData(payload: phoneLoginPayload, type: AuthenticationType.phone);
    context.read<AuthenticationCubit>().verify();

    setState(() {});
  }

  Future<void> sendVerificationCode() async {
    /*isOtpSent = true;

    context
        .read<AuthenticationCubit>()
        .setData(payload: phoneLoginPayload, type: AuthenticationType.phone);
    context.read<AuthenticationCubit>().verify();

    setState(() {});*/

    final form = _formKey.currentState;

    if (form == null) return;
    form.save();
    //checkbox value should be 1 before Login/SignUp
    if (form.validate()) {
      _onTapContinue();
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusBarBase = LoginStatusBar.resolveBaseColor(
      context,
      override: context.color.backgroundColor,
    );
    final settingsState = context.watch<FetchSystemSettingsCubit>().state;
    final bool isSettingsReady = settingsState is FetchSystemSettingsSuccess;
    final bool isSettingsLoading =
        settingsState is FetchSystemSettingsInProgress;
    final bool showSkeleton = _isBootstrapping || isSettingsLoading;
    final overlay = LoginStatusBar.overlayFor(
      context,
      baseColor: statusBarBase,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay,
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: PopScope(
          canPop: isBack,
          onPopInvoked: (didPop) {
            if (didPop) {
              if (mounted) {
                setState(() => isBack = false);
              }
              return;
            }
            HelperUtils.showSnackBarMessage(
              context,
              'اضغط مرة أخرى للتأكيد',
            );
            if (mounted) {
              setState(() => isBack = true);
            }
          },
          child: Scaffold(
            backgroundColor: context.color.backgroundColor,
            appBar: _buildAppBar(context),
            body: SafeArea(
              top: false,
              child: Form(
                key: _formKey,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: showSkeleton
                        ? const _SignUpShimmer(key: ValueKey('signup-shimmer'))
                        : KeyedSubtree(
                            key: const ValueKey('signup-body'),
                            child: buildLoginWidget(
                              isSettingsReady: isSettingsReady,
                              isSettingsLoading: isSettingsLoading,
                            ),
                          ),
                  ),
                ),
              ),
            ),
            bottomNavigationBar: _SignUpActionBar(
              legalNotice: termAndPolicyTxt(),
              onContinue: sendVerificationCode,
              isBusy: showSkeleton,
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: context.color.backgroundColor,
      elevation: 0,
      centerTitle: false,
      titleSpacing: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.of(context).maybePop(),
        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
      ),
      title: Text("signUp".translate(context))
          .size(context.font.large)
          .color(context.color.textColorDark),
    );
  }

  Widget emailSignUp() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(
          height: 36,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("signupWithLbl".translate(context))
                .color(context.color.textColorDark.brighten(50)),
            const SizedBox(
              width: 5,
            ),
            GestureDetector(
              onTap: () {
                Navigator.pushNamed(context, Routes.signupMainScreen);
              },
              child: Text("emailLbl".translate(context))
                  .underline()
                  .color(context.color.territoryColor),
            )
          ],
        ),
      ],
    );
  }

  Widget buildLoginWidget({
    required bool isSettingsReady,
    required bool isSettingsLoading,
  }) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 160),
      children: [
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: TextButton(
            onPressed: () {
              Navigator.pushReplacementNamed(
                context,
                Routes.main,
                arguments: {
                  "from": "login",
                  "isSkipped": true,
                },
              );
            },
            child: Text("skip".translate(context))
                .color(context.color.forthColor)
                .size(context.font.normal),
          ),
        ),
        if (isSettingsLoading && !isSettingsReady)
          const Padding(
            padding: EdgeInsets.only(bottom: 16.0),
            child: SizedBox(
              height: 3,
              child: LinearProgressIndicator(minHeight: 3),
            ),
          ),
        Text("welcome".translate(context))
            .size(context.font.extraLarge)
            .color(context.color.textDefaultColor),
        const SizedBox(height: 8),
        Text("signUpTomarib".translate(context))
            .size(context.font.large)
            .color(context.color.textColorDark),
        const SizedBox(height: 24),
        _buildPhoneSummaryTile(),
        const SizedBox(height: 32),
        if (Constant.isEmailAuthEnabled) emailSignUp(),
        if (Constant.isGoogleAuthEnabled || Constant.isAppleAuthEnabled)
          googleAndAppleAuth(),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("alreadyHaveAcc".translate(context))
                .color(context.color.textColorDark.brighten(50)),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, Routes.login),
              child: Text("login".translate(context))
                  .underline()
                  .color(context.color.territoryColor),
            ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildPhoneSummaryTile() {
    final resolvedCode =
        "+${countryCode ?? widget.countryCode ?? Constant.defaultCountryCode}";
    final String resolvedFlag = flagEmoji != null ? "${flagEmoji!} " : "";
    return InputDecorator(
      decoration: InputDecoration(
        labelText: "mobileNumber".translate(context),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: context.color.borderColor.withOpacity(0.6),
          ),
        ),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      ),
      child: Row(
        children: [
          Text("$resolvedFlag$resolvedCode")
              .size(context.font.large)
              .color(context.color.textColorDark),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.mobile ?? '',
              overflow: TextOverflow.ellipsis,
            ).size(context.font.large),
          ),
        ],
      ),
    );
  }

  Widget googleAndAppleAuth() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(
          height: 24,
        ),
        if (Constant.isGoogleAuthEnabled)
          UiUtils.buildButton(context,
              prefixWidget: Padding(
                padding: EdgeInsetsDirectional.only(end: 10.0),
                child:
                    UiUtils.getSvg(AppIcons.googleIcon, width: 22, height: 22),
              ),
              showElevation: false,
              buttonColor: secondaryColor_,
              border: context.watch<AppThemeCubit>().state.appTheme !=
                      AppTheme.dark
                  ? BorderSide(
                      color: context.color.textDefaultColor.withOpacity(0.5))
                  : null,
              textColor: textDarkColor, onPressed: () {
            context.read<AuthenticationCubit>().setData(
                payload: GoogleLoginPayload(), type: AuthenticationType.google);
            context.read<AuthenticationCubit>().authenticate();
          },
              radius: 8,
              height: 46,
              buttonTitle: "continueWithGoogle".translate(context)),
        if (Constant.isAppleAuthEnabled && Platform.isIOS) ...[
          const SizedBox(
            height: 12,
          ),
          UiUtils.buildButton(context,
              prefixWidget: Padding(
                padding: EdgeInsetsDirectional.only(end: 10.0),
                child:
                    UiUtils.getSvg(AppIcons.appleIcon, width: 22, height: 22),
              ),
              showElevation: false,
              buttonColor: secondaryColor_,
              border: context.watch<AppThemeCubit>().state.appTheme !=
                      AppTheme.dark
                  ? BorderSide(
                      color: context.color.textDefaultColor.withOpacity(0.5))
                  : null,
              textColor: textDarkColor, onPressed: () {
            context.read<AuthenticationCubit>().setData(
                payload: AppleLoginPayload(), type: AuthenticationType.apple);
            context.read<AuthenticationCubit>().authenticate();
          },
              height: 46,
              radius: 8,
              buttonTitle: "continueWithApple".translate(context)),
        ]
      ],
    );
  }

  Widget termAndPolicyTxt() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text("bySigningUpLoggingIn".translate(context))
            .centerAlign()
            .size(context.font.small)
            .color(context.color.textLightColor.withOpacity(0.8)),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            InkWell(
              child: Text("termsOfService".translate(context))
                  .underline()
                  .color(context.color.territoryColor)
                  .size(context.font.small),
              onTap: () => _openStaticContent(
                title: "termsConditions".translate(context),
                param: Api.termsAndConditions,
              ),
            ),
            const SizedBox(width: 5.0),
            Text("andTxt".translate(context))
                .size(context.font.small)
                .color(context.color.textLightColor.withOpacity(0.8)),
            const SizedBox(width: 5.0),
            InkWell(
              child: Text("privacyPolicy".translate(context))
                  .underline()
                  .color(context.color.territoryColor)
                  .size(context.font.small),
              onTap: () => _openStaticContent(
                title: "privacyPolicy".translate(context),
                param: Api.privacyPolicy,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SignUpActionBar extends StatelessWidget {
  final Widget legalNotice;
  final VoidCallback onContinue;
  final bool isBusy;

  const _SignUpActionBar({
    required this.legalNotice,
    required this.onContinue,
    required this.isBusy,
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
            legalNotice,
            const SizedBox(height: 14),
            UiUtils.buildButton(
              context,
              onPressed: onContinue,
              buttonTitle: "verifyMobileNumberLbl".translate(context),
              radius: 14,
              isInProgress: isBusy,
              disabled: isBusy,
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
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 160),
      children: const [
        SizedBox(height: 8),
        ShimmerBox(height: 18, width: 120),
        SizedBox(height: 12),
        ShimmerBox(height: 20, width: 200),
        SizedBox(height: 24),
        ShimmerBox(height: 70),
        SizedBox(height: 20),
        ShimmerBox(height: 46, width: 240),
        SizedBox(height: 16),
        ShimmerBox(height: 46, width: 240),
        SizedBox(height: 16),
        ShimmerBox(height: 20, width: 180),
        SizedBox(height: 12),
        ShimmerBox(height: 20, width: 160),
      ],
    );
  }
}
