// ignore_for_file: public_member_api_docs, sort_constructors_first

import 'dart:io';

import 'package:marib/utils/api.dart';
import 'package:marib/utils/hive_utils.dart';
import 'package:marib/data/repositories/auth_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:marib/data/cubits/auth/authentication_cubit.dart';

abstract class LoginState {}

class LoginInitial extends LoginState {}

class LoginInProgress extends LoginState {}

class LoginSuccess extends LoginState {
  final bool isProfileCompleted;
  final UserCredential credential;
  final Map<String, dynamic> apiResponse;
  final bool isNewUser;

  LoginSuccess({
    required this.isProfileCompleted,
    required this.credential,
    required this.apiResponse,
    required this.isNewUser,
  });
}

// حالة جديدة لنجاح تسجيل الدخول بدون Firebase
class LoginSuccessWithoutCredential extends LoginState {
  final bool isProfileCompleted;
  final Map<String, dynamic> apiResponse;

  LoginSuccessWithoutCredential({
    required this.isProfileCompleted,
    required this.apiResponse,
  });
}

class LoginFailure extends LoginState {
  final dynamic errorMessage;

  LoginFailure(this.errorMessage);
}

class LoginCubit extends Cubit<LoginState> {
  LoginCubit() : super(LoginInitial());

  final AuthRepository _authRepository = AuthRepository();

  Future<String?> getDeviceToken() async {
    String? token;
    if (Platform.isIOS) {
      token = await FirebaseMessaging.instance.getAPNSToken();
    } else {
      token = await FirebaseMessaging.instance.getToken();
    }
    return token;
  }

  // الطريقة الجديدة لتسجيل الدخول بالهاتف مباشرة من backend
  void phonePasswordLogin({
    required String phoneNumber,
    required String password,
  }) async {
    try {
      emit(LoginInProgress());

      // الحصول على FCM token
      String? token = await () async {
        try {
          return await FirebaseMessaging.instance.getToken();
        } catch (_) {
          return '';
        }
      }();

      // إرسال البيانات إلى backend
      Map<String, dynamic> result = await Api.post(
        url: Api.userLoginApi,
        parameter: {
          Api.mobile: phoneNumber,
          Api.type: "phone_password",
          'password': password,
          Api.fcmId: token,
          Api.platformType: Platform.isAndroid ? "android" : "ios",
        },
      );

      // حفظ بيانات المستخدم
      HiveUtils.setJWT(result['token']);
      HiveUtils.setUserIsAuthenticated(true);

      // التحقق من اكتمال الملف الشخصي
      bool isProfileCompleted = (result['data']['name'] != null &&
              result['data']['name'] != "") &&
          (result['data']['email'] != null && result['data']['email'] != "");

      if (!isProfileCompleted) {
        HiveUtils.setProfileNotCompleted();
      }

      HiveUtils.setUserData(result['data']);

      emit(LoginSuccessWithoutCredential(
        apiResponse: Map<String, dynamic>.from(result['data']),
        isProfileCompleted: isProfileCompleted,
      ));
    } catch (e) {
      emit(LoginFailure(e));
    }
  }

  void login({
    String? phoneNumber,
    required String firebaseUserId,
    required String type,
    required UserCredential credential,
    String? countryCode,
  }) async {
    try {
      emit(LoginInProgress());

      /*String? token = await getDeviceToken();*/
      String? token = await () async {
        try {
          return await FirebaseMessaging.instance.getToken();
        } catch (_) {
          return '';
        }
      }();

      FirebaseAuth firebaseAuth = FirebaseAuth.instance;

      User? updatedUser;
      if (type == AuthenticationType.apple.name) {
        updatedUser = firebaseAuth.currentUser;
        if (updatedUser != null) {
          print("Updated Display Name: ${updatedUser.displayName}");
        }
        await credential.user!.reload();
      }

      Map<String, dynamic> result = await _authRepository.numberLoginWithApi(
        phone: phoneNumber ?? credential.user!.providerData[0].phoneNumber,
        type: type,
        uid: firebaseUserId,
        fcmId: token,
        email: credential.user!.providerData[0].email,
        name: type == AuthenticationType.apple.name
            ? updatedUser?.displayName ??
                credential.user!.displayName ??
                credential.user!.providerData[0].displayName
            : credential.user!.providerData[0].displayName,
        profile: credential.user!.providerData[0].photoURL,
        countryCode: countryCode,
      );

      // Storing data to local database {HIVE}
      HiveUtils.setJWT(result['token']);

      if ((result['data']['name'] == "" || result['data']['name'] == null) ||
          (result['data']['email'] == "" || result['data']['email'] == null)) {
        HiveUtils.setProfileNotCompleted();

        var data = result['data'];
        // data['countryCode'] = countryCode;
        HiveUtils.setUserData(data);
        emit(LoginSuccess(
          apiResponse: Map<String, dynamic>.from(result['data']),
          isProfileCompleted: false,
          credential: credential,
          isNewUser: result['isNewUser'] == true,
        ));
      } else {
        var data = result['data'];
        // data['countryCode'] = countryCode;
        HiveUtils.setUserData(data);
        emit(LoginSuccess(
          apiResponse: Map<String, dynamic>.from(result['data']),
          isProfileCompleted: true,
          credential: credential,
          isNewUser: result['isNewUser'] == true,
        ));
      }
    } catch (e) {
      if (e is ApiException) {}

      emit(LoginFailure(e));
    }
  }
}
