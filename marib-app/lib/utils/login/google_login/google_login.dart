import 'package:marib/utils/login/lib/login_status.dart';
import 'package:marib/utils/login/lib/login_system.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:marib/data/helper/widgets.dart';
import 'package:marib/utils/constant.dart';






class GoogleLogin extends LoginSystem {
  GoogleSignIn? _googleSignIn;

  @override
  void init() {
    _googleSignIn = GoogleSignIn(
      scopes: ["profile", "email"],
    );
    // إعادة تعيين حالة تسجيل الدخول عند التهيئة
    _resetGoogleSignIn();
  }

  // إعادة تعيين حالة Google Sign In
  void _resetGoogleSignIn() async {
    try {
      await _googleSignIn?.signOut();
    } catch (e) {
      // تجاهل الأخطاء في إعادة التعيين
    }
  }

  @override
  Future<UserCredential?> login() async {
    try {
      emit(MProgress());
      GoogleSignInAccount? googleSignIn = await _googleSignIn?.signIn();
      if (googleSignIn == null) {
        print("google-terminated");
        throw ErrorDescription("google-terminated");
      }

      GoogleSignInAuthentication? googleAuth =
          await googleSignIn.authentication;

      AuthCredential authCredential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential =
          await firebaseAuth.signInWithCredential(authCredential);
      emit(MSuccess());

      return userCredential;
    } catch (e) {
      if (e is ErrorDescription) {
        emit(MFail("google-terminated"));
      } else {
        emit(MFail(e.toString()));
      }

      rethrow;
    }
  }

  @override
  void onEvent(MLoginState state) {
    final context = Constant.navigatorKey.currentContext;

    if (state is MProgress) {
      if (context != null) {
        Widgets.showLoader(context);
      }
      return;
    }

    if (state is MFail) {
      _resetGoogleSignIn();
      if (context != null) {
        Widgets.hideLoder(context);
      }
    }

  }
}
