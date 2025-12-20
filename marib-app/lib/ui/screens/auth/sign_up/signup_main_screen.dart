// ================================
// File: lib/ui/screens/auth/signup/sign_up_main_screen.dart
// Purpose: Logic/State holder. Delegates all UI to SignUpMainUI in sign_up_main_ui.dart
// ================================
import 'dart:async';
import 'dart:io';

import 'package:country_picker/country_picker.dart';
import 'package:device_region/device_region.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

import 'package:marib/app/routes.dart';
import 'package:marib/data/cubits/auth/authentication_cubit.dart';
import 'package:marib/data/cubits/system/fetch_system_settings_cubit.dart';
import 'package:marib/data/cubits/system/user_details.dart';
import 'package:marib/data/helper/widgets.dart';
import 'package:marib/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:marib/ui/screens/widgets/blurred_dialoge_box.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/api.dart';
import 'package:marib/utils/constant.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/hive_utils.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:marib/utils/login/lib/login_status.dart';
import 'package:marib/utils/login/lib/payloads.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:marib/utils/notification/notification_service.dart';
import 'package:marib/ui/screens/auth/sign_up/sign_up_main_ui.dart';
import 'package:marib/ui/screens/auth/widgets/auth_status_bar.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class SignUpMainScreen extends StatefulWidget {
  final Map<String, dynamic>? arguments;

  const SignUpMainScreen({super.key, this.arguments});

  @override
  State<SignUpMainScreen> createState() => LoginScreenState();

  static Route route(RouteSettings routeSettings) {
    final args = routeSettings.arguments as Map<String, dynamic>?;
    return BlurredRouter(builder: (_) => SignUpMainScreen(arguments: args));
  }
}

class LoginScreenState extends State<SignUpMainScreen> {
  // ===== Controllers =====
  final TextEditingController mobileCtrl = TextEditingController();
  final TextEditingController emailCtrl = TextEditingController();
  final TextEditingController usernameCtrl = TextEditingController();
  final TextEditingController codeCtrl = TextEditingController();
  final TextEditingController passwordCtrl = TextEditingController();

  // ===== Form / State =====
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  bool isObscure = true;
  bool agreed = false;
  String? selectedAccountType; // 1=individual,2=realEstate,3=commercial
  bool _isAccountTypeModalOpen = false;

  // ===== Country / Phone =====
  String? phone;
  String? countryCode;
  String? countryName;
  String? flagEmoji;

  Timer? timer;
  late Size size;
  final CountryService countryCodeService = CountryService();

  // ===== Flow flags =====
  bool isBack = false;
  bool isFromGoogleLogin = false;
  Map<String, dynamic>? googleData;
  bool _isSubmitting = false;

  Future<String?> _showAccountTypeSelectorSheet() async {
    final Map<String, (String label, IconData icon)> options = {
      "1": ("individual".translate(context), Icons.person),
      "2": ("realEstate".translate(context), Icons.home_work_outlined),
      "3": ("commercial".translate(context), Icons.storefront_outlined),
    };

    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.color.textLightColor.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text("chooseAccountType".translate(context),
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                ...options.entries.map((entry) {
                  final isSelected = selectedAccountType == entry.key;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? context.color.territoryColor
                            : context.color.borderColor.darken(30),
                        width: isSelected ? 2 : 1,
                      ),
                      color: isSelected
                          ? context.color.territoryColor.withOpacity(0.08)
                          : context.color.secondaryColor,
                    ),
                    child: ListTile(
                      leading: Icon(
                        entry.value.$2,
                        color: context.color.territoryColor,
                      ),
                      title: Text(entry.value.$1),
                      trailing: isSelected
                          ? Icon(Icons.check_circle,
                              color: context.color.territoryColor)
                          : null,
                      onTap: () => Navigator.of(ctx).pop(entry.key),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<String?> _showAccountTypeDetailsSheet(String? typeValue) async {
    final String key = _accountTypeAlertKey(typeValue);
    return showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: context.color.textLightColor.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "chooseaccountAlertTitle".translate(context),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    key.translate(context),
                    style: TextStyle(
                      fontSize: context.font.small,
                      color: context.color.textDefaultColor,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: UiUtils.buildButton(
                          context,
                          onPressed: () async {
                            Navigator.of(ctx).pop(null);
                          },
                          buttonTitle: "back".translate(context),
                          radius: 12,
                          border: BorderSide(
                            color: context.color.borderColor.darken(20),
                          ),
                          padding: const EdgeInsets.symmetric(
                              vertical: 14, horizontal: 8),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: UiUtils.buildButton(
                          context,
                          onPressed: () => Navigator.of(ctx).pop(typeValue),
                          buttonTitle: "confirm".translate(context),
                          radius: 12,
                          padding: const EdgeInsets.symmetric(
                              vertical: 14, horizontal: 8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Map<String, dynamic> _buildMerchantDraft(Map<String, dynamic> payload) {
    final draft = Map<String, dynamic>.from(payload);
    draft.remove('password');
    return draft;
  }

  Map<String, dynamic> _sanitizePlaceholderEmail(Map<String, dynamic> data) {
    final Map<String, dynamic> sanitized = Map<String, dynamic>.from(data);
    final dynamic rawEmail = sanitized['email'];
    final String email =
        rawEmail == null ? '' : rawEmail.toString().trim().toLowerCase();

    if (email.isNotEmpty &&
        (email.endsWith('@phone.marib.app') || email.startsWith('user_'))) {
      sanitized['email'] = '';
    }
    return sanitized;
  }

  Future<void> _switchToUser(Map<String, dynamic> apiResponse) async {
    await HiveUtils.logoutUser(
      context,
      onLogout: () {},
      isRedirect: false,
    );
    await HiveUtils.setCorePermissionsSnapshot(false);
    HiveUtils.setJWT(apiResponse['token']);
    HiveUtils.setUserData(_sanitizePlaceholderEmail(apiResponse['data']));
    HiveUtils.setUserIsAuthenticated(true);
    context.read<UserDetailsCubit>().fill(HiveUtils.getUserDetails());
    await NotificationService.resendPendingTokenIfNeeded();
    await FetchSystemSettingsCubit.refreshPermissionsForCurrentUser(
      context,
      clearCacheBeforeFetch: true,
    );
  }

  Future<void> _startMerchantOnboarding(Map<String, dynamic> draft) async {
    await HiveUtils.beginMerchantOnboardingSession(
      initialStep: 0,
      draft: draft,
    );
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pushReplacementNamed(
        Routes.merchantOnboarding,
        arguments: {
          'signupDraft': draft,
          'resumeFromStep': 0,
        },
      );
    });
  }

  StreamSubscription<AuthenticationState>? _authenticationSubscription;
  VoidCallback? _loginStateListenerDisposer;

  void _scheduleLazyInit() {
    if (!mounted) return;

    final authCubit = context.read<AuthenticationCubit>();
    authCubit.init();

    _authenticationSubscription = authCubit.stream.listen((state) {
      if (!mounted) return;
      if (state is AuthenticationSuccess) {
        if (state.type == AuthenticationType.google ||
            state.type == AuthenticationType.apple) {
          _handleSocialLogin(state);
        }
      } else if (state is AuthenticationFail) {
        Widgets.hideLoder(context);
        HelperUtils.showSnackBarMessage(context, state.error.toString());
      } else if (state is AuthenticationInProcess) {
        Widgets.showLoader(context);
      }
    });

    _loginStateListenerDisposer?.call();
    _loginStateListenerDisposer = authCubit.listen((MLoginState state) {
      if (!mounted) return;
      if (state is MOtpSendInProgress) Widgets.showLoader(context);
      if (state is MVerificationPending) {
        Widgets.hideLoder(context);
        setState(() {});
      }
      if (state is MFail) {
        if (state.error is firebase_auth.FirebaseAuthException) {
          try {
            HelperUtils.showSnackBarMessage(
              context,
              (state.error as firebase_auth.FirebaseAuthException)
                  .message
                  .toString(),
            );
          } catch (_) {}
        } else {
          HelperUtils.showSnackBarMessage(context, state.error.toString());
        }
      }
    });

    // Pre-fill country from SIM
    getSimCountry().then((value) {
      if (!mounted) return;

      countryCode = value.phoneCode;
      flagEmoji = value.flagEmoji;
      setState(() {});
    });
  }

  @override
  void initState() {
    super.initState();

    // Pull Google/Apple args if any
    if (widget.arguments != null) {
      isFromGoogleLogin = widget.arguments!['isFromGoogleLogin'] ?? false;
      googleData = widget.arguments!['googleData'];

      if (isFromGoogleLogin && googleData != null) {
        usernameCtrl.text = googleData!['name'] ?? '';
        emailCtrl.text = googleData!['email'] ?? '';
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scheduleLazyInit();
    });
  }

  @override
  void dispose() {
    _loginStateListenerDisposer?.call();
    _loginStateListenerDisposer = null;
    timer?.cancel();
    _authenticationSubscription?.cancel();
    _authenticationSubscription = null;
    mobileCtrl.dispose();
    codeCtrl.dispose();
    emailCtrl.dispose();
    usernameCtrl.dispose();
    passwordCtrl.dispose();
    super.dispose();
  }

  /// Obtain SIM country; respects demo flags
  Future<Country> getSimCountry() async {
    final countryList = countryCodeService.getAll();
    String? simCountryCode;

    try {
      simCountryCode = await DeviceRegion.getSIMCountryCode();
    } catch (_) {}

    Country simCountry = countryList.firstWhere(
      (element) {
        if (Constant.isDemoModeOn) {
          return countryList.any(
            (e) => e.phoneCode == Constant.defaultCountryCode,
          );
        } else {
          return element.phoneCode == simCountryCode;
        }
      },
      orElse: () {
        return countryList
            .where((e) => e.phoneCode == Constant.defaultCountryCode)
            .first;
      },
    );

    if (Constant.isDemoModeOn) {
      simCountry = countryList
          .where((e) => e.phoneCode == Constant.demoCountryCode)
          .first;
    }

    return simCountry;
  }

  Future<bool> _ensureSystemSettingsAvailable() async {
    final cubit = context.read<FetchSystemSettingsCubit>();
    final currentState = cubit.state;
    if (currentState is FetchSystemSettingsSuccess) {
      return true;
    }

    Widgets.showLoader(context);
    FetchSystemSettingsState? resolvedState;
    try {
      if (currentState is FetchSystemSettingsInProgress) {
        resolvedState = await cubit.stream.firstWhere(
          (state) =>
              state is FetchSystemSettingsSuccess ||
              state is FetchSystemSettingsFailure,
        );
      } else {
        await cubit.fetchSettings();
        resolvedState = cubit.state;
      }
    } finally {
      Widgets.hideLoder(context);
    }

    if (resolvedState is FetchSystemSettingsFailure) {
      if (mounted) {
        HelperUtils.showSnackBarMessage(
          context,
          resolvedState.errorMessage,
          type: MessageType.error,
        );
      }
      return false;
    }

    return resolvedState is FetchSystemSettingsSuccess;
  }

  Future<void> _openStaticContent({
    required String title,
    required String param,
  }) async {
    final ready = await _ensureSystemSettingsAvailable();
    if (!ready || !mounted) {
      return;
    }

    Navigator.pushNamed(
      context,
      Routes.profileSettings,
      arguments: {
        'title': title,
        'param': param,
      },
    );
  }

  // ====== Social login handler: send to backend, route appropriately ======
  Future<void> _handleSocialLogin(AuthenticationSuccess state) async {
    try {
      final user = state.credential.user;
      if (user == null) return;

      final payload = {
        "firebase_id": user.uid,
        "name": user.displayName ?? "",
        "email": user.email ?? "",
        "profile": user.photoURL ?? "",
        "type": state.type.name,
        "platform_type": Platform.isAndroid ? "android" : "ios",
      };

      final response = await Api.post(url: "user-signup", parameter: payload);

      if (response['error'] == false) {
        HiveUtils.setJWT(response['token']);
        HiveUtils.setUserData(_sanitizePlaceholderEmail(response['data']));

        final userData = response['data'];
        final bool hasAccountType =
            userData['account_type'] != null && userData['account_type'] != 0;
        final bool isEmailVerified = userData['email_verified_at'] != null;
        final bool hasCompleteName =
            userData['name'] != null && userData['name'].toString().isNotEmpty;

        context.read<UserDetailsCubit>().fill(HiveUtils.getUserDetails());

        if (hasAccountType && isEmailVerified && hasCompleteName) {
          HiveUtils.setUserIsAuthenticated(true);
          if ((HiveUtils.getCityName() ?? '').isNotEmpty &&
              HiveUtils.getCityName() != 'null') {
            HelperUtils.killPreviousPages(
                context, Routes.main, {"from": "login"});
          } else {
            Navigator.of(context).pushNamedAndRemoveUntil(
                Routes.main, (route) => false);
          }
        } else {
          final Map<String, dynamic> incomingGoogleData = {
            'name': user.displayName ?? '',
            'email': user.email ?? '',
            'profile': user.photoURL ?? '',
            'firebase_id': user.uid,
          };

          if (!mounted) return;
          setState(() {
            isFromGoogleLogin = true;
            googleData = incomingGoogleData;
            usernameCtrl.text = incomingGoogleData['name'] ?? '';
            emailCtrl.text = incomingGoogleData['email'] ?? '';
          });
        }
        if (selectedAccountType == "3") {
          final draft = _buildMerchantDraft(payload);
          await _startMerchantOnboarding(draft);
          return;
        }
      } else {
        HelperUtils.showSnackBarMessage(context,
            response['message'] ?? "registrationError".translate(context));
      }
    } catch (e) {
      HelperUtils.showSnackBarMessage(context, e.toString());
    } finally {
      Widgets.hideLoder(context);
    }
  }

  // ===== UI callbacks =====
  void onToggleObscure() => setState(() => isObscure = !isObscure);

  void onAgreeChanged(bool v) => setState(() => agreed = v);

  void onAccountTypeChanged(String? v) =>
      setState(() => selectedAccountType = v);

  String _accountTypeAlertKey(String? value) {
    if (value == null) {
      return "chooseaccountAlertcontentDefault";
    }
    final String normalized = value.trim().toLowerCase();
    const Map<String, String> mapping = {
      "1": "1",
      "2": "2",
      "3": "3",
      "individual": "1",
      "realestate": "2",
      "commercial": "3",
    };
    final String? resolved = mapping[normalized];
    if (resolved == null || resolved.isEmpty) {
      return "chooseaccountAlertcontentDefault";
    }
    return "chooseaccountAlertcontent$resolved";
  }

  void onShowCountryPicker() {
    showCountryPicker(
      context: context,
      showWorldWide: true,
      showPhoneCode: true,
      countryListTheme:
          CountryListThemeData(borderRadius: BorderRadius.circular(11)),
      onSelect: (Country value) {
        flagEmoji = value.flagEmoji;
        if (!mounted) return;
        countryCode = value.phoneCode;
        setState(() {});
      },
    );
  }

  Future<Map<String, dynamic>?> _prepareLocationPayload() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        HelperUtils.showSnackBarMessage(
          context,
          'locationServicesDisabledMarib'.translate(context),
          messageDuration: 3,
          type: MessageType.warning,
        );
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        HelperUtils.showSnackBarMessage(
          context,
          'locationPermissionDeniedMarib'.translate(context),
          messageDuration: 3,
          type: MessageType.warning,
        );
        return null;
      }

      if (permission == LocationPermission.deniedForever) {
        HelperUtils.showSnackBarMessage(
          context,
          'locationPermissionDeniedForeverMarib'.translate(context),
          messageDuration: 3,
          type: MessageType.warning,
        );
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      String? adminArea;
      Map<String, dynamic>? meta;

      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (placemarks.isNotEmpty) {
          final placemark = placemarks.first;
          adminArea = placemark.administrativeArea ?? placemark.locality;
          final possibleMeta = <String, dynamic>{
            'administrativeArea': placemark.administrativeArea,
            'locality': placemark.locality,
            'country': placemark.country,
            'isoCountryCode': placemark.isoCountryCode,
            'street': placemark.street,
          };
          possibleMeta.removeWhere(
            (key, value) =>
                value == null || (value is String && value.trim().isEmpty),
          );
          if (possibleMeta.isNotEmpty) {
            meta = possibleMeta;
          }
        }
      } catch (_) {}

      final payload = <String, dynamic>{
        'lat': position.latitude,
        'lng': position.longitude,
        'device_time': DateTime.now().toIso8601String(),
      };

      if (adminArea != null && adminArea.trim().isNotEmpty) {
        payload['admin_area'] = adminArea;
      }

      if (meta != null && meta.isNotEmpty) {
        payload['meta'] = meta;
      }

      return payload;
    } catch (_) {
      HelperUtils.showSnackBarMessage(
        context,
        'errorGettingLocationMarib'.translate(context),
        messageDuration: 3,
        type: MessageType.warning,
      );
      return null;
    }
  }

  // Submit action for primary button
  Future<void> onSubmit() async {
    final form = formKey.currentState;
    if (form == null) return;
    form.save();

    if (!form.validate()) return;
    if (_isSubmitting) {
      return;
    }

    if (!agreed) {
      HelperUtils.showSnackBarMessage(
        context,
        'mustAgreeToTermsAndPrivacy'.translate(context),
        messageDuration: 3,
        type: MessageType.warning,
      );
      return;
    }
    if (selectedAccountType == null || selectedAccountType!.isEmpty) {
      HelperUtils.showSnackBarMessage(
        context,
        'mustSelectAccountType'.translate(context),
        messageDuration: 3,
        type: MessageType.warning,
      );
      return;
    }

    _isSubmitting = true;
    Widgets.showLoader(context);
    bool _navigationTriggered = false;
    bool _signUpSuccess = false;
    void _goHome() {
      if (_navigationTriggered) return;
      _navigationTriggered = true;
      Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil(
        Routes.main,
        (route) => false,
        arguments: {"from": "signup"},
      );
    }

    // نطلب الموقع فقط إذا أدخل المستخدم كود إحالة (للتحقق من نطاق مأرب)
    final String referralCode = codeCtrl.text.trim();
    Map<String, dynamic> locationPayload = {};
    if (referralCode.isNotEmpty) {
      final loc = await _prepareLocationPayload();
      if (loc != null) {
        locationPayload = loc;
      }
    }

    try {
      final basePayload = <String, dynamic>{
        "name": usernameCtrl.text,
        "mobile": mobileCtrl.text,
        "password": passwordCtrl.text,
        "account_type": selectedAccountType ?? "1",
        "country_code": countryCode?.toString() ?? "",
        "country_name": countryName ?? "Unknown",
        "flag_emoji": flagEmoji ?? "ye",
        "platform_type": Platform.isAndroid ? "android" : "ios",
        ...locationPayload,
      };
      final String trimmedEmail = emailCtrl.text.trim();
      if (trimmedEmail.isNotEmpty) {
        basePayload["email"] = trimmedEmail;
      }

      if (referralCode.isNotEmpty) {
        basePayload["code"] = referralCode;
      }

      Map<String, dynamic> payload;

      if (isFromGoogleLogin && googleData != null) {
        // Complete profile for social login
        payload = {
          ...basePayload,
          "type": "google",
          "firebase_id": googleData!['firebase_id'],
          "profile": googleData!['profile'] ?? "",
        };
      } else {
        // Phone signup path
        final currentUser = firebase_auth.FirebaseAuth.instance.currentUser;
        final String firebaseId =
            (currentUser?.uid ?? '').isNotEmpty ? currentUser!.uid : mobileCtrl.text;

        payload = {
          ...basePayload,
          "type": "phone",
          "firebase_id": firebaseId,
        };
      }

      final response = await Api.post(url: "user-signup", parameter: payload);

      if (response['error'] == false) {
        _signUpSuccess = true;
        try {
          await _switchToUser(response);
        } catch (_) {
          // حتى لو فشل تهيئة الجلسة، نتابع التوجيه للصفحة الرئيسية
        }

        if (selectedAccountType == "3") {
          final draft = _buildMerchantDraft(basePayload);
          await _startMerchantOnboarding(draft);
          return;
        }

        if (!mounted) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          _goHome();
        });
      } else {
        HelperUtils.showSnackBarMessage(
          context,
          response['message'] ?? "registrationError".translate(context),
          messageDuration: 3,
        );
      }
    } catch (e) {
      HelperUtils.showSnackBarMessage(context, e.toString(),
          messageDuration: 3);
    } finally {
      Widgets.hideLoder(context);
      _isSubmitting = false;
      if (!mounted) return;
      if (_signUpSuccess &&
          !_navigationTriggered &&
          selectedAccountType != "3") {
        _goHome();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // معرفة حجم الشاشة
    size = MediaQuery.of(context).size;
    final Color statusBarBase = LoginStatusBar.resolveBaseColor(
      context,
      override: context.color.backgroundColor,
    );

    final settingsState = context.watch<FetchSystemSettingsCubit>().state;
    final bool isSettingsReady = settingsState is FetchSystemSettingsSuccess;
    final bool isSettingsLoading =
        settingsState is FetchSystemSettingsInProgress;

    // تهيئة الـ ViewModel (البيانات الخاصة بشاشة التسجيل)
    final vm = SignUpVM(
      formKey: formKey,
      mobileCtrl: mobileCtrl,
      emailCtrl: emailCtrl,
      usernameCtrl: usernameCtrl,
      codeCtrl: codeCtrl,
      passwordCtrl: passwordCtrl,
      countryCode: countryCode,
      countryName: countryName,
      flagEmoji: flagEmoji,
      isFromGoogleLogin: isFromGoogleLogin,
      googleData: googleData,
      isObscure: isObscure,
      agreed: agreed,
      selectedAccountType: selectedAccountType,
      isSystemSettingsReady: isSettingsReady,
      isSystemSettingsLoading: isSettingsLoading,
    );

    // تعريف الكولباكات (Callbacks) للأحداث المختلفة
    final callbacks = SignUpCallbacks(
      onToggleObscure: onToggleObscure,
      onAgreeChanged: onAgreeChanged,
      onAccountTypeChanged: (v) async {
        if (_isAccountTypeModalOpen || v == selectedAccountType) return;
        _isAccountTypeModalOpen = true;
        final confirmed = await _showAccountTypeDetailsSheet(v);
        if (confirmed != null) {
          onAccountTypeChanged(confirmed);
        }
        _isAccountTypeModalOpen = false;
      },
      onShowCountryPicker: onShowCountryPicker,
      onSubmit: onSubmit,
      onNavigateToLogin: () => Navigator.pushNamed(context, Routes.login),
      onOpenStaticContent: ({required String title, required String param}) {
        return _openStaticContent(title: title, param: param);
      },
      onGoogleAuth: () {
        context.read<AuthenticationCubit>().setData(
              payload: GoogleLoginPayload(),
              type: AuthenticationType.google,
            );
        context.read<AuthenticationCubit>().authenticate();
      },
      onAppleAuth: () {
        context.read<AuthenticationCubit>().setData(
              payload: AppleLoginPayload(),
              type: AuthenticationType.apple,
            );
        context.read<AuthenticationCubit>().authenticate();
      },
    );

    // واجهة الشاشة
    final SystemUiOverlayStyle overlay = SystemUiOverlayStyle(
      statusBarColor: Colors.white,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    );

    SystemChrome.setSystemUIOverlayStyle(overlay);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay,
      child: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: PopScope(
            canPop: isBack,
            onPopInvokedWithResult: (didPop, __) =>
                setState(() => isBack = true),
            child: Scaffold(
              resizeToAvoidBottomInset: false,
              backgroundColor: context.color.backgroundColor,
              body: SignUpMainUI(
                vm: vm,
                callbacks: callbacks,
                statusBarBase: statusBarBase,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
