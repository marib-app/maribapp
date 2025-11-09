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
/// ط§ظ„ظ…ظ†ط·ظ‚: SplashController
///==============================
class SplashController extends ChangeNotifier {
  SplashController(this.context);

  final BuildContext context;

  // ط§ظ„ط­ط§ظ„ط© ط§ظ„ط¯ط§ط®ظ„ظٹط©
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

  /// ط¨ط¯ط، ط§ظ„ط¹ظ…ظ„
  void init() {
    _bindCubitStreams();
    _setupFallbackTimeout();
    _subscribeConnectivity();
  }

  /// ط¥ظ„ط؛ط§ط، ط§ظ„ط§ط´طھط±ط§ظƒط§طھ
  @override
  void dispose() {
    _connSub?.cancel();
    _langSub?.cancel();
    _settingsSub?.cancel();
    _timer?.cancel();
    _fallbackTimer?.cancel();
    super.dispose();
  }

  /// ط±ط¨ط· ط³طھط±ظٹظ…ط§طھ ط§ظ„ظ€ Cubits ظ„ط³ظ…ط§ط¹ ط§ظ„ظ†ط¬ط§ط­/ط§ظ„ظپط´ظ„ ط¨ط¯ظˆظ† ظ…ظ†ط·ظ‚ ط¯ط§ط®ظ„ ط§ظ„ظˆط§ط¬ظ‡ط©
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
        isLanguageLoaded = true; // ط§ط³طھط®ط¯ظ… ط§ظ„ط§ظپطھط±ط§ط¶ظٹ
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

        isSettingsLoaded = true; // ط§ط³طھط®ط¯ظ… ط§ظ„ط§ظپطھط±ط§ط¶ظٹ
        notifyListeners();
        _tryNavigate();
      }
    });
  }

  /// ط§ط´طھط±ط§ظƒ ط­ط§ظ„ط© ط§ظ„ط¥ظ†طھط±ظ†طھ
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

    // ظ…ط­ط§ظˆظ„ط© ط£ظˆظ„ظٹط© (ط¨ط¹ط¶ ط§ظ„ط£ط¬ظ‡ط²ط© ظ„ط§ طھط±ط³ظ„ ط£ظˆظ„ ط­ط¯ط« ط¨ط³ط±ط¹ط©)
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

  /// طھط­ظ…ظٹظ„ ط§ظ„ظ„ط؛ط© ط§ظ„ط§ظپطھط±ط§ط¶ظٹط© (ظ†ط³طھط®ط¯ظ… ط§ظ„ط¹ط±ط¨ظٹط© ظƒط§ظپطھط±ط§ط¶ظٹ)
  Future<void> _getDefaultLanguage() async {
    final dynamic stored = HiveUtils.getLanguage();
    final bool hasCachedTranslations = stored is Map &&
        stored['data'] is Map &&
        (stored['data'] as Map).isNotEmpty;

    if (hasCachedTranslations) {
      context.read<LanguageCubit>().emit(LanguageLoader(stored));
      isLanguageLoaded = true;
      notifyListeners();
      _tryNavigate();
    }

    try {
      final codeFromSettings = await _waitForDefaultLanguageCode();
      final code = (codeFromSettings != null && codeFromSettings.isNotEmpty)
          ? codeFromSettings
          : "ar";

      // Always try to refresh the language so panel updates reach the app.
      context.read<FetchLanguageCubit>().getLanguage(code);
    } catch (e) {
      log("Error while load default language $e");

      if (hasCachedTranslations) {
        return;
      }

      // ط¬ط±ظ‘ط¨ ط§ظ„ط¹ط±ط¨ظٹط© ظ…ط¨ط§ط´ط±ط©
      try {
        context.read<FetchLanguageCubit>().getLanguage("ar");
      } catch (_) {
        isLanguageLoaded = true;
        notifyListeners();
        _tryNavigate();
      }
    }
  }

  /// طھط­ظ…ظٹظ„ ط§ظ„ط¥ط¹ط¯ط§ط¯ط§طھ
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

  /// ظ…ط¤ظ‚طھ ط¨ط³ظٹط· ظ„ط¹ط±ط¶ ط§ظ„ط³ط¨ظ„ظ‘ط§ط´
  void _startTimer() {
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 5), () {
      isTimerCompleted = true;
      notifyListeners();
      _tryNavigate();
    });
  }

  /// ط®ط·ط© ط·ظˆط§ط±ط¦: ظ„ط§ طھظ†طھط¸ط± ط£ظƒط«ط± ظ…ظ† 10 ط«ظˆط§ظ†
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

  /// ظ…ط­ط§ظˆظ„ط© ط§ظ„طھظ†ظ‚ظ„ ط¹ظ†ط¯ظ…ط§ طھظƒطھظ…ظ„ ط§ظ„ط´ط±ظˆط·
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
      if (HiveUtils.isMerchantOnboardingInProgress()) {
        final Map<String, dynamic>? draft =
            HiveUtils.getMerchantOnboardingDraft();
        final int resumeStep = HiveUtils.getMerchantOnboardingStep();
        final Map<String, dynamic> args = {
          'resumeFromStep': resumeStep,
        };
        if (draft != null && draft.isNotEmpty) {
          args['signupDraft'] = draft;
        }
        _go(() {
          Navigator.of(context).pushReplacementNamed(
            Routes.merchantOnboarding,
            arguments: args,
          );
        });
        return;
      }

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

    // ط¶ظٹظپ/طھط®ط·ظٹ
    _go(() {
      if (HiveUtils.isUserSkip() == true) {
        Navigator.of(context)
            .pushReplacementNamed(Routes.main, arguments: {'from': "main"});
      } else {
        Navigator.of(context).pushReplacementNamed(Routes.login);
      }
    });
  }

  /// طھظ†ظپظٹط° ط¢ظ…ظ† ط¨ط¹ط¯ ط¥ط·ط§ط± ط§ظ„ط±ط³ظ…
  void _go(VoidCallback nav) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (Navigator.of(context).mounted) nav();
    });
  }

  /// ط²ط± ط¥ط¹ط§ط¯ط© ط§ظ„ظ…ط­ط§ظˆظ„ط© ظ…ظ† ط´ط§ط´ط© ط¹ط¯ظ… ط§ظ„ط§طھطµط§ظ„
  void retry() {
    _startProcessesOnce();
  }
}

///==============================
/// ط§ظ„ظˆط§ط¬ظ‡ط©: SplashScreen
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
    ScreenScaler.init(context); // ظ…ظ‡ظ…

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
    final double footerHorizontalPadding = ScreenScaler.s(24);
    final double footerVerticalPadding = ScreenScaler.s(18);
    final double footerSpacing = ScreenScaler.s(6);
    final double footerFontSize = ScreenScaler.fontSize(context, baseSize: 12);
    final Color footerColor = Colors.black.withOpacity(0.72);

    final TextStyle footerStyle =
        Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: footerColor,
                  fontSize: footerFontSize,
                  fontWeight: FontWeight.w300,
                ) ??
            TextStyle(
              color: footerColor,
              fontSize: footerFontSize,
              fontWeight: FontWeight.w300,
            );
    return AnnotatedRegion(
      value: SystemUiOverlayStyle(
        statusBarColor: context.color.territoryColor,
      ),
      child: Scaffold(
        backgroundColor: context.color.territoryColor,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final double maxHeight = constraints.maxHeight.isFinite
                ? constraints.maxHeight
                : MediaQuery.of(context).size.height;

            return Center(
              child: FittedBox(
                fit: BoxFit.contain,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 500,
                    minHeight: maxHeight,
                    maxHeight: maxHeight,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 500,
                            height: 30,
                            child: Lottie.asset(
                              'assets/lottie/data.json',
                              fit: BoxFit.cover,
                            ),
                          ),
                          SizedBox(height: ScreenScaler.s(16)),
                          AnimatedOpacity(
                            opacity: _showIntroUi ? 1 : 0,
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeInOut,
                            child: _IntroContent(
                              dotsAnimation: _dotsController,
                            ),
                          ),
                        ],
                      ),
                      AnimatedOpacity(
                        opacity: _showIntroUi ? 1 : 0,
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeInOut,
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: footerHorizontalPadding,
                              vertical: footerVerticalPadding,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'ط¬ظ…ظٹط¹ ط§ظ„ط­ظ‚ظˆظ‚ ظ…ط­ظپظˆط¸ط© 2026 C',
                                  textAlign: TextAlign.center,
                                  style: footerStyle,
                                ),
                                SizedBox(height: footerSpacing),
                                Text(
                                  'ظ…ط£ط±ط¨ ط¨ظٹظ† ظٹط¯ظٹظƒ ظ„ظ„ط®ط¯ظ…ط§طھ ط§ظ„ط£ظ„ظƒطھط±ظˆظ†ظٹط©',
                                  textAlign: TextAlign.center,
                                  style: footerStyle.copyWith(
                                    fontWeight: FontWeight.w300,
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
            );
          },
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
              'ظ…ط±ط­ط¨ط§ظ‹ ط¨ظƒ',
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

