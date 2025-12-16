// ignore_for_file: invalid_use_of_protected_member

import 'dart:async';
import 'dart:io';

import 'package:app_links/app_links.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:marib/app/routes.dart';
import 'package:marib/data/cubits/item/search_item_cubit.dart';
import 'package:marib/data/cubits/subscription/fetch_user_package_limit_cubit.dart';
import 'package:marib/data/cubits/system/fetch_system_settings_cubit.dart';
import 'package:marib/data/model/item/item_model.dart';
import 'package:marib/data/model/system_settings_model.dart';
import 'package:marib/data/cubits/system/user_details.dart';
import 'package:marib/data/cubits/seller/fetch_verification_request_cubit.dart';
import 'package:marib/data/model/merchant/merchant_store_snapshot.dart';
import 'package:marib/data/repositories/merchant_repository.dart';

import 'package:marib/ui/screens/Transaction_screen.dart';
import 'package:marib/ui/screens/chat_v2/chat_list_screen_v2.dart';
import 'package:marib/ui/screens/home_screen/home_screen.dart';
import 'package:marib/ui/screens/user_profile/profile_screen.dart';
import 'package:marib/ui/screens/wallet/wallet_screen.dart';

import 'package:marib/ui/screens/widgets/maintenance_mode.dart';
import 'package:marib/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:marib/ui/screens/home/search_screen.dart';
import 'package:marib/ui/screens/widgets/blurred_dialoge_box.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/app_icon.dart';
import 'package:marib/utils/constant.dart';
import 'package:marib/utils/errorFilter.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/helper_utils.dart';
// import 'package:marib/utils/hive_utils.dart'; // ← غير مستخدم الآن
import 'package:marib/utils/responsiveSize.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:marib/utils/svg/svg_edit.dart';
import 'package:marib/utils/hive_utils.dart';
import 'package:marib/ui/widgets/dialogs/store_review_dialogs.dart';

// الواجهة (ملف منفصل للعرض فقط)
import 'main_activity_ui.dart' show MainActivityUI, MainTab;


// متغيّرات مشتركة كما كانت
List<ItemModel> myItemlist = [];
Map<String, dynamic> searchbody = {};
String selectedcategoryId = "0";
String selectedcategoryName = "";
dynamic selectedCategory;
dynamic currentVisitingCategoryId = "";
dynamic currentVisitingCategory = "";
List<int> navigationStack = [0];

ScrollController homeScreenController = ScrollController();
ScrollController profileScreenController = ScrollController();
List<ScrollController> controllerList = <ScrollController>[
  homeScreenController,
  profileScreenController
];


class MainActivity extends StatefulWidget {
  final String from;
  static final GlobalKey<MainActivityState> globalKey =
  GlobalKey<MainActivityState>();

  MainActivity({Key? key, required this.from}) : super(key: globalKey);

  @override
  State<MainActivity> createState() => MainActivityState();

  static Route route(RouteSettings routeSettings) {
    final Map arguments = routeSettings.arguments as Map;
    return BlurredRouter(
      builder: (_) => MainActivity(from: arguments['from'] as String),
    );
  }
}

class MainActivityState extends State<MainActivity> with TickerProviderStateMixin {
  final PageController pageCntrlr = PageController(initialPage: 0);
  int currtab = 0;
  static final FirebaseMessaging firebaseMessaging = FirebaseMessaging.instance;
  final List _pageHistory = [];
  static const int _historyCap = 50;

  DateTime? currentBackPressTime;

  bool svgLoaded = false;
  String? _cachedFabSvg; // كاش للـSVG بعد التلوين
  bool isBack = false;
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  final SVGEdit svgEdit = SVGEdit();

  bool _addBusy = false; // حالة الزر العائم
  bool _pendingListingNavigation = false; // تتبع مصدر طلب الحصة

  final List<Widget?> _pages = List<Widget?>.filled(4, null, growable: false);
  final MerchantRepository _merchantRepository = const MerchantRepository();


  @override
  void initState() {
    super.initState();
    initAppLinks();

    _pages[0] = HomeScreen(from: widget.from);

    _maybeBootstrapMerchantStoreStatus();

    // تحميل SVG لزر الإضافة مرة واحدة
    rootBundle.loadString(AppIcons.plusIcon).then((value) {
      svgEdit.loadSVG(value);
      _recolorAndCacheFabSvg();
      svgLoaded = true;
      setState(() {});
    });

    final settings = context.read<FetchSystemSettingsCubit>();
    if (!const bool.fromEnvironment("force-disable-demo-mode", defaultValue: false)) {
      Constant.isDemoModeOn = settings.getSetting(SystemSetting.demoMode) ?? false;
    }
    final numberWithSuffix = settings.getSetting(SystemSetting.numberWithSuffix);
    Constant.isNumberWithSuffix = numberWithSuffix == "1";

    versionCheck(settings);
    initPageController();
  }

  void _recolorAndCacheFabSvg() {
    final hex = svgEdit.flutterColorToHexColor(context.color.territoryColor);
    svgEdit.change("Path_11299-2", attribute: "fill", value: hex);
    _cachedFabSvg = svgEdit.toSVGString();
  }

  Future<void> initAppLinks() async {
    _appLinks = AppLinks();
    _linkSubscription = _appLinks.uriLinkStream.listen((Uri? uri) {
      if (uri != null) handleDeepLink(uri);
    });
  }

  void handleDeepLink(Uri uri) {
    if (uri.path.contains('/product-details/')) {
      Navigator.push(
        context,
        Routes.onGenerateRouted(RouteSettings(name: uri.toString())),
      );
    }
  }

  void addHistory(int index) {
    if (navigationStack.isEmpty || navigationStack.last != index) {
      navigationStack.add(index);
    }
  }

  void initPageController() {
    pageCntrlr.addListener(() {
      _pageHistory.insert(0, pageCntrlr.page);
      if (_pageHistory.length > _historyCap) {
        _pageHistory.removeRange(_historyCap, _pageHistory.length);
      }
    });
  }

  Future<void> versionCheck(FetchSystemSettingsCubit settings) async {
    final remoteVersion = settings.getSetting(
      Platform.isIOS ? SystemSetting.iosVersion : SystemSetting.androidVersion,
    );
    final forceUpdate = settings.getSetting(SystemSetting.forceUpdate);
    if (remoteVersion == null) return;

    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = HelperUtils.comparableVersion(packageInfo.version);
    final remoteComparable = HelperUtils.comparableVersion(remoteVersion);

    if (remoteComparable > currentVersion) {
      Constant.isUpdateAvailable = true;
      Constant.newVersionNumber = remoteVersion;

      Future.delayed(Duration.zero, () {
        if (!mounted) return;
        if (forceUpdate == "1") {
          UiUtils.showBlurredDialoge(
            context,
            dialoge: BlurredDialogBox(
              onAccept: () async {
                await launchUrl(Uri.parse(Constant.playstoreURLAndroid),
                    mode: LaunchMode.externalApplication);
              },
              backAllowedButton: false,
              svgImagePath: AppIcons.update,
              isAcceptContainesPush: true,
              svgImageColor: context.color.territoryColor,
              showCancleButton: false,
              title: "updateAvailable".translate(context),
              acceptTextColor: context.color.buttonColor,
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("${packageInfo.version}>$remoteVersion"),
                  Text("newVersionAvailableForce".translate(context),
                      textAlign: TextAlign.center),
                ],
              ),
            ),
          );
        } else {
          UiUtils.showBlurredDialoge(
            context,
            dialoge: BlurredDialogBox(
              onAccept: () async {
                await launchUrl(Uri.parse(Constant.playstoreURLAndroid),
                    mode: LaunchMode.externalApplication);
              },
              svgImagePath: AppIcons.update,
              svgImageColor: context.color.territoryColor,
              showCancleButton: true,
              title: "updateAvailable".translate(context),
              content: Text("newVersionAvailable".translate(context)),
            ),
          );
        }
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    ErrorFilter.setContext(context);
    if (svgLoaded) {
      _recolorAndCacheFabSvg();
      setState(() {});
    }
  }

  @override
  void dispose() {
    pageCntrlr.dispose();
    _linkSubscription?.cancel();
    super.dispose();
  }

  void onItemTapped(int index) {
    if (index == currtab) {
      if (index < controllerList.length && controllerList[index].hasClients) {
        controllerList[index].animateTo(
          0,
          duration: const Duration(milliseconds: 1),
          curve: Curves.bounceOut,
        );
      }
      return;
    }

    addHistory(index);
    FocusManager.instance.primaryFocus?.unfocus();

    if (index != 1) {
      context.read<SearchItemCubit>().clearSearch();
      final searchController = SearchScreenState.activeSearchController;
      if (searchController?.hasListeners ?? false) {
        searchController!.text = "";
      }
    }
    searchbody = {};

    if (index == 1 || index == 2) {
      UiUtils.checkUser(
        onNotGuest: () {
          currtab = index;
          pageCntrlr.jumpToPage(currtab);
          setState(() {});
        },
        context: context,
      );
    } else {
      currtab = index;
      pageCntrlr.jumpToPage(currtab);
      if (index == 3 && HiveUtils.isUserAuthenticated()) {
        context.read<FetchVerificationRequestsCubit>().fetchVerificationRequests();
      }
      setState(() {});
    }
  }


  Widget _buildPage(int index) {
    if (index < 0 || index >= _pages.length) {
      throw RangeError.index(index, _pages, '_pages');
    }

    final cached = _pages[index];
    if (cached != null) {
      return cached;
    }

    if (currtab != index) {
      return const SizedBox.shrink();
    }

    late final Widget page;
    switch (index) {
      case 0:
        page = HomeScreen(from: widget.from);
        break;
      case 1:
        page = const ChatListScreenV2();
        break;
      case 2:
        page = const TransactionScreen();
        break;
      case 3:
        page = const ProfileScreen();
        break;
      default:
        page = const SizedBox.shrink();
        break;
    }

    _pages[index] = page;
    return page;
  }


  // تنقّلات مخصّصة حسب نوع الحساب

  void _maybeBootstrapMerchantStoreStatus() {
    final int? accountType = HiveUtils.getUserDetails().userType;
    if (accountType != 3) {
      return;
    }
    final String? cachedStatus = HiveUtils.getMerchantStoreStatus();
    if (cachedStatus != null && cachedStatus.trim().isNotEmpty) {
      return;
    }
    _merchantRepository.fetchStoreProfile().then((snapshot) async {
      await HiveUtils.setMerchantStoreRaw(snapshot?.toMap());
    }).catchError((_) {});
  }

  void _refreshListingLimit() {
    if (!mounted) return;
    _pendingListingNavigation = false;

    context
        .read<FetchUserPackageLimitCubit>()
        .fetchUserPackageLimit(packageType: "item_listing");
  }

  Future<bool> _ensureStoreCanPublish() async {
    final int? accountType = HiveUtils.getUserDetails().userType;
    if (accountType != 3) {
      return true;
    }
    final String? cachedStatus = HiveUtils.getMerchantStoreStatus();
    if (_isStoreStatusApproved(cachedStatus)) {
      return true;
    }
    try {
      final MerchantStoreSnapshot? snapshot =
          await _merchantRepository.fetchStoreProfile();
      await HiveUtils.setMerchantStoreRaw(snapshot?.toMap());
      return snapshot?.isApproved ?? false;
    } catch (_) {
      return false;
    }
  }

  bool _isStoreStatusApproved(String? status) {
    final String normalized = (status ?? '').trim().toLowerCase();
    return normalized == 'approved';
  }




  Future<void> _handleAdCreationNavigation() async {
    if (!mounted) return;

    final bool canPublish = await _ensureStoreCanPublish();
    if (!canPublish) {
      await showStoreReviewDialog(
        context,
        variant: StoreReviewDialogVariant.publishing,
      );
      return;
    }


    try {
      await Navigator.pushNamed(context, Routes.selectCategoryScreen);
    } finally {
      if (mounted) {
        _refreshListingLimit();
      }
    }


  }




  // زر الإضافة العائم (يمرّر للواجهة)
  Widget _buildCenterAddButton() {
    final Widget iconChild = _addBusy
        ? const SizedBox(
      width: 26,
      height: 26,
      child: CircularProgressIndicator(strokeWidth: 2.6),
    )
        : (svgLoaded && _cachedFabSvg != null
        ? Transform.rotate(
      angle: 11.0,
      child: SvgPicture.string(_cachedFabSvg!),
    )
        : const Icon(Icons.add, size: 32, color: Colors.white));

    return Semantics(
      button: true,
      label: "addAdvertisement".translate(context),
      child: FloatingActionButton(
        heroTag: 'add-ad-fab', // حل تعارض الـHero بدون تعطيله
        backgroundColor: const Color(0xFFEB5924),
        elevation: 6,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        onPressed: _addBusy
            ? null
            : () {

          HapticFeedback.selectionClick();
          UiUtils.checkUser(
            onNotGuest: () {
              _pendingListingNavigation = true;
              context
                  .read<FetchUserPackageLimitCubit>()
                  .fetchUserPackageLimit(packageType: "item_listing");
            },
            context: context,
          );
        },

        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: iconChild,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.color;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: UiUtils.getSystemUiOverlayStyle(
        context: context,
        statusBarColor: colors.primaryColor,
      ),
      child: BlocListener<FetchUserPackageLimitCubit, FetchUserPackageLimitState>(
        listener: (context, state) async {
          if (!mounted) return;

          if (state is FetchUserPackageLimitInProgress) {
            if (!_addBusy) setState(() => _addBusy = true);
            return;
          } else if (_addBusy) {
            setState(() => _addBusy = false);
          }

          if (state is FetchUserPackageLimitInSuccess) {

            final summary = UiUtils.subscriptionLimitSummary(
              context,
              state.limit,
            );
            if (summary != null && summary.isNotEmpty) {
              HelperUtils.showSnackBarMessage(
                context,
                summary,
                messageDuration: 3,
              );
            }
            if (state.canCreateListing) {
              if (_pendingListingNavigation) {
                _pendingListingNavigation = false;
                await _handleAdCreationNavigation();
              }
            } else {
              _pendingListingNavigation = false;

              if (state.responseMessage.isNotEmpty) {
                HelperUtils.showSnackBarMessage(
                  context,
                  state.responseMessage,
                  messageDuration: 3,
                );
              }
              UiUtils.noPackageAvailableDialog(
                context,
                limit: state.limit,
              );
            }
          }

          if (state is FetchUserPackageLimitFailure) {
            _pendingListingNavigation = false;

            final rawMessage = (state.error ?? '').toString().trim();
            if (HelperUtils.isConnectivityOrServerError(rawMessage)) {
              final lowerCaseMessage = rawMessage.toLowerCase();
              final message = rawMessage.isNotEmpty &&
                  !lowerCaseMessage.contains('server-not-available') &&
                  !lowerCaseMessage.contains('server not available')
                  ? rawMessage
                  : "somethingWentWrong".translate(context);

              HelperUtils.showSnackBarMessage(
                context,
                message,
                type: MessageType.error,
              );
              return;
            }

            if (HelperUtils.isPackageLimitError(rawMessage)) {
              UiUtils.noPackageAvailableDialog(context);
              return;
            }

            final readableMessage =
            HelperUtils.readableErrorMessage(context, rawMessage);



            HelperUtils.showSnackBarMessage(
              context,
              readableMessage,
              type: MessageType.error,
            );


          }
        },
        child: PopScope(
          canPop: isBack,
          onPopInvoked: (didPop) {
            if (currtab != 0) {
              pageCntrlr.animateToPage(
                0,
                duration: const Duration(milliseconds: 1),
                curve: Curves.easeInOut,
              );
              setState(() {
                currtab = 0;
                isBack = false;
              });
              return;
            } else {
              final now = DateTime.now();
              if (currentBackPressTime == null ||
                  now.difference(currentBackPressTime!) >
                      const Duration(seconds: 2)) {
                currentBackPressTime = now;
                HelperUtils.showSnackBarMessage(
                  context,
                  "pressAgainToExit".translate(context),
                );
                if (!isBack) {
                  setState(() {
                    isBack = false;
                  });
                }
                return;
              }
              setState(() {
                isBack = true;
              });
              return;
            }
          },
          child: MainActivityUI.config(
            pageController: pageCntrlr,
            currentTab: MainTab.values[currtab],
            pageCount: _pages.length,
            pageBuilder: (context, index) => _buildPage(index),
            onTabSelected: (tab) => onItemTapped(tab.index),
            maintenanceOn: Constant.maintenanceMode == "1",
            maintenanceOverlay: const MaintenanceMode(),
            centerActionBuilder: (_) => _buildCenterAddButton(),
          ),
        ),
      ),
    );
  }
}
