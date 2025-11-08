// ================================
// File: lib/ui/screens/auth/signup/sign_up_main_screen.dart
// Purpose: Logic/State holder. Delegates all UI to SignUpMainUI in sign_up_main_ui.dart
// ================================

import 'dart:async';
import 'dart:io';

import 'package:country_picker/country_picker.dart';
import 'package:device_region/device_region.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

import 'package:marib/app/routes.dart';
import 'package:marib/data/cubits/auth/authentication_cubit.dart';
import 'package:marib/data/cubits/system/fetch_system_settings_cubit.dart';
import 'package:marib/data/cubits/system/user_details.dart';
import 'package:marib/data/helper/widgets.dart';
import 'package:marib/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/api.dart';
import 'package:marib/utils/constant.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/hive_utils.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:marib/utils/login/lib/login_status.dart';
import 'package:marib/utils/login/lib/payloads.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:marib/ui/screens/auth/sign_up/sign_up_main_ui.dart'; // ✅

import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:marib/utils/notification/notification_service.dart';

import '../widgets/auth_status_bar.dart';

class SignUpMainScreen extends StatefulWidget {
  final Map<String, dynamic>? arguments;

  const SignUpMainScreen({super.key, this.arguments});

  @override
  State<SignUpMainScreen> createState() => LoginScreenState();

  static Route route(RouteSettings routeSettings) {
    final args = routeSettings.arguments as Map<String, dynamic>?;
    return BlurredRouter(builder: (_) => SignUpMainScreen(arguments: args));
  }
}

const bool _kSkipPhoneVerification = true;

class LoginScreenState extends State<SignUpMainScreen> {
  static const Map<String, String> _accountTypeDetailKeys = {
    '1': 'chooseaccountAlertcontent1',
    '2': 'chooseaccountAlertcontent2',
    '3': 'chooseaccountAlertcontent3',
  };
  static const String _accountTypeDetailFallbackKey =
      'chooseaccountAlertcontentDefault';

  // ===== Controllers =====
  final TextEditingController mobileCtrl = TextEditingController();
  final TextEditingController emailCtrl = TextEditingController();
  final TextEditingController usernameCtrl = TextEditingController();
  final TextEditingController codeCtrl = TextEditingController();
  final TextEditingController passwordCtrl = TextEditingController();

  // ===== Form / State =====
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  bool isObscure = true;
  bool agreed = false;
  String? selectedAccountType; // 1=individual,2=realEstate,3=commercial

  // ===== Country / Phone =====
  String? phone;
  String? countryCode;
  String? countryName;
  String? flagEmoji;

  Timer? timer;
  late Size size;
  final CountryService countryCodeService = CountryService();

  // ===== Flow flags =====
  bool isBack = false;
  bool isFromGoogleLogin = false;
  Map<String, dynamic>? googleData;
  StreamSubscription<AuthenticationState>? _authenticationSubscription;
  VoidCallback? _loginStateListenerDisposer;

  late final Future<void> _bootstrapFuture;
  Future<void> _bootstrapSignUpFlow() async {
    final authCubit = context.read<AuthenticationCubit>();
    authCubit.init();

    _authenticationSubscription = authCubit.stream.listen((state) {
      if (!mounted) return;
      if (state is AuthenticationSuccess) {
        if (state.type == AuthenticationType.google ||
            state.type == AuthenticationType.apple) {
          _handleSocialLogin(state);
        }
      } else if (state is AuthenticationFail) {
        Widgets.hideLoder(context);
        HelperUtils.showSnackBarMessage(context, state.error.toString());
      } else if (state is AuthenticationInProcess) {
        Widgets.showLoader(context);
      }
    });

    _loginStateListenerDisposer?.call();
    _loginStateListenerDisposer = authCubit.listen((MLoginState state) {
      if (!mounted) return;
      if (state is MOtpSendInProgress) Widgets.showLoader(context);
      if (state is MVerificationPending) {
        Widgets.hideLoder(context);
        setState(() {});
      }
      if (state is MFail) {
        if (state.error is firebase_auth.FirebaseAuthException) {
          try {
            HelperUtils.showSnackBarMessage(
              context,
              (state.error as firebase_auth.FirebaseAuthException)
                  .message
                  .toString(),
            );
          } catch (_) {}
        } else {
          HelperUtils.showSnackBarMessage(context, state.error.toString());
        }
      }
    });

    try {
      final country = await getSimCountry();
      if (!mounted) return;

      setState(() {
        countryCode = country.phoneCode;
        flagEmoji = country.flagEmoji;
      });
    } catch (_) {}
  }

  Future<void> _showAccountTypeDetailsSheet(String? type) async {
    if (!mounted || type == null || type.isEmpty) return;

    final contentKey =
        _accountTypeDetailKeys[type] ?? _accountTypeDetailFallbackKey;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            16 + MediaQuery.of(ctx).viewPadding.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.color.textLightColor.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "chooseaccountAlertTitle".translate(context),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.6,
                ),
                child: SingleChildScrollView(
                  child: Text(
                    contentKey.translate(ctx),
                    style: TextStyle(
                      fontSize: context.font.small,
                      color: context.color.textDefaultColor,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              UiUtils.buildButton(
                ctx,
                onPressed: () => Navigator.of(ctx).pop(),
                buttonTitle: 'ok'.translate(context),
                radius: 12,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    // Pull Google/Apple args if any
    if (widget.arguments != null) {
      isFromGoogleLogin = widget.arguments!['isFromGoogleLogin'] ?? false;
      googleData = widget.arguments!['googleData'];

      if (isFromGoogleLogin && googleData != null) {
        usernameCtrl.text = googleData!['name'] ?? '';
        emailCtrl.text = googleData!['email'] ?? '';
      }
    }

    _bootstrapFuture = _bootstrapSignUpFlow();
  }

  @override
  void dispose() {
    _loginStateListenerDisposer?.call();
    _loginStateListenerDisposer = null;
    timer?.cancel();
    _authenticationSubscription?.cancel();
    _authenticationSubscription = null;
    mobileCtrl.dispose();
    codeCtrl.dispose();
    emailCtrl.dispose();
    usernameCtrl.dispose();
    passwordCtrl.dispose();
    super.dispose();
  }

  /// Obtain SIM country; respects demo flags
  Future<Country> getSimCountry() async {
    final countryList = countryCodeService.getAll();
    String? simCountryCode;

    try {
      simCountryCode = await DeviceRegion.getSIMCountryCode();
    } catch (_) {}

    Country simCountry = countryList.firstWhere(
      (element) {
        if (Constant.isDemoModeOn) {
          return countryList.any(
            (e) => e.phoneCode == Constant.defaultCountryCode,
          );
        } else {
          return element.phoneCode == simCountryCode;
        }
      },
      orElse: () {
        return countryList
            .where((e) => e.phoneCode == Constant.defaultCountryCode)
            .first;
      },
    );

    if (Constant.isDemoModeOn) {
      simCountry = countryList
          .where((e) => e.phoneCode == Constant.demoCountryCode)
          .first;
    }

    return simCountry;
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

  // ====== Social login handler: send to backend, route appropriately ======
  Future<void> _handleSocialLogin(AuthenticationSuccess state) async {
    try {
      final user = state.credential.user;
      if (user == null) return;

      final payload = {
        "firebase_id": user.uid,
        "name": user.displayName ?? "",
        "email": user.email ?? "",
        "profile": user.photoURL ?? "",
        "type": state.type.name,
        "platform_type": Platform.isAndroid ? "android" : "ios",
      };

      debugPrint(
        '[SignUpMainScreen] Sending user-signup payload (sanitised) -> '
        'account_type: ${payload['account_type']} | '
        'mobile: ${payload['mobile']} | '
        'email: ${payload['email']} | '
        'code_present: ${payload.containsKey('code')}',
      );

      if (selectedAccountType == "3") {
        Widgets.hideLoder(context);
        HelperUtils.showSnackBarMessage(
          context,
          'أكمل خطوات المتجر لإرسال طلب التسجيل.',
          messageDuration: 3,
          type: MessageType.warning,
        );
        Navigator.pushNamed(
          context,
          Routes.merchantOnboarding,
          arguments: {
            'signupDraft': payload,
          },
        );
        return;
      }

      final response = await Api.post(url: "user-signup", parameter: payload);
      debugPrint(
        '[SignUpMainScreen] user-signup response => error: ${response['error']}',
      );

      if (response['error'] == false) {
        HiveUtils.setJWT(response['token']);
        HiveUtils.setUserData(response['data']);

        final userData = response['data'];
        final bool hasAccountType =
            userData['account_type'] != null && userData['account_type'] != 0;
        final bool isEmailVerified = userData['email_verified_at'] != null;
        final bool hasCompleteName =
            userData['name'] != null && userData['name'].toString().isNotEmpty;

        final bool shouldAuthenticate =
            hasAccountType && isEmailVerified && hasCompleteName;

        if (shouldAuthenticate) {
          HiveUtils.setUserIsAuthenticated(true);
          await NotificationService.resendPendingTokenIfNeeded();
        }

        context.read<UserDetailsCubit>().fill(HiveUtils.getUserDetails());
        FetchSystemSettingsCubit.refreshPermissionsForCurrentUser(
          context,
          clearCacheBeforeFetch: true,
        );

        if (shouldAuthenticate) {
          if ((HiveUtils.getCityName() ?? '').isNotEmpty &&
              HiveUtils.getCityName() != 'null') {
            HelperUtils.killPreviousPages(
                context, Routes.main, {"from": "login"});
          } else {
            Navigator.of(context).pushNamedAndRemoveUntil(
                Routes.locationPermissionScreen, (route) => false);
          }
        } else {
          final Map<String, dynamic> incomingGoogleData = {
            'name': user.displayName ?? '',
            'email': user.email ?? '',
            'profile': user.photoURL ?? '',
            'firebase_id': user.uid,
          };

          if (!mounted) return;
          setState(() {
            isFromGoogleLogin = true;
            googleData = incomingGoogleData;
            usernameCtrl.text = incomingGoogleData['name'] ?? '';
            emailCtrl.text = incomingGoogleData['email'] ?? '';
          });
        }
      } else {
        HelperUtils.showSnackBarMessage(context,
            response['message'] ?? "registrationError".translate(context));
      }
    } catch (e) {
      HelperUtils.showSnackBarMessage(context, e.toString());
    } finally {
      Widgets.hideLoder(context);
    }
  }

  // ===== UI callbacks =====
  void onToggleObscure() => setState(() => isObscure = !isObscure);

  void onAgreeChanged(bool v) => setState(() => agreed = v);

  void onAccountTypeChanged(String? v) =>
      setState(() => selectedAccountType = v);

  void onShowCountryPicker() {
    showCountryPicker(
      context: context,
      showWorldWide: true,
      showPhoneCode: true,
      countryListTheme:
          CountryListThemeData(borderRadius: BorderRadius.circular(11)),
      onSelect: (Country value) {
        flagEmoji = value.flagEmoji;
        if (!mounted) return;
        countryCode = value.phoneCode;
        setState(() {});
      },
    );
  }

  Future<Map<String, dynamic>?> _prepareLocationPayload() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        HelperUtils.showSnackBarMessage(
          context,
          'locationServicesDisabledMarib'.translate(context),
          messageDuration: 3,
          type: MessageType.warning,
        );
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        HelperUtils.showSnackBarMessage(
          context,
          'locationPermissionDeniedMarib'.translate(context),
          messageDuration: 3,
          type: MessageType.warning,
        );
        return null;
      }

      if (permission == LocationPermission.deniedForever) {
        HelperUtils.showSnackBarMessage(
          context,
          'locationPermissionDeniedForeverMarib'.translate(context),
          messageDuration: 3,
          type: MessageType.warning,
        );
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      String? adminArea;
      Map<String, dynamic>? meta;

      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (placemarks.isNotEmpty) {
          final placemark = placemarks.first;
          adminArea = placemark.administrativeArea ?? placemark.locality;
          final possibleMeta = <String, dynamic>{
            'administrativeArea': placemark.administrativeArea,
            'locality': placemark.locality,
            'country': placemark.country,
            'isoCountryCode': placemark.isoCountryCode,
            'street': placemark.street,
          };
          possibleMeta.removeWhere(
            (key, value) =>
                value == null || (value is String && value.trim().isEmpty),
          );
          if (possibleMeta.isNotEmpty) {
            meta = possibleMeta;
          }
        }
      } catch (_) {}

      final payload = <String, dynamic>{
        'lat': position.latitude,
        'lng': position.longitude,
        'device_time': DateTime.now().toIso8601String(),
      };

      if (adminArea != null && adminArea.trim().isNotEmpty) {
        payload['admin_area'] = adminArea;
      }

      if (meta != null && meta.isNotEmpty) {
        payload['meta'] = meta;
      }

      return payload;
    } catch (_) {
      HelperUtils.showSnackBarMessage(
        context,
        'errorGettingLocationMarib'.translate(context),
        messageDuration: 3,
        type: MessageType.warning,
      );
      return null;
    }
  }

  // Submit action for primary button
  Future<void> onSubmit() async {
    final form = formKey.currentState;
    if (form == null) return;
    form.save();

    if (!form.validate()) return;

    if (!agreed) {
      HelperUtils.showSnackBarMessage(
        context,
        'mustAgreeToTermsAndPrivacy'.translate(context),
        messageDuration: 3,
        type: MessageType.warning,
      );
      return;
    }
    if (selectedAccountType == null || selectedAccountType!.isEmpty) {
      HelperUtils.showSnackBarMessage(
        context,
        'mustSelectAccountType'.translate(context),
        messageDuration: 3,
        type: MessageType.warning,
      );
      return;
    }

    Widgets.showLoader(context);

    Map<String, dynamic>? locationPayload;
    final String referralCode = codeCtrl.text.trim();

    if (referralCode.isNotEmpty) {
      locationPayload = await _prepareLocationPayload();
      if (locationPayload == null) {
        Widgets.hideLoder(context);
        return;
      }
    }

    try {
      final basePayload = <String, dynamic>{
        "name": usernameCtrl.text,
        "mobile": mobileCtrl.text,
        "password": passwordCtrl.text,
        "account_type": selectedAccountType ?? "1",
        "email": emailCtrl.text,
        "country_code": countryCode?.toString() ?? "",
        "country_name": countryName ?? "Unknown",
        "flag_emoji": flagEmoji ?? "ye",
        "platform_type": Platform.isAndroid ? "android" : "ios",
        ...?locationPayload,
      };

      if (referralCode.isNotEmpty) {
        basePayload["code"] = referralCode;
      }

      Map<String, dynamic> payload;

      if (isFromGoogleLogin && googleData != null) {
        // Complete profile for social login
        payload = {
          ...basePayload,
          "type": "google",
          "firebase_id": googleData!['firebase_id'],
          "profile": googleData!['profile'] ?? "",
        };
      } else {
        // Phone signup path
        String firebaseId;
        final currentUser = firebase_auth.FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          firebaseId = currentUser.uid;
        } else {
          firebaseId =
              "user_${countryCode}${mobileCtrl.text}"; // temporary fallback
        }

        payload = {
          ...basePayload,
          "type": "phone",
          "firebase_id": firebaseId,
        };
      }

      final response = await Api.post(url: "user-signup", parameter: payload);

      if (response['error'] == false) {
        HiveUtils.setJWT(response['token']);
        HiveUtils.setUserData(response['data']);
        HiveUtils.setUserIsAuthenticated(true);
        unawaited(NotificationService.resendPendingTokenIfNeeded());

        context.read<UserDetailsCubit>().fill(HiveUtils.getUserDetails());
        FetchSystemSettingsCubit.refreshPermissionsForCurrentUser(
          context,
          clearCacheBeforeFetch: true,
        );
        Widgets.hideLoder(context);
        if (!mounted) return;

        if (_kSkipPhoneVerification) {
          final bool isCommercialAccount = selectedAccountType == "3";
          if (!isCommercialAccount) {
            HelperUtils.showSnackBarMessage(
              context,
              'تم إنشاء الحساب وسيتم تفعيل التحقق لاحقاً.',
              messageDuration: 3,
              type: MessageType.success,
            );
          }
          await _completeSignupFlowWithoutOtp();
        } else {
          Navigator.pushNamed(
            context,
            Routes.otp,
            arguments: {
              'selectedAccountType': selectedAccountType,
              'phoneNumber': mobileCtrl.text,
              'countryCode': countryCode,
              'username': usernameCtrl.text,
              'password': passwordCtrl.text,
              'isFromGoogleLogin': isFromGoogleLogin,
              'googleData': googleData,
            },
          );
        }
      } else {
        HelperUtils.showSnackBarMessage(
          context,
          response['message'] ?? "registrationError".translate(context),
          messageDuration: 3,
        );
      }
    } catch (e) {
      String message = "registrationError".translate(context);
      if (e is ApiHttpException) {
        final dynamic payload = e.payload;
        if (payload is Map<String, dynamic>) {
          final dynamic serverMessage = payload['message'];
          if (serverMessage is String && serverMessage.trim().isNotEmpty) {
            message = serverMessage.trim();
          }
        } else if (payload is String && payload.trim().isNotEmpty) {
          message = payload.trim();
        }
      } else if (e is ApiException) {
        message = e.toString();
      } else {
        message = e.toString();
      }

      HelperUtils.showSnackBarMessage(
        context,
        message,
        messageDuration: 3,
      );
    } finally {
      Widgets.hideLoder(context);
    }
  }

  Future<void> _completeSignupFlowWithoutOtp() async {
    if (!mounted) return;

    try {
      final userDetails = HiveUtils.getUserDetails();
      if (userDetails != null) {
        userDetails.isVerified = 1;
        HiveUtils.setUserData(userDetails.toJson());
      }

      if (selectedAccountType == "3") {
        Navigator.pushNamed(context, Routes.merchantOnboarding);
        return;
      }

      if (selectedAccountType == "2") {
        Navigator.pushNamed(
          context,
          Routes.signup,
          arguments: {
            'selectedAccountType': selectedAccountType,
            'phoneNumber': mobileCtrl.text,
            'countryCode': countryCode,
          },
        );
        return;
      }

      HiveUtils.setUserIsAuthenticated(true);
      await NotificationService.resendPendingTokenIfNeeded();
      FetchSystemSettingsCubit.refreshPermissionsForCurrentUser(
        context,
        clearCacheBeforeFetch: true,
      );

      final String? cityName = HiveUtils.getCityName();
      if (cityName != null &&
          cityName.isNotEmpty &&
          cityName.toLowerCase() != 'null') {
        HelperUtils.killPreviousPages(
          context,
          Routes.main,
          {"from": "signup"},
        );
      } else {
        Navigator.of(context).pushNamedAndRemoveUntil(
          Routes.locationPermissionScreen,
          (route) => false,
        );
      }
    } catch (_) {
      HelperUtils.killPreviousPages(
        context,
        Routes.main,
        {"from": "signup"},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusBarBase = LoginStatusBar.resolveBaseColor(context);

    // واجهة الشاشة
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: LoginStatusBar.overlayFor(
        context,
        baseColor: statusBarBase,
      ),
      child: SafeArea(
        top: false,
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          // إخفاء الكيبورد عند الضغط خارج الحقول
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
            child: AnnotatedRegion<SystemUiOverlayStyle>(
              value: LoginStatusBar.overlayFor(
                context,
                baseColor: statusBarBase,
              ),
              child: FutureBuilder<void>(
                future: _bootstrapFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const _SignUpLoadingPlaceholder();
                  }

                  size = MediaQuery.of(context).size;

                  final settingsState =
                      context.watch<FetchSystemSettingsCubit>().state;
                  final bool isSettingsReady =
                      settingsState is FetchSystemSettingsSuccess;
                  final bool isSettingsLoading =
                      settingsState is FetchSystemSettingsInProgress;

                  final vm = SignUpVM(
                    formKey: formKey,
                    mobileCtrl: mobileCtrl,
                    emailCtrl: emailCtrl,
                    usernameCtrl: usernameCtrl,
                    codeCtrl: codeCtrl,
                    passwordCtrl: passwordCtrl,
                    countryCode: countryCode,
                    countryName: countryName,
                    flagEmoji: flagEmoji,
                    isFromGoogleLogin: isFromGoogleLogin,
                    googleData: googleData,
                    isObscure: isObscure,
                    agreed: agreed,
                    selectedAccountType: selectedAccountType,
                    isSystemSettingsReady: isSettingsReady,
                    isSystemSettingsLoading: isSettingsLoading,
                  );

                  final callbacks = SignUpCallbacks(
                    onToggleObscure: onToggleObscure,
                    onAgreeChanged: onAgreeChanged,
                    onAccountTypeChanged: (v) async {
                      onAccountTypeChanged(v);
                      await _showAccountTypeDetailsSheet(v);
                    },
                    onShowCountryPicker: onShowCountryPicker,
                    onSubmit: onSubmit,
                    onNavigateToLogin: () =>
                        Navigator.pushNamed(context, Routes.login),
                    onOpenStaticContent: (
                        {required String title, required String param}) {
                      return _openStaticContent(title: title, param: param);
                    },
                    onGoogleAuth: () {
                      context.read<AuthenticationCubit>().setData(
                            payload: GoogleLoginPayload(),
                            type: AuthenticationType.google,
                          );
                      context.read<AuthenticationCubit>().authenticate();
                    },
                    onAppleAuth: () {
                      context.read<AuthenticationCubit>().setData(
                            payload: AppleLoginPayload(),
                            type: AuthenticationType.apple,
                          );
                      context.read<AuthenticationCubit>().authenticate();
                    },
                  );

                  return Scaffold(
                    backgroundColor: context.color.backgroundColor,
                    body: SignUpMainUI(
                      vm: vm,
                      callbacks: callbacks,
                      statusBarBase: statusBarBase,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SignUpLoadingPlaceholder extends StatelessWidget {
  const _SignUpLoadingPlaceholder();

  @override
  Widget build(BuildContext context) {
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
      child: const Center(
        child: SizedBox(
          width: 36,
          height: 36,
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }
}
