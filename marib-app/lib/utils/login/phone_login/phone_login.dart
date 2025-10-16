// import 'package:marib/utils/login/lib/login_status.dart';
// import 'package:marib/utils/login/lib/payloads.dart';
// import 'package:firebase_auth/firebase_auth.dart';

// import 'package:marib/utils/constant.dart';
// import 'package:marib/utils/login/lib/login_system.dart';

// class PhoneLogin extends LoginSystem {
//   String? verificationId;

//   @override
//   Future<UserCredential?> login() async {
//     try {
//       emit(MProgress());
//       // (state);

//       PhoneAuthCredential credential = PhoneAuthProvider.credential(
//           verificationId: verificationId ?? "",
//           smsCode: (payload as PhoneLoginPayload).getOTP()!);

//       UserCredential userCredential =
//           await firebaseAuth.signInWithCredential(credential);

//       emit(MSuccess());

//       return userCredential;
//     } catch (e) {
//       emit(MFail(e));
//     }
//     return null;
//   }

//   @override
//   Future<void> requestVerification() async {
//     emit(MOtpSendInProgress());
//     await FirebaseAuth.instance
//         .verifyPhoneNumber(
//           timeout: Duration(
//             seconds: Constant.otpTimeOutSecond,
//           ),
//           phoneNumber:
//               "+${(payload as PhoneLoginPayload).countryCode}${(payload as PhoneLoginPayload).phoneNumber}",
//           verificationCompleted: (PhoneAuthCredential credential) {},
//           verificationFailed: (FirebaseAuthException e) {
//             emit(MFail(e));
//           },
//           codeSent: (String verificationId, int? resendToken) {
//             super.requestVerification();
//             forceResendingToken = resendToken;
//             this.verificationId = verificationId;
//           },
//           codeAutoRetrievalTimeout: (String verificationId) {},
//           forceResendingToken: forceResendingToken,
//         )
//         .then((value) {});
//   }

//   @override
//   void onEvent(MLoginState state) {}
// }

import 'package:marib/utils/login/lib/login_status.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:marib/utils/login/lib/login_system.dart';
import 'package:marib/utils/login/lib/payloads.dart';
import 'package:marib/utils/api.dart';
import 'package:marib/utils/hive_utils.dart';
import 'package:marib/data/repositories/auth_repository.dart';

class PhoneLogin extends LoginSystem {
  bool _isPhonePasswordLoginSuccess = false;
  UserCredential? userCredential;

  // إعادة تعيين الحالة قبل كل عملية تسجيل دخول
  void resetState() {
    _isPhonePasswordLoginSuccess = false;
  }

  @override
  void init() {
    super.init();
    // إعادة تعيين الحالة عند التهيئة
    resetState();
  }

  @override
  Future<UserCredential?> login() async {
    UserCredential? userCredential;

    if (payload is PhoneLoginPayload) {
      var payloadData = (payload as PhoneLoginPayload);
      String phoneNumber = payloadData.phoneNumber;
      String countryCode = payloadData.countryCode;

      // تسجيل الدخول بـ OTP عبر Firebase
      await firebaseAuth.verifyPhoneNumber(
        timeout: const Duration(seconds: 60),
        phoneNumber: "+$countryCode$phoneNumber",
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            userCredential =
                await firebaseAuth.signInWithCredential(credential);
            emit(MSuccess());
          } catch (e) {
            emit(MFail(e));
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          emit(MFail(e));
        },
        codeSent: (String verificationId, int? resendToken) {
          AuthRepository.forceResendingToken = resendToken;
          emit(MVerificationPending());
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          // Handle auto retrieval timeout
        },
      );
    } else if (payload is PhoneAndPasswordPayload) {
      var payloadData = (payload as PhoneAndPasswordPayload);

      try {
        resetState(); // إعادة تعيين الحالة قبل البدء
        emit(MProgress());

        // إرسال البيانات إلى الباكيند الخاص بك للتحقق من صحة تسجيل الدخول
        Map<String, dynamic> loginResponse = await Api.post(
          url: Api.userLoginApi,
          parameter: {
            Api.mobile: payloadData.phoneNumber,
            Api.type: "phone_password",
            'password': payloadData.password, // إضافة كلمة المرور
          },
        );

        if (!loginResponse[Api.error]) {
          // حفظ بيانات المستخدم في Hive مباشرة بدون Firebase
          HiveUtils.setJWT(loginResponse['token']);
          HiveUtils.setUserData(loginResponse['data']);
          HiveUtils.setUserIsAuthenticated(true);

          // تعيين علامة النجاح
          _isPhonePasswordLoginSuccess = true;

          emit(MSuccess());

          // إرجاع null لكن سيتم التعامل معه بشكل خاص في AuthenticationCubit
          userCredential = null;
        } else {
          String errorMessage = loginResponse[Api.message] ??
              loginResponse['message'] ??
              'loginFailedCheckCredentials';
          emit(MFail(errorMessage));
        }
      } catch (e) {
        emit(MFail(e));
      }
    }
    return userCredential;
  }

  @override
  Future<void> requestVerification() async {
    if (payload is PhoneLoginPayload) {
      var payloadData = (payload as PhoneLoginPayload);
      String phoneNumber = payloadData.phoneNumber;
      String countryCode = payloadData.countryCode;

      try {
        await firebaseAuth.verifyPhoneNumber(
          forceResendingToken: AuthRepository.forceResendingToken,
          timeout: const Duration(seconds: 60),
          phoneNumber: "+$countryCode$phoneNumber",
          verificationCompleted: (PhoneAuthCredential credential) async {
            userCredential =
                await firebaseAuth.signInWithCredential(credential);
            emit(MSuccess());
          },
          verificationFailed: (FirebaseAuthException e) {
            emit(MFail(e));
          },
          codeSent: (String verificationId, int? resendToken) {
            AuthRepository.forceResendingToken = resendToken;
            emit(MVerificationPending());
          },
          codeAutoRetrievalTimeout: (String verificationId) {},
        );
      } catch (e) {
        emit(MFail(e));
      }
    }
  }

  // إضافة دالة للتحقق من نجاح العملية
  bool get isPhonePasswordLoginSuccess => _isPhonePasswordLoginSuccess;

  @override
  void onEvent(MLoginState state) {}
}
