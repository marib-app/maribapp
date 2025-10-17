// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:async';
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




import 'home_ui.dart'; // ← الواجهة المنفصلة



const double sidePadding = 18;

class HomeScreen extends StatefulWidget {
  final String? from;
  const HomeScreen({super.key, this.from});

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin<HomeScreen> {
  @override
  bool get wantKeepAlive => true;

  /// ScrollController مع تنظيف صحيح + حارس منع التكرار
  late final ScrollController _scrollController = ScrollController();
  bool _isFetchingMore = false; // ← يمنع تكرار fetchMore عند الحافة

  /// ملاحظة: حذفت عناصر غير مستخدمة لتقليل الضوضاء والتسريبات:
  /// - itemLocalList, isCategoryEmpty, _refreshIndicatorKey

  @override
  void initState() {
    super.initState(); // ✅ ضع دائمًا أولاً

    initializeSettings();
    addPageScrollListener();

    // ✅ تأجيل تهيئة خدمات الإشعارات وطلب الأذونات لما بعد أول إطار
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // طلب الإذن بعد الإطار الأول يقلل الإزعاج والمشاكل مع الـ context
      notificationPermissionChecker();
      LocalAwsomeNotification().init(context);
      NotificationService.init(context);
    });

    // ✅ تقليل استدعاءات context.read المتكررة
    final r = context.read;
    unawaited(r<SliderCubit>().fetchSlider(context));
    r<FetchCategoryCubit>().fetchCategories();
    r<FetchHomeScreenCubit>().fetch(interfaceType: "homepage");
    r<FetchHomeAllItemsCubit>().fetch();

    // if (HiveUtils.isUserAuthenticated()) {
    //   fetchApiKeys(); // ← فعّلها إن كنت تحتاج مفاتيح فعلاً
    // }

    // ✅ مستمع واحد منظّف في dispose
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    // ✅ إزالة المستمع لتفادي تسريب الذاكرة
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void initializeSettings() {
    final settingsCubit = context.read<FetchSystemSettingsCubit>();
    if (!const bool.fromEnvironment("force-disable-demo-mode", defaultValue: false)) {
      Constant.isDemoModeOn =
          settingsCubit.getSetting(SystemSetting.demoMode) ?? false;
    }
  }

  void addPageScrollListener() {
    // homeScreenController.addListener(pageScrollListener); // ← غير مستخدم حالياً
  }

  void fetchApiKeys() {
    context.read<GetApiKeysCubit>().fetch();
  }

  /// ✅ مستمع التمرير مع حارس لمنع التكرار + قراءة Hive مرة واحدة
  void _onScroll() {
    if (!_scrollController.isEndReached()) return;

    final itemsCubit = context.read<FetchHomeAllItemsCubit>();
    if (_isFetchingMore || !itemsCubit.hasMoreData()) return;

    _isFetchingMore = true;

    // ✅ اقرأ القيم من Hive مرة واحدة لتقليل I/O
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

  @override
  Widget build(BuildContext context) {
    super.build(context);

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

      // بيانات البروفايل (بدل appBarLeading)
      isAuthenticated: HiveUtils.isUserAuthenticated(),
      name: HiveUtils.getUserId()?.toString() ?? 'زائر',
      mobile: '',
      profileUrl: '',
      isVerified: false,
      cartCount: 0,
      notifCount: 0,
      onAvatarTap: () {},
      onCartTap: () {},
      onNotificationTap: () {},
      onInfoTap: () {},
    );
  }



  Widget _buildHomeContentSliver() {
    return BlocBuilder<FetchHomeScreenCubit, FetchHomeScreenState>(
      buildWhen: (prev, curr) => prev.runtimeType != curr.runtimeType,
      builder: (context, state) {
        if (state is FetchHomeScreenInProgress) {
          return SliverToBoxAdapter(child: homeShimmerEffect(context));
        }

        if (state is FetchHomeScreenSuccess) {
          final bool canShowShein = HiveUtils.hasDelegateAccess('shein');
          final bool canShowComputer = HiveUtils.hasDelegateAccess('computer');

          final List<Widget> children = <Widget>[
            RepaintBoundary(
              child: SliderWidget(interfaceType: "homepage"),
            ),
            const SizedBox(height: 12),
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
                    'تعذّر تحميل الصفحة الرئيسية',
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () =>
                        context.read<FetchHomeScreenCubit>().fetch(),
                    child: const Text('إعادة المحاولة'),
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
  // تنقلات الأقسام (عزل الدوال يقلل إنشاء Closures داخل build)
  // =======================
  bool _navLockRealEstate = false;
  final Duration _navThrottle = const Duration(milliseconds: 700);


  Future<void> _goRealEstate() async {
    if (_navLockRealEstate) return;
    _navLockRealEstate = true;

    try {
      // 1) تجهيز خفيف قبل التنقّل لتقليل التقطيع:
      // - لو عندك صورة أول شاشة في صفحة العقار، حضّرها هنا (اختياري).
      // - precacheImage يساعد GPU/Cache ويخفّف jank أول فريم.
      // مثال (عدّل المسار إن لديك Banner أولي في شاشة العقار):
      // await precacheImage(const AssetImage('assets/realestate/hero.jpg'), context);

      // 2) (اختياري) Prefetch بيانات أولية لو عندك Cubit/Repo يدعم:
      // يشغّل جلبًا خفيفًا في الخلفية قبل التنقّل بحيث الشاشة التالية تلاقي بيانات جاهزة.
      // try {
      //   await context.read<FetchItemFromCategoryCubit>().prefetch(categoryId: "1");
      // } catch (_) {}

      // 3) (اختياري) لمسة اهتزاز خفيفة UX
      // if (await HapticFeedback.vibrate() is Future) { /* لا شيء */ }
      // HapticFeedback.selectionClick();

      // 4) التنقّل الفعلي (نفس المسار ونفس المفاتيح تمامًا)
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

      // 5) بعد الرجوع (اختياري): حدّث جزء من الصفحة لو لزم
      // context.read<FetchHomeScreenCubit>().refreshIfNeeded();

    } finally {
      // فك القفل بعد فترة قصيرة لمنع السبام وتحسين السلاسة
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
    Navigator.pushNamed(context, Routes.itemsListSeller, arguments: {
      'catID': "3",
      'catName': "electronicStore".translate(context),
      "categoryIds": ["3"],
    });
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



// =============
// أذونات الإشعارات
// =============
Future<void> notificationPermissionChecker() async {
  // ✅ طلب الإذن عند الحاجة فقط
  if (!(await Permission.notification.isGranted)) {
    await Permission.notification.request();
  }
}
