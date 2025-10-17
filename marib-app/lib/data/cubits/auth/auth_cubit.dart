import 'dart:io';

import 'package:dio/dio.dart';
import 'package:marib/utils/api.dart';
import 'package:marib/utils/hive_utils.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marib/data/cubits/system/fetch_system_settings_cubit.dart';

abstract class AuthState {}

class AuthInitial extends AuthState {}

class AuthProgress extends AuthState {}

class Unauthenticated extends AuthState {}

class Authenticated extends AuthState {
  bool isAuthenticated = false;

  Authenticated(this.isAuthenticated);
}

class AuthFailure extends AuthState {
  final String errorMessage;

  AuthFailure(this.errorMessage);
}

class AuthCubit extends Cubit<AuthState> {
  //late String name, email, profile, address;
  AuthCubit() : super(AuthInitial()) {
    // checkIsAuthenticated();
  }

  void checkIsAuthenticated() {
    if (HiveUtils.isUserAuthenticated()) {
      //setUserData();
      emit(Authenticated(true));
    } else {
      emit(Unauthenticated());
    }
  }

  /*Future<String?> getDeviceToken() async {
    String? token;
    if (Platform.isIOS) {
      token = await FirebaseMessaging.instance.getAPNSToken();
    } else {
      token = await FirebaseMessaging.instance.getToken();
    }
    return token;
  }*/

/*  Future updateFCM(BuildContext context) async {
    try {
      await Api.post(
        url: Api.updateProfileApi,
        parameter: {
          Api.fcmId: getDeviceToken,
        },
      );
    } catch (e) {}
  }*/

  Future<Map<String, dynamic>> updateuserdata(BuildContext context,
      {String? name,
      String? email,
      String? address,
      String? location,
      File? fileUserimg,
      String? fcmToken,
      String? notification,
      String? mobile,
      String? countryCode,
      int? personalDetail,
      Map<String, dynamic>? additionalData}) async {
    Map<String, dynamic> parameters = {
      Api.name: name ?? '',
      Api.email: email ?? '',
      Api.address: address ?? '',
      Api.fcmId: fcmToken ?? '',
      Api.notification: notification,
      Api.mobile: mobile,
      Api.countryCode: countryCode,
      Api.personalDetail: personalDetail
    };

    if (location != null && location.isNotEmpty) {
      parameters['location'] = location;
    }

    // إضافة البيانات الإضافية إذا كانت متوفرة
    if (additionalData != null) {
      print('Adding additional data to parameters: $additionalData'); // للتصحيح
      parameters['additional_data'] = additionalData;
    }

    if (fileUserimg != null) {
      parameters['profile'] = await MultipartFile.fromFile(fileUserimg.path);
    }

    try {
      print('Using endpoint: ${Api.updateProfileApi}'); // للتصحيح
      print('Final parameters: $parameters'); // للتصحيح

      var response =
          await Api.post(url: Api.updateProfileApi, parameter: parameters);
      if (!response[Api.error]) {
        HiveUtils.setUserData(response['data']);
        //checkIsAuthenticated();
      }

      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signOut(BuildContext context) async {
    if (state is! Authenticated) {
      return;
    }
    final Authenticated authenticatedState = state as Authenticated;
    if (!authenticatedState.isAuthenticated) {
      return;
    }
    await FetchSystemSettingsCubit.resetDelegateSectionsFor(
      context,
      clearCachedSections: true,
    );
    await HiveUtils.logoutUser(context, onLogout: () {});
    emit(Unauthenticated());
  }
}
