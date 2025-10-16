import 'dart:async';
import 'dart:io';

import 'package:country_picker/country_picker.dart';
import 'package:device_region/device_region.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import 'package:marib/app/routes.dart';
import 'package:marib/data/cubits/auth/authentication_cubit.dart';
import 'package:marib/data/cubits/system/fetch_system_settings_cubit.dart';
import 'package:marib/data/cubits/system/user_details.dart';
import 'package:marib/data/helper/widgets.dart';
import 'package:marib/ui/screens/auth/sign_up/sign_up_main_ui.dart';
import 'package:marib/ui/screens/widgets/blurred_dialoge_box.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/api.dart';
import 'package:marib/utils/constant.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/hive_utils.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:marib/utils/login/lib/login_status.dart';
import 'package:marib/utils/login/lib/payloads.dart';
import 'package:marib/utils/ui_utils.dart';

class SignupFlowScreen extends StatefulWidget {
  final Map<String, dynamic>? arguments;

  const SignupFlowScreen({super.key, this.arguments});

  @override
  SignupFlowState createState() => SignupFlowState();
}

class SignupFlowState extends State<SignupFlowScreen> {
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
  String? countryCode;
  String? countryName;
  String? flagEmoji;

  bool isBack = false;
  bool isFromGoogleLogin = false;
  Map<String, dynamic>? googleData;

  final CountryService _countryCodeService = CountryService();
  StreamSubscription<AuthenticationState>? _authenticationSubscription;
  VoidCallback? _loginStateListenerDisposer;

  @override
  void initState() {
    super.initState();

    _prefillFromArguments(widget.arguments);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scheduleLazyInit();
    });
  }

  @override
  void dispose() {
    _disposeAuthenticationListeners();
    mobileCtrl.dispose();
    codeCtrl.dispose();
    emailCtrl.dispose();
    usernameCtrl.dispose();
    passwordCtrl.dispose();
    super.dispose();
  }

  void _prefillFromArguments(Map<String, dynamic>? arguments) {
    if (arguments == null) {
      return;
    }

    isFromGoogleLogin = arguments['isFromGoogleLogin'] ?? false;
    googleData = arguments['googleData'];

    if (isFromGoogleLogin && googleData != null) {
      usernameCtrl.text = googleData!['name'] ?? '';
      emailCtrl.text = googleData!['email'] ?? '';
    }
  }

  void _scheduleLazyInit() {
    final authCubit = context.read<AuthenticationCubit>();
    authCubit.init();

    _attachAuthenticationListeners(authCubit);
    _prefillCountryFromSim();
  }

  void _attachAuthenticationListeners(AuthenticationCubit authCubit) {
    _authenticationSubscription?.cancel();
    _authenticationSubscription =
        authCubit.stream.listen(_onAuthenticationStateChanged);

    _loginStateListenerDisposer?.call();
    _loginStateListenerDisposer = authCubit.listen(_onLoginStateChanged);
  }

  void _disposeAuthenticationListeners() {
    _loginStateListenerDisposer?.call();
    _loginStateListenerDisposer = null;
    _authenticationSubscription?.cancel();
    _authenticationSubscription = null;
  }

  void _onAuthenticationStateChanged(AuthenticationState state) {
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
  }

  void _onLoginStateChanged(MLoginState state) {
    if (!mounted) return;

    if (state is MOtpSendInProgress) {
      Widgets.showLoader(context);
    }

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
  }

  void _prefillCountryFromSim() {
    _getSimCountry().then((value) {
      if (!mounted) return;

      countryCode = value.phoneCode;
      flagEmoji = value.flagEmoji;
      countryName = value.name;
      setState(() {});
    });
  }

  Future<Country> _getSimCountry() async {
    final countryList = _countryCodeService.getAll();
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

      final response = await Api.post(url: "user-signup", parameter: payload);

      if (response['error'] == false) {
        HiveUtils.setJWT(response['token']);
        HiveUtils.setUserData(response['data']);

        final userData = response['data'];
        final bool hasAccountType =
            userData['account_type'] != null && userData['account_type'] != 0;
        final bool isEmailVerified = userData['email_verified_at'] != null;
        final bool hasCompleteName =
            userData['name'] != null &&
                userData['name'].toString().isNotEmpty;

        context.read<UserDetailsCubit>().fill(HiveUtils.getUserDetails());

        if (hasAccountType && isEmailVerified && hasCompleteName) {
          HiveUtils.setUserIsAuthenticated(true);
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
        HelperUtils.showSnackBarMessage(
          context,
          response['message'] ?? "registrationError".translate(context),
        );
      }
    } catch (e) {
      HelperUtils.showSnackBarMessage(context, e.toString());
    } finally {
      Widgets.hideLoder(context);
    }
  }

  void _toggleObscure() => setState(() => isObscure = !isObscure);

  void _updateAgreement(bool value) => setState(() => agreed = value);

  Future<void> _handleAccountTypeChange(String? value) async {
    setState(() => selectedAccountType = value);

    await UiUtils.showBlurredDialoge(
      context,
      dialoge: BlurredDialogBox(
        showCancleButton: false,
        title: "chooseaccountAlertTitle".translate(context),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          child: SingleChildScrollView(
            child: Text(
              "chooseaccountAlertcontent ${value ?? ''}".translate(context),
              style: TextStyle(
                fontSize: context.font.small,
                color: context.color.textDefaultColor,
                height: 1.5,
              ),
            ),
          ),
        ),
        acceptButtonName: 'ok'.translate(context),
        isAcceptContainesPush: true,
        onAccept: () async {
          Navigator.of(context).pop();
        },
      ),
    );
  }

  void _showCountryPicker() {
    showCountryPicker(
      context: context,
      showWorldWide: true,
      showPhoneCode: true,
      countryListTheme: CountryListThemeData(
        borderRadius: BorderRadius.circular(11),
      ),
      onSelect: (Country value) {
        flagEmoji = value.flagEmoji;
        countryCode = value.phoneCode;
        countryName = value.name;
        if (!mounted) return;
        setState(() {});
      },
    );
  }

  void _startSocialAuthentication({
    required AuthenticationType type,
    required LoginPayload payload,
  }) {
    final cubit = context.read<AuthenticationCubit>();
    cubit.setData(payload: payload, type: type);
    cubit.authenticate();
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

  Future<void> _submit() async {
    final form = formKey.currentState;
    if (form == null) return;
    form.save();

    if (!form.validate()) return;

    if (codeCtrl.text.trim().isEmpty) {
      HelperUtils.showSnackBarMessage(
        context,
        'Please enter your referral code.',
        messageDuration: 3,
        type: MessageType.warning,
      );
      return;
    }

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

    final locationPayload = await _prepareLocationPayload();
    if (locationPayload == null) {
      Widgets.hideLoder(context);
      return;
    }

    try {
      final basePayload = <String, dynamic>{
        "name": usernameCtrl.text,
        "mobile": mobileCtrl.text,
        "password": passwordCtrl.text,
        "account_type": selectedAccountType ?? "1",
        "code": codeCtrl.text.trim(),
        "email": emailCtrl.text,
        "country_code": countryCode?.toString() ?? "",
        "country_name": countryName ?? "Unknown",
        "flag_emoji": flagEmoji ?? "ye",
        "platform_type": Platform.isAndroid ? "android" : "ios",
        ...locationPayload,
      };

      Map<String, dynamic> payload;

      if (isFromGoogleLogin && googleData != null) {
        payload = {
          ...basePayload,
          "type": "google",
          "firebase_id": googleData!['firebase_id'],
          "profile": googleData!['profile'] ?? "",
        };
      } else {
        String firebaseId;
        final currentUser = firebase_auth.FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          firebaseId = currentUser.uid;
        } else {
          firebaseId = "user_${countryCode}${mobileCtrl.text}";
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

        context.read<UserDetailsCubit>().fill(HiveUtils.getUserDetails());

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
      } else {
        HelperUtils.showSnackBarMessage(
          context,
          response['message'] ?? "registrationError".translate(context),
          messageDuration: 3,
        );
      }
    } catch (e) {
      HelperUtils.showSnackBarMessage(
        context,
        e.toString(),
        messageDuration: 3,
      );
    } finally {
      Widgets.hideLoder(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsState = context.watch<FetchSystemSettingsCubit>().state;
    final bool isSettingsReady = settingsState is FetchSystemSettingsSuccess;
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
      onToggleObscure: _toggleObscure,
      onAgreeChanged: _updateAgreement,
      onAccountTypeChanged: (value) {
        unawaited(_handleAccountTypeChange(value));
      },
      onShowCountryPicker: _showCountryPicker,
      onSubmit: _submit,
      onNavigateToLogin: () => Navigator.pushNamed(context, Routes.login),
      onOpenStaticContent: ({required String title, required String param}) {
        return _openStaticContent(title: title, param: param);
      },
      onGoogleAuth: () => _startSocialAuthentication(
        type: AuthenticationType.google,
        payload: GoogleLoginPayload(),
      ),
      onAppleAuth: () => _startSocialAuthentication(
        type: AuthenticationType.apple,
        payload: AppleLoginPayload(),
      ),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: UiUtils.getSystemUiOverlayStyle(
        context: context,
        statusBarColor: context.color.backgroundColor,
      ),
      child: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: PopScope(
            canPop: isBack,
            onPopInvoked: (didPop) => setState(() => isBack = true),
            child: AnnotatedRegion<SystemUiOverlayStyle>(
              value: SystemUiOverlayStyle.light.copyWith(
                statusBarColor: Colors.transparent,
              ),
              child: Scaffold(
                backgroundColor: context.color.backgroundColor,
                body: SignUpMainUI(
                  vm: vm,
                  callbacks: callbacks,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}