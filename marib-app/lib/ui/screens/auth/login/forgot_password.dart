import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:country_picker/country_picker.dart';
import 'package:marib/app/routes.dart';
import 'package:marib/data/cubits/password_reset_cubit.dart';
import 'package:marib/data/repositories/otp_repository.dart';
import 'package:marib/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:marib/ui/screens/widgets/new_password_dialog.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:marib/utils/hive_utils.dart';
import 'package:marib/utils/extensions/extensions.dart';

// الواجهة المفصولة
import 'forgot_password_ui.dart';
import 'package:marib/data/cubits/system/fetch_system_settings_cubit.dart';



class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  static Route route(RouteSettings routeSettings) {
    return BlurredRouter(
      builder: (_) => const ForgotPasswordScreen(),
    );
  }

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  // Controllers + مفاتيح
  final _phoneController = TextEditingController();
  final _pinputController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  late final PasswordResetCubit _passwordResetCubit;

  // حالة واجهة الهاتف
  String? countryCode = "+967";
  String? flagEmoji = "🇾🇪";

  // حالة OTP + مؤقت
  String _currentOtp = '';
  Timer? _timer;
  int _countdownSeconds = 180;
  bool _isTimerActive = false;

  // UI state
  bool _isOtpSent = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _passwordResetCubit = PasswordResetCubit(OtpRepository());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _phoneController.dispose();
    _pinputController.dispose();
    _passwordResetCubit.close();
    super.dispose();
  }

  // ====== منطق المؤقت ======
  void _startTimer() {
    _countdownSeconds = 180;
    _isTimerActive = true;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_countdownSeconds > 0) {
        setState(() => _countdownSeconds--);
      } else {
        _timer?.cancel();
        setState(() => _isTimerActive = false);
      }
    });
  }

  // ====== منطق الإرسال ======
  Future<void> _sendOtp() async {
    if (_isOtpSent && _isTimerActive) {
      final remainingTime = _formatTime(_countdownSeconds);
      HelperUtils.showSnackBarMessage(
        context,
        "يرجى الانتظار حتى $remainingTime لإعادة إرسال الرمز.",
        messageDuration: 3,
        type: MessageType.warning,
      );
      return;
    }

    if (_formKey.currentState?.validate() != true) return;

    setState(() => _isLoading = true);
    try {
      await _passwordResetCubit.sendPasswordResetOtp(
        _phoneController.text,
        (countryCode ?? '+967').replaceAll('+', ''),
      );
      _pinputController.clear();
      setState(() {
        _currentOtp = '';
        _isOtpSent = true;
      });
      _startTimer();
    } catch (e) {
      // تم التعامل مع الخطأ في الـCubit listener
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ====== منطق التحقق ======
  Future<void> _verifyOtp() async {
    final enteredOtp = _pinputController.text.trim();
    if (enteredOtp.length != 6) {
      HelperUtils.showSnackBarMessage(
        context,
        "يرجى إدخال رمز التحقق المكون من 6 أرقام.",
        messageDuration: 3,
        type: MessageType.warning,
      );
      return;
    }
    if (!_isTimerActive) {
      HelperUtils.showSnackBarMessage(
        context,
        "انتهت صلاحية الرمز. أعد الإرسال.",
        messageDuration: 4,
        type: MessageType.error,
      );
      _pinputController.clear();
      setState(() => _currentOtp = '');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _passwordResetCubit.verifyPasswordResetOtp(
        _phoneController.text,
        enteredOtp,
        (countryCode ?? '+967').replaceAll('+', ''),
      );
    } catch (_) {
      // الخطأ يُعرض عبر الحالة
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ====== حوار كلمة المرور الجديدة ======
  void _showNewPasswordDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => NewPasswordDialog(
        onPasswordSet: (password) async {
          Navigator.of(context).pop();
          setState(() => _isLoading = true);
          try {
            await _passwordResetCubit.updatePassword(
              _phoneController.text,
              password,
              (countryCode ?? '+967').replaceAll('+', ''),
            );
          } catch (_) {
            // الحالة تتكفل بعرض الأخطاء
          } finally {
            if (mounted) setState(() => _isLoading = false);
          }
        },
        onCancel: () => Navigator.of(context).pop(),
      ),
    );
  }

  // ====== اختيار الدولة ======
  void _showCountryPicker() {
    showCountryPicker(
      context: context,
      showWorldWide: false,
      showPhoneCode: true,
      countryListTheme:
      CountryListThemeData(borderRadius: BorderRadius.circular(11)),
      onSelect: (value) {
        setState(() {
          flagEmoji = value.flagEmoji;
          countryCode = "+${value.phoneCode}";
        });
      },
    );
  }

  // ====== أدوات مساعدة ======
  String _formatTime(int s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final rs = (s % 60).toString().padLeft(2, '0');
    return "$m:$rs";
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _passwordResetCubit,
      child: BlocConsumer<PasswordResetCubit, PasswordResetState>(
        listener: (context, state) {
          if (state is PasswordResetOtpSent) {
            HelperUtils.showSnackBarMessage(
              context,
              'تم إرسال رمز التحقق بنجاح',
              messageDuration: 3,
              type: MessageType.success,
            );
          } else if (state is PasswordResetOtpSendError) {
            HelperUtils.showSnackBarMessage(
              context,
              state.error,
              messageDuration: 4,
              type: MessageType.error,
            );
          } else if (state is PasswordResetOtpVerified) {
            HelperUtils.showSnackBarMessage(
              context,
              'تم التحقق بنجاح!',
              messageDuration: 2,
              type: MessageType.success,
            );
            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted) _showNewPasswordDialog();
            });
          } else if (state is PasswordResetOtpVerifyError) {
            HelperUtils.showSnackBarMessage(
              context,
              state.error,
              messageDuration: 4,
              type: MessageType.error,
            );
            _pinputController.clear();
            setState(() => _currentOtp = '');
          } else if (state is PasswordUpdated) {
            HelperUtils.showSnackBarMessage(
              context,
              'تم تحديث كلمة المرور بنجاح!',
              messageDuration: 3,
              type: MessageType.success,
            );
            Future.delayed(const Duration(milliseconds: 500), () {
              if (!mounted) return;

              FetchSystemSettingsCubit.refreshPermissionsForCurrentUser(
                context,
                clearCacheBeforeFetch: true,
              );

              if ((HiveUtils.getCityName() ?? '').isNotEmpty) {
                HelperUtils.killPreviousPages(
                  context,
                  Routes.main,
                  {"from": "password_reset"},
                );
              } else {
                Navigator.of(context).pushNamedAndRemoveUntil(
                  Routes.main,
                      (route) => false,
                );
              }
            });
          } else if (state is PasswordUpdateError) {
            HelperUtils.showSnackBarMessage(
              context,
              state.error,
              messageDuration: 4,
              type: MessageType.error,
            );
          }
        },
        builder: (context, state) {
          return ForgotPasswordUI(
            // الحالة والقيم
            formKey: _formKey,
            phoneController: _phoneController,
            pinputController: _pinputController,
            isOtpSent: _isOtpSent,
            isLoading: _isLoading,
            isTimerActive: _isTimerActive,
            countdownSeconds: _countdownSeconds,
            currentOtp: _currentOtp,
            countryCode: countryCode ?? "+967",
            flagEmoji: flagEmoji ?? "🇾🇪",

            // الأحداث/الكولباكات
            onSendOtp: _sendOtp,
            onVerifyOtp: _verifyOtp,
            onChangePhonePressed: () {
              setState(() {
                _isOtpSent = false;
                _timer?.cancel();
                _isTimerActive = false;
                _pinputController.clear();
                _currentOtp = '';
              });
            },
            onCountryPickerPressed: _showCountryPicker,
            onOtpChanged: (val) => setState(() => _currentOtp = val),
            // أدوات مساعدة
            formatTime: _formatTime,
          );
        },
      ),
    );
  }
}
