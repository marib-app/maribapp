import 'package:marib/utils/api.dart';
import 'package:dio/dio.dart';
import 'package:marib/utils/hive_utils.dart';
import 'package:marib/utils/notification/notification_service.dart';

class OtpRepository {
  Future<void> sendOtp(
      {required String phone, required String countryCode}) async {
    print("Sending OTP to phone: $phone");

    try {
      final response = await Api.post(
        url: Api.sendOtpApi,
        parameter: {
          "country_code": countryCode,
          "phone": phone,
          "type": "new_user"
        },
      );

      print("Send OTP Response: $response");
      print("Response error field: ${response['error']}");
      print("Response error type: ${response['error'].runtimeType}");
      print("Send OTP Response: ${response['code']}");

      // التحقق من الاستجابة بطريقة أكثر دقة
      if (response['error']?.toString() == 'true' ||
          response['error']?.toString() == '1') {
        throw Exception(
            response['message']?.toString() ?? 'فشل إرسال رمز التحقق');
      }
    } catch (e) {
      print("Send OTP Error: $e");

      // Check if the error is a DioError and try to extract the message
      if (e is DioError) {
        if (e.response?.data is Map && e.response?.data['message'] != null) {
          throw Exception(e.response!.data['message']);
        }
      }

      if (e.toString().contains('Bearer')) {
        throw Exception('خطأ في المصادقة - يرجى إعادة تسجيل الدخول');
      } else if (e.toString().contains('Exception:')) {
        throw Exception(e.toString().replaceAll('Exception: ', ''));
      } else if (e.toString().contains('SocketException') ||
          e.toString().contains('NetworkException')) {
        throw Exception('تحقق من اتصالك بالإنترنت وحاول مرة أخرى');
      } else {
        // throw Exception('حدث خطأ في إرسال رمز التحقق');
        print("Send OTP Error: $e");
      }
    }
  }

  Future<bool> verifyOtp(
      {required String phone,
      required String otp,
      required String countryCode}) async {
    print("Verifying OTP for phone: $phone, OTP: $otp");

    try {
      final response = await Api.post(
        url: Api.verifyOtpApi,
        parameter: {"phone": phone, "otp": otp, "country_code": countryCode},
      );

      print("OTP Verify Response: $response");

      if (response['code']?.toString() == '200') {
        return true;
      } else {
        String errorMessage =
            response['message']?.toString() ?? 'حدث خطأ في التحقق';
        final code = response['code']?.toString();

        if (code == '410') {
          throw Exception('رمز التحقق منتهي الصلاحية');
        } else if (code == '404') {
          throw Exception('رمز التحقق غير صحيح');
        } else {
          throw Exception(errorMessage);
        }
      }
    } catch (e) {
      print("Verify OTP Error: $e");

      if (e.toString().contains('SocketException') ||
          e.toString().contains('NetworkException')) {
        throw Exception('تحقق من اتصالك بالإنترنت وحاول مرة أخرى');
      } else if (e.toString().contains('Exception:')) {
        throw Exception(e.toString().replaceAll('Exception: ', ''));
      } else {
        rethrow;
      }
    }
  }

  // إرسال OTP لإعادة تعيين كلمة المرور
  Future<void> sendPasswordResetOtp(
      {required String phone, required String countryCode}) async {
    print("Sending password reset OTP to phone: $phone");

    try {
      final response = await Api.post(
        url: Api.sendOtpApi,
        parameter: {
          "country_code": countryCode,
          "phone": phone,
          "type": "password"
        },
      );

      print("Send Password Reset OTP Response: $response");
      print("Response error field: ${response['error']}");
      print("Response error type: ${response['error'].runtimeType}");
      print("Send Password Reset OTP Response: ${response['code']}");

      // التحقق من الاستجابة بطريقة أكثر دقة
      if (response['error']?.toString() == 'true' ||
          response['error']?.toString() == '1') {
        throw Exception(
            response['message']?.toString() ?? 'فشل إرسال رمز التحقق');
      }
    } catch (e) {
      print("Send Password Reset OTP Error: $e");

      // Check if the error is a DioError and try to extract the message
      if (e is DioError) {
        if (e.response?.data is Map && e.response?.data['message'] != null) {
          throw Exception(e.response!.data['message']);
        }
      }

      if (e.toString().contains('Bearer')) {
        throw Exception('خطأ في المصادقة - يرجى إعادة تسجيل الدخول');
      } else if (e.toString().contains('Exception:')) {
        throw Exception(e.toString().replaceAll('Exception: ', ''));
      } else if (e.toString().contains('SocketException') ||
          e.toString().contains('NetworkException')) {
        throw Exception('تحقق من اتصالك بالإنترنت وحاول مرة أخرى');
      } else {
        throw Exception('حدث خطأ في إرسال رمز التحقق');
      }
    }
  }

  // التحقق من OTP لإعادة تعيين كلمة المرور
  Future<bool> verifyPasswordResetOtp(
      {required String phone,
      required String otp,
      required String countryCode}) async {
    print("Verifying password reset OTP for phone: $phone, OTP: $otp");

    try {
      final response = await Api.post(
        url: Api.verifyOtpApi,
        parameter: {"phone": phone, "otp": otp, "country_code": countryCode},
      );

      print("Password Reset OTP Verify Response: $response");

      if (response['code']?.toString() == '200') {
        return true;
      } else {
        String errorMessage =
            response['message']?.toString() ?? 'حدث خطأ في التحقق';
        final code = response['code']?.toString();

        if (code == '410') {
          throw Exception('رمز التحقق منتهي الصلاحية');
        } else if (code == '404') {
          throw Exception('رمز التحقق غير صحيح');
        } else {
          throw Exception(errorMessage);
        }
      }
    } catch (e) {
      print("Verify Password Reset OTP Error: $e");

      if (e.toString().contains('SocketException') ||
          e.toString().contains('NetworkException')) {
        throw Exception('تحقق من اتصالك بالإنترنت وحاول مرة أخرى');
      } else if (e.toString().contains('Exception:')) {
        throw Exception(e.toString().replaceAll('Exception: ', ''));
      } else {
        rethrow;
      }
    }
  }

  // تحديث كلمة المرور بعد التحقق من OTP
  Future<bool> updatePassword(
      {required String phone,
      required String newPassword,
      required String countryCode}) async {
    print("Updating password for phone: $phone");

    try {
      final response = await Api.post(
        url: Api.updatePasswordApi,
        parameter: {
          "phone": phone,
          "password": newPassword,
          "country_code": countryCode
        },
      );

      print("Update Password Response: $response");

      if (response['code']?.toString() == '200') {
        // حفظ بيانات المستخدم والتوكن في Hive
        if (response['data'] != null && response['token'] != null) {
          HiveUtils.setJWT(response['token']);
          HiveUtils.setUserData(response['data']);
          HiveUtils.setUserIsAuthenticated(true);
          await NotificationService.resendPendingTokenIfNeeded();
          print("User logged in automatically after password update");
        }
        return true;
      } else {
        String errorMessage =
            response['message']?.toString() ?? 'حدث خطأ في تحديث كلمة المرور';
        throw Exception(errorMessage);
      }
    } catch (e) {
      print("Update Password Error: $e");

      if (e.toString().contains('SocketException') ||
          e.toString().contains('NetworkException')) {
        throw Exception('تحقق من اتصالك بالإنترنت وحاول مرة أخرى');
      } else if (e.toString().contains('Exception:')) {
        throw Exception(e.toString().replaceAll('Exception: ', ''));
      } else {
        rethrow;
      }
    }
  }
}
