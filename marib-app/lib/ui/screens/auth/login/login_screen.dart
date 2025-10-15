// lib/ui/screens/auth/login_screen.dart

import 'dart:async';
import 'dart:io';
import 'package:country_picker/country_picker.dart';
import 'package:device_region/device_region.dart';
import 'package:flutter_svg/svg.dart';
import 'package:marib/app/app_theme.dart';
import 'package:marib/app/routes.dart';
import 'package:marib/data/cubits/auth/authentication_cubit.dart';
import 'package:marib/data/cubits/auth/login_cubit.dart';
import 'package:marib/data/cubits/system/app_theme_cubit.dart';
import 'package:marib/data/cubits/system/user_details.dart';
import 'package:marib/data/helper/widgets.dart';
import 'package:marib/utils/api.dart';
import 'package:marib/utils/constant.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:marib/utils/hive_utils.dart';
import 'package:marib/utils/login/lib/login_status.dart';
import 'package:marib/utils/login/lib/payloads.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sms_autofill/sms_autofill.dart';
import 'package:marib/ui/screens/widgets/animated_routes/blur_page_route.dart';


// واجهة منفصلة بالكامل
import 'login_screen_ui.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class LoginScreen extends StatefulWidget {
  final bool? isDeleteAccount;
  final bool? popToCurrent;

  const LoginScreen({super.key, this.isDeleteAccount, this.popToCurrent});

  @override
  State<LoginScreen> createState() => LoginScreenState();



  static BlurredRouter route(RouteSettings routeSettings) {
    Map? args = routeSettings.arguments as Map?;
    return BlurredRouter(
      builder: (_) => LoginScreen(
        isDeleteAccount: args?['isDeleteAccount'],
        popToCurrent: args?['popToCurrent'],
      ),
    );
  }
}



class LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailMobileTextController = TextEditingController(
    text: Constant.isDemoModeOn ? Constant.demoMobileNumber : "",
  );

  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool isOtpSent = false;
  bool isMobileNumberField = false;
  bool sendMailClicked = false;
  bool isObscure = true;
  bool isBack = false;

  String? countryCode, countryName, flagEmoji;
  String? phoneEmailError;
  String? passwordError;
  String? otp;
  String numberOrEmail = "";
  String signature = "";

  Timer? timer;
  late Size size;

  CountryService countryCodeService = CountryService();
  VoidCallback? _authenticationListenerDisposer;

  // ملاحظة: لا تُستخدم إلا بعد تحديد countryCode فعليًا
  late PhoneLoginPayload phoneLoginPayload =
  PhoneLoginPayload(emailMobileTextController.text, countryCode ?? "");

  @override
  void initState() {
    super.initState();

    if (Constant.mobileAuthentication == "1" && Constant.isDemoModeOn) {
      isMobileNumberField = true;
      numberOrEmail = Constant.demoMobileNumber;
    }

    _initPlatform();
    _listenAuth();

  }

  Future<void> _initPlatform() async {
    signature = await SmsAutoFill().getAppSignature;
    SmsAutoFill().listenForCode;
    if (mounted) setState(() {});

    final sim = await _getSimCountry();
    countryCode = sim.phoneCode;
    flagEmoji = sim.flagEmoji;
    if (mounted) setState(() {});
  }

  void _listenAuth() {
    // AuthenticationCubit listener (OTP/Google/Apple)
    final authCubit = context.read<AuthenticationCubit>();
    authCubit.init();
    _authenticationListenerDisposer?.call();
    _authenticationListenerDisposer = authCubit.listen((MLoginState state) {
      if (!mounted) return;
      if (state is MOtpSendInProgress) {
        if (mounted) Widgets.showLoader(context);
      }

      if (state is MVerificationPending) {
        if (!mounted) return;
        Widgets.hideLoder(context);
        isOtpSent = true;
        setState(() {});
        if (isMobileNumberField) {
          HelperUtils.showSnackBarMessage(
            context,
            "optsentsuccessflly".translate(context),
          );
        }
      }

      if (state is MFail) {
      if (!mounted) return;
        if (!isOtpSent && isMobileNumberField) {
          Widgets.hideLoder(context);
        }
        if (isOtpSent && (otp
            ?.trim()
            .isEmpty ?? true)) {
          HelperUtils.showSnackBarMessage(
            context,
            "${"weSentCodeOnNumber".translate(
                context)}\t${emailMobileTextController.text}",
            type: MessageType.error,
          );
        } else {
          if (state.error is FirebaseAuthException) {
            try {
              HelperUtils.showSnackBarMessage(
                context,
                (state.error as FirebaseAuthException).message!.toString(),
              );
            } catch (_) {}
          } else {
            HelperUtils.showSnackBarMessage(
              context,
              state.error.toString(),
            );
          }
        }
      }

      if (state is MSuccess) {
        // success handled below in BlocConsumer listener
      }
    });
  }


  Future<String?> _resolveFcmToken() async {
    final List<String?> candidates = <String?>[
      HiveUtils.getUserDetails().fcmId,
      HiveUtils.getUserDetail<String>(key: Api.fcmId),
    ];

    for (final String? candidate in candidates) {
      final String normalized = (candidate ?? '').trim();
      if (normalized.isNotEmpty) {
        return normalized;
      }
    }

    try {
      final String? fetched = await FirebaseMessaging.instance.getToken();
      final String normalized = (fetched ?? '').trim();
      if (normalized.isEmpty) {
        return null;
      }

      await HiveUtils.setUserDetail(key: Api.fcmId, value: normalized);
      return normalized;
    } catch (e) {
      debugPrint('Failed to resolve FCM token: $e');
      return null;
    }
  }

  Future<Country> _getSimCountry() async {
    final list = countryCodeService.getAll();
    String? simCode;
    try {
      simCode = await DeviceRegion.getSIMCountryCode();
    } catch (_) {}

    final normalizedSimCode = simCode?.toUpperCase();
    final Country fallback = list.firstWhere(
          (e) => e.phoneCode == Constant.defaultCountryCode,
      orElse: () => list.first,
    );

    Country simCountry = fallback;

    if (normalizedSimCode != null && normalizedSimCode.isNotEmpty) {
      simCountry = list.firstWhere(
            (e) => e.countryCode.toUpperCase() == normalizedSimCode,
        orElse: () => fallback,
      );
    }

    if (Constant.isDemoModeOn) {
      return list.firstWhere(
            (e) => e.phoneCode == Constant.demoCountryCode,
        orElse: () => fallback,
      );
    }
    return simCountry;
  }

  @override
  void dispose() {
    SmsAutoFill().unregisterListener();
    _authenticationListenerDisposer?.call();
    _authenticationListenerDisposer = null;
    timer?.cancel();
    _passwordController.dispose();
    emailMobileTextController.dispose();
    super.dispose();
  }

  // ===== Actions (Callbacks للـ UI) =====

  void _onToggleObscure() {
    setState(() => isObscure = !isObscure);
  }

  void _onShowCountryCode() {
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
  }

  void _onChangedInput(String v) {
    final isNumber = v.contains(RegExp(r'^[0-9]+$'));
    isMobileNumberField =
    Constant.mobileAuthentication == "1" ? isNumber : false;
    numberOrEmail = v;

    // إزالة أخطاء فورية
    if (phoneEmailError != null) phoneEmailError = null;
    setState(() {});
  }

  void _onGoogleLogin() {
    context.read<AuthenticationCubit>().setData(
      payload: GoogleLoginPayload(),
      type: AuthenticationType.google,
    );
    context.read<AuthenticationCubit>().authenticate();
  }

  void _onAppleLogin() {
    context.read<AuthenticationCubit>().setData(
      payload: AppleLoginPayload(),
      type: AuthenticationType.apple,
    );
    context.read<AuthenticationCubit>().authenticate();
  }

  void _onForgotPassword() {
    Navigator.pushNamed(context, Routes.forgotPassword);
  }

  void _onSkip() {
    HelperUtils.killPreviousPages(
      context,
      Routes.main,
      {"from": "login", "isSkipped": true},
    );
  }

  void _onChangeLoginMode() {
    // بدل الانتقال، نرجع لنفس الشاشة مع إعادة الترتيب
    setState(() {
      isOtpSent = false;
      sendMailClicked = false;
    });
  }

  void _onResendOtp() {
    context.read<AuthenticationCubit>().setData(
      payload: phoneLoginPayload,
      type: AuthenticationType.phone,
    );
    context.read<AuthenticationCubit>().verify();
  }

  void _onVerifyOtp() {
    if ((otp ?? "")
        .trim()
        .length < 6) {
      HelperUtils.showSnackBarMessage(
        context,
        "pleaseEnterSixDigits".translate(context),
      );
      return;
    }
    phoneLoginPayload.setOTP(otp!.trim());
    context.read<AuthenticationCubit>().authenticate();
  }

  void _onOtpChanged(String? code) {
    otp = code;
  }

  void _onSubmitCredentials(String userInput, String pass, bool asPhone) {
    // تصفية الأخطاء السابقة
    phoneEmailError = null;
    passwordError = null;

    final input = userInput.trim();
    final password = pass.trim();

    bool hasError = false;
    if (input.isEmpty) {
      phoneEmailError = asPhone
          ? "pleaseEnterPhoneNumber".translate(context)
          : "pleaseEnterEmail".translate(context);
      hasError = true;
    }
    if (password.isEmpty) {
      passwordError = "pleaseEnterPassword".translate(context);
      hasError = true;
    }
    if (!hasError && asPhone) {
      final phoneRegex = RegExp(r'^[0-9]+$');
      if (!phoneRegex.hasMatch(input) || input.length < 7) {
        phoneEmailError = "pleaseEnterValidPhoneNumber".translate(context);
        hasError = true;
      }
    }

    if (hasError) {
      setState(() {});
      return;
    }


    if (asPhone) {
      // تسجيل مباشر من الـ backend (هاتف + كلمة مرور)
      context.read<LoginCubit>().phonePasswordLogin(
        phoneNumber: input,
        password: password,
      );
    } else {
      // تسجيل بالإيميل والباسوورد عبر AuthenticationCubit
      context.read<AuthenticationCubit>().setData(
        payload: PhoneAndPasswordPayload(
          phoneNumber: input,
          password: password,
          type: EmailLoginType.login,
        ),
        type: AuthenticationType.email,
      );
      context.read<AuthenticationCubit>().authenticate();
    }
  }

  void _onContinueTap() {
    if (Constant.mobileAuthentication != "1") return;

    phoneLoginPayload =
        PhoneLoginPayload(emailMobileTextController.text, countryCode ?? "");

    context.read<AuthenticationCubit>().setData(
      payload: phoneLoginPayload,
      type: AuthenticationType.phone,
    );
    context.read<AuthenticationCubit>().verify();

    setState(() {});
  }

  // Google/Apple: بعد نجاح المصادقة من AuthenticationCubit
  Future<void> _handleSocialLoginFromLogin(AuthenticationSuccess state) async {
    try {
      final user = state.credential.user;
      if (user != null) {
        final payload = {
          "firebase_id": user.uid,
          "type": state.type.name,
          "platform_type": Platform.isAndroid ? "android" : "ios",
        };

        final String? fcmToken = await _resolveFcmToken();
        if (fcmToken != null && fcmToken.isNotEmpty) {
          payload["fcm_id"] = fcmToken;
        }

        final response = await Api.post(url: "user-login", parameter: payload);

        if (response['error'] == false) {
          HiveUtils.setJWT(response['token']);
          HiveUtils.setUserData(response['data']);
          HiveUtils.setUserIsAuthenticated(true);
          context.read<UserDetailsCubit>().fill(HiveUtils.getUserDetails());

          if ((HiveUtils.getCityName() ?? "").isNotEmpty &&
              HiveUtils.getCityName() != "null") {
            HelperUtils.killPreviousPages(
                context, Routes.main, {"from": "login"});
          } else {
            Navigator.of(context).pushNamedAndRemoveUntil(
              Routes.locationPermissionScreen,
                  (route) => false,
            );
          }
        } else {
          await _handleGoogleSignupFromLogin(state);
        }
      }
    } catch (_) {
      await _handleGoogleSignupFromLogin(state);
    }
  }

  Future<void> _handleGoogleSignupFromLogin(AuthenticationSuccess state) async {
    try {
      final user = state.credential.user;
      if (user != null) {
        final payload = {
          "firebase_id": user.uid,
          "name": user.displayName ?? "",
          "email": user.email ?? "",
          "profile": user.photoURL ?? "",
          "type": state.type.name,
          "platform_type": Platform.isAndroid ? "android" : "ios",
        };


        final String? fcmToken = await _resolveFcmToken();
        if (fcmToken != null && fcmToken.isNotEmpty) {
          payload["fcm_id"] = fcmToken;
        }


        final response = await Api.post(url: "user-signup", parameter: payload);

        if (response['error'] == false) {
          HiveUtils.setJWT(response['token']);
          HiveUtils.setUserData(response['data']);
          HiveUtils.setUserIsAuthenticated(true);
          context.read<UserDetailsCubit>().fill(HiveUtils.getUserDetails());

          final userData = response['data'];
          final hasAccountType =
              userData['account_type'] != null && userData['account_type'] != 0;
          final isEmailVerified = userData['email_verified_at'] != null;
          final isVerified = userData['is_verified'] == 1;
          final hasCompleteName =
              (userData['name'] ?? "")
                  .toString()
                  .isNotEmpty;

          if (hasAccountType && (isEmailVerified || isVerified) &&
              hasCompleteName) {
            if ((HiveUtils.getCityName() ?? "").isNotEmpty &&
                HiveUtils.getCityName() != "null") {
              HelperUtils.killPreviousPages(
                  context, Routes.main, {"from": "login"});
            } else {
              Navigator.of(context).pushNamedAndRemoveUntil(
                Routes.locationPermissionScreen,
                    (route) => false,
              );
            }
          } else {
            Navigator.pushReplacementNamed(
              context,
              Routes.signupMainScreen,
              arguments: {
                'isFromGoogleLogin': true,
                'googleData': {
                  'name': user.displayName ?? "",
                  'email': user.email ?? "",
                  'profile': user.photoURL ?? "",
                  'firebase_id': user.uid,
                },
              },
            );
          }
        } else {
          HelperUtils.showSnackBarMessage(
            context,
            response['message'] ?? "registrationError".translate(context),
          );
        }
      }
    } catch (e) {
      HelperUtils.showSnackBarMessage(context, e.toString());
    }
  }

  void _setDemoOTP() {
    if (Constant.mobileAuthentication == "1" &&
        emailMobileTextController.text == Constant.demoMobileNumber) {
      otp = Constant.demoModeOTP;
    } else {
      // otp = "";
    }
  }

  @override
  Widget build(BuildContext context) {
    size = MediaQuery
        .of(context)
        .size;
    _setDemoOTP();

    return LoginHeaderSection(
      isBack: isBack,
      isOtpSent: isOtpSent,
      sendMailClicked: sendMailClicked,
      isDeleteAccount: widget.isDeleteAccount ?? false,
      onResetOTP: () {
        setState(() {
          isOtpSent = false;
          isMobileNumberField = true;
        });
      },
      onBack: () {
        setState(() {
          sendMailClicked = false;
        });
      },
      updateBackState: (v) => setState(() => isBack = v),

      // محتوى الشاشة (واجهة صافية + منطق BLoC)
      child: LoginScreenFrame(
        child: BlocListener<LoginCubit, LoginState>(
          listener: (context, state) {
            // إيقاف التحميل عند انتهاء أي عملية


            // نجاح تسجيل الدخول (OAuth / Phone-Email)
            if (state is LoginSuccess ||
                state is LoginSuccessWithoutCredential) {
              final api = (state as dynamic).apiResponse;
              final isEmailVerified = api['email_verified_at'] != null;
              final isVerified = api['is_verified'] == 1;
              final hasAccountType =
                  api['account_type'] != null && api['account_type'] != 0;

              if ((isEmailVerified || isVerified) && hasAccountType) {
                HiveUtils.setUserIsAuthenticated(true);
                HiveUtils.setUserData(api);
                context.read<UserDetailsCubit>().fill(
                    HiveUtils.getUserDetails());

                final city = HiveUtils.getCityName();
                if ((city ?? "").isNotEmpty && city != "null") {
                  HelperUtils.killPreviousPages(
                      context, Routes.main, {"from": "login"});
                } else {
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    Routes.locationPermissionScreen,
                        (route) => false,
                  );
                }
                return;
              }

              // غير مُحقق → أرسل لواجهة OTP
              if (!isEmailVerified && !isVerified) {
                Navigator.pushReplacementNamed(
                  context,
                  Routes.otp,
                  arguments: {
                    'phoneNumber': api['mobile']?.replaceFirst(
                        '+$countryCode', '') ?? '',
                    'countryCode': countryCode,
                    'selectedAccountType': api['account_type']?.toString() ??
                        "1",
                  },
                );
                return;
              }
            }

            // فشل
            if (state is LoginFailure) {
              HelperUtils.showSnackBarMessage(
                context,
                state.errorMessage.toString(),
              );
            }
          },
          child: BlocConsumer<AuthenticationCubit, AuthenticationState>(
            buildWhen: (previous, current) =>
            current is! AuthenticationInProcess &&
                current is! AuthenticationFail,
            listener: (context, state) async {


              if (state is AuthenticationSuccess) {
                Widgets.hideLoder(context);

                // تسجيل خارجي
                if (state.type == AuthenticationType.google ||
                    state.type == AuthenticationType.apple) {
                  await _handleSocialLoginFromLogin(state);
                  return;
                }

                // إيميل/كلمة مرور
                if (state.type == AuthenticationType.email) {
                  if (state.credential.user?.emailVerified == true) {
                    context.read<LoginCubit>().login(
                      phoneNumber: state.credential.user!.phoneNumber,
                      firebaseUserId: state.credential.user!.uid,
                      type: state.type.name,
                      credential: state.credential,
                      countryCode: null,
                    );
                  }
                }
                // هاتف
                else if (state.type == AuthenticationType.phone) {
                  context.read<LoginCubit>().login(
                    phoneNumber: (state.payload as PhoneLoginPayload)
                        .phoneNumber,
                    firebaseUserId: state.credential.user!.uid,
                    type: state.type.name,
                    credential: state.credential,
                    countryCode:
                    "+${(state.payload as PhoneLoginPayload).countryCode}",
                  );
                }
                // أنواع أخرى
                else {
                  context.read<LoginCubit>().login(
                    phoneNumber: state.credential.user!.phoneNumber,
                    firebaseUserId: state.credential.user!.uid,
                    type: state.type.name,
                    credential: state.credential,
                    countryCode: null,
                  );
                }
              }

              if (state is AuthenticationFail) {
                Widgets.hideLoder(context);
              }

              if (state is AuthenticationInProcess) {
                Widgets.showLoader(context);
              }
            },
            builder: (context, state) {
              final isAuthLoading = state is AuthenticationInProcess;

              return BlocSelector<LoginCubit, LoginState, bool>(
                selector: (loginState) => loginState is LoginInProgress,
                builder: (context, isLoginLoading) {
                  final isLoading = isAuthLoading || isLoginLoading;

                  return Form(
                    key: _formKey,
                    child: LoginScreenUI(
                  // حالة العرض
                  isOtpSent: isOtpSent,
                  sendMailClicked: sendMailClicked,
                  isMobileNumberField: isMobileNumberField,
                  isLoading: isLoading,
                  isObscure: isObscure,

                  // نصوص وأخطاء
                  phoneEmailError: phoneEmailError,
                  passwordError: passwordError,

                  // الكونترولرز
                  emailController: emailMobileTextController,
                  passwordController: _passwordController,

                  // بلد/رمز
                  countryCode: countryCode,
                  flagEmoji: flagEmoji,

                  // OTP
                  phoneLoginPayload: phoneLoginPayload,
                  currentOtp: otp,
                  onOtpChanged: _onOtpChanged,

                  // أزرار وإجراءات
                  onSkip: _onSkip,
                  onShowCountryPicker: _onShowCountryCode,
                  onToggleObscure: _onToggleObscure,
                  onForgotPassword: _onForgotPassword,
                  onChangeLoginMode: _onChangeLoginMode,
                  onResendOtp: _onResendOtp,
                  onVerifyOtp: _onVerifyOtp,
                  onSubmitCredentials: _onSubmitCredentials,
                  onGoogleLogin: _onGoogleLogin,
                  onAppleLogin: _onAppleLogin,

                  // تغيّر الإدخال
                  onChangedNumberOrEmail: _onChangedInput,

                  // المتطلبات/التفعيل
                  showMobileAuth: Constant.mobileAuthentication == "1",
                  showEmailAuth: Constant.emailAuthentication == "1",
                  showGoogle: Constant.googleAuthentication == "1",
                  showApple: Constant.appleAuthentication == "1" &&
                      Platform.isIOS,

                  // متابعة (تحويل إلى كلمة مرور الإيميل أو إرسال OTP للهاتف)
                  onTapContinue: () {
                    sendMailClicked = true;
                    if (isMobileNumberField) {
                      sendMailClicked = false;
                      _onContinueTap();
                    } else {
                      setState(() {}); // إظهار نموذج كلمة المرور للإيميل
                    }
                  },

                  // إنشاء حساب (تنقّل فعلي)
                  onGoToSignup: () {
                    Navigator.pushNamed(context, Routes.signupMainScreen);
                  },
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}