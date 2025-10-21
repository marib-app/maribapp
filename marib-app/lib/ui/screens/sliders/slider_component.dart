import 'dart:async';
import 'package:flutter/material.dart';
import 'package:marib/data/model/home_slider.dart';
import 'package:marib/data/repositories/item/item_repository.dart';
import 'package:marib/data/model/category_model.dart';
import 'package:marib/utils/responsiveSize.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:marib/app/routes.dart';
import 'package:url_launcher/url_launcher.dart' as urllauncher;
import 'package:marib/data/helper/widgets.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:marib/data/cubits/cart/cart_cubit.dart';
import 'package:marib/ui/screens/settings/main_activity.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:marib/utils/api.dart';
import 'package:marib/utils/hive_utils.dart';
import 'package:marib/utils/slider_interface_mapper.dart';
import 'slider_shimmer.dart';
import 'package:marib/ui/screens/widgets/lazy_network_image.dart';
import 'package:marib/ui/widgets/shimmer/shimmer_box.dart';
import 'slider_constants.dart';


const EdgeInsetsGeometry kSliderHorizontalPadding =
EdgeInsets.symmetric(horizontal: 10);


class SliderComponent extends StatefulWidget {
  final String interfaceType;
  final List<HomeSlider> sliderList;
  final EdgeInsetsGeometry padding;

  const SliderComponent({
    super.key,
    required this.interfaceType,
    required this.sliderList,
    this.padding = kSliderHorizontalPadding,
  });

  @override
  State<SliderComponent> createState() => _SliderComponentState();
}

typedef _LaunchUrlCallback = Future<bool> Function(Uri uri);
typedef _CanLaunchUrlCallback = Future<bool> Function(Uri uri);
typedef _SliderClickPostCallback = Future<Map<String, dynamic>> Function({
required String url,
dynamic parameter,
Map<String, dynamic>? extraHeaders,
});

typedef _EnsureSliderSessionCallback = Future<String> Function();

_LaunchUrlCallback? _launchUrlOverride;
_CanLaunchUrlCallback? _canLaunchUrlOverride;
_SliderClickPostCallback? _sliderClickReporterOverride;
_EnsureSliderSessionCallback? _ensureSliderSessionOverride;

@visibleForTesting
void setSliderUrlLauncherOverrides({
  _LaunchUrlCallback? launch,
  _CanLaunchUrlCallback? canLaunch,
}) {
  _launchUrlOverride = launch;
  _canLaunchUrlOverride = canLaunch;
}

@visibleForTesting
void setSliderClickReporterOverrides({
  _SliderClickPostCallback? postOverride,
  _EnsureSliderSessionCallback? ensureSessionOverride,
}) {
  _sliderClickReporterOverride = postOverride;
  _ensureSliderSessionOverride = ensureSessionOverride;
}

Future<bool> _launchExternalUrl(Uri uri) {
  final _LaunchUrlCallback? override = _launchUrlOverride;
  if (override != null) {
    return override(uri);
  }
  return urllauncher.launchUrl(
    uri,
    mode: urllauncher.LaunchMode.externalApplication,
  );
}

Future<bool> _canLaunchExternalUrl(Uri uri) {
  final _CanLaunchUrlCallback? override = _canLaunchUrlOverride;
  if (override != null) {
    return override(uri);
  }
  return urllauncher.canLaunchUrl(uri);
}

class _SliderComponentState extends State<SliderComponent>
    with AutomaticKeepAliveClientMixin {
  final ValueNotifier<int> _bannerIndex =
  ValueNotifier(0); // لتتبع السلايدر الحالي
  Timer? _sliderTimer;
  late final PageController _pageController;
  bool _userInteracting = false;
  double? _currentPage;
  final Set<int> _pendingSliderClickReports = <int>{};

  /// ✅ الفلترة النهائية للسلايدر حسب نوع الواجهة، مع حماية إضافية
  List<HomeSlider> get filteredList {
    final String rawTarget = widget.interfaceType.trim().toLowerCase();
    final String normalizedTarget =
        SliderInterfaceMapper.normalize(widget.interfaceType) ?? rawTarget;

    bool isGeneralInterfaceValue(String? value) {
      if (value == null) {
        return true;
      }

      final String cleaned = value.trim().toLowerCase();
      return cleaned.isEmpty || cleaned == 'all';
    }

    return widget.sliderList.where((HomeSlider e) {
      if (isGeneralInterfaceValue(e.interfaceType)) {
        return true;
      }

      final String sliderRaw = (e.interfaceType ?? '').trim().toLowerCase();
      final String normalizedSlider =
          SliderInterfaceMapper.normalize(e.interfaceType) ?? sliderRaw;

      if (normalizedTarget.isEmpty) {
        return normalizedSlider.isEmpty && sliderRaw == rawTarget;
      }

      return normalizedSlider == normalizedTarget || sliderRaw == rawTarget;
    }).toList(growable: false);
  }

  /// ✅ عدد البنرات بعد التصفية
  int get bannersLength => filteredList.length;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    _pageController = PageController(
      initialPage: bannersLength == 1 ? 0 : bannersLength * 1000,
    );

    _currentPage = _pageController.initialPage.toDouble();

    _startAutoSlider(resetToInitial: true);
  }

  @override
  void didUpdateWidget(covariant SliderComponent oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.sliderList != widget.sliderList) {
      _startAutoSlider(resetToInitial: true);
    }
  }

  @override
  void dispose() {
    _sliderTimer?.cancel();
    _pageController.dispose();
    _bannerIndex.dispose();
    super.dispose();
  }

  // ✅ تشغيل السلايدر بشكل تلقائي كل 5 ثوانٍ

  void _startAutoSlider({bool resetToInitial = false}) {
    _sliderTimer?.cancel(); // وقف المؤقت السابق لو موجود

    if (resetToInitial) {
      _resetToInitialPage();
    } else {
      if (_pageController.hasClients) {
        _currentPage = _pageController.page ?? _currentPage;
      }
      _currentPage ??= _pageController.initialPage.toDouble();
    }

    if (bannersLength <= 1) {
      return;
    }
    _sliderTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || bannersLength == 0 || !_pageController.hasClients) return;
      if (_userInteracting)
        return; // إذا المستخدم يتفاعل، لا تنفذ التنقل التلقائي
      if (bannersLength <= 1) return;

      final currentPageValue = _pageController.page ??
          _currentPage ??
          _pageController.initialPage.toDouble();
      final currentIndex = currentPageValue.floor();
      final next = currentIndex + 1;

      _pageController
          .animateToPage(
        next,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      )
          .then((_) {
        if (!mounted) return;
        _currentPage = next.toDouble();
        if (bannersLength > 0) {
          _bannerIndex.value = next % bannersLength;
        }
      });
    });
  }

  void _resetToInitialPage() {
    final initialPage = bannersLength <= 1 ? 0 : bannersLength * 1000;
    _currentPage = initialPage.toDouble();

    if (_pageController.hasClients) {
      _pageController.jumpToPage(initialPage);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_pageController.hasClients) return;
        _pageController.jumpToPage(initialPage);
      });
    }

    if (bannersLength > 0) {
      _bannerIndex.value = initialPage % bannersLength;
    } else {
      _bannerIndex.value = 0;
    }
  }

  BoxDecoration _buildBannerDecoration() {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      color: Colors.grey.shade200,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  Widget _buildBannerShell({required Widget child, VoidCallback? onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Ink(
          decoration: _buildBannerDecoration(),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: child,
          ),
        ),
      ),
    );
  }


  /// ✅ التعامل مع الضغط على كل صورة داخل السلايدر
  Future<void> _handleTap(HomeSlider slider) async {
    if (!mounted) return;
    unawaited(_reportSliderClick(slider));

    final String? actionType = slider.actionTypeNormalized;
    final String? destination = slider.destinationNormalized;

    if (_isChatAction(actionType, destination)) {
      MainActivity.globalKey.currentState?.onItemTapped(1);
      return;
    }

    if (_isCouponAction(actionType, destination)) {
      await _handleCouponAction(slider);
      return;
    }

    if (await _handleExternalLink(slider, actionType, destination)) {
      return;
    }

    final bool navigated =
    await _handleTargetNavigation(slider, actionType, destination);
    if (navigated) {
      return;
    }

    await _handleLegacyTap(slider);
  }

  Future<void> _reportSliderClick(HomeSlider slider) async {
    final int? sliderId = slider.id;
    if (sliderId == null) {
      return;
    }

    if (_pendingSliderClickReports.contains(sliderId)) {
      return;
    }

    _pendingSliderClickReports.add(sliderId);

    try {
      final _EnsureSliderSessionCallback ensureSession =
          _ensureSliderSessionOverride ?? HiveUtils.ensureSliderSessionId;
      await ensureSession();

      final _SliderClickPostCallback reporter =
          _sliderClickReporterOverride ?? Api.post;

      await reporter(
        url: 'sliders/$sliderId/click',
        parameter: <String, dynamic>{},
      );
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Slider click tracking failed: $error');
        debugPrint(stackTrace.toString());
      }
    } finally {
      _pendingSliderClickReports.remove(sliderId);
    }
  }

  bool _isChatAction(String? actionType, String? destination) {
    return actionType == 'open_chat' ||
        destination == 'chat' ||
        actionType == 'chat';
  }

  bool _isCouponAction(String? actionType, String? destination) {
    return actionType == 'apply_coupon' ||
        actionType == 'coupon' ||
        destination == 'coupon';
  }

  Future<bool> _handleExternalLink(
      HomeSlider slider,
      String? actionType,
      String? destination,
      ) async {
    final bool wantsExternal = actionType == 'open_link' ||
        actionType == 'external_link' ||
        destination == 'external_link' ||
        destination == 'external';

    String? link = wantsExternal ? slider.resolvedExternalLink : null;
    link ??= slider.thirdPartyLink;

    if (link == null || link.trim().isEmpty) {
      return false;
    }

    final Uri? uri = Uri.tryParse(link.trim());
    if (uri == null) {
      return false;
    }

    if (await _canLaunchExternalUrl(uri)) {
      if (!mounted) return true;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('جاري فتح الرابط...'),
          duration: Duration(seconds: 1),
        ),
      );
      await _launchExternalUrl(uri);
      return true;
    }

    return false;
  }

  Future<bool> _handleTargetNavigation(
      HomeSlider slider,
      String? actionType,
      String? destination,
      ) async {
    final bool shouldNavigate = slider.targetSummary != null ||
        actionType == 'navigate' ||
        destination == 'internal' ||
        destination == 'navigate';

    if (!shouldNavigate || slider.targetSummary == null) {
      return false;
    }

    final HomeSliderTargetSummary target = slider.targetSummary!;

    if (target.isCategory) {
      return _navigateToCategory(slider, target);
    }

    if (target.isItem) {
      return _navigateToItem(slider, target);
    }

    final String? route = target.routeName;
    if (route != null && route.isNotEmpty) {
      if (!mounted) return true;
      await Navigator.pushNamed(context, route,
          arguments: target.arguments ?? target.meta);
      return true;
    }

    return false;
  }

  Future<bool> _navigateToCategory(
      HomeSlider slider,
      HomeSliderTargetSummary target,
      ) async {
    final CategorySlider? category = target.asCategorySlider ?? slider.model;
    final int? categoryId = target.idAsInt ?? slider.modelId ?? category?.id;
    if (category == null || categoryId == null) {
      return false;
    }

    final int subCount =
        target.subCategoriesCount ?? category.subCategoriesCount ?? 0;
    final int? parentId = target.parentCategoryId ?? category.parentCategoryId;
    if (!mounted) {
      return false;
    }

    if (subCount > 0 && parentId != null) {
      Navigator.pushNamed(context, Routes.subCategoryScreen, arguments: {
        'categoryList': <CategoryModel>[],
        'catName': category.name,
        'catId': categoryId,
        'categoryIds': [parentId.toString(), categoryId.toString()],
      });
    } else {
      Navigator.pushNamed(context, Routes.itemsList, arguments: {
        'catID': categoryId.toString(),
        'catName': category.name,
        'categoryIds': [categoryId.toString()],
      });
    }
    return true;
  }

  Future<bool> _navigateToItem(
      HomeSlider slider,
      HomeSliderTargetSummary target,
      ) async {
    final ItemRepository repository = ItemRepository();
    try {
      Widgets.showLoader(context);
      final int? itemId = target.idAsInt ?? slider.modelId;
      final String? slug = target.slug;
      if ((slug == null || slug.isEmpty) && itemId == null) {
        Widgets.hideLoder(context);
        return false;
      }
      final data = slug != null && slug.isNotEmpty
          ? await repository.fetchItemFromItemSlug(slug)
          : await repository.fetchItemFromItemId(itemId!);
      if (!mounted) {
        return true;
      }
      await Future.delayed(const Duration(milliseconds: 100));
      Widgets.hideLoder(context);
      await Navigator.pushNamed(context, Routes.adDetailsScreen, arguments: {
        'model': data.modelList.first,
      });
      return true;
    } catch (error) {
      Widgets.hideLoder(context);
      if (mounted) {
        HelperUtils.showSnackBarMessage(context, error.toString());
      }
      return true;
    }
  }

  Future<void> _handleLegacyTap(HomeSlider slider) async {
    if (await _handleExternalLink(slider, null, null)) {
      return;
    }

    if (slider.modelType?.contains('Category') == true) {
      if (slider.model == null) return;

      if (slider.model!.subCategoriesCount != null &&
          slider.model!.subCategoriesCount! > 0) {
        if (!mounted) return;

        Navigator.pushNamed(context, Routes.subCategoryScreen, arguments: {
          'categoryList': <CategoryModel>[],
          'catName': slider.model!.name,
          'catId': slider.modelId,
          'categoryIds': [
            slider.model!.parentCategoryId.toString(),
            slider.modelId.toString()
          ]
        });
      } else {
        if (!mounted) return;

        Navigator.pushNamed(context, Routes.itemsList, arguments: {
          'catID': slider.modelId.toString(),
          'catName': slider.model!.name,
          'categoryIds': [slider.modelId.toString()]
        });
      }
      return;
    }

    if (slider.modelId == null) {
      return;
    }

    try {
      Widgets.showLoader(context);
      final data = await ItemRepository().fetchItemFromItemId(slider.modelId!);
      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 100));
      Widgets.hideLoder(context);
      await Navigator.pushNamed(context, Routes.adDetailsScreen, arguments: {
        'model': data.modelList.first,
      });
    } catch (e) {
      Widgets.hideLoder(context);
      if (mounted) {
        HelperUtils.showSnackBarMessage(context, e.toString());
      }
    }
  }

  Future<void> _handleCouponAction(HomeSlider slider) async {
    final String? coupon =
        slider.resolvedCouponCode ?? slider.actionPayload?.couponCode;
    if (coupon == null || coupon.trim().isEmpty) {
      if (!mounted) return;
      HelperUtils.showSnackBarMessage(context, 'تعذر قراءة رمز القسيمة.');
      return;
    }

    CartCubit? cartCubit;
    try {
      cartCubit = BlocProvider.of<CartCubit>(context, listen: false);
    } catch (_) {
      cartCubit = null;
    }
    if (cartCubit != null) {
      await cartCubit.applyCoupon(coupon);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم إرسال القسيمة للسلة: $coupon'),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('رمز القسيمة $coupon متاح. افتح السلة لتطبيقه.'),
          duration: const Duration(seconds: 2),
        ),
      );
      await Navigator.pushNamed(context, Routes.cart);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final hasBanners = bannersLength > 0;
    final itemCount = hasBanners
        ? (bannersLength == 1 ? 1 : null)
        : 1; // الحفاظ على صفحة واحدة عند غياب أي بنرات
    final pagePhysics = hasBanners
        ? (bannersLength == 1
        ? const BouncingScrollPhysics()
        : const ClampingScrollPhysics())
        : const NeverScrollableScrollPhysics();

    if (!hasBanners) {
      debugPrint(
          "⚠️ SliderComponent: لا توجد بانرات لواجهة '${widget.interfaceType}'");
      return _wrapWithPadding(const SliderShimmer());
    }

    return _wrapWithPadding(
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            height: kSliderBannerHeight,
            child: Stack(
              fit: StackFit.expand,
              children: [
                NotificationListener<UserScrollNotification>(
                  onNotification: (notification) {
                    if (!hasBanners) return false;

                    if (notification is ScrollStartNotification) {
                      _userInteracting = true;
                      _sliderTimer?.cancel();
                    } else if (notification is ScrollEndNotification) {
                      _userInteracting = false;
                      _startAutoSlider();
                    }
                    return false;
                  },
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: itemCount,
                    physics: pagePhysics,
                    onPageChanged: hasBanners
                        ? (int index) {
                      if (bannersLength > 1) {
                        _bannerIndex.value = index % bannersLength;
                      } else {
                        _bannerIndex.value = 0;
                      }
                      _currentPage = index.toDouble();
                    }
                        : null,
                    itemBuilder: (_, int index) {
                      final int actualIndex =
                      bannersLength == 1 ? 0 : index % bannersLength;
                      final HomeSlider slider = filteredList[actualIndex];

                      return _buildBannerShell(
                        onTap: () => _handleTap(slider),
                        child: LazyNetworkImage(
                          imageUrl: slider.image ?? '',
                          fit: BoxFit.cover,
                          placeholder: const ShimmerBox(),
                          errorWidget: const ShimmerBox(animate: false),
                        ),
                      );
                    },
                  ),
                ),

              ],
            ),
          ),
          SizedBox(height: 8.rh(context)),
          ValueListenableBuilder<int>(
            valueListenable: _bannerIndex,
            builder: (context, activeIndex, _) {
              final int total = bannersLength > 0 ? bannersLength : 1;
              final int safeActiveIndex = total == 0 ? 0 : activeIndex % total;
              return AnimatedSmoothIndicator(
                activeIndex: safeActiveIndex,
                count: total,
                effect: CustomizableEffect(
                  spacing: 6,
                  activeDotDecoration: DotDecoration(
                    width: 16,
                    height: 8,
                    color: const Color(0xFFEB5924),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  dotDecoration: DotDecoration(
                    width: 8,
                    height: 8,
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              );
            },
          )
        ],
      ),
    );
  }

  Widget _wrapWithPadding(Widget child) {
    if (widget.padding == EdgeInsets.zero ||
        widget.padding == EdgeInsetsDirectional.zero) {
      return child;
    }
    return Padding(
      padding: widget.padding,
      child: child,
    );
  }
}