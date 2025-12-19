import 'dart:async'; // Import for Timer
import 'package:flutter/material.dart'; // Core Flutter material design
import 'package:flutter/services.dart'; // For SystemUiOverlayStyle
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart'; // For displaying SVG images
import 'package:marib/app/routes.dart';
import 'package:marib/data/cubits/auth/authentication_cubit.dart';
import 'package:marib/data/cubits/otp_cubit.dart';
import 'package:marib/data/repositories/otp_repository.dart';
// <-- Added import for Api
import 'package:marib/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:marib/utils/hive_utils.dart';
// Still required for _showErrorDialog
import 'package:pinput/pinput.dart'; // For OTP input fields
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:io';
import 'package:marib/utils/api.dart';
import 'package:marib/data/cubits/system/fetch_system_settings_cubit.dart';
import 'package:marib/utils/notification/notification_service.dart';
import '../widgets/auth_status_bar.dart';

const double sidePadding = 20.0;

class MobileVerificationScreen extends StatefulWidget {
  final String? selectedAccountType;
  final String phoneNumber;
  final String countryCode;
  final bool isFromGoogleLogin;
  final Map<String, dynamic>? googleData;

  const MobileVerificationScreen({
    super.key,
    this.selectedAccountType,
    required this.phoneNumber,
    required this.countryCode,
    this.isFromGoogleLogin = false,
    this.googleData,
  });







  static Route route(RouteSettings settings) {
    final args = settings.arguments as Map<String, dynamic>?;
    final selectedType = args?['selectedAccountType'] as String?;
    final phoneNumber = (args?['phoneNumber'] as String?) ?? "";

    if (phoneNumber.isEmpty) {
      print("Error: Phone number argument is missing for MobileVerificationScreen");
      throw ArgumentError("Phone number is required for MobileVerificationScreen");
    }

    return BlurredRouter(
      builder: (context) {
        return MobileVerificationScreen(
          selectedAccountType: selectedType,
          phoneNumber: phoneNumber,
          countryCode: args?['countryCode'] ?? "",
          isFromGoogleLogin: args?['isFromGoogleLogin'] ?? false,
          googleData: args?['googleData'],
        );
      },
    );
  }





  @override
  State<MobileVerificationScreen> createState() =>
      _MobileVerificationScreenState();
}

class _MobileVerificationScreenState extends State<MobileVerificationScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey();
  final TextEditingController _pinputController = TextEditingController();
  late final OtpCubit _otpCubit;
  String _currentOtp = '';
  Timer? _timer;
  int _countdownSeconds = 180;
  bool _isTimerActive = false;
  bool _isLoading = false; // Added state variable for loading
  Timer? _bottomSheetTimer; // Timer to automatically close bottom sheet



  @override
  void initState() {
    super.initState();
    _otpCubit = OtpCubit(OtpRepository());



    print("Selected account type: " + (widget.selectedAccountType ?? ''));
    print("Verifying phone number: ${widget.phoneNumber}");

    // Debug logging for Google data
    if (widget.isFromGoogleLogin) {
      print("🔍 Google Login OTP Verification:");
      print("   - Phone: ${widget.phoneNumber}");
      print("   - Country Code: ${widget.countryCode}");
      print("   - Google Data: ${widget.googleData}");
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // التأكد من أن الرقم صحيح
        if (widget.phoneNumber.isEmpty) {
          print("ERROR: Phone number is empty!");
          HelperUtils.showSnackBarMessage(context, 'رقم الهاتف غير صحيح');
          Navigator.of(context).pop();
          return;
        }

        _startTimer();
        //Adding a small delay to ensure backend is ready
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            print("Auto-sending OTP to: ${widget.phoneNumber}");
            _otpCubit.sendOtp(widget.phoneNumber, widget.countryCode);

          }
        });
      }
    });
  }







  @override
  void dispose() {
    _timer?.cancel();
    _bottomSheetTimer?.cancel();
    _pinputController.dispose();
    _otpCubit.close();
    super.dispose();
  }

  void _startTimer() {
    _countdownSeconds = 180;
    _isTimerActive = true;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdownSeconds > 0) {
        setState(() {
          _countdownSeconds--;
        });
      } else {
        _timer?.cancel();
        setState(() {
          _isTimerActive = false;
        });
      }
    });
    print("UI: Timer started/restarted.");
  }

  // --- New helper function to display Modal Bottom Sheet and close it automatically ---
  void _showTimedBottomSheet(String message, Duration displayDuration) {
    // Close any previous bottom sheet before opening a new one
    if (_bottomSheetTimer != null && _bottomSheetTimer!.isActive) {
      Navigator.of(context).pop();
      _bottomSheetTimer?.cancel();
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: false,
      backgroundColor:
          context.color.primaryColor.darken(-5), // Use a color from the theme
      enableDrag: false,
      builder: (context) {
        // Start a timer to close the bottom sheet after the duration ends
        _bottomSheetTimer = Timer(displayDuration, () {
          // Ensure the bottom sheet is still present before attempting to close it
          if (Navigator.of(context).mounted) {
            Navigator.of(context).pop();
          }
        });

        return Container(
          // height: 200, // Commented out based on the original code
          child: Padding(
            padding: const EdgeInsets.all(30.0),
            child: Column(
              mainAxisSize: MainAxisSize
                  .min, // Makes the column take minimum possible space
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.translate(context), // Translate the message
                ).size(context.font.larger), // Use a font size from the theme
              ],
            ),
          ),
        );
      },
    ).whenComplete(() {
      // When the bottom sheet is closed (either manually or by timer), cancel the timer
      _bottomSheetTimer?.cancel();
    });
  }
  // --- End of _showTimedBottomSheet function ---

  Future<void> _sendOtp() async {
    if (_isTimerActive) {
      final remainingTime = _formatTime(_countdownSeconds);
      HelperUtils.showSnackBarMessage(
          context, "يرجى الانتظار حتى $remainingTime لإعادة إرسال الرمز.",
          messageDuration: 3, type: MessageType.warning);
      return;
    }
    setState(() {
      _isLoading = true;
    });

    try {
      await _otpCubit.sendOtp(widget.phoneNumber, widget.countryCode);
      _pinputController.clear();
      setState(() {
        _currentOtp = '';
        _startTimer();
      });
    } catch (e) {
      print("Send OTP Error in UI: $e");
      if (mounted) {
        // HelperUtils.showSnackBarMessage(context, "حدث خطأ أثناء إرسال الرمز.",
        //     messageDuration: 4, type: MessageType.error);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // تحقق من رمز OTP عبر Cubit
  Future<void> _verifyOtp() async {
    final enteredOtp = _pinputController.text.trim();
    if (enteredOtp.length != 6) {
      HelperUtils.showSnackBarMessage(
          context, "يرجى إدخال رمز التحقق المكون من 6 أرقام.",
          messageDuration: 3, type: MessageType.warning);
      return;
    }
    if (!_isTimerActive) {
      HelperUtils.showSnackBarMessage(
          context, "انتهت صلاحية الرمز. أعد الإرسال.",
          messageDuration: 4, type: MessageType.error);
      _pinputController.clear();
      setState(() => _currentOtp = '');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _otpCubit.verifyOtp(
          widget.phoneNumber, enteredOtp, widget.countryCode);
    } catch (e) {
      // print("OTP Verification Error: $e");
      // if (mounted) {
      //   HelperUtils.showSnackBarMessage(
      //       context, "حدث خطأ أثناء التحقق. يرجى المحاولة مرة أخرى.",
      //       messageDuration: 4, type: MessageType.error);
      //   _pinputController.clear();
      //   setState(() => _currentOtp = '');
      // }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatTime(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final remainingSeconds = (seconds % 60).toString().padLeft(2, '0');
    return "$minutes:$remainingSeconds";
  }

  Map<String, dynamic> _buildMerchantOtpDraft() {
    final Map<String, dynamic> draft = <String, dynamic>{
      'mobile': widget.phoneNumber,
      'country_code': widget.countryCode,
      'account_type': widget.selectedAccountType ?? '3',
    };
    draft.removeWhere(
      (key, value) {
        if (value == null) return true;
        if (value is String) {
          return value.trim().isEmpty;
        }
        return false;
      },
    );
    return draft;
  }

  @override
  Widget build(BuildContext context) {
    final statusBarBase = LoginStatusBar.resolveBaseColor(
      context,
      override: context.color.territoryColor,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
        value: LoginStatusBar.overlayFor(
          context,
          baseColor: statusBarBase,
        ),
        child: BlocProvider.value(

          value: _otpCubit,
      child: BlocConsumer<OtpCubit, OtpState>(
        listener: (context, state) {
          if (state is OtpVerified) {
            HelperUtils.showSnackBarMessage(context, 'تم التحقق بنجاح!',
                messageDuration: 2, type: MessageType.success);

            Future.delayed(const Duration(milliseconds: 300), () async {
              if (mounted) {
                print("OTP verification successful, activating account...");

                // تحديث بيانات المستخدم لتعكس حالة التحقق
                var userData = HiveUtils.getUserDetails();
                userData.isVerified = 1; // تعيين المستخدم كمحقق
                HiveUtils.setUserData(userData.toJson());

                print(
                    "User verification successful. User data: ${userData.toJson()}");
                print("User authenticated: ${HiveUtils.isUserAuthenticated()}");

                // تحديد الخطوة التالية حسب نوع الحساب
                if (widget.selectedAccountType == "3") {
                  final draft = _buildMerchantOtpDraft();
                  await HiveUtils.beginMerchantOnboardingSession(
                    initialStep: 0,
                    draft: draft,
                  );
                  Navigator.pushNamed(
                    context,
                    Routes.merchantOnboarding,
                    arguments: {
                      'signupDraft': draft,
                      'resumeFromStep': 0,
                    },
                  );
                } else if (widget.selectedAccountType == "2") {
                  // للحسابات العقارية - الانتقال لشاشة التسجيل المتقدمة
                  Navigator.pushNamed(
                    context,
                    Routes.signup,
                    arguments: {
                      'selectedAccountType': widget.selectedAccountType,
                      'phoneNumber': widget.phoneNumber,
                      'countryCode': widget.countryCode,
                    },
                  );
                } else {
                  // للحسابات الفردية - التحقق من الموقع أولاً
                  if (HiveUtils.getCityName() != null &&
                      HiveUtils.getCityName() != "" &&
                      HiveUtils.getCityName() != "null") {
                    // الموقع محفوظ مسبقاً - الدخول مباشرة للتطبيق
                    HiveUtils.setUserIsAuthenticated(true);
                    await NotificationService.resendPendingTokenIfNeeded();

                    FetchSystemSettingsCubit.refreshPermissionsForCurrentUser(
                      context,
                      clearCacheBeforeFetch: true,
                    );
                    HelperUtils.killPreviousPages(
                        context, Routes.main, {"from": "verification"});
                  } else {
                    // الموقع غير محفوظ - الانتقال لشاشة تحديد الموقع
                    HiveUtils.setUserIsAuthenticated(true);
                    await NotificationService.resendPendingTokenIfNeeded();
                    FetchSystemSettingsCubit.refreshPermissionsForCurrentUser(
                      context,
                      clearCacheBeforeFetch: true,
                    );
                    Navigator.of(context).pushNamedAndRemoveUntil(
                        Routes.main, (route) => false);
                  }
                }
              }
            });
          } else if (state is OtpVerifyError) {
            print("OTP Verify Error: ${state.error}");
            Future.delayed(const Duration(milliseconds: 100), () {
              if (mounted) {
                HelperUtils.showSnackBarMessage(context, state.error,
                    messageDuration: 4, type: MessageType.error);
              }
            });
            _pinputController.clear();
            setState(() => _currentOtp = '');
          } else if (state is OtpSent) {
            Future.delayed(const Duration(milliseconds: 100), () {
              if (mounted) {
                HelperUtils.showSnackBarMessage(
                    context, 'تم إرسال رمز التحقق بنجاح',
                    messageDuration: 3, type: MessageType.success);
              }
            });
          } else if (state is OtpSendError) {
            print("OTP Send Error: ${state.error}");
            Future.delayed(const Duration(milliseconds: 100), () {
              if (mounted) {
                HelperUtils.showSnackBarMessage(context, state.error,
                    messageDuration: 4, type: MessageType.error);
              }
            });
          }
        },
        builder: (context, state) {
          final defaultPinTheme = PinTheme(
            width: 46,
            height: 56,
            textStyle: TextStyle(
              fontSize: 20,
              color: context.color.textColorDark,
              fontWeight: FontWeight.bold,
            ),
            decoration: BoxDecoration(
              border: Border.all(color: context.color.territoryColor),
              borderRadius: BorderRadius.circular(8),
            ),
          );

          final focusedPinTheme = defaultPinTheme.copyDecorationWith(
            border: Border.all(color: context.color.territoryColor, width: 2),
          );

          final submittedPinTheme = defaultPinTheme.copyDecorationWith(
            border: Border.all(color: context.color.territoryColor, width: 2),
          );

          // Determine button states based on local state variables
          // Verify button is disabled if loading OR OTP length is not 6 OR timer is NOT active
          final bool isVerifyButtonDisabled =
              _isLoading || _currentOtp.length != 6 || !_isTimerActive;
          // Resend button is disabled if loading OR timer IS active
          final bool isResendButtonDisabled = _isLoading || _isTimerActive;

          return Scaffold(
            backgroundColor: context.color.territoryColor,
            body: SafeArea(
              top: false,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.topCenter, colors: [
                    context.color.territoryColor,
                    context.color.territoryColor,
                  ]),
                ),
                child: Column(
                  // Direct Column as the body content
                  children: [
                    LoginStatusBar.topSpacer(
                      context,
                      baseColor: statusBarBase,
                    ),
                    const SizedBox(height: 16),
                    SvgPicture.asset('assets/svg/Logo.svg',
                        height: 90, color: context.color.buttonColor),
                    Text("readytoserve".translate(context))
                        .size(context.font.large)
                        .color(context.color.buttonColor),
                    const SizedBox(height: 20),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.only(top: 23),
                        decoration: BoxDecoration(
                            color: context.color.primaryColor,
                            borderRadius: BorderRadius.circular(30)),
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: Padding(
                            padding: const EdgeInsets.all(sidePadding),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text("otp".translate(context))
                                      .size(context.font.extraLarge)
                                      .color(context.color.textDefaultColor),
                                  const SizedBox(height: 8),
                                  if (widget.isFromGoogleLogin)
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 10.0),
                                      child: Text(
                                        "إكمال التحقق لحساب Google",
                                        style: TextStyle(
                                          fontSize: context.font.normal,
                                          color: context.color.textLightColor,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  Text(
                                    "enterSixDigitOtp".translate(context),
                                    style: TextStyle(
                                      fontSize: context.font.normal,
                                      // color: context.color.,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  SizedBox(height: 5),
                                  Text(
                                    widget.phoneNumber,
                                    style: TextStyle(
                                      fontSize: context.font.large,
                                      // color: context.color.textColor,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 30),
                                  Directionality(
                                    textDirection: TextDirection.ltr,
                                    child: Pinput(
                                      controller: _pinputController,
                                      length: 6,
                                      defaultPinTheme: defaultPinTheme,
                                      focusedPinTheme: focusedPinTheme,
                                      submittedPinTheme: submittedPinTheme,
                                      keyboardType: TextInputType.number,
                                      useNativeKeyboard: true,
                                      pinputAutovalidateMode:
                                          PinputAutovalidateMode.onSubmit,
                                      showCursor: true,
                                      onChanged: (pin) {
                                        print("UI: Pinput onChanged: $pin");
                                        setState(() {
                                          _currentOtp = pin;
                                        });
                                      },
                                      validator: (s) {
                                        return null;
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Align(
                                    alignment: AlignmentDirectional.center,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          _formatTime(_countdownSeconds),
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: context.color.textColorDark,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        OutlinedButton(
                                          onPressed: isResendButtonDisabled
                                              ? null
                                              : () {
                                                  _sendOtp();
                                                },
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor:
                                                isResendButtonDisabled
                                                    ? context
                                                        .color.textColor
                                                        .withOpacity(0.5)
                                                    : context
                                                        .color.territoryColor,
                                            side: BorderSide(
                                              color: isResendButtonDisabled
                                                  ? context.color.textColor
                                                      .withOpacity(0.5)
                                                  : context
                                                      .color.territoryColor,
                                            ),
                                          ),
                                          child: Text(
                                              "resendOTP".translate(context)),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 19),
                                  if (_isLoading)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 16.0),
                                      child: CircularProgressIndicator(
                                          color: context.color.territoryColor),
                                    )
                                  else
                                    ElevatedButton(
                                      onPressed: isVerifyButtonDisabled
                                          ? null
                                          : () {
                                              _verifyOtp();
                                            },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            context.color.territoryColor,
                                        foregroundColor: context.color.buttonColor,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 15),
                                        minimumSize:
                                            const Size(double.infinity, 50),
                                      ),
                                      child: Text("verify".translate(context)),
                                    ),
                                  const SizedBox(height: 30),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
        ),
    );
  }
}
