import 'package:marib/data/cubits/item/fetch_item_summary_cubit.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/constant.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:marib/app/routes.dart';
import 'package:marib/data/model/item/item_model.dart';
import 'package:marib/utils/responsiveSize.dart';
import 'package:marib/utils/sliver_grid_delegate_with_fixed_cross_axis_count_and_fixed_height.dart';
import 'package:marib/ui/screens/widgets/errors/no_data_found.dart';
import 'package:marib/ui/screens/native_ads_screen.dart';
import 'package:flutter/foundation.dart'; // لـ ValueListenable / ValueNotifier
import 'package:marib/data/cubits/category/fetch_category_cubit.dart';
import 'package:marib/data/model/category_model.dart';
import 'package:shimmer/shimmer.dart'; // تأثير التوهج أثناء تحميل الصور
import 'package:marib/ui/screens/sliders/slider_widget.dart';

import '../SubcatsHorizontalGrid.dart';
import 'package:marib/ui/screens/item/cards/horizontal_card.dart';
import 'package:marib/ui/screens/widgets/shimmerLoadingContainer.dart';
import 'smart_search_app_bar.dart';
import '../../../../item/cards/sections_adapter.dart';
import 'package:marib/data/model/item_filter_model.dart'; // ← مهم
import 'package:marib/utils/slider_interface_mapper.dart';
import 'special_request_card.dart';
import 'package:flutter/rendering.dart';
import 'package:marib/ui/screens/sliders/slider_constants.dart';

//==============================================================================
///                                   HomeTabView
//==============================================================================

class HomeTabView extends StatefulWidget {
  final ValueNotifier<int?> selectedCategoryId;
  final String categoryId;
  final TextEditingController searchController;

  // وضع العرض الخارجي (Grid/List)
  final ValueListenable<ViewMode> viewModeListenable;
  final double bottomPadding;
  final bool showShimmer;
  final int sliderRefreshToken;

  final String? specialRequestSectionSlug;

  // NEW: لا تبني/تجلب السلايدر إلا بعد Success
  final bool enableAdSlider;

  final String? adInterfaceType; // ← جديد
  // NEW 👇
  final bool enableSubcats;

  final String? currentSortBy;
  final ItemFilterModel? currentFilter;

  final String? sortBy;
  final ItemFilterModel? filter;
  final ValueChanged<bool>? onLoadMore;
  final ValueChanged<bool>? onScrollDirectionChanged;
  final List<int>? sellerCategoryIds;

  const HomeTabView({
    required this.selectedCategoryId,
    required this.categoryId,
    required this.searchController,
    required this.viewModeListenable,
    this.specialRequestSectionSlug,
    this.bottomPadding = 0.0,
    this.enableAdSlider = false, // افتراضي: مخفي
    this.adInterfaceType,
    this.sellerCategoryIds,

    // NEW 👇
    required this.sliderRefreshToken,
    required this.showShimmer,
    this.currentSortBy, // ← جديد
    this.currentFilter, // ← جديد
    this.enableSubcats = true, // ← جديد (افتراضي)
    this.onScrollDirectionChanged,
    this.sortBy,
    this.filter,
    this.onLoadMore,
    super.key,
  });

  @override
  State<HomeTabView> createState() => _HomeTabViewState();
}

class _HomeTabViewState extends State<HomeTabView> {
  static const int _gridCrossAxisCount = 2;
  static const double _scrollDirectionChangeThreshold = 40.0;

  late final ScrollController controller;
  double _lastReportedScrollOffset = 0.0;

  int? _activeSubcatId; // الفئة الفرعية المختارة حالياً
  int? _lastTopCatId; // لملاحظة تغيّر التصنيف العلوي وإعادة ضبط الفرعيات
  bool? _lastReportedScrollIsUp;

  // ✅ قفل تحميل المزيد + تباطؤ بسيط لتجنّب سيل الاستدعاءات
  bool _isLoadingMore = false;
  bool _loadingIndicatorPulseForward = true;
  Set<int>? _sellerCategoryIdSet;

  @override
  void initState() {
    super.initState();
    controller = ScrollController();

    _lastReportedScrollOffset = controller.initialScrollOffset;
    _sellerCategoryIdSet =
        _normalizeSellerCategoryIds(widget.sellerCategoryIds);

    widget.selectedCategoryId.addListener(_onSelectedCategoryChanged);
    controller.addListener(_handleScrollDirectionChange);

    _lastTopCatId = widget.selectedCategoryId.value;
  }

  @override
  void dispose() {
    widget.selectedCategoryId.removeListener(_onSelectedCategoryChanged);
    controller.removeListener(_handleScrollDirectionChange);

    controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant HomeTabView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedCategoryId != widget.selectedCategoryId) {
      oldWidget.selectedCategoryId.removeListener(_onSelectedCategoryChanged);
      widget.selectedCategoryId.addListener(_onSelectedCategoryChanged);
      _onSelectedCategoryChanged();
    }
    if (!listEquals(oldWidget.sellerCategoryIds, widget.sellerCategoryIds)) {
      _sellerCategoryIdSet =
          _normalizeSellerCategoryIds(widget.sellerCategoryIds);
    }
  }

  void _onSelectedCategoryChanged() {
    if (!mounted) return;
    final int normalizedSelected = widget.selectedCategoryId.value ?? 0;
    if (_lastTopCatId != normalizedSelected) {
      _lastTopCatId = normalizedSelected;
      _activeSubcatId = null;
    }
    setState(() {});
    _scheduleScrollReset();
  }

  void _fetchItemsForCategory(int categoryId) {
    if (categoryId <= 0) {
      return;
    }

    final fetchCubit = context.read<FetchItemSummaryCubit>();
    final String query = widget.searchController.text.trim();
    final String? resolvedSortBy = widget.currentSortBy ?? widget.sortBy;
    final ItemFilterModel? baseFilter = widget.currentFilter ?? widget.filter;
    final ItemFilterModel? effectiveFilter =
        baseFilter?.copyWith(categoryId: categoryId.toString());

    fetchCubit.fetchSummaries(
      categoryId: categoryId,
      search: query,
      sortBy: resolvedSortBy,
      filter: effectiveFilter,
      perPage: FetchItemSummaryCubit.defaultPerPage,
    );
  }

  void _scheduleScrollReset() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !controller.hasClients) {
        return;
      }
      controller
          .animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      )
          .catchError((_) {
        if (!mounted || !controller.hasClients) {
          return;
        }
        controller.jumpTo(0);
      });
    });
  }

  int? _tryExtractNestedCategoryId(ItemSummary item) {
    try {
      final dynamic dynamicItem = item;
      final dynamic nestedCategory = dynamicItem.category;
      if (nestedCategory is CategoryModel) {
        return nestedCategory.id;
      }
      if (nestedCategory is Map<String, dynamic>) {
        final dynamic rawId = nestedCategory['id'];
        if (rawId is int) {
          return rawId;
        }
        if (rawId is num) {
          return rawId.toInt();
        }
        if (rawId is String) {
          return int.tryParse(rawId);
        }
      }
    } on NoSuchMethodError {
      // ItemSummary لا يعرّف خاصية category في بعض الردود.
      return null;
    } on TypeError {
      return null;
    }
    return null;
  }

  Set<int>? _normalizeSellerCategoryIds(List<int>? ids) {
    if (ids == null) {
      return null;
    }
    final Set<int> normalized = <int>{};
    for (final int id in ids) {
      if (id > 0) {
        normalized.add(id);
      }
    }
    if (normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  bool _treeContainsCategoryId(
    List<CategoryModel> categories,
    int target,
  ) {
    for (final CategoryModel category in categories) {
      final int? categoryId = category.id;
      if (categoryId != null && categoryId == target) {
        return true;
      }
      final List<CategoryModel>? children = category.children;
      if (children != null && children.isNotEmpty) {
        if (_treeContainsCategoryId(children, target)) {
          return true;
        }
      }
    }
    return false;
  }

  List<CategoryModel> _filterCategoriesByAllowedIds(
    List<CategoryModel> categories,
    Set<int> allowedIds,
  ) {
    final List<CategoryModel> result = <CategoryModel>[];
    for (final CategoryModel category in categories) {
      final List<CategoryModel> children =
          category.children ?? const <CategoryModel>[];
      final List<CategoryModel> filteredChildren =
          _filterCategoriesByAllowedIds(children, allowedIds);
      final bool includeSelf =
          (category.id != null && allowedIds.contains(category.id!)) ||
              filteredChildren.isNotEmpty;

      if (!includeSelf) {
        continue;
      }

      result.add(
        CategoryModel(
          id: category.id,
          name: category.name,
          url: category.url,
          description: category.description,
          interfaceType: category.interfaceType,
          subcategoriesCount: category.subcategoriesCount,
          children: category.children == null && filteredChildren.isEmpty
              ? null
              : filteredChildren,
        ),
      );
    }

    return result;
  }


  bool _categoryMatchesAllowed(
      CategoryModel category,
      Set<int> allowedIds,
      ) {
    final int? categoryId = category.id;
    if (categoryId != null && allowedIds.contains(categoryId)) {
      return true;
    }

    final List<CategoryModel>? children = category.children;
    if (children == null || children.isEmpty) {
      return false;
    }

    for (final CategoryModel child in children) {
      if (_categoryMatchesAllowed(child, allowedIds)) {
        return true;
      }
    }

    return false;
  }

  List<CategoryModel> _prioritizeCategoriesByAllowedIds(
      List<CategoryModel> categories,
      Set<int> allowedIds,
      ) {
    if (categories.isEmpty || allowedIds.isEmpty) {
      return categories;
    }

    final List<CategoryModel> prioritized = <CategoryModel>[];
    final List<CategoryModel> remainder = <CategoryModel>[];

    for (final CategoryModel category in categories) {
      final List<CategoryModel>? children = category.children;
      final List<CategoryModel>? reorderedChildren =
      (children == null || children.isEmpty)
          ? children
          : _prioritizeCategoriesByAllowedIds(children, allowedIds);

      final CategoryModel normalizedCategory =
      (reorderedChildren == null || identical(reorderedChildren, category.children))
          ? category
          : CategoryModel(
        id: category.id,
        name: category.name,
        url: category.url,
        description: category.description,
        interfaceType: category.interfaceType,
        subcategoriesCount: category.subcategoriesCount,
        children: reorderedChildren,
      );

      final bool matches =
      _categoryMatchesAllowed(normalizedCategory, allowedIds);
      if (matches) {
        prioritized.add(normalizedCategory);
      } else {
        remainder.add(normalizedCategory);
      }
    }

    if (prioritized.isEmpty) {
      return remainder;
    }
    if (remainder.isEmpty) {
      return prioritized;
    }

    return <CategoryModel>[...prioritized, ...remainder];
  }


  CategoryModel _copyCategoryWithChildren(
    CategoryModel source,
    List<CategoryModel> children,
  ) {
    return CategoryModel(
      id: source.id,
      name: source.name,
      url: source.url,
      description: source.description,
      interfaceType: source.interfaceType,
      subcategoriesCount: source.subcategoriesCount,
      children: children,
    );
  }

  // =========================

  double _adSliderHeight(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    const horizontalPadding =
        24.0; // 12 يسار + 12 يمين (نفس الـ Padding اللي تستخدمه)
    final contentW = w - horizontalPadding;

    // اختَر نفس نسبة الصور الفعلية للسلايدر (عدّلها لو عندك نسبة مختلفة):
    const ratio = 16 / 9;

    // حسب النسبة: الارتفاع = العرض / النسبة
    final h = contentW / ratio;

    // سقف وحد أدنى عشان ما يكون صغير/كبير زيادة
    return h.clamp(140.0, 220.0);
  }

  // =========================
  // تحميل لانهائي بهدوء
  // =========================
  bool _shouldTriggerLoadMore(ScrollMetrics metrics) {
    final AxisDirection axisDirection = metrics.axisDirection;
    if (axisDirection == AxisDirection.left ||
        axisDirection == AxisDirection.right) {
      return false;
    }

    // استخدم extentAfter لضمان التحميل حتى في القوائم القصيرة
    return metrics.extentAfter <= 200;
  }

  Future<void> _maybeLoadMore() async {
    if (_isLoadingMore) return;
    final cubit = context.read<FetchItemSummaryCubit>();
    if (!cubit.hasMoreData()) return;

    _isLoadingMore = true;
    widget.onLoadMore?.call(true);

    // تباطؤ بسيط يخفف الجهد أثناء السحب
    await Future.delayed(const Duration(milliseconds: 100));
    try {
      await cubit.loadMoreSummaries();
    } finally {
      _isLoadingMore = false;
      widget.onLoadMore?.call(false);
    }
  }

  void _handleScrollDirectionChange() {
    if (!controller.hasClients) {
      return;
    }

    final ScrollPosition position = controller.position;
    final ScrollDirection direction = position.userScrollDirection;
    bool? isScrollingUp;
    switch (direction) {
      case ScrollDirection.forward:
        isScrollingUp = true;
        break;
      case ScrollDirection.reverse:
        isScrollingUp = false;
        break;
      case ScrollDirection.idle:
        isScrollingUp = null;
        break;
    }

    if (isScrollingUp == null) {
      return;
    }

    final double offsetDelta = position.pixels - _lastReportedScrollOffset;
    final bool movedBeyondThreshold = isScrollingUp
        ? offsetDelta <= -_scrollDirectionChangeThreshold
        : offsetDelta >= _scrollDirectionChangeThreshold;

    if (_lastReportedScrollIsUp == isScrollingUp) {
      if (movedBeyondThreshold) {
        _lastReportedScrollOffset = position.pixels;
      }
      return;
    }

    if (!movedBeyondThreshold) {
      return;
    }

    _lastReportedScrollIsUp = isScrollingUp;
    _lastReportedScrollOffset = position.pixels;

    widget.onScrollDirectionChanged?.call(isScrollingUp);
  }

  // =========================
  // اختيار مفتاح السلايدر بكلفة منخفضة
  // =========================
  String? _pickSliderKey(Set<String> keys, int catId) {
    if (catId != 0) {
      for (final k in [
        'shein_products_cat_$catId',
        'category_$catId',
        'cat_$catId',
        'items_$catId',
        'shein_products_$catId',
      ]) {
        if (keys.contains(k)) return k;
      }
    }
    for (final f in ['shein_products', 'all']) {
      if (keys.contains(f)) return f;
    }
    return null;
  }

  // ✅ أضف هنا:
  double get _gridCardHeight {
    final h = MediaQuery.of(context).size.height;
    return h / 3.5.rh(context); // أو h / 3.5 فقط
  }

// شيمر السلايدر

  Widget _buildAdSliderShimmer() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final base = colorScheme.shimmerBaseColor;
    final highlight = colorScheme.shimmerHighlightColor;
    final content = colorScheme.shimmerContentColor;

    final hImage = _adSliderImageHeight(context);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: kAdSliderHPad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(kAdSliderRadius),
            child: Shimmer.fromColors(
              baseColor: base,
              highlightColor: highlight,
              period: const Duration(milliseconds: 1200),
              child: SizedBox(
                height: hImage,
                width: double.infinity,
                child:
                    Container(color: content), // لازم لون مصمت عشان الشيمر يبان
              ),
            ),
          ),
          SizedBox(height: _dotsSpacingHeight(context)),
          SizedBox(
            height: _kIndicatorDotHeight,
            child: Shimmer.fromColors(
              baseColor: base,
              highlightColor: highlight,
              period: const Duration(milliseconds: 1200),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (int i = 0; i < 5; i++) ...[
                    Container(
                      width: _kIndicatorDotHeight,
                      height: _kIndicatorDotHeight,
                      decoration: BoxDecoration(
                        color: content,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    if (i != 4) const SizedBox(width: 6),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

// ثابت عرض الحافة لليمين/اليسار
  double kAdSliderHPad = 10.0;

// نصف القطر
  double kAdSliderRadius = 12.0;

// ارتفاع نقاط المؤشر = ارتفاع الـ dots نفسها (SmoothPageIndicator.dotHeight)
  static const double _kIndicatorDotHeight = 8.0;

// حجز بسيط جدًا لنقاط السلايدر (الفراغ الذي يسبق المؤشر)
  double _dotsSpacingHeight(BuildContext ctx) => 8.rh(ctx);

// الارتفاع الكامل للمؤشر + الفراغ السابق له، مطابق لما في SliderComponent
  double _dotsReserveHeight(BuildContext ctx) =>
      _kIndicatorDotHeight + _dotsSpacingHeight(ctx);

  double _adSliderImageHeight(BuildContext ctx) {
    return kSliderBannerHeight;
  }

  double _adSliderTotalHeight(BuildContext ctx) {
    return kSliderBannerHeight + _dotsReserveHeight(ctx);
  }

// اختياري: لوج سريع للتأكد من الأرقام
  void _logHeights(BuildContext ctx) {
    final img = _adSliderImageHeight(ctx);
    final tot = _adSliderTotalHeight(ctx);
    final reserve = _dotsReserveHeight(ctx);

    debugPrint('AD_SLIDER heights: image=$img, total=$tot, reserve=$reserve');
  }

  @override
  Widget build(BuildContext context) {
    // ========= فواصل محسوبة مرّة واحدة =========
    final scrH = MediaQuery.sizeOf(context).height;
    final gapSmall = (scrH * 0.01).clamp(6, 16).toDouble();
    final gapMedium = (scrH * 0.02).clamp(12, 32).toDouble();

    // ✅ فيزياء التمرير حسب المنصة (أخف على أندرويد)
    final platform = Theme.of(context).platform;

    final int? selectedCategoryId = widget.selectedCategoryId.value;

    return ValueListenableBuilder<ViewMode>(
      valueListenable: widget.viewModeListenable,
      builder: (context, mode, _) {
        final bool isList = (mode == ViewMode.list);
        final String? resolvedInterfaceType =
            SliderInterfaceMapper.normalize(widget.adInterfaceType) ??
                widget.adInterfaceType?.trim();
        final String sliderInterfaceType =
            (resolvedInterfaceType == null || resolvedInterfaceType.isEmpty)
                ? 'homepage'
                : resolvedInterfaceType;
        final bool shouldShowSlider =
            widget.enableAdSlider && !widget.showShimmer;
        final bool shouldShowSliderShimmer =
            widget.enableAdSlider && widget.showShimmer;

        // ✅ البطاقة الخاصة لا تظهر إلا في تبويب "الكل"
        final bool isAllCategory =
            selectedCategoryId == null || selectedCategoryId == 0;

        // ✅ استمع للتمرير هنا (بدل بعثرة المنطق داخل عناصر داخلية)
        return NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n is ScrollUpdateNotification ||
                n is ScrollEndNotification ||
                n is OverscrollNotification) {
              if (_shouldTriggerLoadMore(n.metrics)) {
                _maybeLoadMore();
              }
            }
            return false;
          },
          child: CustomScrollView(
            controller: controller,
            cacheExtent: 800, // ✅ تحميل مسبق معتدل يقلل التقطيع
            slivers: [
              // ============= السلايدر =============

              SliverToBoxAdapter(
                child: !widget.enableAdSlider
                    ? const SizedBox.shrink()
                    : shouldShowSliderShimmer
                        ? _buildAdSliderShimmer()
                        : shouldShowSlider
                            ? Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: kAdSliderHPad),
                                child: ClipRRect(
                                  borderRadius:
                                      BorderRadius.circular(kAdSliderRadius),
                                  child: SizedBox(
                                    height: _adSliderTotalHeight(context),
                                    // صورة + دوتس (نفس الإجمالي)
                                    width: double.infinity,
                                    child: RepaintBoundary(
                                      child: SliderWidget(
                                        key: ValueKey(
                                          'slider_${sliderInterfaceType}_${widget.sliderRefreshToken}',
                                        ),
                                        interfaceType: sliderInterfaceType,
                                        padding: EdgeInsets.zero,
                                        margin: EdgeInsets.zero,
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(),
              ),

              // فاصل صغير
              SliverToBoxAdapter(child: SizedBox(height: gapSmall)),

              // ============= التصنيفات الفرعية (دائمًا ظاهرة) =============

              SliverToBoxAdapter(
                child: RepaintBoundary(
                  child: ValueListenableBuilder<int?>(
                    valueListenable: widget.selectedCategoryId,
                    builder: (context, selectedId, ___) {
                      // عند تغيّر التصنيف العلوي صفّر اختيار الفرعيّة (اختياري)
                      final int normalizedSelected = selectedId ?? 0;
                      if (_lastTopCatId != normalizedSelected) {
                        _lastTopCatId = normalizedSelected;
                        _activeSubcatId = null;
                      }
                      return LayoutBuilder(
                        builder: (context, constraints) {
                          const double _rowSpacing = 12.0;
                          const double _hPad = 12.0;
                          const double _spacing = 10.0;
                          const double _gap = 6.0;
                          const double _titleHeight = 30.0;

                          final double maxWidth = constraints.maxWidth;
                          final double availableWidth = maxWidth - (_hPad * 2);
                          int itemsPerRow = 1;
                          for (int cols = 1; cols <= 6; cols++) {
                            final double widthForItems =
                                availableWidth - (_spacing * (cols - 1));
                            final double perItem = widthForItems / cols;
                            if (perItem >= 70.0) {
                              itemsPerRow = cols;
                            } else {
                              break;
                            }
                          }

                          const int maxRows = 2;
                          final double widthForItems =
                              (availableWidth - (_spacing * (itemsPerRow - 1)))
                                  .clamp(0.0, 4000.0);

                          final double itemWidth =
                              (widthForItems / itemsPerRow).clamp(70.0, 120.0);
                          final double circleSize =
                              (itemWidth * 0.82).clamp(48.0, 64.0);
                          final double rowHeight =
                              circleSize + _gap + _titleHeight;

                          Widget subcatShimmerBuilder(
                            BuildContext context,
                            double dynamicRowHeight,
                            int dynamicRows,
                          ) {
                            final colorScheme = Theme.of(context).colorScheme;
                            final base = colorScheme.shimmerBaseColor;
                            final highlight = colorScheme.shimmerHighlightColor;
                            final content = colorScheme.shimmerContentColor;
                            const double indicatorGap = 6.0;
                            const double indicatorHeight = 8.0;
                            const int placeholderDots = 4;
                            final double shimmerGridHeight =
                                dynamicRowHeight * dynamicRows +
                                    _rowSpacing * (dynamicRows - 1);

                            return SizedBox(
                              height: shimmerGridHeight +
                                  indicatorGap +
                                  indicatorHeight,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: _hPad),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      height: shimmerGridHeight,
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: List.generate(dynamicRows,
                                            (rowIndex) {
                                          return Padding(
                                            padding: EdgeInsets.only(
                                                top: rowIndex == 0
                                                    ? 0
                                                    : _rowSpacing),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: List.generate(
                                                  itemsPerRow, (_) {
                                                return SizedBox(
                                                  width: itemWidth,
                                                  child: Column(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Shimmer.fromColors(
                                                        baseColor: base,
                                                        highlightColor:
                                                            highlight,
                                                        period: const Duration(
                                                            milliseconds: 1150),
                                                        child: Container(
                                                          width: circleSize,
                                                          height: circleSize,
                                                          decoration:
                                                              BoxDecoration(
                                                            color: content,
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        20),
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(
                                                          height: _gap),
                                                      SizedBox(
                                                        height: _titleHeight,
                                                        child: Align(
                                                          alignment: Alignment
                                                              .topCenter,
                                                          child: Shimmer
                                                              .fromColors(
                                                            baseColor: base,
                                                            highlightColor:
                                                                highlight,
                                                            period:
                                                                const Duration(
                                                                    milliseconds:
                                                                        1150),
                                                            child: Container(
                                                              height: 12,
                                                              width: itemWidth,
                                                              decoration:
                                                                  BoxDecoration(
                                                                color: content,
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            6),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              }),
                                            ),
                                          );
                                        }),
                                      ),
                                    ),
                                    const SizedBox(height: indicatorGap),
                                    SizedBox(
                                      height: indicatorHeight,
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: List.generate(placeholderDots,
                                            (dotIndex) {
                                          final bool isActive = dotIndex == 0;
                                          final double width =
                                              isActive ? 18.0 : 8.0;

                                          return Shimmer.fromColors(
                                            baseColor: base,
                                            highlightColor: highlight,
                                            period: const Duration(
                                                milliseconds: 1150),
                                            child: Container(
                                              margin:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 4),
                                              width: width,
                                              height: indicatorHeight,
                                              decoration: BoxDecoration(
                                                color: content,
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                            ),
                                          );
                                        }),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }

                          return SubcatsDeferredBlock(
                            enabled:
                                widget.enableSubcats && !widget.showShimmer,
                            // ← لا نبدأ إلا بعد فتح القسم
                            rowHeight: rowHeight,
                            maxRows: maxRows,
                            shimmerBuilder: subcatShimmerBuilder,
                            // انتظر نجاح جلب التصنيفات (أو اكتمال مؤقت)
                            onDeferLoad: () async {
                              final FetchCategoryCubit catCubit =
                                  context.read<FetchCategoryCubit>();
                              final FetchCategoryState catState =
                                  catCubit.state;
                              final FetchCategorySuccess? successState =
                                  catState is FetchCategorySuccess
                                      ? catState
                                      : null;

                              final int rootId =
                                  int.tryParse(widget.categoryId) ?? 0;
                              String? interfaceType =
                                  successState?.interfaceType;
                              interfaceType ??= SliderInterfaceMapper.normalize(
                                    widget.adInterfaceType,
                                  ) ??
                                  widget.adInterfaceType?.trim();

                              try {
                                await catCubit.fetchCategories(
                                  categoryId: rootId > 0 ? rootId : null,
                                  interfaceType: interfaceType,
                                );
                              } catch (_) {
                                // تجاهل أي أخطاء عابرة، سيستمر الشيمر حتى تتوفر البيانات
                              }
                            },
                            // المحتوى الحقيقي بعد الجاهزية
                            builderWhenReady: () {
                              if (widget.showShimmer) {
                                return subcatShimmerBuilder(
                                  context,
                                  rowHeight,
                                  maxRows,
                                );
                              }
                              final catState =
                                  context.watch<FetchCategoryCubit>().state;
                              if (catState is! FetchCategorySuccess) {
                                final subcatsBlockState =
                                    context.findAncestorStateOfType<
                                        SubcatsDeferredBlockState>();

                                if (subcatsBlockState != null) {
                                  final shimmerBuilder =
                                      subcatsBlockState.widget.shimmerBuilder;
                                  return shimmerBuilder?.call(
                                        context,
                                        rowHeight,
                                        maxRows,
                                      ) ??
                                      subcatsBlockState.buildDefaultShimmer(
                                        context,
                                        rowHeight,
                                        maxRows,
                                      );
                                }

                                return subcatShimmerBuilder(
                                  context,
                                  rowHeight,
                                  maxRows,
                                );
                              }

                              // حدّد الجذر (تصنيف القسم) ثم اختر الأب الحالي
                              final int rootId =
                                  int.tryParse(widget.categoryId) ?? 0;
                              final CategoryModel root =
                                  catState.categories.firstWhere(
                                (c) => c.id == rootId,
                                orElse: () => CategoryModel(
                                    id: rootId, name: '', children: const []),
                              );
                              final List<CategoryModel> rootChildren =
                                  root.children ?? const <CategoryModel>[];

                              final FetchItemSummaryState itemState =
                                  context.watch<FetchItemSummaryCubit>().state;
                              final FetchItemSummarySuccess? successState =
                                  itemState is FetchItemSummarySuccess
                                      ? itemState
                                      : null;

                              final Set<int>? sellerCategorySet =
                                  _sellerCategoryIdSet;
                              final bool applySellerFilter =
                                  sellerCategorySet != null &&
                                      sellerCategorySet.isNotEmpty;
                              List<CategoryModel> processedRootChildren =
                                  rootChildren;
                              bool sellerFilterApplied = false;
                              if (applySellerFilter) {
                                final List<CategoryModel> sellerFiltered =
                                    _filterCategoriesByAllowedIds(
                                        rootChildren, sellerCategorySet);
                                if (sellerFiltered.isNotEmpty) {
                                  processedRootChildren = sellerFiltered;
                                  sellerFilterApplied = true;
                                }
                              }

                              final Set<int> allowedCategoryIds = <int>{};
                              if (successState != null) {
                                for (final ItemSummary item
                                    in successState.items) {
                                  final int? primaryCategoryId =
                                      item.categoryId;
                                  if (primaryCategoryId != null &&
                                      primaryCategoryId > 0) {
                                    allowedCategoryIds.add(primaryCategoryId);
                                  }

                                  final int? nestedCategoryId =
                                      _tryExtractNestedCategoryId(item);
                                  if (nestedCategoryId != null &&
                                      nestedCategoryId > 0) {
                                    allowedCategoryIds.add(nestedCategoryId);
                                  }
                                }
                              }

                              final bool hasAllowedHints =
                                  allowedCategoryIds.isNotEmpty;
                              final List<CategoryModel> prioritizedRootChildren =
                              hasAllowedHints
                                  ? _prioritizeCategoriesByAllowedIds(
                                  processedRootChildren,
                                  allowedCategoryIds)
                                  : processedRootChildren;

                              final bool needsSyntheticRoot =
                                  sellerFilterApplied || hasAllowedHints;
                              final List<CategoryModel> effectiveRootChildren =
                                  prioritizedRootChildren;

                              final CategoryModel effectiveRoot =
                              needsSyntheticRoot
                                      ? _copyCategoryWithChildren(
                                          root, effectiveRootChildren)
                                      : root;

                              if (sellerFilterApplied  &&
                                  selectedId != null &&
                                  selectedId > 0) {
                                final bool selectedAllowed =
                                    _treeContainsCategoryId(
                                  effectiveRootChildren,
                                  selectedId,
                                );
                                if (!selectedAllowed) {
                                  WidgetsBinding.instance
                                      .addPostFrameCallback((_) {
                                    if (!mounted) {
                                      return;
                                    }
                                    if (widget.selectedCategoryId.value ==
                                        selectedId) {
                                      widget.selectedCategoryId.value = 0;
                                      if (_activeSubcatId != null) {
                                        setState(() {
                                          _activeSubcatId = null;
                                        });
                                      }
                                    }
                                  });
                                }
                              }

                              final bool isTopLevel =
                                  (selectedId == null || selectedId == 0);

                              // إن كان "الكل" → الأب = الجذر، غير ذلك → الأب = التصنيف المختار إن وُجد، وإلا الجذر
                              final CategoryModel currentParent = isTopLevel
                                  ? effectiveRoot
                                  : (effectiveRootChildren.firstWhere(
                                      (c) => c.id == selectedId,
                                      orElse: () => effectiveRoot,
                                    ));

                              // لو الأب الحالي بلا أبناء، اعرض أبناء الجذر كي لا يختفي الشريط
                              final List<CategoryModel> subcats =
                                  (currentParent.children?.isNotEmpty ?? false)
                                      ? (currentParent.children!)
                                      : effectiveRootChildren;
                              List<CategoryModel> visibleSubcats = subcats;
                              if (sellerFilterApplied) {
                                final List<CategoryModel>
                                    sellerFilteredSubcats =
                                    _filterCategoriesByAllowedIds(
                                        visibleSubcats, sellerCategorySet!);
                                if (sellerFilteredSubcats.isNotEmpty) {
                                  visibleSubcats = sellerFilteredSubcats;
                                }
                              }
                              if (hasAllowedHints) {
                                visibleSubcats =
                                    _prioritizeCategoriesByAllowedIds(
                                        visibleSubcats, allowedCategoryIds);
                              }
                              if (visibleSubcats.isEmpty)
                                return const SizedBox.shrink();

                              final int? activeSubcatId = _activeSubcatId;
                              if (activeSubcatId != null &&
                                  activeSubcatId > 0 &&
                                  !visibleSubcats.any((category) =>
                                      category.id == activeSubcatId)) {
                                WidgetsBinding.instance
                                    .addPostFrameCallback((_) {
                                  if (!mounted) {
                                    return;
                                  }
                                  if (_activeSubcatId == activeSubcatId) {
                                    setState(() {
                                      _activeSubcatId = null;
                                    });
                                  }
                                });
                              }

                              final brand =
                                  Theme.of(context).colorScheme.primary;

                              final String? specialSlug = widget
                                  .specialRequestSectionSlug
                                  ?.trim()
                                  .toLowerCase();
                              final bool shouldShowSpecialRequestCard =
                                  isAllCategory &&
                                      (specialSlug == 'shein' ||
                                          specialSlug == 'computer');

                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SubcatsHorizontalGrid(
                                    subcats: visibleSubcats,
                                    selectedId: _activeSubcatId,
                                    // تظليل الفرعيّة المختارة
                                    brand: brand,
                                    isTopLevel: isTopLevel,
                                    onTap: (_) {},

                                    leadingBuilder: shouldShowSpecialRequestCard
                                        ? (context) => SpecialRequestCard(
                                              sectionSlug: widget
                                                  .specialRequestSectionSlug!,
                                            )
                                        : null,

                                    // في تبويب "الكل": اضغط فرعيّة ⇒ انقل شريط التصنيفات للفئة واضبط الجلب لها
                                    onTopCategoryPick: (c) {
                                      if (!isTopLevel) return;
                                      final int? categoryId = c.id;
                                      if (categoryId == null ||
                                          categoryId <= 0) {
                                        return;
                                      }

                                      if (widget.selectedCategoryId.value !=
                                          categoryId) {
                                        widget.selectedCategoryId.value =
                                            categoryId;
                                      }

                                      _activeSubcatId = null;
                                      setState(() {});
                                      _fetchItemsForCategory(categoryId);
                                      _scheduleScrollReset();
                                    },

                                    // في فئة علوية ≠ "الكل": اضغط فرعيّة ⇒ فلترة مباشرة وتظليل الفرعيّة
                                    onSubcatPick: (c) {
                                      final int? categoryId = c.id;
                                      if (categoryId == null ||
                                          categoryId <= 0) {
                                        return;
                                      }

                                      setState(
                                          () => _activeSubcatId = categoryId);
                                      _fetchItemsForCategory(categoryId);
                                      _scheduleScrollReset();
                                    },
                                  ),
                                  SizedBox(
                                    // تجنّب cast من num: احسب clamp يدويًا
                                    height: () {
                                      final h =
                                          MediaQuery.sizeOf(context).height *
                                              0.01;
                                      if (h < 6.0) return 6.0;
                                      if (h > 16.0) return 16.0;
                                      return h;
                                    }(),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ),

              // فاصل متوسط (يتأثر بحالة ظهور شريط التنقل السفلي)
              SliverToBoxAdapter(
                child: SizedBox(height: gapMedium),
              ),

              // ============= القائمة الرئيسية (كما هي عندك) =============
              // ملاحظة: داخل _itemsSliver احرص على استخدام SliverList/SliverGrid
              // مع addRepaintBoundaries: true, addAutomaticKeepAlives: false,
              // ومفاتيح مستقرة + itemExtent/prototypeItem إن أمكن
              ..._buildItemsSlivers(isList),

              // فاصل أخير (يتأثر بحالة ظهور شريط التنقل السفلي)
              SliverToBoxAdapter(
                child: SizedBox(height: gapMedium),
              ),
              if (widget.bottomPadding > 0)
                SliverToBoxAdapter(
                  child: SizedBox(height: widget.bottomPadding),
                ),
            ],
          ),
        );
      },
    );
  }

  // قائمة الإعلانات (مربوطة بوضع العرض)

  List<Widget> _buildItemsSlivers(bool isList) {
    final FetchItemSummaryState state =
        context.watch<FetchItemSummaryCubit>().state;

    if (state is FetchItemSummaryInitial || state is FetchItemSummaryLoading) {
      if (isList) {
        return <Widget>[
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _listShimmer(context),
              childCount: 8,
            ),
          ),
        ];
      }

      return <Widget>[
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
          sliver: SliverGrid(
            gridDelegate:
                SliverGridDelegateWithFixedCrossAxisCountAndFixedHeight(
              crossAxisCount: _gridCrossAxisCount,
              height: _gridCardHeight,
              mainAxisSpacing: 7,
              crossAxisSpacing: 10,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => _gridShimmer(context),
              childCount: 8,
            ),
          ),
        ),
      ];
    }

    if (state is FetchItemSummaryFailure) {
      return <Widget>[
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Center(child: Text(state.errorMessage)),
          ),
        ),
      ];
    }

    if (state is FetchItemSummarySuccess) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _isLoadingMore) {
          return;
        }
        final fetchCubit = context.read<FetchItemSummaryCubit>();
        final FetchItemSummaryState currentState = fetchCubit.state;
        if (currentState is! FetchItemSummarySuccess ||
            currentState.isLoadingMore) {
          return;
        }
        if (!controller.hasClients) {
          return;
        }
        if (controller.position.maxScrollExtent > 0) {
          return;
        }
        if (!fetchCubit.hasMoreData()) {
          return;
        }
        _maybeLoadMore();
      });

      final bool showLoadingMoreError = state.loadingMoreError;
      final fetchCubit = context.read<FetchItemSummaryCubit>();
      final bool hasMoreData = fetchCubit.hasMoreData();
      if (state.items.isEmpty) {
        return <Widget>[
          SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: NoDataFound(
                  onTap: () =>
                      context.read<FetchItemSummaryCubit>().fetchSummaries(
                            categoryId: int.tryParse(widget.categoryId) ?? 0,
                            search: widget.searchController.text.trim(),
                            sortBy: widget.sortBy,
                            filter: widget.filter,
                            perPage: FetchItemSummaryCubit.defaultPerPage,
                          ),
                  category: EmptyStateCategory.items,
                ),
              ),
            ),
          ),
        ];
      }

      final List<_HomeTabEntry> entries = _buildItemEntries(
        state.items,
        isLoadingMore: state.isLoadingMore,
      );

      if (isList) {
        final bool hasLoadingMoreEntry = entries.isNotEmpty &&
            entries.last.type == _HomeTabEntryType.loadingMore;
        final List<_HomeTabEntry> listEntries = hasLoadingMoreEntry
            ? entries.sublist(0, entries.length - 1)
            : entries;

        final List<Widget> slivers = <Widget>[
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final _HomeTabEntry entry = listEntries[index];
                switch (entry.type) {
                  case _HomeTabEntryType.item:
                    final ItemSummary summary = state.items[entry.itemIndex!];
                    final ItemModel item = summary.toItemModelSkeleton();
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 3,
                      ),
                      child: GestureDetector(
                        onTap: () => _navigateToDetails(context, item),
                        child: ItemHorizontalCard(item: item),
                      ),
                    );
                  case _HomeTabEntryType.ad:
                    return const _KeepAliveNativeAd();

                  case _HomeTabEntryType.loadingMore:
                    return const SizedBox.shrink();
                }
              },
              childCount: listEntries.length,
              addAutomaticKeepAlives: false,
              addRepaintBoundaries: true,
            ),
          ),
        ];
        if (hasMoreData && !showLoadingMoreError) {
          slivers.add(_buildLoadingMoreStatusSliver(context, state));
        }

        if (!hasMoreData) {
          slivers.add(_buildEndOfResultsSliver(context));
        }

        if (showLoadingMoreError) {
          slivers.add(_buildLoadingMoreErrorSliver(context));
        }

        return slivers;
      }

      final List<Widget> gridSlivers = _buildGridModeSlivers(
        context,
        entries,
        state.items,
        state,
        hasMoreData,
        showLoadingMoreError,
      );

      if (showLoadingMoreError) {
        gridSlivers.add(_buildLoadingMoreErrorSliver(context));
      }
      return gridSlivers;
    }

    return const <Widget>[
      SliverToBoxAdapter(child: SizedBox(height: 1)),
    ];
  }

  // بناء أقسام العناصر (مع إدراج إعلان بين كل مقطع وآخر)

  // بناء أقسام العناصر مع فواصل وإعلانات

  List<_HomeTabEntry> _buildItemEntries(
    List<ItemSummary> items, {
    required bool isLoadingMore,
  }) {
    final List<_HomeTabEntry> entries = <_HomeTabEntry>[];
    final int step = max(1, Constant.nativeAdsAfterItemNumber);

    for (int index = 0; index < items.length; index++) {
      entries.add(_HomeTabEntry.item(index));
      final bool shouldInsertAd =
          ((index + 1) % step == 0) && (index + 1 < items.length);
      if (shouldInsertAd) {
        entries.add(const _HomeTabEntry.ad());
      }
    }

    if (isLoadingMore) {
      entries.add(const _HomeTabEntry.loadingMore());
    }

    return entries;
  }

  List<Widget> _buildGridModeSlivers(
    BuildContext context,
    List<_HomeTabEntry> entries,
    List<ItemSummary> items,
    FetchItemSummarySuccess state,
    bool hasMoreData,
    bool showLoadingMoreError,
  ) {
    final bool hasLoadingMoreEntry = entries.isNotEmpty &&
        entries.last.type == _HomeTabEntryType.loadingMore;
    final List<_HomeTabEntry> gridEntries =
        hasLoadingMoreEntry ? entries.sublist(0, entries.length - 1) : entries;

    final List<Widget> slivers = <Widget>[];
    int cursor = 0;

    while (cursor < gridEntries.length) {
      final _HomeTabEntry entry = gridEntries[cursor];
      switch (entry.type) {
        case _HomeTabEntryType.item:
          final List<int> batchIndices = <int>[];
          while (cursor < gridEntries.length &&
              gridEntries[cursor].type == _HomeTabEntryType.item) {
            batchIndices.add(gridEntries[cursor].itemIndex!);
            cursor++;
          }

          if (batchIndices.isNotEmpty) {
            slivers.add(
              SliverPadding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                sliver: SliverGrid(
                  gridDelegate:
                      SliverGridDelegateWithFixedCrossAxisCountAndFixedHeight(
                    crossAxisCount: _gridCrossAxisCount,
                    height: _gridCardHeight,
                    mainAxisSpacing: 7,
                    crossAxisSpacing: 10,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final ItemSummary summary = items[batchIndices[index]];
                      final ItemModel item = summary.toItemModelSkeleton();
                      return GestureDetector(
                        onTap: () => _navigateToDetails(context, item),
                        child: ICard(
                          item: item,
                          created: item.created,
                        ),
                      );
                    },
                    childCount: batchIndices.length,
                    addAutomaticKeepAlives: false,
                    addRepaintBoundaries: true,
                  ),
                ),
              ),
            );
          }
          break;
        case _HomeTabEntryType.ad:
          slivers.add(
            const SliverToBoxAdapter(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: 8),
                  NativeAdWidget(type: TemplateType.medium),
                  SizedBox(height: 8),
                ],
              ),
            ),
          );
          cursor++;
          break;
        case _HomeTabEntryType.loadingMore:
          cursor++;
          break;
      }

      if (entry.type == _HomeTabEntryType.item) {
        // تم تحريك المؤشر داخل الحلقة الداخلية.
      }
    }
    if (hasMoreData && !showLoadingMoreError) {
      slivers.add(_buildLoadingMoreStatusSliver(context, state));
    }

    if (!hasMoreData) {
      slivers.add(_buildEndOfResultsSliver(context));
    }

    return slivers;
  }

  Widget _buildEndOfResultsSliver(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final Color messageColor = colorScheme.onSurface.withOpacity(0.6);

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 2),
            Text(
              'لقد شاهدت كل النتائج',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(color: messageColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingMoreErrorSliver(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'تعذر تحميل المزيد، حاول مجددًا',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () =>
                  context.read<FetchItemSummaryCubit>().loadMoreSummaries(),
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingMoreStatusSliver(
    BuildContext context,
    FetchItemSummarySuccess state,
  ) {
    const double indicatorExtent = 52;
    const double verticalPadding = 26;

    if (!state.isLoadingMore) {
      _loadingIndicatorPulseForward = true;
    }

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: verticalPadding),
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: state.isLoadingMore
                ? TweenAnimationBuilder<double>(
                    key: const ValueKey('loading_more_indicator'),
                    tween: Tween<double>(
                      begin: _loadingIndicatorPulseForward ? 0.45 : 1.0,
                      end: _loadingIndicatorPulseForward ? 1.0 : 0.45,
                    ),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeInOut,
                    onEnd: () {
                      if (!mounted || !state.isLoadingMore) {
                        return;
                      }
                      setState(() {
                        _loadingIndicatorPulseForward =
                            !_loadingIndicatorPulseForward;
                      });
                    },
                    builder: (context, opacity, child) {
                      return Opacity(opacity: opacity, child: child);
                    },
                    child: Container(
                      height: indicatorExtent,
                      width: indicatorExtent,
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceVariant
                            .withOpacity(0.35),
                        borderRadius:
                            BorderRadius.circular(indicatorExtent / 2),
                      ),
                      alignment: Alignment.center,
                      child: SizedBox(
                        height: indicatorExtent - 20,
                        width: indicatorExtent - 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            context.color.territoryColor,
                          ),
                        ),
                      ),
                    ),
                  )
                : const SizedBox(
                    key: ValueKey('loading_more_spacer'),
                    height: indicatorExtent,
                    width: indicatorExtent,
                  ),
          ),
        ),
      ),
    );
  }

  // ====== الشيمرات ======
  Widget _listShimmer(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Container(
        height: 120.rh(context),
        decoration: BoxDecoration(
          border: Border.all(
            width: 1.5,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
          ),
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            CustomShimmer(height: 120.rh(context), width: 100.rw(context)),
            SizedBox(width: 10.rw(context)),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                CustomShimmer(
                    width: 100.rw(context), height: 10, borderRadius: 7),
                CustomShimmer(
                    width: 150.rw(context), height: 10, borderRadius: 7),
                CustomShimmer(
                    width: 120.rw(context), height: 10, borderRadius: 7),
                CustomShimmer(
                    width: 80.rw(context), height: 10, borderRadius: 7),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _gridShimmer(BuildContext context) {
    return SizedBox(
      height: _gridCardHeight,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Theme.of(context).colorScheme.surface,
          border: Border.all(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 3,
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                ),
                child: CustomShimmer(height: double.infinity, borderRadius: 0),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomShimmer(
                      width: 110.rw(context), height: 12, borderRadius: 8),
                  const SizedBox(height: 6),
                  CustomShimmer(
                      width: 80.rw(context), height: 12, borderRadius: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToDetails(BuildContext context, ItemModel item) {
    Navigator.pushNamed(
      context,
      Routes.adDetailsScreen,
      arguments: {'model': item},
    );
  }
}

// أثر التحميل

Widget buildItemsShimmer(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(8.0),
    child: Container(
      height: 120.rh(context),
      decoration: BoxDecoration(
        border: Border.all(
          width: 1.5,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
        ),
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          CustomShimmer(height: 120.rh(context), width: 100.rw(context)),
          SizedBox(width: 10.rw(context)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              CustomShimmer(
                  width: 100.rw(context), height: 10, borderRadius: 7),
              CustomShimmer(
                  width: 150.rw(context), height: 10, borderRadius: 7),
              CustomShimmer(
                  width: 120.rw(context), height: 10, borderRadius: 7),
              CustomShimmer(width: 80.rw(context), height: 10, borderRadius: 7),
            ],
          ),
        ],
      ),
    ),
  );
}

enum _HomeTabEntryType { item, ad, loadingMore }

class _HomeTabEntry {
  const _HomeTabEntry._(
    this.type, {
    this.itemIndex,
  });

  const _HomeTabEntry.item(int index)
      : this._(
          _HomeTabEntryType.item,
          itemIndex: index,
        );

  const _HomeTabEntry.ad()
      : this._(
          _HomeTabEntryType.ad,
        );

  const _HomeTabEntry.loadingMore()
      : this._(
          _HomeTabEntryType.loadingMore,
        );

  final _HomeTabEntryType type;
  final int? itemIndex;
}

Widget buildGridShimmer(BuildContext context) {
  return Container(
    margin: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      color: Theme.of(context).colorScheme.surface,
      border: Border.all(
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // صورة المنتج
        CustomShimmer(
          height: 120.rh(context),
          borderRadius: 12,
        ),

        const SizedBox(height: 8),

        // نصوص المنتج
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomShimmer(
                  width: 100.rw(context), height: 12, borderRadius: 8),
              const SizedBox(height: 6),
              CustomShimmer(width: 70.rw(context), height: 12, borderRadius: 8),
            ],
          ),
        ),

        const SizedBox(height: 8),
      ],
    ),
  );
}

class _KeepAliveNativeAd extends StatefulWidget {
  const _KeepAliveNativeAd({super.key});

  @override
  State<_KeepAliveNativeAd> createState() => _KeepAliveNativeAdState();
}

class _KeepAliveNativeAdState extends State<_KeepAliveNativeAd>
    with AutomaticKeepAliveClientMixin<_KeepAliveNativeAd> {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: 8),
        NativeAdWidget(type: TemplateType.medium),
        SizedBox(height: 8),
      ],
    );
  }
}
