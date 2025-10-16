import 'dart:io';

import 'package:country_picker/country_picker.dart';
import 'package:device_region/device_region.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'package:marib/app/routes.dart';
import 'package:marib/data/cubits/auth/authentication_cubit.dart';
import 'package:marib/data/cubits/auth/login_cubit.dart';
import 'package:marib/data/cubits/system/user_details.dart';
import 'package:marib/ui/screens/auth/login_new/signup_new_page.dart';
import 'package:marib/utils/api.dart';
import 'package:marib/utils/constant.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:marib/utils/hive_utils.dart';
import 'package:marib/utils/login/lib/login_status.dart';
import 'package:marib/utils/login/lib/payloads.dart';

class LoginNewUiState {
  final bool isProcessing;
  final bool showOtpField;
  final bool usingPhoneInput;
  final bool obscurePassword;
  final bool showIdentifierShimmer;
  final String dialCode;
  final String? flagEmoji;
  final String? errorMessage;
  final String? infoMessage;
  final bool canSubmit;
  final bool canRequestOtp;
  final bool enableGoogle;
  final bool enableApple;
  final bool enableEmail;
  final bool enablePhone;

  const LoginNewUiState({
    required this.isProcessing,
    required this.showOtpField,
    required this.usingPhoneInput,
    required this.obscurePassword,
    required this.showIdentifierShimmer,
    required this.dialCode,
    required this.flagEmoji,
    required this.errorMessage,
    required this.infoMessage,
    required this.canSubmit,
    required this.canRequestOtp,
    required this.enableGoogle,
    required this.enableApple,
    required this.enableEmail,
    required this.enablePhone,
  });

  factory LoginNewUiState.initial() {
    return const LoginNewUiState(
      isProcessing: false,
      showOtpField: false,
      usingPhoneInput: true,
      obscurePassword: true,
      showIdentifierShimmer: true,
      dialCode: Constant.defaultCountryCode,
      flagEmoji: null,
      errorMessage: null,
      infoMessage: null,
      canSubmit: false,
      canRequestOtp: false,
      enableGoogle: false,
      enableApple: false,
      enableEmail: false,
      enablePhone: false,
    );
  }

  LoginNewUiState copyWith({
    bool? isProcessing,
    bool? showOtpField,
    bool? usingPhoneInput,
    bool? obscurePassword,
    bool? showIdentifierShimmer,
    String? dialCode,
    String? flagEmoji,
    String? errorMessage,
    String? infoMessage,
    bool? canSubmit,
    bool? canRequestOtp,
    bool? enableGoogle,
    bool? enableApple,
    bool? enableEmail,
    bool? enablePhone,
  }) {
    return LoginNewUiState(
      isProcessing: isProcessing ?? this.isProcessing,
      showOtpField: showOtpField ?? this.showOtpField,
      usingPhoneInput: usingPhoneInput ?? this.usingPhoneInput,
      obscurePassword: obscurePassword ?? this.obscurePassword,
      showIdentifierShimmer:
      showIdentifierShimmer ?? this.showIdentifierShimmer,
      dialCode: dialCode ?? this.dialCode,
      flagEmoji: flagEmoji ?? this.flagEmoji,
      errorMessage: errorMessage ?? this.errorMessage,
      infoMessage: infoMessage ?? this.infoMessage,
      canSubmit: canSubmit ?? this.canSubmit,
      canRequestOtp: canRequestOtp ?? this.canRequestOtp,
      enableGoogle: enableGoogle ?? this.enableGoogle,
      enableApple: enableApple ?? this.enableApple,
      enableEmail: enableEmail ?? this.enableEmail,
      enablePhone: enablePhone ?? this.enablePhone,
    );
  }
}

class LoginNewViewModel extends ValueNotifier<LoginNewUiState> {
  LoginNewViewModel({
    required this.loginCubit,
    required this.authenticationCubit,
    this.userDetailsCubit,
  }) : super(LoginNewUiState.initial());

  final LoginCubit loginCubit;
  final AuthenticationCubit authenticationCubit;
  final UserDetailsCubit? userDetailsCubit;

  final TextEditingController identifierController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController otpController = TextEditingController();

  final FocusNode identifierFocusNode = FocusNode();
  final FocusNode passwordFocusNode = FocusNode();
  final FocusNode otpFocusNode = FocusNode();

  final CountryService _countryService = CountryService();

  VoidCallback? _authFlowListenerDisposer;
  PhoneLoginPayload? _pendingPhonePayload;
  bool _hasInitialized = false;

  void initialize(BuildContext context) {
    if (_hasInitialized) return;
    _hasInitialized = true;

    final enablePhone = Constant.mobileAuthentication == '1';
    final enableEmail = Constant.emailAuthentication == '1';
    final enableGoogle = Constant.googleAuthentication == '1';
    final enableApple = Constant.appleAuthentication == '1' && Platform.isIOS;

    value = value.copyWith(
      enablePhone: enablePhone,
      enableEmail: enableEmail,
      enableGoogle: enableGoogle,
      enableApple: enableApple,
    );

    _attachAuthFlowListener();
    _prefillDemoData();
    _prefillCountryFromSim();
    _updateSubmitAvailability();
    _updateOtpAvailability();
    authenticationCubit.init();
  }

  void _attachAuthFlowListener() {
    _authFlowListenerDisposer?.call();
    _authFlowListenerDisposer = authenticationCubit.listen(_onAuthFlowEvent);
  }

  void _prefillDemoData() {
    if (Constant.isDemoModeOn && value.enablePhone) {
      identifierController.text = Constant.demoMobileNumber;
      passwordController.text = 'password';
      value = value.copyWith(showIdentifierShimmer: false);
    }
  }

  Future<void> _prefillCountryFromSim() async {
    try {
      final allCountries = _countryService.getAll();
      final String? simCountryCode = await DeviceRegion.getSIMCountryCode();
      final Country? country = allCountries.firstWhere(
            (country) =>
        country.countryCode.toUpperCase() ==
            (simCountryCode ?? '').toUpperCase(),
        orElse: () {
          return allCountries.firstWhere(
                (element) => element.phoneCode == Constant.defaultCountryCode,
            orElse: () => allCountries.first,
          );
        },
      );
      value = value.copyWith(
        dialCode: country.phoneCode,
        flagEmoji: country.flagEmoji,
        showIdentifierShimmer: false,
      );
    } catch (_) {
      value = value.copyWith(showIdentifierShimmer: false);
    }
  }

  void onIdentifierChanged(String valueText) {
    final normalized = valueText.trim();
    final isNumeric = RegExp(r'^[0-9]+$').hasMatch(normalized);
    final usingPhone = value.enablePhone && (normalized.isEmpty
        ? value.usingPhoneInput
        : isNumeric);
    value = value.copyWith(
      usingPhoneInput: usingPhone,
      errorMessage: null,
      infoMessage: null,
    );
    _updateSubmitAvailability();
    _updateOtpAvailability();
  }

  void onPasswordChanged(String _) {
    value = value.copyWith(errorMessage: null);
    _updateSubmitAvailability();
  }

  void onOtpChanged(String text) {
    otpController.value = TextEditingValue(text: text);
    _updateSubmitAvailability();
  }

  void toggleIdentifierMode() {
    final bool usePhone = !value.usingPhoneInput && value.enablePhone;
    value = value.copyWith(
      usingPhoneInput: usePhone,
      errorMessage: null,
      infoMessage: null,
    );
    _updateSubmitAvailability();
    _updateOtpAvailability();
  }

  void switchIdentifierMode(bool usePhone) {
    if (usePhone == value.usingPhoneInput) {
      return;
    }
    if (usePhone && !value.enablePhone) {
      return;
    }
    if (!usePhone && !value.enableEmail) {
      return;
    }
    value = value.copyWith(
      usingPhoneInput: usePhone,
      errorMessage: null,
      infoMessage: null,
    );
    _updateSubmitAvailability();
    _updateOtpAvailability();
  }

  void togglePasswordVisibility() {
    value = value.copyWith(obscurePassword: !value.obscurePassword);
  }

  void selectCountry(BuildContext context) {
    showCountryPicker(
      context: context,
      showPhoneCode: true,
      showWorldWide: false,
      countryListTheme: CountryListThemeData(
        bottomSheetHeight: MediaQuery.of(context).size.height * 0.7,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      onSelect: (Country country) {
        value = value.copyWith(
          dialCode: country.phoneCode,
          flagEmoji: country.flagEmoji,
        );
        _updateOtpAvailability();
      },
    );
  }

  void startOtpFlow(BuildContext context) {
    final normalized = identifierController.text.trim();
    if (normalized.isEmpty) {
      value = value.copyWith(
        errorMessage: 'pleaseEnterPhoneNumber'.translate(context),
      );
      return;
    }

    if (!RegExp(r'^[0-9]+$').hasMatch(normalized)) {
      value = value.copyWith(
        errorMessage: 'pleaseEnterValidPhoneNumber'.translate(context),
      );
      return;
    }

    _pendingPhonePayload = PhoneLoginPayload(normalized, value.dialCode);
    value = value.copyWith(
      isProcessing: true,
      errorMessage: null,
      showOtpField: true,
    );
    authenticationCubit.setData(
      payload: _pendingPhonePayload!,
      type: AuthenticationType.phone,
    );
    authenticationCubit.verify();
  }

  void submitPrimary(BuildContext context) {
    if (value.showOtpField) {
      _verifyOtp(context);
      return;
    }

    final identifier = identifierController.text.trim();
    final password = passwordController.text.trim();

    if (identifier.isEmpty) {
      value = value.copyWith(
        errorMessage: value.usingPhoneInput
            ? 'pleaseEnterPhoneNumber'.translate(context)
            : 'pleaseEnterEmail'.translate(context),
      );
      return;
    }
    if (password.isEmpty) {
      value = value.copyWith(
        errorMessage: 'pleaseEnterPassword'.translate(context),
      );
      return;
    }

    value = value.copyWith(
      isProcessing: true,
      errorMessage: null,
      infoMessage: null,
    );

    if (value.usingPhoneInput && value.enablePhone) {
      authenticationCubit.setData(
        payload: PhoneAndPasswordPayload(
          phoneNumber: identifier,
          password: password,
          type: EmailLoginType.login,
        ),
        type: AuthenticationType.phone,
      );
      authenticationCubit.authenticate();
      return;
    }

    if (value.enableEmail) {
      authenticationCubit.setData(
        payload: EmailLoginPayload(
          email: identifier,
          password: password,
          type: EmailLoginType.login,
        ),
        type: AuthenticationType.email,
      );
      authenticationCubit.authenticate();
    }
  }

  void loginWithGoogle() {
    if (!value.enableGoogle) return;
    value = value.copyWith(isProcessing: true, errorMessage: null);
    authenticationCubit.setData(
      payload: GoogleLoginPayload(),
      type: AuthenticationType.google,
    );
    authenticationCubit.authenticate();
  }

  void loginWithApple() {
    if (!value.enableApple) return;
    value = value.copyWith(isProcessing: true, errorMessage: null);
    authenticationCubit.setData(
      payload: AppleLoginPayload(),
      type: AuthenticationType.apple,
    );
    authenticationCubit.authenticate();
  }

  void goToSignup(BuildContext context) {
    Navigator.of(context).push(SignupNewPage.route());
  }

  void handleLoginState(BuildContext context, LoginState state) {
    if (state is LoginInProgress) {
      value = value.copyWith(isProcessing: true, errorMessage: null);
      return;
    }

    value = value.copyWith(isProcessing: false);

    if (state is LoginSuccess || state is LoginSuccessWithoutCredential) {
      final dynamic response = (state as dynamic).apiResponse;
      _handleBackendLoginSuccess(context, response as Map<String, dynamic>);
    } else if (state is LoginFailure) {
      value = value.copyWith(errorMessage: state.errorMessage.toString());
    }
  }

  void handleAuthenticationState(
      BuildContext context, AuthenticationState state) {
    if (state is AuthenticationInProcess) {
      value = value.copyWith(isProcessing: true, errorMessage: null);
      return;
    }

    if (state is AuthenticationFail) {
      value = value.copyWith(
        isProcessing: false,
        errorMessage: state.error.toString(),
      );
      return;
    }

    if (state is AuthenticationSuccessWithoutCredential) {
      value = value.copyWith(isProcessing: false);
      _handlePhonePasswordSuccess(context);
      return;
    }

    if (state is AuthenticationSuccess) {
      value = value.copyWith(isProcessing: false);
      if (state.type == AuthenticationType.google ||
          state.type == AuthenticationType.apple) {
        _handleSocialAuthentication(context, state);
        return;
      }

      if (state.type == AuthenticationType.email) {
        final user = state.credential.user;
        if (user != null && user.emailVerified) {
          loginCubit.login(
            phoneNumber: user.phoneNumber,
            firebaseUserId: user.uid,
            type: state.type.name,
            credential: state.credential,
          );
        } else {
          value = value.copyWith(
            errorMessage: 'pleaseFirstVerifyUser'.translate(context),
          );
        }
        return;
      }

      if (state.type == AuthenticationType.phone) {
        loginCubit.login(
          phoneNumber: (state.payload as PhoneLoginPayload).phoneNumber,
          firebaseUserId: state.credential.user!.uid,
          type: state.type.name,
          credential: state.credential,
          countryCode: '+${(state.payload as PhoneLoginPayload).countryCode}',
        );
      }
    }
  }

  void _onAuthFlowEvent(MLoginState state) {
    if (state is MOtpSendInProgress) {
      value = value.copyWith(isProcessing: true, errorMessage: null);
    } else if (state is MVerificationPending) {
      value = value.copyWith(isProcessing: false, showOtpField: true);
    } else if (state is MFail) {
      value = value.copyWith(
        isProcessing: false,
        errorMessage: state.error.toString(),
      );
    }
  }

  void _verifyOtp(BuildContext context) {
    if (_pendingPhonePayload == null) {
      value = value.copyWith(
        errorMessage: 'Please request the OTP first.',
      );
      return;
    }

    final otp = otpController.text.trim();
    if (otp.length < 6) {
      value = value.copyWith(
        errorMessage: 'pleaseEnterSixDigits'.translate(context),
      );
      return;
    }

    _pendingPhonePayload!.setOTP(otp);
    value = value.copyWith(isProcessing: true, errorMessage: null);
    authenticationCubit.setData(
      payload: _pendingPhonePayload!,
      type: AuthenticationType.phone,
    );
    authenticationCubit.authenticate();
  }

  Future<void> _handleSocialAuthentication(
      BuildContext context,
      AuthenticationSuccess state,
      ) async {
    try {
      final user = state.credential.user;
      if (user == null) {
        value = value.copyWith(
          errorMessage: 'authenticationFailed'.translate(context),
        );
        return;
      }

      final payload = {
        'firebase_id': user.uid,
        'type': state.type.name,
        'platform_type': Platform.isAndroid ? 'android' : 'ios',
      };

      final String? fcmToken = await _resolveFcmToken();
      if (fcmToken != null && fcmToken.isNotEmpty) {
        payload['fcm_id'] = fcmToken;
      }

      final response = await Api.post(
        url: Api.userLoginApi,
        parameter: payload,
      );

      if (response['error'] == false) {
        _handleBackendLoginSuccess(
          context,
          Map<String, dynamic>.from(response['data']),
        );
        return;
      }

      await _handleSocialSignupFallback(context, state, payload);
    } catch (_) {
      await _handleSocialSignupFallback(context, state, {});
    }
  }

  Future<void> _handleSocialSignupFallback(
      BuildContext context,
      AuthenticationSuccess state,
      Map<String, dynamic> payload,
      ) async {
    final user = state.credential.user;
    if (user == null) return;

    final enrichedPayload = {
      ...payload,
      'firebase_id': user.uid,
      'name': user.displayName ?? '',
      'email': user.email ?? '',
      'profile': user.photoURL ?? '',
      'type': state.type.name,
      'platform_type': Platform.isAndroid ? 'android' : 'ios',
    };

    final String? fcmToken = await _resolveFcmToken();
    if (fcmToken != null && fcmToken.isNotEmpty) {
      enrichedPayload['fcm_id'] = fcmToken;
    }

    final response = await Api.post(
      url: Api.loginApi,
      parameter: enrichedPayload,
    );

    if (response['error'] == false) {
      _handleBackendLoginSuccess(
        context,
        Map<String, dynamic>.from(response['data']),
      );
    } else {
      value = value.copyWith(
        errorMessage: response['message']?.toString() ??
            'authenticationFailed'.translate(context),
      );
    }
  }

  Future<String?> _resolveFcmToken() async {
    final candidates = <String?>[
      HiveUtils.getUserDetails().fcmId,
      HiveUtils.getUserDetail<String>(key: Api.fcmId),
    ];

    for (final candidate in candidates) {
      final normalized = (candidate ?? '').trim();
      if (normalized.isNotEmpty) {
        return normalized;
      }
    }

    try {
      final fetched = await FirebaseMessaging.instance.getToken();
      final normalized = (fetched ?? '').trim();
      if (normalized.isEmpty) {
        return null;
      }
      await HiveUtils.setUserDetail(key: Api.fcmId, value: normalized);
      return normalized;
    } catch (_) {
      return null;
    }
  }

  void _handlePhonePasswordSuccess(BuildContext context) {
    final userData = HiveUtils.getUserDetails().toJson();
    _handleBackendLoginSuccess(context, userData);
  }

  void _handleBackendLoginSuccess(
      BuildContext context,
      Map<String, dynamic> apiResponse,
      ) {
    HiveUtils.setUserIsAuthenticated(true);
    HiveUtils.setUserData(apiResponse);
    userDetailsCubit?.fill(HiveUtils.getUserDetails());

    final bool isEmailVerified = apiResponse['email_verified_at'] != null;
    final bool isVerified = apiResponse['is_verified'] == 1;
    final bool hasAccountType =
        apiResponse['account_type'] != null && apiResponse['account_type'] != 0;

    if ((isEmailVerified || isVerified) && hasAccountType) {
      final String? city = HiveUtils.getCityName();
      if ((city ?? '').isNotEmpty && city != 'null') {
        HelperUtils.killPreviousPages(
          context,
          Routes.main,
          {'from': 'login'},
        );
      } else {
        Navigator.of(context).pushNamedAndRemoveUntil(
          Routes.locationPermissionScreen,
              (route) => false,
        );
      }
    } else {
      Navigator.pushReplacementNamed(
        context,
        Routes.otp,
        arguments: {
          'phoneNumber': apiResponse['mobile'] ?? '',
          'countryCode': value.dialCode,
          'selectedAccountType':
          apiResponse['account_type']?.toString() ?? '1',
        },
      );
    }
  }

  void _updateSubmitAvailability() {
    final identifier = identifierController.text.trim();
    final password = passwordController.text.trim();
    final otp = otpController.text.trim();

    bool allowSubmit;
    if (value.showOtpField) {
      allowSubmit = otp.length == 6;
    } else {
      allowSubmit = identifier.isNotEmpty && password.isNotEmpty;
    }
    value = value.copyWith(canSubmit: allowSubmit);
  }

  void _updateOtpAvailability() {
    final identifier = identifierController.text.trim();
    final canRequest = value.enablePhone &&
        RegExp(r'^[0-9]{6,}$').hasMatch(identifier);
    value = value.copyWith(canRequestOtp: canRequest);
  }

  @override
  void dispose() {
    _authFlowListenerDisposer?.call();
    identifierController.dispose();
    passwordController.dispose();
    otpController.dispose();
    identifierFocusNode.dispose();
    passwordFocusNode.dispose();
    otpFocusNode.dispose();
    super.dispose();
  }
}