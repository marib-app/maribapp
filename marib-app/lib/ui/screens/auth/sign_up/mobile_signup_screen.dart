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

class MobileSignUpScreen extends StatefulWidget {
  final String? mobile;
  final String? countryCode;

  const MobileSignUpScreen({super.key, this.mobile, this.countryCode});

  @override
  State<MobileSignUpScreen> createState() => MobileSignUpScreenState();

  static BlurredRouter route(RouteSettings routeSettings) {
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
  String? phone, otp, countryName, flagEmoji;

  // Timer? timer;
  late Size size;
  CountryService countryCodeService = CountryService();
  bool isLoginButtonDisabled = true;
  final _formKey = GlobalKey<FormState>();

  //TextEditingController _otpController = TextEditingController();

  bool isObscure = true;
  late PhoneLoginPayload phoneLoginPayload =
      PhoneLoginPayload(widget.mobile!, widget.countryCode!);
  bool isBack = false;
  String signature = "";
  VoidCallback? _authenticationListenerDisposer;

  @override
  void initState() {
    super.initState();
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

    Country simCountry = countryList.firstWhere(
      (element) {
        if (Constant.isDemoModeOn) {
          return countryList.any(
            (element) => element.phoneCode == Constant.defaultCountryCode,
          );
        } else {
          return element.phoneCode == simCountryCode;
        }
      },
      orElse: () {
        return countryList
            .where(
              (element) => element.phoneCode == Constant.defaultCountryCode,
            )
            .first;
      },
    );

    if (Constant.isDemoModeOn) {
      simCountry = countryList
          .where((element) => element.phoneCode == Constant.demoCountryCode)
          .first;
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
    phoneLoginPayload = PhoneLoginPayload(widget.mobile!, widget.countryCode!);

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
    size = MediaQuery.of(context).size;
    final settingsState = context.watch<FetchSystemSettingsCubit>().state;
    final bool isSettingsReady = settingsState is FetchSystemSettingsSuccess;
    final bool isSettingsLoading =
        settingsState is FetchSystemSettingsInProgress;
    return AnnotatedRegion(
      value: UiUtils.getSystemUiOverlayStyle(
        context: context,
        statusBarColor: context.color.backgroundColor,
      ),
      child: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: PopScope(
            canPop: isBack,
            onPopInvoked: (didPop) {
              setState(() {
                isBack = true;
              });
              return;
            },
            child: AnnotatedRegion(
              value: SystemUiOverlayStyle(
                statusBarColor: context.color.backgroundColor,
              ),
              child: Scaffold(
                backgroundColor: context.color.backgroundColor,
                bottomNavigationBar: termAndPolicyTxt(),
                body: Builder(builder: (context) {
                  return Form(
                    key: _formKey,
                    child: buildLoginWidget(
                      isSettingsReady: isSettingsReady,
                      isSettingsLoading: isSettingsLoading,
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
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
    return SingleChildScrollView(
      child: SizedBox(
        height: context.screenHeight - 50,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: AlignmentDirectional.topEnd,
                child: FittedBox(
                  fit: BoxFit.none,
                  child: MaterialButton(
                    onPressed: () {
                      //HiveUtils.setUserIsNotNew();

                      Navigator.pushReplacementNamed(
                        context,
                        Routes.main,
                        arguments: {
                          "from": "login",
                          "isSkipped": true,
                        },
                      );
                    },
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    color: context.color.forthColor.withOpacity(0.102),
                    elevation: 0,
                    height: 28,
                    minWidth: 64,
                    child: Text("skip".translate(context))
                        .color(context.color.forthColor),
                  ),
                ),
              ),
              const SizedBox(
                height: 66,
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
              const SizedBox(
                height: 8,
              ),
              Text("signUpTomarib".translate(context))
                  .size(context.font.large)
                  .color(
                    context.color.textColorDark,
                  ),
              const SizedBox(
                height: 24,
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 5, vertical: 18),
                decoration: BoxDecoration(
                    color: context.color.secondaryColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: context.color.borderColor.darken(30))),
                child: Row(
                  children: [
                    // Display the country code as text
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text("+${widget.countryCode}")
                          .size(context.font.large)
                          .centerAlign(),
                    ),
                    Expanded(
                      child: Text(
                        widget.mobile!,
                      ).size(context.font.large),
                    ),
                  ],
                ),
              ),
              const SizedBox(
                height: 46,
              ),
              UiUtils.buildButton(context,
                  onPressed: sendVerificationCode,
                  buttonTitle: "verifyMobileNumberLbl".translate(context),
                  radius: 10,
                  disabledColor: const Color.fromARGB(255, 104, 102, 106)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (Constant.emailAuthentication == '1') emailSignUp(),
                  if (Constant.googleAuthentication == "1" ||
                      Constant.appleAuthentication == "1")
                    googleAndAppleAuth(),
                  const SizedBox(
                    height: 24,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("alreadyHaveAcc".translate(context))
                          .color(context.color.textColorDark.brighten(50)),
                      const SizedBox(
                        width: 12,
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.pushNamed(context, Routes.login);
                        },
                        child: Text("login".translate(context))
                            .underline()
                            .color(context.color.territoryColor),
                      )
                    ],
                  ),
                  const SizedBox(
                    height: 24,
                  ),
                ],
              ),
            ],
          ),
        ),
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
        if (Constant.googleAuthentication == "1")
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
        if (Constant.appleAuthentication == "1" && Platform.isIOS) ...[
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
    return Padding(
      padding: EdgeInsetsDirectional.only(bottom: 15.0, start: 25.0, end: 25.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("bySigningUpLoggingIn".translate(context))
              .centerAlign()
              .size(context.font.small)
              .color(context.color.textLightColor.withOpacity(0.8)),
          const SizedBox(
            height: 3,
          ),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            InkWell(
                child: Text("termsOfService".translate(context))
                    .underline()
                    .color(context.color.territoryColor)
                    .size(context.font.small),
                onTap: () => _openStaticContent(
                      title: "termsConditions".translate(context),
                      param: Api.termsAndConditions,
                    )),
            /*CustomTextButton(
                text:Text("termsOfService".translate(context)).underline().color(context.color.teritoryColor).size(context.font.small),
                onPressed: () => Navigator.pushNamed(
                        context, Routes.profileSettings,
                        arguments: {
                          'title': UiUtils.getTranslatedLabel(
                              context, "termsConditions"),
                          'param': Api.termsAndConditions
                        })),*/
            const SizedBox(
              width: 5.0,
            ),
            Text("andTxt".translate(context))
                .size(context.font.small)
                .color(context.color.textLightColor.withOpacity(0.8)),
            const SizedBox(
              width: 5.0,
            ),
            InkWell(
                child: Text("privacyPolicy".translate(context))
                    .underline()
                    .color(context.color.territoryColor)
                    .size(context.font.small),
                onTap: () => _openStaticContent(
                      title: "privacyPolicy".translate(context),
                      param: Api.privacyPolicy,
                    )),
            /*CustomTextButton(
                text:
                    Text("privacyPolicy".translate(context)).underline().color(context.color.teritoryColor).size(context.font.small),
                onPressed: () => Navigator.pushNamed(
                      context,
                      Routes.profileSettings,
                      arguments: {
                        'title': UiUtils.getTranslatedLabel(
                            context, "privacyPolicy"),
                        'param': Api.privacyPolicy
                      },
                    )),*/
          ]),
        ],
      ),
    );
  }

/*  void showCountryCode() {
    showCountryPicker(
      context: context,
      showWorldWide: false,
      showPhoneCode: true,
      countryListTheme:
          CountryListThemeData(borderRadius: BorderRadius.circular(11)),
      onSelect: (Country value) {
        flagEmoji = value.flagEmoji;
        countryCode = value.phoneCode;
        setState(() {});
      },
    );
  }*/
}
