import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marib/data/repositories/otp_repository.dart';

abstract class PasswordResetState {}

class PasswordResetInitial extends PasswordResetState {}

// حالات إرسال OTP
class PasswordResetOtpSending extends PasswordResetState {}

class PasswordResetOtpSent extends PasswordResetState {}

class PasswordResetOtpSendError extends PasswordResetState {
  final String error;
  PasswordResetOtpSendError(this.error);
}

// حالات التحقق من OTP
class PasswordResetOtpVerifying extends PasswordResetState {}

class PasswordResetOtpVerified extends PasswordResetState {}

class PasswordResetOtpVerifyError extends PasswordResetState {
  final String error;
  PasswordResetOtpVerifyError(this.error);
}

// حالات تحديث كلمة المرور
class PasswordUpdating extends PasswordResetState {}

class PasswordUpdated extends PasswordResetState {}

class PasswordUpdateError extends PasswordResetState {
  final String error;
  PasswordUpdateError(this.error);
}

class PasswordResetCubit extends Cubit<PasswordResetState> {
  final OtpRepository repository;

  PasswordResetCubit(this.repository) : super(PasswordResetInitial());

  // إرسال OTP لإعادة تعيين كلمة المرور
  Future<void> sendPasswordResetOtp(String phone, String countryCode) async {
    emit(PasswordResetOtpSending());
    try {
      await repository.sendPasswordResetOtp(
          phone: phone, countryCode: countryCode);
      emit(PasswordResetOtpSent());
    } catch (e) {
      final errorMsg = e.toString().replaceAll('Exception: ', '');
      emit(PasswordResetOtpSendError(errorMsg));
    }
  }

  // التحقق من OTP لإعادة تعيين كلمة المرور
  Future<void> verifyPasswordResetOtp(
      String phone, String otp, String countryCode) async {
    emit(PasswordResetOtpVerifying());
    try {
      final result = await repository.verifyPasswordResetOtp(
          phone: phone, otp: otp, countryCode: countryCode);
      if (result) {
        emit(PasswordResetOtpVerified());
      } else {
        emit(PasswordResetOtpVerifyError('رمز التحقق غير صحيح'));
      }
    } catch (e) {
      final errorMsg = e.toString().replaceAll('Exception: ', '');
      print("Password Reset OTP Error: $errorMsg");
      emit(PasswordResetOtpVerifyError(errorMsg));
    }
  }

  // تحديث كلمة المرور الجديدة
  Future<void> updatePassword(
      String phone, String newPassword, String countryCode) async {
    emit(PasswordUpdating());
    try {
      final result = await repository.updatePassword(
          phone: phone, newPassword: newPassword, countryCode: countryCode);
      if (result) {
        emit(PasswordUpdated());
      } else {
        emit(PasswordUpdateError('فشل في تحديث كلمة المرور'));
      }
    } catch (e) {
      final errorMsg = e.toString().replaceAll('Exception: ', '');
      print("Password Update Error: $errorMsg");
      emit(PasswordUpdateError(errorMsg));
    }
  }
}
