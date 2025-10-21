import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:marib/ui/screens/widgets/custom_text_form_field.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:pinput/pinput.dart';
import 'widgets/login_status_bar.dart';

const double sidePadding = 20.0;

/// واجهة تقديمية (Presentation-Only).
/// - لا تحتوي أي منطق.
/// - كل الحالة تصل عبر الـ props.
/// - كل الأفعال تُستدعى عبر الـ callbacks.
class ForgotPasswordUI extends StatelessWidget {
  const ForgotPasswordUI({
    super.key,
    required this.formKey,
    required this.phoneController,
    required this.pinputController,
    required this.isOtpSent,
    required this.isLoading,
    required this.isTimerActive,
    required this.countdownSeconds,
    required this.currentOtp,
    required this.countryCode,
    required this.flagEmoji,
    required this.onSendOtp,
    required this.onVerifyOtp,
    required this.onChangePhonePressed,
    required this.onCountryPickerPressed,
    required this.onOtpChanged,
    required this.formatTime,
  });

  // الحالة
  final GlobalKey<FormState> formKey;
  final TextEditingController phoneController;
  final TextEditingController pinputController;

  final bool isOtpSent;
  final bool isLoading;
  final bool isTimerActive;
  final int countdownSeconds;
  final String currentOtp;
  final String countryCode;
  final String flagEmoji;

  // الأحداث
  final VoidCallback onSendOtp;
  final VoidCallback onVerifyOtp;
  final VoidCallback onChangePhonePressed;
  final VoidCallback onCountryPickerPressed;
  final ValueChanged<String> onOtpChanged;

  // أدوات
  final String Function(int seconds) formatTime;

  @override
  Widget build(BuildContext context) {
    final statusBarColor = LoginStatusBar.resolveBaseColor(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: LoginStatusBar.overlayFor(
        context,
        baseColor: statusBarColor,
      ),
      child: Scaffold(
        backgroundColor: context.color.territoryColor,
        body: SafeArea(
          top: false,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                colors: [
                  context.color.territoryColor,
                  context.color.territoryColor,
                ],
              ),
            ),
            child: Column(
              children: [
                LoginStatusBar.topSpacer(
                  context,
                  baseColor: statusBarColor,
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
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Padding(
                        padding: const EdgeInsets.all(sidePadding),
                        child: Form(
                          key: formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!isOtpSent) ...[
                                // ===== الواجهة: إدخال رقم الهاتف =====
                                Text("forgotPassword".translate(context))
                                    .size(context.font.extraLarge)
                                    .color(context.color.textDefaultColor),
                                const SizedBox(height: 20),
                                Text("enterPhoneForOtp".translate(context))
                                    .size(context.font.large)
                                    .color(context.color.textColor),
                                const SizedBox(height: 8),
                                Text("otpSentViaWhatsapp".translate(context))
                                    .size(context.font.small)
                                    .color(context.color.textLightColor),
                                const SizedBox(height: 24),
                                CustomTextFormField(
                                  controller: phoneController,
                                  keyboard: TextInputType.phone,
                                  hintText: "phoneNumber".translate(context),
                                  validator:
                                      CustomTextFieldValidator.phoneNumber,
                                  fixedPrefix: InkWell(
                                    onTap: onCountryPickerPressed,
                                    child: Container(
                                      width: 80,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        border: Border(
                                          right: BorderSide(
                                            color: context.color.borderColor,
                                            width: 1.5,
                                          ),
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          "$flagEmoji $countryCode",
                                          style: TextStyle(
                                            fontSize: context.font.normal,
                                            color:
                                                context.color.textDefaultColor,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 25),
                                if (isLoading)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16.0),
                                    child: CircularProgressIndicator(
                                      color: context.color.territoryColor,
                                    ),
                                  )
                                else
                                  UiUtils.buildButton(
                                    context,
                                    onPressed: onSendOtp,
                                    buttonTitle:
                                        "sendOtpCode".translate(context),
                                    radius: 8,
                                  ),
                              ] else ...[
                                // ===== الواجهة: التحقق من OTP =====
                                Text("otp".translate(context))
                                    .size(context.font.extraLarge)
                                    .color(context.color.textDefaultColor),
                                const SizedBox(height: 8),
                                Text(
                                  "enterSixDigitOtp".translate(context),
                                  style: TextStyle(
                                    fontSize: context.font.normal,
                                    color: context.color.textColor,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  "$countryCode${phoneController.text}",
                                  style: TextStyle(
                                    fontSize: context.font.large,
                                    color: context.color.textColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 30),
                                Directionality(
                                  textDirection: TextDirection.ltr,
                                  child: Pinput(
                                    controller: pinputController,
                                    length: 6,
                                    defaultPinTheme: PinTheme(
                                      width: 46,
                                      height: 56,
                                      textStyle: TextStyle(
                                        fontSize: 20,
                                        color: context.color.textColorDark,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: context.color.textColor
                                              .withOpacity(0.5),
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    focusedPinTheme: PinTheme(
                                      width: 46,
                                      height: 56,
                                      textStyle: TextStyle(
                                        fontSize: 20,
                                        color: context.color.textColorDark,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: context.color.territoryColor,
                                          width: 2,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    submittedPinTheme: PinTheme(
                                      width: 46,
                                      height: 56,
                                      textStyle: TextStyle(
                                        fontSize: 20,
                                        color: context.color.textColorDark,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: context.color.territoryColor,
                                          width: 2,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    keyboardType: TextInputType.number,
                                    useNativeKeyboard: true,
                                    pinputAutovalidateMode:
                                        PinputAutovalidateMode.onSubmit,
                                    showCursor: true,
                                    onChanged: onOtpChanged,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Align(
                                  alignment: AlignmentDirectional.center,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        formatTime(countdownSeconds),
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: context.color.textColorDark,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      OutlinedButton(
                                        onPressed: (isLoading || isTimerActive)
                                            ? null
                                            : onSendOtp,
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: (isLoading ||
                                                  isTimerActive)
                                              ? context.color.textColor
                                                  .withOpacity(0.5)
                                              : context.color.territoryColor,
                                          side: BorderSide(
                                            color: (isLoading || isTimerActive)
                                                ? context.color.textColor
                                                    .withOpacity(0.5)
                                                : context.color.territoryColor,
                                          ),
                                        ),
                                        child: Text(
                                          "resendOTP".translate(context),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 19),
                                if (isLoading)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16.0),
                                    child: CircularProgressIndicator(
                                      color: context.color.territoryColor,
                                    ),
                                  )
                                else
                                  ElevatedButton(
                                    onPressed: (isLoading ||
                                            currentOtp.length != 6 ||
                                            !isTimerActive)
                                        ? null
                                        : onVerifyOtp,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          context.color.territoryColor,
                                      foregroundColor:
                                          context.color.buttonColor,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 15),
                                      minimumSize:
                                          const Size(double.infinity, 50),
                                    ),
                                    child: Text("verify".translate(context)),
                                  ),
                                const SizedBox(height: 20),
                                TextButton(
                                  onPressed: onChangePhonePressed,
                                  child: Text(
                                    "changePhoneNumber".translate(context),
                                    style: TextStyle(
                                      color: context.color.territoryColor,
                                      fontSize: context.font.normal,
                                    ),
                                  ),
                                ),
                              ],
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
      ),
    );
  }
}
