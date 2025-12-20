// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:async';
import 'dart:io';
import 'package:timeago/timeago.dart' as timeago;
import 'package:marib/app/routes.dart';
import 'package:marib/utils/constant.dart';
import 'package:marib/utils/extensions/extensions.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/widgets.dart';

import 'package:permission_handler/permission_handler.dart';
import 'package:marib/ui/screens/home_screen/sections_widget.dart';

import 'home_ui.dart';

import 'package:marib/data/cubits/category/fetch_category_cubit.dart';
import 'package:marib/data/cubits/slider_cubit.dart';
import 'package:marib/data/cubits/system/fetch_system_settings_cubit.dart';
import 'package:marib/data/cubits/system/get_api_keys_cubit.dart';
import 'package:marib/data/cubits/home/fetch_home_all_items_cubit.dart';
import 'package:marib/data/cubits/home/fetch_home_screen_cubit.dart';
import 'package:marib/data/cubits/notifications/unread_notifications_cubit.dart';
import 'package:marib/data/cubits/cart/cart_cubit.dart';

import 'package:marib/data/model/system_settings_model.dart';

import 'package:marib/ui/screens/home/widgets/animated_search_bar.dart';
import 'category_widget_offline.dart';
import 'package:marib/utils/notification/awsomeNotification.dart';
import 'package:marib/utils/notification/notification_service.dart';

//import 'package:marib/ui/code/section/Computers/Computers.dart';
import 'package:marib/ui/screens/sliders/slider_widget.dart';

import 'package:marib/utils/hive_utils.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:marib/utils/helper_utils.dart';
//import 'package:marib/ui/code/section/sections/general_section_screen_paged.dart';

import 'home_ui.dart'; // â†گ ط§ظ„ظˆط§ط¬ظ‡ط© ط§ظ„ظ…ظ†ظپطµظ„ط©

const double sidePadding = 18;

class HomeScreen extends StatefulWidget {
  final String? from;

  const HomeScreen({super.key, this.from});

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen>
    with
        TickerProviderStateMixin,
        AutomaticKeepAliveClientMixin<HomeScreen>,
        WidgetsBindingObserver {
  @override
  bool get wantKeepAlive => true;

  /// ScrollController ظ…ط¹ طھظ†ط¸ظٹظپ طµط­ظٹط­ + ط­ط§ط±ط³ ظ…ظ†ط¹ ط§ظ„طھظƒط±ط§ط±
  late final ScrollController _scrollController = ScrollController();
  static bool _permissionsPromptShown = false;
  bool _isFetchingMore = false; // â†گ ظٹظ…ظ†ط¹ طھظƒط±ط§ط± fetchMore ط¹ظ†ط¯ ط§ظ„ط­ط§ظپط©

  /// ظ…ظ„ط§ط­ط¸ط©: ط­ط°ظپطھ ط¹ظ†ط§طµط± ط؛ظٹط± ظ…ط³طھط®ط¯ظ…ط© ظ„طھظ‚ظ„ظٹظ„ ط§ظ„ط¶ظˆط¶ط§ط، ظˆط§ظ„طھط³ط±ظٹط¨ط§طھ:
  /// - itemLocalList, isCategoryEmpty, _refreshIndicatorKey

  @override
  void initState() {
    super.initState(); // âœ… ط¶ط¹ ط¯ط§ط¦ظ…ظ‹ط§ ط£ظˆظ„ط§ظ‹
    WidgetsBinding.instance.addObserver(this);

    initializeSettings();
    addPageScrollListener();

    // âœ… طھط£ط¬ظٹظ„ طھظ‡ظٹط¦ط© ط®ط¯ظ…ط§طھ ط§ظ„ط¥ط´ط¹ط§ط±ط§طھ ظˆط·ظ„ط¨ ط§ظ„ط£ط°ظˆظ†ط§طھ ظ„ظ…ط§ ط¨ط¹ط¯ ط£ظˆظ„ ط¥ط·ط§ط±
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // ط·ظ„ط¨ ط§ظ„ط¥ط°ظ† ط¨ط¹ط¯ ط§ظ„ط¥ط·ط§ط± ط§ظ„ط£ظˆظ„ ظٹظ‚ظ„ظ„ ط§ظ„ط¥ط²ط¹ط§ط¬ ظˆط§ظ„ظ…ط´ط§ظƒظ„ ظ…ط¹ ط§ظ„ظ€ context
      notificationPermissionChecker();
      _showPermissionPromptIfNeeded();
      LocalAwsomeNotification().init(context);
      NotificationService.init(context);
    });

    // âœ… طھظ‚ظ„ظٹظ„ ط§ط³طھط¯ط¹ط§ط،ط§طھ context.read ط§ظ„ظ…طھظƒط±ط±ط©
    final r = context.read;
    unawaited(r<SliderCubit>().fetchSlider(context));
    r<FetchCategoryCubit>().fetchCategories();
    r<FetchHomeScreenCubit>().fetch(interfaceType: "homepage");
    r<FetchHomeAllItemsCubit>().fetch();
    unawaited(r<UnreadNotificationsCubit>().refresh(silent: true));

    if (HiveUtils.isUserAuthenticated()) {
      unawaited(r<CartCubit>().fetchCart().catchError((_) {}));
    }

    // if (HiveUtils.isUserAuthenticated()) {
    //   fetchApiKeys(); // â†گ ظپط¹ظ‘ظ„ظ‡ط§ ط¥ظ† ظƒظ†طھ طھط­طھط§ط¬ ظ…ظپط§طھظٹط­ ظپط¹ظ„ط§ظ‹
    // }

    // âœ… ظ…ط³طھظ…ط¹ ظˆط§ط­ط¯ ظ…ظ†ط¸ظ‘ظپ ظپظٹ dispose
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    // âœ… ط¥ط²ط§ظ„ط© ط§ظ„ظ…ط³طھظ…ط¹ ظ„طھظپط§ط¯ظٹ طھط³ط±ظٹط¨ ط§ظ„ط°ط§ظƒط±ط©
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    NotificationService.disposeListeners();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      context.read<UnreadNotificationsCubit>().refresh(silent: true);
    }
  }

  void initializeSettings() {
    final settingsCubit = context.read<FetchSystemSettingsCubit>();
    if (!const bool.fromEnvironment("force-disable-demo-mode",
        defaultValue: false)) {
      Constant.isDemoModeOn =
          settingsCubit.getSetting(SystemSetting.demoMode) ?? false;
    }
  }

  void addPageScrollListener() {
    // homeScreenController.addListener(pageScrollListener); // â†گ ط؛ظٹط± ظ…ط³طھط®ط¯ظ… ط­ط§ظ„ظٹط§ظ‹
  }

  void fetchApiKeys() {
    context.read<GetApiKeysCubit>().fetch();
  }

  /// âœ… ظ…ط³طھظ…ط¹ ط§ظ„طھظ…ط±ظٹط± ظ…ط¹ ط­ط§ط±ط³ ظ„ظ…ظ†ط¹ ط§ظ„طھظƒط±ط§ط± + ظ‚ط±ط§ط،ط© Hive ظ…ط±ط© ظˆط§ط­ط¯ط©
  void _onScroll() {
    if (!_scrollController.isEndReached()) return;

    final itemsCubit = context.read<FetchHomeAllItemsCubit>();
    if (_isFetchingMore || !itemsCubit.hasMoreData()) return;

    _isFetchingMore = true;

    // âœ… ط§ظ‚ط±ط£ ط§ظ„ظ‚ظٹظ… ظ…ظ† Hive ظ…ط±ط© ظˆط§ط­ط¯ط© ظ„طھظ‚ظ„ظٹظ„ I/O
    final city = HiveUtils.getCityName();
    final areaId = HiveUtils.getAreaId();
    final radius = HiveUtils.getNearbyRadius();
    final lon = HiveUtils.getLongitude();
    final lat = HiveUtils.getLatitude();
    final country = HiveUtils.getCountryName();
    final state = HiveUtils.getStateName();

    itemsCubit
        .fetchMore(
      city: city,
      areaId: areaId,
      radius: radius,
      longitude: lon,
      latitude: lat,
      country: country,
      stateName: state,
    )
        .whenComplete(() {
      _isFetchingMore = false;
    });
  }

  Future<void> _showPermissionPromptIfNeeded() async {
    if (_permissionsPromptShown || HiveUtils.hasCorePermissionsSnapshot()) {
      _permissionsPromptShown = true;
      return;
    }
    _permissionsPromptShown = true;

    if (!await _needsCorePermissions()) {
      await HiveUtils.setCorePermissionsSnapshot(true);
      return;
    }

    final bool accepted = await _showCorePermissionSheet();
    if (!accepted) {
      await HiveUtils.setCorePermissionsSnapshot(false);
      return;
    }

    await _requestCorePermissions();
    await HiveUtils.setCorePermissionsSnapshot(true);
  }

  Future<void> _requestCorePermissions() async {
    // إشعارات
    if (!_isGrantedOrLimited(await Permission.notification.status)) {
      await Permission.notification.request();
    }

    // موقع أثناء الاستخدام
    if (!_isGrantedOrLimited(await Permission.locationWhenInUse.status)) {
      await Permission.locationWhenInUse.request();
    }

    // كاميرا
    if (!_isGrantedOrLimited(await Permission.camera.status)) {
      await Permission.camera.request();
    }

    // مايكروفون
    if (!_isGrantedOrLimited(await Permission.microphone.status)) {
      await Permission.microphone.request();
    }

    // وسائط (صور/تخزين) - يكفي إذن واحد منهما
    if (!await _isMediaPermissionSatisfied()) {
      if (Platform.isIOS) {
        await Permission.photos.request();
      } else if (Platform.isAndroid) {
        // جرّب photos للأجهزة الحديثة ثم التخزين كخيار أوسع
        await Permission.photos.request();
        if (!await _isMediaPermissionSatisfied()) {
          await Permission.storage.request();
        }
      }
    }
  }

  Future<bool> _needsCorePermissions() async {
    if (!_isGrantedOrLimited(await Permission.notification.status)) {
      return true;
    }
    if (!_isGrantedOrLimited(await Permission.locationWhenInUse.status)) {
      return true;
    }
    if (!_isGrantedOrLimited(await Permission.camera.status)) {
      return true;
    }
    if (!_isGrantedOrLimited(await Permission.microphone.status)) {
      return true;
    }
    if (!await _isMediaPermissionSatisfied()) {
      return true;
    }
    return false;
  }

  bool _isGrantedOrLimited(PermissionStatus status) {
    return status.isGranted || status.isLimited;
  }

  Future<bool> _showCorePermissionSheet() async {
    return await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          backgroundColor: sheetContext.color.primaryColor,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (sheetContext) {
            final theme = Theme.of(sheetContext);
            final colors = sheetContext.color;

            Widget bullet(String text) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.check_circle_outline,
                          size: 18, color: colors.territoryColor),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          text,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.onSurface.withOpacity(0.9),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                );

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
                top: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colors.onSurface.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "السماح بالصلاحيات",
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "نحتاج بعض الأذونات لتعمل الميزات الأساسية بسلاسة:",
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurface.withOpacity(0.75),
                    ),
                  ),
                  const SizedBox(height: 12),
                  bullet("الإشعارات لإخبارك بالرسائل والتنبيهات المهمة."),
                  bullet("الموقع لعرض الخدمات القريبة وضبط نتائج البحث."),
                  bullet("الوسائط/الصور لرفع صور الإعلانات والملفات."),
                  bullet("الكاميرا/الميكروفون للاتصال وتصوير المنتجات."),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(sheetContext).pop(false),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(color: colors.outline),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            "لاحقاً",
                            style: theme.textTheme.titleMedium
                                ?.copyWith(color: colors.onSurface),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(sheetContext).pop(true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colors.territoryColor,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            "متابعة",
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: colors.onPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ) ??
        false;
  }

  Future<bool> _isMediaPermissionSatisfied() async {
    // أي من الصور أو التخزين يكفي
    final photoStatus = await Permission.photos.status;
    final storageStatus = await Permission.storage.status;
    return _isGrantedOrLimited(photoStatus) || _isGrantedOrLimited(storageStatus);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final FetchHomeScreenState homeFetchState =
        context.watch<FetchHomeScreenCubit>().state;
    final bool isHomeLoading = homeFetchState is FetchHomeScreenInitial ||
        homeFetchState is FetchHomeScreenInProgress;
    final int unreadCount =
        context.watch<UnreadNotificationsCubit>().state;
    final int cartCount = context.watch<CartCubit>().distinctItemsCount;

    final List<Widget> bodySlivers = <Widget>[
      _buildHomeContentSliver(),
      const SliverToBoxAdapter(child: SizedBox(height: 30)),
    ];

    return HomeScreenUI(
      scrollController: _scrollController,
      onSupportPressed: () => Navigator.pushNamed(context, Routes.support),
      bodySlivers: bodySlivers,
      userId: HiveUtils.getUserId()?.toString(),
      showWelcomeLine: true,

      // ط¨ظٹط§ظ†ط§طھ ط§ظ„ط¨ط±ظˆظپط§ظٹظ„ (ط¨ط¯ظ„ appBarLeading)
      isAuthenticated: HiveUtils.isUserAuthenticated(),
      name: HiveUtils.getUserId()?.toString() ?? 'ط²ط§ط¦ط±',
      mobile: '',
      profileUrl: '',
      isVerified: false,
      cartCount: cartCount,
      notifCount: unreadCount,
      showHeaderShimmer: isHomeLoading,
      onAvatarTap: null,
      onCartTap: () {
        UiUtils.checkUser(
          context: context,
          onNotGuest: () => Navigator.pushNamed(context, Routes.cart),
        );
      },
      onNotificationTap: () {},
      onInfoTap: () {},
    );
  }

  Widget _buildHomeContentSliver() {
    return BlocBuilder<FetchHomeScreenCubit, FetchHomeScreenState>(
      buildWhen: (prev, curr) => prev.runtimeType != curr.runtimeType,
      builder: (context, state) {
        if (state is FetchHomeScreenInitial ||
            state is FetchHomeScreenInProgress) {
          return SliverToBoxAdapter(child: homeShimmerEffect(context));
        }

        if (state is FetchHomeScreenSuccess) {
          final bool canShowShein = HiveUtils.hasDelegateAccess('shein');
          final bool canShowComputer = HiveUtils.hasDelegateAccess('computer');

          final List<Widget> children = <Widget>[
            RepaintBoundary(
              child: SliderWidget(interfaceType: "homepage"),
            ),
            RepaintBoundary(child: AnimatedSearchBar()),
            const SizedBox(height: 12),
            RepaintBoundary(child: CategoryWidgetOffline()),
            const SizedBox(height: 16),
            _buildBannerCard(
              assetPath: 'assets/sections/1.jpg',
              onTap: _goRealEstate,
            ),
            const SizedBox(height: 8),
            _buildBannerCard(
              assetPath: 'assets/sections/2.jpg',
              onTap: _goTourism,
            ),
            const SizedBox(height: 8),
            _buildBannerCard(
              assetPath: 'assets/sections/3.jpg',
              onTap: _goElectronicStore,
            ),
          ];

          if (canShowShein) {
            children
              ..add(const SizedBox(height: 8))
              ..add(
                _buildBannerCard(
                  assetPath: 'assets/sections/4.jpg',
                  onTap: _goShein,
                ),
              );
          }

          if (canShowComputer) {
            children
              ..add(const SizedBox(height: 8))
              ..add(
                _buildBannerCard(
                  assetPath: 'assets/sections/5.jpg',
                  onTap: _goComputerSection,
                ),
              );
          }

          children
            ..add(const SizedBox(height: 8))
            ..add(
              _buildBannerCard(
                assetPath: 'assets/sections/6.jpg',
                onTap: _goPublicAds,
              ),
            );

          return SliverList(
            delegate: SliverChildListDelegate(
              children,
              addAutomaticKeepAlives: false,
              addRepaintBoundaries: true,
            ),
          );
        }

        if (state is FetchHomeScreenFail) {
          return SliverToBoxAdapter(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  Text(
                    'طھط¹ط°ظ‘ط± طھط­ظ…ظٹظ„ ط§ظ„طµظپط­ط© ط§ظ„ط±ط¦ظٹط³ظٹط©',
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () =>
                        context.read<FetchHomeScreenCubit>().fetch(),
                    child: const Text('ط¥ط¹ط§ط¯ط© ط§ظ„ظ…ط­ط§ظˆظ„ط©'),
                  ),
                ],
              ),
            ),
          );
        }

        return const SliverToBoxAdapter(child: SizedBox.shrink());
      },
    );
  }

  Widget _buildBannerCard({
    required String assetPath,
    required VoidCallback onTap,
  }) {
    return RepaintBoundary(
      child: ImageWithNavigationWidget(
        assetPath: assetPath,
        onTap: onTap,
      ),
    );
  }

  // =======================
  // طھظ†ظ‚ظ„ط§طھ ط§ظ„ط£ظ‚ط³ط§ظ… (ط¹ط²ظ„ ط§ظ„ط¯ظˆط§ظ„ ظٹظ‚ظ„ظ„ ط¥ظ†ط´ط§ط، Closures ط¯ط§ط®ظ„ build)
  // =======================
  bool _navLockRealEstate = false;
  final Duration _navThrottle = const Duration(milliseconds: 700);

  Future<void> _goRealEstate() async {
    if (_navLockRealEstate) return;
    _navLockRealEstate = true;

    try {
      // 1) طھط¬ظ‡ظٹط² ط®ظپظٹظپ ظ‚ط¨ظ„ ط§ظ„طھظ†ظ‚ظ‘ظ„ ظ„طھظ‚ظ„ظٹظ„ ط§ظ„طھظ‚ط·ظٹط¹:
      // - ظ„ظˆ ط¹ظ†ط¯ظƒ طµظˆط±ط© ط£ظˆظ„ ط´ط§ط´ط© ظپظٹ طµظپط­ط© ط§ظ„ط¹ظ‚ط§ط±طŒ ط­ط¶ظ‘ط±ظ‡ط§ ظ‡ظ†ط§ (ط§ط®طھظٹط§ط±ظٹ).
      // - precacheImage ظٹط³ط§ط¹ط¯ GPU/Cache ظˆظٹط®ظپظ‘ظپ jank ط£ظˆظ„ ظپط±ظٹظ….
      // ظ…ط«ط§ظ„ (ط¹ط¯ظ‘ظ„ ط§ظ„ظ…ط³ط§ط± ط¥ظ† ظ„ط¯ظٹظƒ Banner ط£ظˆظ„ظٹ ظپظٹ ط´ط§ط´ط© ط§ظ„ط¹ظ‚ط§ط±):
      // await precacheImage(const AssetImage('assets/realestate/hero.jpg'), context);

      // 2) (ط§ط®طھظٹط§ط±ظٹ) Prefetch ط¨ظٹط§ظ†ط§طھ ط£ظˆظ„ظٹط© ظ„ظˆ ط¹ظ†ط¯ظƒ Cubit/Repo ظٹط¯ط¹ظ…:
      // ظٹط´ط؛ظ‘ظ„ ط¬ظ„ط¨ظ‹ط§ ط®ظپظٹظپظ‹ط§ ظپظٹ ط§ظ„ط®ظ„ظپظٹط© ظ‚ط¨ظ„ ط§ظ„طھظ†ظ‚ظ‘ظ„ ط¨ط­ظٹط« ط§ظ„ط´ط§ط´ط© ط§ظ„طھط§ظ„ظٹط© طھظ„ط§ظ‚ظٹ ط¨ظٹط§ظ†ط§طھ ط¬ط§ظ‡ط²ط©.
      // try {
      //   await context.read<FetchItemFromCategoryCubit>().prefetch(categoryId: "1");
      // } catch (_) {}

      // 3) (ط§ط®طھظٹط§ط±ظٹ) ظ„ظ…ط³ط© ط§ظ‡طھط²ط§ط² ط®ظپظٹظپط© UX
      // if (await HapticFeedback.vibrate() is Future) { /* ظ„ط§ ط´ظٹط، */ }
      // HapticFeedback.selectionClick();

      // 4) ط§ظ„طھظ†ظ‚ظ‘ظ„ ط§ظ„ظپط¹ظ„ظٹ (ظ†ظپط³ ط§ظ„ظ…ط³ط§ط± ظˆظ†ظپط³ ط§ظ„ظ…ظپط§طھظٹط­ طھظ…ط§ظ…ظ‹ط§)
      await Navigator.pushNamed(
        context,
        Routes.section_screen,
        arguments: {
          'catID': "1",
          'catName': "realEstateservices".translate(context),
          "categoryIds": ["1"],
          "interfaceType": "real_estate_services",
        },
      );

      // 5) ط¨ط¹ط¯ ط§ظ„ط±ط¬ظˆط¹ (ط§ط®طھظٹط§ط±ظٹ): ط­ط¯ظ‘ط« ط¬ط²ط، ظ…ظ† ط§ظ„طµظپط­ط© ظ„ظˆ ظ„ط²ظ…
      // context.read<FetchHomeScreenCubit>().refreshIfNeeded();
    } finally {
      // ظپظƒ ط§ظ„ظ‚ظپظ„ ط¨ط¹ط¯ ظپطھط±ط© ظ‚طµظٹط±ط© ظ„ظ…ظ†ط¹ ط§ظ„ط³ط¨ط§ظ… ظˆطھط­ط³ظٹظ† ط§ظ„ط³ظ„ط§ط³ط©
      await Future.delayed(_navThrottle);
      _navLockRealEstate = false;
    }
  }

  void _goTourism() {
    Navigator.pushNamed(
      context,
      Routes.classifiedScreenRoute,
      arguments: {
        'catID': "2",
        'catName': "tourismServices".translate(context),
        "interfaceType": "tourism_services"
      },
    );
  }

  void _goElectronicStore() {
    final String categoryId = Constant.storeRootCategoryIdAsString;

    Navigator.pushNamed(
      context,
      Routes.itemsListSeller,
      arguments: {
        'catID': categoryId,
        'catName': "electronicStore".translate(context),
        "categoryIds": [categoryId],
      },
    );
  }

  void _goShein() {
    Navigator.pushNamed(context, Routes.section_screen, arguments: {
      'catID': "4",
      'catName': "productsShein".translate(context),
      "categoryIds": ["4"],
      "interfaceType": "shein_products",
    });
  }

  void _goComputerSection() {
    Navigator.pushNamed(context, Routes.section_screen, arguments: {
      'catID': "5",
      'catName': "computer".translate(context),
      "categoryIds": ["5"],
      "interfaceType": "computer_section"
    });
  }

  void _goPublicAds() {
    Navigator.pushNamed(context, Routes.section_screen, arguments: {
      'catID': "6",
      'catName': "publicAds".translate(context),
      "categoryIds": ["6"],
      "interfaceType": "public_ads"
    });
  }
}

class _PermissionPromptSheet extends StatelessWidget {
  const _PermissionPromptSheet({
    required this.onAllow,
    required this.onSkip,
  });

  final VoidCallback onAllow;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    Widget tile(IconData icon, String title, String subtitle) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: colors.primary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          top: 16,
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
                  color: colors.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'فعّل أفضل التجربة',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'بضغطة واحدة نفعّل الأذونات الضرورية علشان توصلك التنبيهات وتظهر النتائج الأقرب وتقدر ترفع ملفاتك وتسجّل صوت/فيديو.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(height: 18),
            tile(Icons.notifications_active_rounded, 'الإشعارات',
                'علشان نرسل لك العروض والتنبيهات المهمة في وقتها.'),
            tile(Icons.place_rounded, 'الموقع الجغرافي',
                'لإظهار الإعلانات والخدمات الأقرب لك وتحديد التوصيل بدقة.'),
            tile(Icons.photo_library_rounded, 'الصور والملفات',
                'لرفع صور المنتجات والمستندات بدون خطوات إضافية.'),
            tile(Icons.mic_none_rounded, 'الكاميرا والمايك',
                'لتسجيل الملاحظات الصوتية أو مكالمات الدعم والشات.'),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onAllow,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'تفعيل الآن',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colors.onPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: onSkip,
                child: const Text('لاحقاً'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============
// ط£ط°ظˆظ†ط§طھ ط§ظ„ط¥ط´ط¹ط§ط±ط§طھ
// =============
Future<void> notificationPermissionChecker() async {
  // طلب إشعار مستقل أُلغي لصالح النافذة الموحدة
}
