import 'dart:io';

import 'package:country_picker/country_picker.dart';
import 'package:device_region/device_region.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'package:marib/app/routes.dart';
import 'package:marib/data/cubits/auth/authentication_cubit.dart';
import 'package:marib/data/cubits/system/user_details.dart';
import 'package:marib/data/repositories/auth_repository.dart';
import 'package:marib/utils/api.dart';
import 'package:marib/utils/constant.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:marib/utils/hive_utils.dart';

class SignupNewUiState {
  final int currentStep;
  final bool isProcessing;
  final bool obscurePassword;
  final bool obscureConfirmPassword;
  final bool termsAccepted;
  final String dialCode;
  final String? flagEmoji;
  final String? errorMessage;
  final String? infoMessage;
  final bool canContinue;
  final bool canSubmit;
  final int? selectedAccountType;

  const SignupNewUiState({
    required this.currentStep,
    required this.isProcessing,
    required this.obscurePassword,
    required this.obscureConfirmPassword,
    required this.termsAccepted,
    required this.dialCode,
    required this.flagEmoji,
    required this.errorMessage,
    required this.infoMessage,
    required this.canContinue,
    required this.canSubmit,
    required this.selectedAccountType,
  });

  factory SignupNewUiState.initial() {
    return const SignupNewUiState(
      currentStep: 0,
      isProcessing: false,
      obscurePassword: true,
      obscureConfirmPassword: true,
      termsAccepted: false,
      dialCode: Constant.defaultCountryCode,
      flagEmoji: null,
      errorMessage: null,
      infoMessage: null,
      canContinue: false,
      canSubmit: false,
      selectedAccountType: null,
    );
  }

  SignupNewUiState copyWith({
    int? currentStep,
    bool? isProcessing,
    bool? obscurePassword,
    bool? obscureConfirmPassword,
    bool? termsAccepted,
    String? dialCode,
    String? flagEmoji,
    String? errorMessage,
    String? infoMessage,
    bool? canContinue,
    bool? canSubmit,
    int? selectedAccountType,
  }) {
    return SignupNewUiState(
      currentStep: currentStep ?? this.currentStep,
      isProcessing: isProcessing ?? this.isProcessing,
      obscurePassword: obscurePassword ?? this.obscurePassword,
      obscureConfirmPassword:
      obscureConfirmPassword ?? this.obscureConfirmPassword,
      termsAccepted: termsAccepted ?? this.termsAccepted,
      dialCode: dialCode ?? this.dialCode,
      flagEmoji: flagEmoji ?? this.flagEmoji,
      errorMessage: errorMessage ?? this.errorMessage,
      infoMessage: infoMessage ?? this.infoMessage,
      canContinue: canContinue ?? this.canContinue,
      canSubmit: canSubmit ?? this.canSubmit,
      selectedAccountType: selectedAccountType ?? this.selectedAccountType,
    );
  }
}

class SignupNewViewModel extends ValueNotifier<SignupNewUiState> {
  SignupNewViewModel({
    required AuthRepository authRepository,
    required MultiAuthRepository multiAuthRepository,
    this.userDetailsCubit,
    int? initialAccountType,
    String? initialPhoneNumber,
    String? initialDialCode,
    bool fromSocialLogin = false,
    Map<String, dynamic>? legacyArguments,
  })  : _authRepository = authRepository,
        _multiAuthRepository = multiAuthRepository,
        _initialAccountType = initialAccountType,
        _initialPhoneNumber = initialPhoneNumber,
        _initialDialCode = initialDialCode,
        _fromSocialLogin = fromSocialLogin,
        _legacyArguments = legacyArguments == null
            ? null
            : Map<String, dynamic>.unmodifiable(legacyArguments),
        super(SignupNewUiState.initial());

  final AuthRepository _authRepository;

  final int? _initialAccountType;
  final String? _initialPhoneNumber;
  final String? _initialDialCode;
  final bool _fromSocialLogin;
  final Map<String, dynamic>? _legacyArguments;

  final MultiAuthRepository _multiAuthRepository;
  final UserDetailsCubit? userDetailsCubit;

  final CountryService _countryService = CountryService();

  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
  TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController cityController = TextEditingController();
  final TextEditingController otpController = TextEditingController();

  final FocusNode nameFocus = FocusNode();
  final FocusNode emailFocus = FocusNode();
  final FocusNode passwordFocus = FocusNode();
  final FocusNode confirmPasswordFocus = FocusNode();
  final FocusNode phoneFocus = FocusNode();
  final FocusNode cityFocus = FocusNode();
  final FocusNode otpFocus = FocusNode();

  String? _verificationId;
  bool _hasInitialized = false;

  void initialize(BuildContext context) {
    if (_hasInitialized) return;
    _hasInitialized = true;

    assert(() {
      if (_legacyArguments != null) {
        debugPrint(
          'SignupNewViewModel received legacy args: '
              'accountType=${_initialAccountType ?? 'null'}, '
              'phone=${_initialPhoneNumber ?? 'null'}, '
              'dial=${_initialDialCode ?? 'null'}, '
              'keys=${_legacyArguments?.keys.toList() ?? []}',
        );
      }
      return true;
    }());

    _applyInitialData();

    _prefillDemoData();
    _prefillCountryFromSim();
    _evaluateProgress();
  }


  void _applyInitialData() {
    if (_initialAccountType != null) {
      value = value.copyWith(selectedAccountType: _initialAccountType);
    }

    if ((_initialPhoneNumber ?? '').trim().isNotEmpty) {
      phoneController.text = _initialPhoneNumber!.trim();
    }

    final String? sanitizedDial = _initialDialCode
        ?.replaceAll(' ', '')
        .replaceFirst('+', '')
        .trim();
    if ((sanitizedDial ?? '').isNotEmpty) {
      value = value.copyWith(dialCode: sanitizedDial);
    }

    if (_fromSocialLogin) {
      assert(() {
        debugPrint('SignupNewViewModel: social login flow detected');
        return true;
      }());
    }
  }



  void _prefillDemoData() {
    if (!Constant.isDemoModeOn) return;
    if (fullNameController.text.isEmpty) {
      fullNameController.text = 'Demo User';
    }
    if (emailController.text.isEmpty) {
      emailController.text = 'demo.user@example.com';
    }
    if (phoneController.text.isEmpty) {
      phoneController.text = Constant.demoMobileNumber;
    }

  }

  Future<void> _prefillCountryFromSim() async {

    if ((_initialDialCode ?? '').trim().isNotEmpty) {
      return;
    }

    try {
      final list = _countryService.getAll();
      final code = await DeviceRegion.getSIMCountryCode();
      final match = list.firstWhere(
            (c) => c.countryCode.toUpperCase() == (code ?? '').toUpperCase(),
        orElse: () => list.first,
      );
      value = value.copyWith(
        dialCode: match.phoneCode,
        flagEmoji: match.flagEmoji,
      );
    } catch (_) {}
  }

  void onNameChanged(String _) => _evaluateProgress();
  void onEmailChanged(String _) => _evaluateProgress();
  void onPasswordChanged(String _) => _evaluateProgress();
  void onConfirmPasswordChanged(String _) => _evaluateProgress();
  void onPhoneChanged(String _) => _evaluateProgress();
  void onCityChanged(String _) => _evaluateProgress();
  void onOtpChanged(String _) => _evaluateProgress();

  void togglePasswordVisibility() {
    value = value.copyWith(obscurePassword: !value.obscurePassword);
  }

  void toggleConfirmVisibility() {
    value = value.copyWith(
        obscureConfirmPassword: !value.obscureConfirmPassword);
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
        _evaluateProgress();
      },
    );
  }

  void setAccountType(int type) {
    value = value.copyWith(selectedAccountType: type);
    _evaluateProgress();
  }

  void setTermsAccepted(bool accepted) {
    value = value.copyWith(termsAccepted: accepted);
    _evaluateProgress();
  }

  void goToPreviousStep() {
    if (value.currentStep == 0) return;
    value = value.copyWith(
      currentStep: value.currentStep - 1,
      errorMessage: null,
      infoMessage: null,
    );
    _evaluateProgress();
  }

  Future<void> goToNextStep(BuildContext context) async {
    if (value.currentStep == 0) {
      if (!_validateAccountSection(context)) {
        return;
      }
      value = value.copyWith(
        currentStep: 1,
        errorMessage: null,
        infoMessage: null,
      );
      _evaluateProgress();
      return;
    }

    if (value.currentStep == 1) {
      if (!_validateContactSection(context)) {
        return;
      }
      await _requestOtp(context);
    }
  }

  Future<void> submit(BuildContext context) async {
    if (value.currentStep != 2) return;
    if (!_validateOtpSection(context)) {
      return;
    }

    if (_verificationId == null) {
      value = value.copyWith(
        errorMessage: 'Please request an OTP first.',
      );
      return;
    }

    try {
      value = value.copyWith(isProcessing: true, errorMessage: null);

      await _authRepository.verifyOTP(
        otpVerificationId: _verificationId!,
        otp: otpController.text.trim(),
      );

      final emailCredential = await _multiAuthRepository.createUserWithEmail(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      final payload = <String, dynamic>{
        Api.name: fullNameController.text.trim(),
        Api.email: emailController.text.trim(),
        Api.mobile: phoneController.text.trim(),
        'country_code': value.dialCode,
        'account_type': value.selectedAccountType?.toString() ?? '1',
        Api.firebaseId: emailCredential.user?.uid,
        Api.type: AuthenticationType.email.name,
        Api.fcmId: await _resolveFcmToken(),
        'password': passwordController.text.trim(),
        'city': cityController.text.trim(),
        'platform_type': Platform.isAndroid ? 'android' : 'ios',
      };

      final response = await Api.post(
        url: Api.loginApi,
        parameter: payload,
      );

      if (response['error'] == false) {
        HiveUtils.setJWT(response['token']);
        HiveUtils.setUserData(response['data']);
        HiveUtils.setUserIsAuthenticated(true);
        userDetailsCubit?.fill(HiveUtils.getUserDetails());
        _navigateAfterSuccess(context);
      } else {
        value = value.copyWith(
          errorMessage:
          response['message']?.toString() ?? 'Sign up failed. Please try again.',
        );
      }
    } catch (e) {
      value = value.copyWith(errorMessage: e.toString());
    } finally {
      value = value.copyWith(isProcessing: false);
    }
  }

  Future<void> resendOtp(BuildContext context) async {
    if (value.currentStep != 2) return;
    await _requestOtp(context, showNavigation: false);
  }

  Future<void> _requestOtp(BuildContext context,
      {bool showNavigation = true}) async {
    final phone = phoneController.text.trim();
    if (phone.isEmpty) {
      value = value.copyWith(
        errorMessage: 'pleaseEnterPhoneNumber'.translate(context),
      );
      return;
    }

    value = value.copyWith(isProcessing: true, errorMessage: null);

    await _authRepository.sendOTP(
      phoneNumber: '+${value.dialCode}$phone',
      onCodeSent: (verificationId) {
        _verificationId = verificationId;
        value = value.copyWith(
          isProcessing: false,
          infoMessage: 'Verification code sent to +${value.dialCode}$phone',
          currentStep: showNavigation ? 2 : value.currentStep,
        );
        _evaluateProgress();
      },
      onError: (error) {
        value = value.copyWith(
          isProcessing: false,
          errorMessage: error.toString(),
        );
      },
    );
  }

  bool _validateAccountSection(BuildContext context) {
    final name = fullNameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text;
    final confirmPassword = confirmPasswordController.text;

    if (name.isEmpty) {
      value = value.copyWith(
        errorMessage: 'Please enter your name.',
      );
      return false;
    }

    if (email.isEmpty || !email.contains('@')) {
      value = value.copyWith(
        errorMessage: 'pleaseEnterEmail'.translate(context),
      );
      return false;
    }

    if (password.length < 6) {
      value = value.copyWith(
        errorMessage: 'Password should be at least 6 characters.',
      );
      return false;
    }

    if (password != confirmPassword) {
      value = value.copyWith(
        errorMessage: 'Passwords do not match.',
      );
      return false;
    }

    return true;
  }

  bool _validateContactSection(BuildContext context) {
    final phone = phoneController.text.trim();
    if (phone.isEmpty) {
      value = value.copyWith(
        errorMessage: 'pleaseEnterPhoneNumber'.translate(context),
      );
      return false;
    }

    if (!RegExp(r'^[0-9]{6,}$').hasMatch(phone)) {
      value = value.copyWith(
        errorMessage: 'pleaseEnterValidPhoneNumber'.translate(context),
      );
      return false;
    }

    if (value.selectedAccountType == null) {
      value = value.copyWith(
        errorMessage: 'Please select an account type.',
      );
      return false;
    }

    return true;
  }

  bool _validateOtpSection(BuildContext context) {
    if (otpController.text.trim().length < 6) {
      value = value.copyWith(
        errorMessage: 'pleaseEnterSixDigits'.translate(context),
      );
      return false;
    }

    if (!value.termsAccepted) {
      value = value.copyWith(
        errorMessage: 'Please accept the terms and conditions.',
      );
      return false;
    }

    return true;
  }

  Future<String?> _resolveFcmToken() async {
    final stored = HiveUtils.getUserDetail<String>(key: Api.fcmId);
    if ((stored ?? '').isNotEmpty) return stored;

    try {
      final token = await FirebaseMessaging.instance.getToken();
      if ((token ?? '').isNotEmpty) {
        await HiveUtils.setUserDetail(key: Api.fcmId, value: token);
        return token;
      }
    } catch (_) {}
    return null;
  }

  void _navigateAfterSuccess(BuildContext context) {
    final city = HiveUtils.getCityName();
    if ((city ?? '').isNotEmpty && city != 'null') {
      HelperUtils.killPreviousPages(
        context,
        Routes.main,
        {'from': 'signup'},
      );
    } else {
      Navigator.of(context).pushNamedAndRemoveUntil(
        Routes.locationPermissionScreen,
            (route) => false,
      );
    }
  }

  void _evaluateProgress() {
    if (value.currentStep == 0) {
      final ready = fullNameController.text.trim().isNotEmpty &&
          emailController.text.trim().isNotEmpty &&
          passwordController.text.length >= 6 &&
          confirmPasswordController.text == passwordController.text;
      value = value.copyWith(canContinue: ready, canSubmit: false);
    } else if (value.currentStep == 1) {
      final ready = phoneController.text.trim().length >= 6 &&
          value.selectedAccountType != null;
      value = value.copyWith(canContinue: ready, canSubmit: false);
    } else {
      final ready = otpController.text.trim().length == 6 && value.termsAccepted;
      value = value.copyWith(canSubmit: ready, canContinue: false);
    }
  }

  @override
  void dispose() {
    fullNameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    phoneController.dispose();
    cityController.dispose();
    otpController.dispose();
    nameFocus.dispose();
    emailFocus.dispose();
    passwordFocus.dispose();
    confirmPasswordFocus.dispose();
    phoneFocus.dispose();
    cityFocus.dispose();
    otpFocus.dispose();
    super.dispose();
  }
}