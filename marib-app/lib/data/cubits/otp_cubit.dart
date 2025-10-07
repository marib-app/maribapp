import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marib/data/repositories/otp_repository.dart';

abstract class OtpState {}

class OtpInitial extends OtpState {}

class OtpSending extends OtpState {}

class OtpSent extends OtpState {}

class OtpSendError extends OtpState {
  final String error;
  OtpSendError(this.error);
}

class OtpVerifying extends OtpState {}

class OtpVerified extends OtpState {}

class OtpVerifyError extends OtpState {
  final String error;
  OtpVerifyError(this.error);
}

class OtpCubit extends Cubit<OtpState> {
  final OtpRepository repository;
  OtpCubit(this.repository) : super(OtpInitial());

  Future<void> sendOtp(String phone, String countryCode) async {
    emit(OtpSending());
    try {
      await repository.sendOtp(phone: phone, countryCode: countryCode);
      emit(OtpSent());
    } catch (e) {
      final errorMsg = e.toString().replaceAll('Exception: ', '');
      emit(OtpSendError(errorMsg));
    }
  }

  Future<void> verifyOtp(String phone, String otp, String countryCode) async {
    emit(OtpVerifying());
    try {
      final result = await repository.verifyOtp(
          phone: phone, otp: otp, countryCode: countryCode);
      if (result) {
        emit(OtpVerified());
      } else {
        emit(OtpVerifyError('رمز التحقق غير صحيح'));
      }
    } catch (e) {
      final errorMsg = e.toString().replaceAll('Exception: ', '');
      print("OTP Error: $errorMsg");
      emit(OtpVerifyError(errorMsg));
    }
  }
}
