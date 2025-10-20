import 'dart:async';
import 'dart:developer';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lottie/lottie.dart';

import 'package:marib/app/routes.dart';
import 'package:marib/data/cubits/system/fetch_language_cubit.dart';
import 'package:marib/data/cubits/system/fetch_system_settings_cubit.dart';
import 'package:marib/data/cubits/system/language_cubit.dart';
import 'package:marib/data/model/system_settings_model.dart';
import 'package:marib/settings.dart';
import 'package:marib/ui/screens/widgets/errors/no_internet.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/constant.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/hive_utils.dart';
import 'package:marib/utils/screen_scaler.dart';
import 'package:marib/utils/ui_utils.dart';

///==============================
/// المنطق: SplashController
///==============================
class SplashController extends ChangeNotifier {
  SplashController(this.context);

  final BuildContext context;

  // الحالة الداخلية
  bool hasInternet = true;
  bool isTimerCompleted = false;
  bool isSettingsLoaded = false;
  bool isLanguageLoaded = false;

  StreamSubscription<List<ConnectivityResult>>? _connSub;
  StreamSubscription<FetchLanguageState>? _langSub;
  StreamSubscription<FetchSystemSettingsState>? _settingsSub;
  Completer<String?>? _defaultLanguageCompleter;
  String? _defaultLanguageFromSettings;
  Timer? _timer;
  Timer? _fallbackTimer;

  /// بدء العمل
  void init() {
    _bindCubitStreams();
    _setupFallbackTimeout();
    _subscribeConnectivity();
  }

  /// إلغاء الاشتراكات
  @override
  void dispose() {
    _connSub?.cancel();
    _langSub?.cancel();
    _settingsSub?.cancel();
    _timer?.cancel();
    _fallbackTimer?.cancel();
    super.dispose();
  }

  /// ربط ستريمات الـ Cubits لسماع النجاح/الفشل بدون منطق داخل الواجهة
  void _bindCubitStreams() {
    _langSub = context.read<FetchLanguageCubit>().stream.listen((state) {
      if (state is FetchLanguageSuccess) {
        final map = state.toMap();
        final data = map['file_name'];
        map['data'] = data;
        map.remove('file_name');

        HiveUtils.storeLanguage(map);
        context.read<LanguageCubit>().emit(LanguageLoader(map));

        isLanguageLoaded = true;
        notifyListeners();
        _tryNavigate();
      } else if (state is FetchLanguageFailure) {
        isLanguageLoaded = true; // استخدم الافتراضي
        notifyListeners();
        _tryNavigate();
      }
    });

    _settingsSub =
        context.read<FetchSystemSettingsCubit>().stream.listen((state) {
      if (state is FetchSystemSettingsSuccess) {
        Constant.isDemoModeOn = context
            .read<FetchSystemSettingsCubit>()
            .getSetting(SystemSetting.demoMode);
        _defaultLanguageFromSettings = _resolveDefaultLanguageCode();
        _completeDefaultLanguageWaiters();

        isSettingsLoaded = true;
        notifyListeners();
        _tryNavigate();
      } else if (state is FetchSystemSettingsFailure) {
        _completeDefaultLanguageWaiters();

        isSettingsLoaded = true; // استخدم الافتراضي
        notifyListeners();
        _tryNavigate();
      }
    });
  }

  /// اشتراك حالة الإنترنت
  void _subscribeConnectivity() {
    _connSub = Connectivity().onConnectivityChanged.listen((results) {
      final online = !results.contains(ConnectivityResult.none);
      if (hasInternet != online) {
        hasInternet = online;
        notifyListeners();
      }

      if (online) {
        _startProcessesOnce();
      }
    });

    // محاولة أولية (بعض الأجهزة لا ترسل أول حدث بسرعة)
    Connectivity().checkConnectivity().then((results) {
      final online = !results.contains(ConnectivityResult.none);
      hasInternet = online;
      notifyListeners();
      if (online) _startProcessesOnce();
    });
  }

  bool _started = false;

  void _startProcessesOnce() {
    if (_started) return;
    _started = true;

    _getDefaultLanguage();
    _fetchSystemSettings();
    _startTimer();
  }

  /// تحميل اللغة الافتراضية (نستخدم العربية كافتراضي)
  Future<void> _getDefaultLanguage() async {
    try {
      final codeFromSettings = await _waitForDefaultLanguageCode();
      final code = (codeFromSettings != null && codeFromSettings.isNotEmpty)
          ? codeFromSettings
          : "ar";

      final stored = HiveUtils.getLanguage();
      if (stored == null ||
          stored['data'] == null ||
          HiveUtils.isUserFirstTime() == true) {
        context.read<FetchLanguageCubit>().getLanguage(code);
      } else {
        isLanguageLoaded = true;
        notifyListeners();
        _tryNavigate();
      }
    } catch (e) {
      log("Error while load default language $e");
      // جرّب العربية مباشرة
      try {
        context.read<FetchLanguageCubit>().getLanguage("ar");
      } catch (_) {
        isLanguageLoaded = true;
        notifyListeners();
        _tryNavigate();
      }
    }
  }

  /// تحميل الإعدادات
  void _fetchSystemSettings() {
    context.read<FetchSystemSettingsCubit>().fetchSettings(forceRefresh: true);
  }

  Future<String?> _waitForDefaultLanguageCode() async {
    if (_defaultLanguageFromSettings != null &&
        _defaultLanguageFromSettings!.isNotEmpty) {
      return _defaultLanguageFromSettings;
    }

    final cubit = context.read<FetchSystemSettingsCubit>();
    if (cubit.state is FetchSystemSettingsSuccess) {
      _defaultLanguageFromSettings = _resolveDefaultLanguageCode();
      if (_defaultLanguageFromSettings != null &&
          _defaultLanguageFromSettings!.isNotEmpty) {
        return _defaultLanguageFromSettings;
      }
    }

    _defaultLanguageCompleter ??= Completer<String?>();
    return _defaultLanguageCompleter!.future
        .timeout(const Duration(seconds: 5), onTimeout: () => null);
  }

  String? _resolveDefaultLanguageCode() {
    try {
      final raw = context
          .read<FetchSystemSettingsCubit>()
          .getSetting(SystemSetting.defaultLanguage);
      if (raw is String) {
        return raw.trim();
      }
    } catch (_) {
      // ignore
    }
    return null;
  }

  void _completeDefaultLanguageWaiters() {
    if (_defaultLanguageCompleter != null &&
        !_defaultLanguageCompleter!.isCompleted) {
      _defaultLanguageCompleter!.complete(_defaultLanguageFromSettings);
      _defaultLanguageCompleter = null;
    }
  }

  /// مؤقت بسيط لعرض السبلّاش
  void _startTimer() {
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 5), () {
      isTimerCompleted = true;
      notifyListeners();
      _tryNavigate();
    });
  }

  /// خطة طوارئ: لا تنتظر أكثر من 10 ثوان
  void _setupFallbackTimeout() {
    _fallbackTimer?.cancel();
    _fallbackTimer = Timer(const Duration(seconds: 10), () {
      if (!isSettingsLoaded || !isLanguageLoaded) {
        isSettingsLoaded = true;
        isLanguageLoaded = true;
        notifyListeners();
        _tryNavigate();
      }
    });
  }

  /// محاولة التنقل عندما تكتمل الشروط
  void _tryNavigate() {
    if (!isTimerCompleted || !isSettingsLoaded || !isLanguageLoaded) return;

    final maintenance = context
            .read<FetchSystemSettingsCubit>()
            .getSetting(SystemSetting.maintenanceMode) ==
        "1";

    if (maintenance) {
      _go(() =>
          Navigator.of(context).pushReplacementNamed(Routes.maintenanceMode));
      return;
    }

    if (HiveUtils.isUserFirstTime() == true) {
      _go(() => Navigator.of(context).pushReplacementNamed(Routes.onboarding));
      return;
    }

    if (HiveUtils.isUserAuthenticated()) {
      final user = HiveUtils.getUserDetails();
      final missingName = (user.name == null || user.name == "");
      final missingEmail = (user.email == null || user.email == "");
      if (missingName || missingEmail) {
        _go(() {
          Navigator.pushReplacementNamed(
            context,
            Routes.completeProfile,
            arguments: {"from": "login"},
          );
        });
      } else {
        _go(() => Navigator.of(context)
            .pushReplacementNamed(Routes.main, arguments: {'from': "main"}));
      }
      return;
    }

    if (HiveUtils.isUserBasicallyAuthenticated()) {
      try {
        final u = HiveUtils.getUserDetails();
        if (u.userType == null || u.userType == 0) {
          _go(() {
            Navigator.pushReplacementNamed(
              context,
              Routes.signup,
              arguments: {
                'selectedAccountType': null,
                'fromSocialLogin': true,
              },
            );
          });
        } else if (!HiveUtils.isUserVerified()) {
          _go(() => Navigator.pushReplacementNamed(context, Routes.login));
        }
      } catch (_) {
        _go(() => Navigator.pushReplacementNamed(context, Routes.login));
      }
      return;
    }

    // ضيف/تخطي
    _go(() {
      if (HiveUtils.isUserSkip() == true) {
        Navigator.of(context)
            .pushReplacementNamed(Routes.main, arguments: {'from': "main"});
      } else {
        Navigator.of(context).pushReplacementNamed(Routes.login);
      }
    });
  }

  /// تنفيذ آمن بعد إطار الرسم
  void _go(VoidCallback nav) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (Navigator.of(context).mounted) nav();
    });
  }

  /// زر إعادة المحاولة من شاشة عدم الاتصال
  void retry() {
    _startProcessesOnce();
  }
}

///==============================
/// الواجهة: SplashScreen
///==============================
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  SplashScreenState createState() => SplashScreenState();
}

class SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final SplashController _controller;
  late final AnimationController _dotsController;
  bool _showIntroUi = false;
  Timer? _introTimer;

  @override
  void initState() {
    super.initState();
    _controller = SplashController(context)..init();
    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _introTimer = Timer(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() {
        _showIntroUi = true;
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _introTimer?.cancel();
    _dotsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ScreenScaler.init(context); // مهم

    return AnimatedBuilder(
      animation: _controller,
      builder: (ctx, _) {
        return _controller.hasInternet
            ? _buildOnline(ctx)
            : NoInternet(onRetry: _controller.retry);
      },
    );
  }

  Widget _buildOnline(BuildContext context) {
    // مقدار الرفع عن الوضع الحالي (وحدات لوحة 500px)
    final double lift = 150; // جرّب 60–120 حسب رغبتك
    const double footerHeight = 270;
    final double footerHorizontalPadding = ScreenScaler.s(24);
    final double footerVerticalPadding = ScreenScaler.s(18);
    final double footerSpacing = ScreenScaler.s(6);
    final double footerFontSize = ScreenScaler.fontSize(context, baseSize: 12);
    final Color footerColor =
        Theme.of(context).colorScheme.onPrimary.withOpacity(0.72);
    final TextStyle footerStyle =
        Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: footerColor,
                  fontSize: footerFontSize,
                  fontWeight: FontWeight.w500,
                ) ??
            TextStyle(
              color: footerColor,
              fontSize: footerFontSize,
              fontWeight: FontWeight.w500,
            );
    return AnnotatedRegion(
      value: SystemUiOverlayStyle(
        statusBarColor: context.color.territoryColor,
      ),
      child: Scaffold(
        backgroundColor: context.color.territoryColor,
        body: Center(
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: 500,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Padding(
                    padding: EdgeInsets.only(bottom: lift),
                    child: Column(
                      children: [
                        SizedBox(
                          width: 500,
                          height: 30,
                          child: Lottie.asset('assets/lottie/data.json',
                              fit: BoxFit.cover),
                        ),
                        SizedBox(
                          height: 545,
                          child: Center(
                            child: AnimatedOpacity(
                              opacity: _showIntroUi ? 1 : 0,
                              duration: const Duration(milliseconds: 500),
                              curve: Curves.easeInOut,
                              child: _IntroContent(
                                dotsAnimation: _dotsController,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedOpacity(
                    opacity: _showIntroUi ? 1 : 0,
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeInOut,
                    child: SizedBox(
                      height: footerHeight,
                      width: double.infinity,
                      child: Container(
                        alignment: Alignment.bottomCenter,
                        padding: EdgeInsets.symmetric(
                          horizontal: footerHorizontalPadding,
                          vertical: footerVerticalPadding,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'محافظة مأرب - التحول الرقمي',
                              textAlign: TextAlign.center,
                              style: footerStyle,
                            ),
                            SizedBox(height: footerSpacing),
                            Text(
                              'تطبيق ${AppSettings.applicationName} للخدمات الإلكترونية',
                              textAlign: TextAlign.center,
                              style: footerStyle.copyWith(
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IntroContent extends StatelessWidget {
  const _IntroContent({required this.dotsAnimation});

  final Animation<double> dotsAnimation;

  @override
  Widget build(BuildContext context) {
    final Color textColor = Theme.of(context).colorScheme.onPrimary;

    final TextStyle baseStyle =
        Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w600,
                ) ??
            TextStyle(
              color: textColor,
              fontSize: 24,
              fontWeight: FontWeight.w600,
            );

    final Animation<double> fadeAnimation = CurvedAnimation(
      parent: dotsAnimation,
      curve: Curves.easeInOut,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'مرحباً بك',
              textAlign: TextAlign.center,
              style: baseStyle,
            ),
            AnimatedBuilder(
              animation: dotsAnimation,
              builder: (context, _) {
                final int step = ((dotsAnimation.value * 3).floor() % 3) + 1;
                final String dots =
                    step <= 0 ? '' : ' ${List.filled(step, '.').join(' ')}';
                return FadeTransition(
                  opacity: fadeAnimation,
                  child: Text(
                    dots,
                    textAlign: TextAlign.center,
                    style: baseStyle.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}
