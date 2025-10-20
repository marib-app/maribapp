import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/constant.dart';
import 'package:marib/utils/hive_utils.dart';
import 'package:marib/utils/api.dart';
import 'package:marib/data/model/item_filter_model.dart';
import 'package:marib/data/cubits/item/fetch_item_summary_cubit.dart';
import 'package:marib/data/cubits/home/fetch_home_screen_cubit.dart';

import 'package:marib/data/cubits/slider_cubit.dart';

import 'package:marib/utils/ui_utils.dart';
import 'package:marib/ui/screens/widgets/animated_routes/blur_page_route.dart';

import 'widgets/filter_sort_bar/filter_sort_bar.dart';
import 'widgets/items_body_box.dart';
import 'package:marib/utils/slider_interface_mapper.dart';
import 'package:marib/utils/featured_section_utils.dart';
import 'package:marib/utils/logger.dart';
import 'package:marib/app/routes.dart';

class Section_screen extends StatefulWidget {
  final String categoryId; // معرف الفئة الحالية
  final String categoryName; // اسم الفئة الحالية
  final List<String> categoryIds; // قائمة معرفات الفئات
  final String? interfaceType;

  const Section_screen({
    super.key,
    required this.categoryId,
    required this.categoryName,
    required this.categoryIds,
    this.interfaceType,
  });

  @override
  Section_screenState createState() => Section_screenState();

  static Route route(RouteSettings routeSettings) {
    final Map? arguments = routeSettings.arguments as Map?;
    final dynamic rawInterfaceType = arguments?['interfaceType'];
    final String? interfaceType =
        rawInterfaceType is String && rawInterfaceType.trim().isNotEmpty
            ? rawInterfaceType.trim()
            : null;
    return BlurredRouter(
      builder: (_) => BlocProvider(
        create: (context) => FetchHomeScreenCubit(
          defaultInterfaceType: interfaceType,
        ),
        child: Section_screen(
          categoryId: arguments?['catID'] as String,
          categoryName: arguments?['catName'],
          categoryIds: arguments?['categoryIds'],
          interfaceType: interfaceType,
        ),
      ),
    );
  }
}

class Section_screenState extends State<Section_screen> {
  // =========================
  // متغيرات الحالة / الأداء
  // =========================

  static const double _kFilterSortBarVerticalPadding = 16.0;
  static const double _kFilterSortBarMinButtonHeight = 44.0;
  static const double _kFilterSortBarMaxButtonHeight = 52.0;
  static const double _kBottomBarMinimumSafeArea = 12.0;

  static const Duration _bottomBarAnimationDuration =
      Duration(milliseconds: 320);

  // ✅ تحويل categoryId مرة واحدة
  static const int _defaultCategoryId = 0;

  late final int _catId;
  bool _catIdUsedFallback = false;
  bool _hasLoggedFallbackFetch = false;

  // ✅ حقل البحث + ديباونس
  final TextEditingController searchController = TextEditingController();

  // ✅ تحميل المزيد
  bool _isLoadingMore = false;

  // ✅ إظهار shimmer
  bool showShimmer = true;

  // ✅ فرز وفلاتر
  String? sortBy;
  ItemFilterModel? filter;
  ItemFilterModel? _initialFilter;

  // ✅ تبليغ الفئة المختارة
  final ValueNotifier<int?> selectedCategoryId = ValueNotifier<int?>(0);

  // ✅ تحكم ظهور شريط التصنيفات الحقيقي
  bool _showSlider = false;

  // ✅ تحكم في ظهور شريط الفلترة/الفرز السفلي حسب التمرير
  final ValueNotifier<bool> _showBottomBar = ValueNotifier<bool>(true);

  // ✅ لإجبار إظهار الشيمر فترة دنيا بعد أول Loading
  bool _sawLoading = false;
  DateTime? _loadingStart;
  static const Duration _minShimmer = Duration(milliseconds: 350);
  late final String _sliderInterfaceType;

  late final bool _hasAdSlider;

  bool _showAdSlider = false;
  bool _requestedSlider = false;

  late final String? _requestSectionSlug;

  bool _isValidCategoryId(String? raw) {
    if (raw == null) return false;
    final String trimmed = raw.trim();
    if (trimmed.isEmpty) return false;
    return int.tryParse(trimmed) != null;
  }

  int _parseInitialCategoryId(String raw) {
    final String trimmed = raw.trim();
    final int? parsed = int.tryParse(trimmed);
    if (parsed != null) {
      return parsed;
    }

    _catIdUsedFallback = true;
    _emitInvalidCategoryIdLog(raw);
    return _defaultCategoryId;
  }

  void _emitInvalidCategoryIdLog(String raw) {
    Logger.debug(
      'Section_screen received invalid categoryId "$raw". Falling back to $_defaultCategoryId.',
      name: 'Section_screen',
    );
  }

  String _resolveCategoryIdString({
    ItemFilterModel? source,
    int? categoryIdOverride,
  }) {
    final String? candidate = source?.categoryId;
    if (_isValidCategoryId(candidate)) {
      return candidate!.trim();
    }

    final int fallback = categoryIdOverride ?? _catId;
    return fallback.toString();
  }

  int _resolveCategoryIdInt({
    ItemFilterModel? source,
    int? categoryIdOverride,
  }) {
    final String resolved = _resolveCategoryIdString(
      source: source,
      categoryIdOverride: categoryIdOverride,
    );

    return int.tryParse(resolved) ?? (categoryIdOverride ?? _catId);
  }

  int _resolveSelectedCategoryFallback() {
    final int? selected = selectedCategoryId.value;
    if (selected == null || selected <= 0) {
      return _catId;
    }
    return selected;
  }

  ItemFilterModel _buildEffectiveFilter({
    ItemFilterModel? base,
    int? categoryIdOverride,
  }) {
    final ItemFilterModel? source = base ?? filter ?? _initialFilter;
    final String resolvedCategoryId = _resolveCategoryIdString(
      source: source,
      categoryIdOverride: categoryIdOverride,
    );

    if (source == null) {
      return ItemFilterModel(
        categoryId: resolvedCategoryId,
      );
    }

    return source.copyWith(
      categoryId: resolvedCategoryId,
    );
  }

  double _estimateFilterSortBarHeight(MediaQueryData mediaQuery) {
    final double fallbackHeight = (mediaQuery.size.height * 0.08)
        .clamp(_kFilterSortBarMinButtonHeight, _kFilterSortBarMaxButtonHeight)
        .toDouble();
    return fallbackHeight + _kFilterSortBarVerticalPadding;
  }

  double _calculateBottomBarHeight(BuildContext context) {
    final MediaQueryData mediaQuery = MediaQuery.of(context);
    final double filterSortBarHeight = _estimateFilterSortBarHeight(mediaQuery);
    final double safeBottom = mediaQuery.viewPadding.bottom;
    final double effectiveSafeBottom = safeBottom >= _kBottomBarMinimumSafeArea
        ? safeBottom
        : _kBottomBarMinimumSafeArea;
    return filterSortBarHeight + effectiveSafeBottom;
  }

  void _requestFeaturedSections({int? rootId, String? slug}) {
    final String? normalizedInterface =
        SliderInterfaceMapper.normalize(widget.interfaceType) ??
            widget.interfaceType?.trim();

    if (normalizedInterface == null || normalizedInterface.isEmpty) {
      context.read<FetchHomeScreenCubit>().fetch();
      return;
    }
    final int effectiveRootId = rootId ?? _resolveSelectedCategoryFallback();

    final FetchHomeScreenState cubitState =
        context.read<FetchHomeScreenCubit>().state;
    String? cachedRootIdentifier;
    if (cubitState is FetchHomeScreenSuccess) {
      cachedRootIdentifier = cubitState.rootIdentifier;
    }

    final String? resolvedRootIdentifier =
        FeaturedSectionUtils.resolveRootIdentifier(
      interfaceType: normalizedInterface,
      rootCategoryId: effectiveRootId,
      cachedRootIdentifier: cachedRootIdentifier,
    );
    final String? cleanedSlug = slug?.trim();

    context.read<FetchHomeScreenCubit>().loadFeaturedSections(
          interfaceType: normalizedInterface,
          slug: (cleanedSlug != null && cleanedSlug.isNotEmpty)
              ? cleanedSlug
              : null,
          rootIdentifier: resolvedRootIdentifier,
        );
  }

  Future<void> _refreshData({
    ItemFilterModel? baseFilter,
    String? search,
    int? categoryId,
  }) async {
    final ItemFilterModel effectiveFilter = _buildEffectiveFilter(
      base: baseFilter,
      categoryIdOverride: categoryId,
    );

    final int resolvedCategoryId = _resolveCategoryIdInt(
      source: effectiveFilter,
      categoryIdOverride: categoryId,
    );

    filter = effectiveFilter;

    final String query = search ?? searchController.text;

    await context.read<FetchItemSummaryCubit>().fetchSummaries(
          categoryId: resolvedCategoryId,
          search: query,
          sortBy: sortBy,
          filter: effectiveFilter,
        );
  }

  @override
  void initState() {
    super.initState();
    // =========================
    // إعداد معرف الفئة الأساسي
    // =========================
    _catId = _parseInitialCategoryId(widget.categoryId);

    // (اختياري) لو هذه المتغيرات عندك أصلاً — وإلا احذف السطور الثلاثة:
    // searchbody = {};
    // selectedcategoryId = widget.categoryId;
    // selectedcategoryName = widget.categoryName;
    // searchbody[Api.categoryId] = widget.categoryId;

    // 2) الجلب الأولي بعوامل الموقع
    final country = HiveUtils.getCountryName() ?? "";
    final areaId = HiveUtils.getAreaId() != null
        ? int.parse(HiveUtils.getAreaId().toString())
        : null;
    final city = HiveUtils.getCityName() ?? "";
    final state = HiveUtils.getStateName() ?? "";
    final radius = HiveUtils.getNearbyRadius();
    final lat = HiveUtils.getLatitude();
    final lon = HiveUtils.getLongitude();

    final ItemFilterModel locationFilter = ItemFilterModel(
      country: country,
      areaId: areaId,
      city: city,
      state: state,
      categoryId: widget.categoryId,
      radius: radius,
      latitude: lat,
      longitude: lon,
    );

    final ItemFilterModel effectiveFilter = _buildEffectiveFilter(
      base: locationFilter,
      categoryIdOverride: _catId,
    );

    _initialFilter = effectiveFilter;
    filter = effectiveFilter;

    _requestSectionSlug = _resolveRequestSectionSlug();

    unawaited(
      _refreshData(
        baseFilter: effectiveFilter,
        categoryId: _catId,
        search: '',
      ),
    );

    // لضمان توفر البيانات قبل بناء HomeTabView.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _requestFeaturedSections(rootId: _catId);
    });

    final String? normalizedInterfaceType =
        SliderInterfaceMapper.normalize(widget.interfaceType) ??
            widget.interfaceType?.trim();
    _sliderInterfaceType =
        (normalizedInterfaceType == null || normalizedInterfaceType.isEmpty)
            ? 'homepage'
            : normalizedInterfaceType;
    _hasAdSlider = _sliderInterfaceType.isNotEmpty;
    if (_hasAdSlider) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _requestedSlider) {
          return;
        }
        _requestedSlider = true;
        unawaited(
          context.read<SliderCubit>().fetchSlider(
                context,
                forceRefresh: true,
                interfaceType: _sliderInterfaceType,
              ),
        );
      });
    }

    // 3) حالة البداية: اعتبر أننا سنرى Loading حالًا
    showShimmer = true;
    _showSlider = false;
    _showAdSlider = _hasAdSlider;
  }

  String? _resolveRequestSectionSlug() {
    if (_catId == Constant.sheinRootCategoryId) {
      return 'shein';
    }
    if (_catId == Constant.computerRootCategoryId) {
      return 'computer';
    }

    final String? normalizedInterfaceType =
        SliderInterfaceMapper.normalize(widget.interfaceType) ??
            widget.interfaceType?.trim().toLowerCase();

    switch (normalizedInterfaceType) {
      case 'shein':
      case 'shein_products':
        return 'shein';
      case 'computer':
      case 'computer_section':
        return 'computer';
      default:
        return null;
    }
  }

  @override
  void dispose() {
    _showBottomBar.dispose();
    selectedCategoryId.dispose();
    searchController.dispose();
    super.dispose();
  }

  // =========================
  // تحميل لانهائي
  // =========================
  void _handleLoadMoreState(bool isLoading) {
    if (_isLoadingMore == isLoading) return;

    if (!mounted) {
      // يحمي setState من استدعاءات onLoadMore المتأخرة بعد التخلص من الودجت.
      return;
    }

    setState(() => _isLoadingMore = isLoading);
  }

  // =========================
  // سحب للتحديث
  // =========================
  Future<void> _handleRefresh() async {
    try {
      HapticFeedback.selectionClick();
      setState(() => showShimmer = true);

      if (_hasAdSlider) {
        unawaited(
          context.read<SliderCubit>().fetchSlider(
                context,
                forceRefresh: true,
                interfaceType: _sliderInterfaceType,
              ),
        );
      }

      final ItemFilterModel effectiveFilter = _buildEffectiveFilter();
      final int resolvedCategoryId = _resolveCategoryIdInt(
        source: effectiveFilter,
      );

      filter = effectiveFilter;

      await context.read<FetchItemSummaryCubit>().fetchSummaries(
            categoryId: resolvedCategoryId,
            search: searchController.text,
            sortBy: sortBy,
            filter: effectiveFilter,
          );

      // إعادة تحميل أقسام الإعلانات المميزة عند السحب للتحديث
      _requestFeaturedSections(
        rootId: resolvedCategoryId,
      );

      // (اختياري)
      // Constant.itemFilter = null;
      // searchbody = {};
    } finally {
      if (mounted) setState(() => showShimmer = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final overlay = UiUtils.getSystemUiOverlayStyle(
      context: context,
      statusBarColor: context.color.secondaryColor,
    );

    final bool showCartAction = {
      Constant.sheinRootCategoryId,
      Constant.computerRootCategoryId,
      Constant.storeRootCategoryId,
    }.contains(_catId);

    final VoidCallback? onCartTap =
        showCartAction ? () => Navigator.pushNamed(context, Routes.cart) : null;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay,
      child: BlocListener<FetchItemSummaryCubit, FetchItemSummaryState>(
        listenWhen: (prev, curr) => prev.runtimeType != curr.runtimeType,
        listener: (_, state) async {
          if (!mounted) return;

          if (state is FetchItemSummaryInitial ||
              state is FetchItemSummaryLoading) {
            debugPrint('[Realestate] state=Loading');
            _sawLoading = true;
            _loadingStart = DateTime.now();

            setState(() {
              showShimmer = true;
              _showSlider = false; // اخفِ شريط التصنيفات
              _showAdSlider = _hasAdSlider; // حافظ على حالة السلايدر الإعلاني
            });
            return;
          }

          if (state is FetchItemSummarySuccess) {
            debugPrint('[Realestate] state=Success');

            // فرض مدة دنيا للشيمر
            final elapsed = _loadingStart == null
                ? _minShimmer
                : DateTime.now().difference(_loadingStart!);
            final wait = elapsed >= _minShimmer
                ? Duration.zero
                : (_minShimmer - elapsed);

            if (wait > Duration.zero) {
              await Future.delayed(wait);
              if (!mounted) return;
            }

            setState(() {
              showShimmer = false;
              _showSlider = true; // أظهر التصنيفات
              _showAdSlider =
                  _hasAdSlider; // أظهر السلايدر الإعلاني (يبدأ الجلب الآن)
            });

            _sawLoading = false;
            _loadingStart = null;
            return;
          }

          if (state is FetchItemSummaryFailure) {
            debugPrint('[Realestate] state=Failure');
            setState(() {
              showShimmer = false;
              _showSlider = false;
              _showAdSlider = false;
            });
            _sawLoading = false;
            _loadingStart = null;
          }
        },
        child: ValueListenableBuilder<bool>(
            valueListenable: _showBottomBar,
            builder: (context, show, _) {
              final double bottomContentPadding =
                  show ? _calculateBottomBarHeight(context) : 0.0;

              final Widget animatedBottomBar = AnimatedSwitcher(
                duration: _bottomBarAnimationDuration,
                layoutBuilder:
                    (Widget? currentChild, List<Widget> previousChildren) {
                  return Stack(
                    alignment: Alignment.bottomCenter,
                    children: <Widget>[
                      ...previousChildren,
                      if (currentChild != null) currentChild,
                    ],
                  );
                },
                transitionBuilder: (Widget child, Animation<double> animation) {
                  final Animation<double> fadeAnimation = CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOut,
                    reverseCurve: Curves.easeIn,
                  );
                  final Animation<Offset> slideAnimation = Tween<Offset>(
                    begin: const Offset(0, 1),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                    reverseCurve: Curves.easeInCubic,
                  ));

                  return SlideTransition(
                    position: slideAnimation,
                    child: FadeTransition(
                      opacity: fadeAnimation,
                      child: child,
                    ),
                  );
                },
                child: show
                    ? SafeArea(
                        key: const ValueKey('bottom_bar_visible'),
                        top: false,
                        left: false,
                        right: false,
                        minimum: const EdgeInsets.only(bottom: 12),
                        child: ValueListenableBuilder<int?>(
                          valueListenable: selectedCategoryId,
                          builder: (context, selectedId, _) {
                            final int effectiveCategoryId =
                                selectedId ?? _catId;
                            final bool showMap = !{
                              Constant.computerRootCategoryId,
                              Constant.sheinRootCategoryId,
                              Constant.storeRootCategoryId,
                            }.contains(effectiveCategoryId);

                            return FilterSortBar(
                              categoryIds: widget.categoryIds,
                              categoryId: widget.categoryId,
                              searchController: searchController,
                              onFilterChanged: (newFilter) {
                                final ItemFilterModel effectiveFilter =
                                    _buildEffectiveFilter(
                                  base: newFilter,
                                );
                                filter = effectiveFilter;
                                final int resolvedCategoryId =
                                    _resolveCategoryIdInt(
                                  source: effectiveFilter,
                                );

                                if (_isValidCategoryId(newFilter?.categoryId) &&
                                    selectedCategoryId.value !=
                                        resolvedCategoryId) {
                                  selectedCategoryId.value = resolvedCategoryId;
                                }

                                context
                                    .read<FetchItemSummaryCubit>()
                                    .fetchSummaries(
                                      categoryId: resolvedCategoryId,
                                      search: searchController.text,
                                      filter: effectiveFilter,
                                      sortBy: sortBy,
                                    );
                              },
                              onSortChanged: (newSort) {
                                sortBy = newSort;

                                final ItemFilterModel effectiveFilter =
                                    _buildEffectiveFilter();
                                filter = effectiveFilter;
                                final int resolvedCategoryId =
                                    _resolveCategoryIdInt(
                                  source: effectiveFilter,
                                );

                                context
                                    .read<FetchItemSummaryCubit>()
                                    .fetchSummaries(
                                      categoryId: resolvedCategoryId,
                                      search: searchController.text,
                                      filter: effectiveFilter,
                                      sortBy: sortBy,
                                    );
                              },
                              showMapButton: showMap,
                              onMapSearchTap: showMap
                                  ? () {
                                      Navigator.pushNamed(
                                          context, '/mapSearch');
                                    }
                                  : null,
                            );
                          },
                        ),
                      )
                    : const SizedBox.shrink(
                        key: ValueKey('bottom_bar_hidden'),
                      ),
              );

              return Scaffold(
                backgroundColor: context.color.primaryColor,
                appBar: null, // AppBar داخل ItemsBodyBox
                body: Stack(
                  children: [
                    Positioned.fill(
                      child: Column(
                        children: [
                          Expanded(
                            child: RepaintBoundary(
                              child: NotificationListener<ScrollNotification>(
                                onNotification: (_) => false,
                                child: RefreshIndicator(
                                  onRefresh: _handleRefresh,
                                  color: context.color.territoryColor,
                                  displacement: 40,
                                  strokeWidth: 3.0,
                                  triggerMode:
                                      RefreshIndicatorTriggerMode.onEdge,
                                  notificationPredicate: (notification) {
                                    if (_isLoadingMore) return false;
                                    return defaultScrollNotificationPredicate(
                                        notification);
                                  },
                                  child: ItemsBodyBox(
                                    key: ValueKey('items_${widget.categoryId}'),
                                    categoryId: widget.categoryId,
                                    categoryName: widget.categoryName,
                                    bottomContentPadding: bottomContentPadding,

                                    showCartAction: showCartAction,
                                    onCartTap: onCartTap,

                                    selectedCategoryId: selectedCategoryId,
                                    showShimmer: showShimmer,
                                    searchController: searchController,
                                    specialRequestSectionSlug:
                                        _requestSectionSlug,
                                    enableTopBar: _showSlider,
                                    enableAdSlider: _showAdSlider,
                                    // إن كانت موجودة عندك
                                    adInterfaceType: _sliderInterfaceType,
                                    // ← تمرير الواجهة المعتمدة دائمًا
                                    sortBy: sortBy,
                                    // ← جديد
                                    filter: filter,
                                    // ← جديد
                                    enableSubcats: _showSlider,
                                    // ← نفس منطق التأجيل (أظهر بعد Success)
                                    onLoadMore: _handleLoadMoreState,
                                    onScrollDirectionChanged: (isScrollingUp) {
                                      if (_showBottomBar.value !=
                                          isScrollingUp) {
                                        _showBottomBar.value = isScrollingUp;
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned.fill(
                      child: IgnorePointer(
                        ignoring: !show,
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: animatedBottomBar,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
      ),
    );
  }
}
