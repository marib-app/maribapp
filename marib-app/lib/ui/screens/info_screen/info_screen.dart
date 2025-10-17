import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:marib/data/model/social_link_model.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:marib/app/routes.dart';
import 'package:marib/data/cubits/chat/blocked_users_list_cubit.dart';
import 'package:marib/data/cubits/chat/get_buyer_chat_users_cubit.dart';
import 'package:marib/data/cubits/favorite/favorite_cubit.dart';
import 'package:marib/data/cubits/report/update_report_items_list_cubit.dart';
import 'package:marib/data/cubits/system/user_details.dart';
import 'package:marib/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:marib/ui/screens/widgets/blurred_dialoge_box.dart';
// الواجهة المفصولة
import 'info_screen_ui.dart';
// إكستنشنات translate وغيرها
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/api.dart';
import 'package:marib/utils/app_icon.dart';
import 'package:marib/utils/constant.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:marib/utils/hive_utils.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:share_plus/share_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:marib/data/cubits/system/fetch_system_settings_cubit.dart';
import 'usage_guide_screen.dart';




class InfoScreen extends StatefulWidget {
  const InfoScreen({super.key});

  static Route route(RouteSettings routeSettings) {
    return BlurredRouter(
      builder: (_) => const InfoScreen(),
    );
  }

  @override
  State<InfoScreen> createState() => InfoScreenState();
}

class InfoScreenState extends State<InfoScreen> with TickerProviderStateMixin {
  final InAppReview _inAppReview = InAppReview.instance;

  late final FetchSystemSettingsCubit _settingsCubit;
  StreamSubscription<FetchSystemSettingsState>? _settingsSubscription;
  String? _usageGuideHtml;
  List<SocialLink> _socialLinks = const [];

  bool _isGuideDialogVisible = false;

  @override
  void initState() {
    super.initState();
    _settingsCubit = context.read<FetchSystemSettingsCubit>();
    _usageGuideHtml = _normalizeGuideHtml(Constant.usageGuide);
    _socialLinks = Constant.socialLinks;

    final FetchSystemSettingsState initialState = _settingsCubit.state;
    if (initialState is FetchSystemSettingsSuccess) {
      _usageGuideHtml = _normalizeGuideHtml(initialState.usageGuide);
      _socialLinks = initialState.socialLinks;

    }

    _settingsSubscription =
        _settingsCubit.stream.listen(_handleSettingsStateUpdate);
  }

  @override
  void dispose() {
    _settingsSubscription?.cancel();
    super.dispose();
  }



  @override
  Widget build(BuildContext context) {
    return InfoScreenUI(
      onGuideTap: _openGuide,
      onFaqsTap: _openFaqs,
      onShareTap: shareApp,
      onContactUsTap: _openContactUs,
      onAboutUsTap: () => _openStaticPage(
        title: "aboutUs".translate(context),
        param: Api.aboutUs,
      ),
      onTermsTap: () => _openStaticPage(
        title: "termsConditions".translate(context),
        param: Api.termsAndConditions,
      ),
      onPrivacyTap: () => _openStaticPage(
        title: "privacyPolicy".translate(context),
        param: Api.privacyPolicy,
      ),
      socialLinks: _socialLinks,

    );
  }

  // ---------- Callbacks ----------

  void _openGuide() {
    unawaited(_handleGuideTap());
  }

  void _openFaqs() {
    UiUtils.checkUser(
      onNotGuest: () {
        Navigator.pushNamed(context, Routes.faqsScreen);
      },
      context: context,
    );
  }

  Future<void> _handleGuideTap() async {
    final String? cachedHtml = _usageGuideHtml;
    if (_hasGuideHtml(cachedHtml)) {
      await _pushGuideWithHtml(cachedHtml!);
      return;
    }

    final FetchSystemSettingsState currentState = _settingsCubit.state;
    if (currentState is FetchSystemSettingsSuccess) {
      final String? resolvedHtml = _normalizeGuideHtml(currentState.usageGuide);
      if (resolvedHtml != null) {
        if (_usageGuideHtml != resolvedHtml && mounted) {
          setState(() {
            _usageGuideHtml = resolvedHtml;
          });
        }
        await _pushGuideWithHtml(resolvedHtml);
        return;
      }

      if (_usageGuideHtml != null && mounted) {
        setState(() {
          _usageGuideHtml = null;
        });
      }

      await _openGuideFallback();
      return;
    }

    _showGuideLoader();
    try {
      final String? fetchedHtml =
      await _waitForGuideAfterTrigger(currentState);
      _hideGuideLoader();

      if (!mounted) {
        return;
      }

      final String? normalized = _normalizeGuideHtml(fetchedHtml);
      if (normalized != null) {
        if (_usageGuideHtml != normalized) {
          setState(() {
            _usageGuideHtml = normalized;
          });
        }
        await _pushGuideWithHtml(normalized);
        return;
      }

      if (_usageGuideHtml != null) {
        setState(() {
          _usageGuideHtml = null;
        });
      }

      await _openGuideFallback();
    } catch (_) {
      _hideGuideLoader();
      if (!mounted) {
        return;
      }
      if (_usageGuideHtml != null) {
        setState(() {
          _usageGuideHtml = null;
        });
      }
      HelperUtils.showSnackBarMessage(
        context,
        "somethingWentWrong".translate(context),
      );
      await _openGuideFallback();
    }
  }

  Future<String?> _waitForGuideAfterTrigger(
      FetchSystemSettingsState currentState,
      ) async {
    final Completer<String?> completer = Completer<String?>();
    late final StreamSubscription<FetchSystemSettingsState> subscription;
    subscription = _settingsCubit.stream.listen((state) {
      if (state is FetchSystemSettingsSuccess) {
        if (!completer.isCompleted) {
          completer.complete(_normalizeGuideHtml(state.usageGuide));
        }
      } else if (state is FetchSystemSettingsFailure) {
        if (!completer.isCompleted) {
          completer.completeError(state.errorMessage);
        }
      }
    });

    try {
      if (currentState is FetchSystemSettingsSuccess) {
        if (!completer.isCompleted) {
          completer.complete(_normalizeGuideHtml(currentState.usageGuide));
        }
      } else {
        if (currentState is! FetchSystemSettingsInProgress &&
            currentState is! FetchSystemSettingsSuccess) {
          unawaited(_settingsCubit.fetchSettings());
        }
      }

      return await completer.future;
    } finally {
      await subscription.cancel();
    }
  }

  void _showGuideLoader() {
    if (_isGuideDialogVisible || !mounted) {
      return;
    }
    _isGuideDialogVisible = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _GuideLoadingDialog(),
    ).whenComplete(() {
      _isGuideDialogVisible = false;
    });
  }

  void _hideGuideLoader() {
    if (!_isGuideDialogVisible || !mounted) {
      return;
    }
    Navigator.of(context, rootNavigator: true).maybePop();
  }

  Future<void> _pushGuideWithHtml(String html) async {
    final Uri baseUri = _buildUsageGuideFallbackUri();
    if (!mounted) {
      return;
    }
    await Navigator.of(context).push(
      UsageGuideScreen.route(
        title: "guide".translate(context),
        htmlContent: html,
        fallbackUri: baseUri,
      ),
    );
  }

  Future<void> _openGuideFallback() async {
    if (!mounted) {
      return;
    }
    final Uri fallbackUri = _buildUsageGuideFallbackUri();
    await Navigator.of(context).push(
      UsageGuideScreen.route(
        title: "guide".translate(context),
        fallbackUri: fallbackUri,
      ),
    );
  }



  Uri _buildUsageGuideFallbackUri() {
    final String base = Constant.baseUrl.trim();
    if (base.isEmpty) {
      return Uri.parse('https://marib.app/page/usage-guide');
    }
    try {
      final Uri parsed = Uri.parse(base);
      if (!parsed.hasScheme) {
        return Uri.parse('https://$base').resolve('/page/usage-guide');
      }
      return parsed.resolve('/page/usage-guide');
    } catch (_) {
      final String sanitized = base.endsWith('/')
          ? base.substring(0, base.length - 1)
          : base;
      return Uri.parse('$sanitized/page/usage-guide');
    }
  }

  String? _normalizeGuideHtml(String? value) {
    if (value == null) {
      return null;
    }
    if (value.trim().isEmpty) {
      return null;
    }
    return value;
  }

  bool _hasGuideHtml(String? value) => value != null && value.isNotEmpty;

  void _handleSettingsStateUpdate(FetchSystemSettingsState state) {
    if (!mounted) {
      return;
    }
    if (state is FetchSystemSettingsSuccess) {
      final String? normalized = _normalizeGuideHtml(state.usageGuide);
      final bool guideChanged = _usageGuideHtml != normalized;
      final bool socialChanged = !listEquals(_socialLinks, state.socialLinks);
      if (!guideChanged && !socialChanged) {

        return;
      }
      setState(() {
        _usageGuideHtml = normalized;
        _socialLinks = state.socialLinks;

      });
    }
  }


  void _openContactUs() {
    Navigator.pushNamed(context, Routes.contactUs);
  }

  void _openStaticPage({required String title, required String param}) {
    Navigator.pushNamed(
      context,
      Routes.profileSettings,
      arguments: {'title': title, 'param': param},
    );
  }

  // ---------- مشاركة/تقييم/تسجيل خروج ----------

  void shareApp() {
    try {
      if (Platform.isAndroid) {
        Share.share(
          '${Constant.appName}\n${Constant.playstoreURLAndroid}\n${Constant.shareappText}',
          subject: Constant.appName,
        );
      } else {
        // نفس منطقك الأصلي مع sharePositionOrigin
        Share.share(
          '${Constant.appName}\n${Constant.appstoreURLios}\n${Constant.shareappText}',
          subject: Constant.appName,
          sharePositionOrigin: Rect.fromLTWH(
            0,
            0,
            MediaQuery.of(context).size.width,
            MediaQuery.of(context).size.height / 2,
          ),
        );
      }
    } catch (e) {
      HelperUtils.showSnackBarMessage(context, e.toString());
    }
  }

  Future<void> rateUs() => _inAppReview.openStoreListing(
    appStoreId: Constant.iOSAppId,
    microsoftStoreId: 'microsoftStoreId',
  );

  void logOutConfirmWidget() {
    UiUtils.showBlurredDialoge(
      context,
      dialoge: BlurredDialogBox(
        title: "confirmLogoutTitle".translate(context),
        onAccept: () async {
          Future.delayed(
            Duration.zero,
                () async {
              HiveUtils.clear();
              Constant.favoriteItemList.clear();
              context.read<UserDetailsCubit>().clear();
              context.read<FavoriteCubit>().resetState();
              context.read<UpdatedReportItemCubit>().clearItem();
              context.read<GetBuyerChatListCubit>().resetState();
              context.read<BlockedUsersListCubit>().resetState();
              await FetchSystemSettingsCubit.resetDelegateSectionsFor(
                context,
                clearCachedSections: true,
              );
              await HiveUtils.logoutUser(context, onLogout: () {});

              },
          );
        },
        cancelTextColor: context.color.textColorDark,
        svgImagePath: AppIcons.logoutIcon,
        content: Text("confirmLogOutMsg".translate(context)),
      ),
    );
  }
}
class _GuideLoadingDialog extends StatelessWidget {
  const _GuideLoadingDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
        backgroundColor: context.color.secondaryColor,
        insetPadding: const EdgeInsets.symmetric(horizontal: 120),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SizedBox(
            height: 32,
            width: 32,
            child: UiUtils.progress(width: 32, height: 32),
          ),
        ),
        );
    }
}