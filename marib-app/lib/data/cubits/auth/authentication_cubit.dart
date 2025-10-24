import 'dart:io';
import 'package:marib/utils/constant.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/login/apple_login/apple_login.dart';
import 'package:marib/utils/login/email_login/email_login.dart';
import 'package:marib/utils/login/google_login/google_login.dart';
import 'package:marib/utils/login/phone_login/phone_login.dart';
import 'package:marib/utils/login/lib/login_system.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:marib/utils/login/lib/login_status.dart';
import 'package:marib/utils/login/lib/payloads.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';



enum AuthenticationType {
  email,
  google,
  apple,
  phone;
}

abstract class AuthenticationState {}

class AuthenticationInitial extends AuthenticationState {}

class AuthenticationInProcess extends AuthenticationState {
  final AuthenticationType type;

  AuthenticationInProcess(this.type);
}

class AuthenticationSuccess extends AuthenticationState {
  final AuthenticationType type;
  final UserCredential credential;
  final LoginPayload payload;

  AuthenticationSuccess(this.type, this.credential, this.payload);
}

// حالة جديدة لتسجيل الدخول بالهاتف وكلمة المرور بدون Firebase
class AuthenticationSuccessWithoutCredential extends AuthenticationState {
  final AuthenticationType type;
  final LoginPayload payload;

  AuthenticationSuccessWithoutCredential(this.type, this.payload);
}

class AuthenticationFail extends AuthenticationState {
  final dynamic error;

  AuthenticationFail(this.error);
}

class AuthenticationCubit extends Cubit<AuthenticationState> {
  AuthenticationCubit() : super(AuthenticationInitial());
  AuthenticationType? type;
  LoginPayload? payload;
  MMultiAuthentication mMultiAuthentication = MMultiAuthentication({
    "google": GoogleLogin(),
    "email": EmailLogin(),
    if (Platform.isIOS) "apple": AppleLogin(),
    "phone": PhoneLogin()
  });

  void init() {
    mMultiAuthentication.init();
  }

  void setData(
      {required LoginPayload payload, required AuthenticationType type}) {
    this.type = type;
    this.payload = payload;
  }

  void authenticate() async {
    if (type == null && payload == null) {
      return;
    }

    try {
      emit(AuthenticationInProcess(type!));
      mMultiAuthentication.setActive(type!.name);
      mMultiAuthentication.payload = MultiLoginPayload({
        type!.name: payload!,
      });

      UserCredential? credential = await mMultiAuthentication.login();

      LoginPayload? payloadData = (payload);

      // التعامل الخاص بـ phone password login
      if (payloadData is PhoneAndPasswordPayload &&
          payloadData.type == EmailLoginType.login &&
          type == AuthenticationType.phone) {
        // التحقق من نجاح العملية من PhoneLogin system
        PhoneLogin phoneLoginSystem =
            mMultiAuthentication.systems["phone"] as PhoneLogin;
        if (phoneLoginSystem.isPhonePasswordLoginSuccess) {
          // إرسال حالة النجاح بدون credentials
          emit(AuthenticationSuccessWithoutCredential(type!, payload!));
          return;
        }
      }

      if (payloadData is PhoneAndPasswordPayload &&
          payloadData.type == EmailLoginType.login) {
        if (credential != null) {
          User? user = credential.user;
          if (user != null && !user.emailVerified) {
            // Handle the case when the user's email is not verified
            final context = Constant.navigatorKey.currentContext;
            if (context != null) {
              final message = "pleaseFirstVerifyUser".translate(context);
              HelperUtils.showSnackBarMessage(context, message);
              emit(AuthenticationFail(message));
            } else {
              emit(AuthenticationFail("pleaseFirstVerifyUser"));
            }
          } else {
            emit(AuthenticationSuccess(type!, credential, payload!));
          }
        }
      } else {
        emit(AuthenticationSuccess(type!, credential!, payload!));
      }
    } catch (e) {
      emit(AuthenticationFail(e));
    }
  }

  VoidCallback listen(Function(MLoginState state) fn) {
    return mMultiAuthentication.listen(fn);
  }

  void verify() {
    mMultiAuthentication.setActive(type!.name);
    mMultiAuthentication.payload = MultiLoginPayload({
      type!.name: payload!,
    });
    mMultiAuthentication.requestVerification();
  }
}
