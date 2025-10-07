import 'package:marib/data/cubits/item/fetch_item_summary_cubit.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/constant.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marib/utils/ui_utils.dart';
import 'dart:async';
import 'dart:math';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:marib/app/routes.dart';
import 'package:marib/data/cubits/home/fetch_home_screen_cubit.dart';
import 'package:marib/data/model/item/item_model.dart';
import 'package:marib/utils/responsiveSize.dart';
import 'package:marib/utils/sliver_grid_delegate_with_fixed_cross_axis_count_and_fixed_height.dart';
import 'package:marib/ui/screens/widgets/errors/no_data_found.dart';
import 'package:marib/ui/screens/native_ads_screen.dart';
import 'package:flutter/foundation.dart'; // لـ ValueListenable / ValueNotifier
import 'package:marib/data/cubits/category/fetch_category_cubit.dart';
import 'package:marib/data/model/category_model.dart';
// للعمليات الرياضية مثل min
import 'package:shimmer/shimmer.dart'; // تأثير التوهج أثناء تحميل الصور

// Widgets

import 'package:marib/ui/screens/sliders/slider_widget.dart';

import 'package:marib/ui/screens/home_screen/section/section_screen/SubcatsHorizontalGrid.dart';
//import 'package:marib/ui/screens/home/section/Items_List/item/sections_adapter.dart';
import 'package:marib/ui/screens/item/cards/horizontal_card.dart';
import 'package:marib/ui/screens/widgets/shimmerLoadingContainer.dart';

import 'package:marib/ui/screens/home_screen/section/section_screen/widgets/smart_search_app_bar.dart';
import 'package:marib/ui/screens/item/cards/sections_adapter.dart';
import 'package:marib/data/model/item_filter_model.dart'; // ← مهم

import 'package:marib/data/model/home/home_screen_section.dart';
import 'package:marib/utils/slider_interface_mapper.dart';

//==============================================================================
///                                   HomeTabView
//==============================================================================

class HomeTabView extends StatefulWidget {
  final ValueNotifier<int?> selectedCategoryId;
  final String categoryId;
  final TextEditingController searchController;

  // وضع العرض الخارجي (Grid/List)
  final ValueListenable<ViewMode> viewModeListenable;

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

  const HomeTabView({
    required this.selectedCategoryId,
    required this.categoryId,
    required this.searchController,
    required this.viewModeListenable,
    this.enableAdSlider = false, // افتراضي: مخفي
    this.adInterfaceType,
    // NEW 👇

    this.currentSortBy, // ← جديد
    this.currentFilter, // ← جديد
    this.enableSubcats = true, // ← جديد (افتراضي)

    this.sortBy,
    this.filter,
    this.onLoadMore,
    super.key,
  });

  @override
  State<HomeTabView> createState() => _HomeTabViewState();
}

class _HomeTabViewState extends State<HomeTabView> {
  late final ScrollController controller;

  int? _activeSubcatId; // الفئة الفرعية المختارة حالياً
  int? _lastTopCatId; // لملاحظة تغيّر التصنيف العلوي وإعادة ضبط الفرعيات
  bool _hasRequestedInitialFeatured = false;

  // ✅ قفل تحميل المزيد + تباطؤ بسيط لتجنّب سيل الاستدعاءات
  bool _isLoadingMore = false;

  final Map<int, String> _rootIdentifierByCategoryId = <int, String>{};
  final Map<int, String> _slugByCategoryId = <int, String>{};
  final Map<String, String> _slugByRootIdentifier = <String, String>{};
  int? _lastRequestedRootId;

  @override
  void initState() {
    super.initState();
    controller = ScrollController();
    widget.selectedCategoryId.addListener(_onSelectedCategoryChanged);

    _lastTopCatId = widget.selectedCategoryId.value;

    final cubit = context.read<FetchHomeScreenCubit>();
    if (cubit.state is! FetchHomeScreenInitial) {
      _hasRequestedInitialFeatured = true;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _hasRequestedInitialFeatured) {
        return;
      }
      _hasRequestedInitialFeatured = true;
      _loadFeaturedSectionsForRoot(widget.selectedCategoryId.value);
    });
  }

  @override
  void dispose() {
    widget.selectedCategoryId.removeListener(_onSelectedCategoryChanged);
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
  }

  void _onSelectedCategoryChanged() {
    if (!mounted) return;
    final int normalizedSelected = widget.selectedCategoryId.value ?? 0;
    if (_lastTopCatId != normalizedSelected) {
      _lastTopCatId = normalizedSelected;
      _activeSubcatId = null;
      _loadFeaturedSectionsForRoot(widget.selectedCategoryId.value);
    }
    setState(() {});
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
  bool _isNearBottom(ScrollNotification n) {
    final AxisDirection axisDirection = n.metrics.axisDirection;
    if (axisDirection == AxisDirection.left ||
        axisDirection == AxisDirection.right) {
      return false;
    }

    if (n.metrics.maxScrollExtent <= 0) return false;
    // هامش 200px قبل النهاية لبدء التحميل
    return n.metrics.pixels >= n.metrics.maxScrollExtent - 200;
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

  String? _getCachedRootIdentifier(int? categoryId) {
    if (categoryId == null || categoryId <= 0) {
      return null;
    }

    final String? value = _rootIdentifierByCategoryId[categoryId];
    if (value == null) {
      return null;
    }

    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      _rootIdentifierByCategoryId.remove(categoryId);
      return null;
    }

    if (!identical(value, trimmed)) {
      _rootIdentifierByCategoryId[categoryId] = trimmed;
    }

    return trimmed;
  }

  String? _getSlugForRootIdentifier(String? rootIdentifier) {
    if (rootIdentifier == null || rootIdentifier.isEmpty) {
      return null;
    }

    final String? value = _slugByRootIdentifier[rootIdentifier];
    if (value == null) {
      return null;
    }

    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      _slugByRootIdentifier.remove(rootIdentifier);
      return null;
    }

    if (!identical(value, trimmed)) {
      _slugByRootIdentifier[rootIdentifier] = trimmed;
    }

    return trimmed;
  }

  String? _cleanSlug(String? value) {
    if (value == null) {
      return null;
    }

    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  void _cacheRootIdentifiers({
    required List<HomeScreenSection> sections,
    int? rootId,
    String? requestedRootIdentifier,
  }) {
    String? resolved = requestedRootIdentifier?.trim();
    if (resolved == null || resolved.isEmpty) {
      for (final HomeScreenSection section in sections) {
        final String? sectionRoot = section.rootIdentifier?.trim();
        if (sectionRoot != null && sectionRoot.isNotEmpty) {
          resolved = sectionRoot;
          break;
        }
      }
    }

    if (rootId != null &&
        rootId > 0 &&
        resolved != null &&
        resolved.isNotEmpty) {
      _rootIdentifierByCategoryId[rootId] = resolved;
    }

    for (final HomeScreenSection section in sections) {
      final String? sectionRoot = section.rootIdentifier?.trim();
      final String? sectionSlug = _cleanSlug(section.slug);

      if (sectionRoot == null || sectionRoot.isEmpty) {
        continue;
      }

      if (sectionSlug != null) {
        _slugByRootIdentifier[sectionRoot] = sectionSlug;

        if (rootId != null &&
            rootId > 0 &&
            resolved != null &&
            resolved.isNotEmpty &&
            resolved == sectionRoot) {
          _slugByCategoryId[rootId] = sectionSlug;
        }
      }

      final Iterable<int> categoryIds = section.sectionData == null
          ? const <int>[]
          : section.sectionData!
              .map((ItemModel item) => item.categoryId)
              .whereType<int>();

      for (final int categoryId in categoryIds) {
        if (categoryId <= 0) {
          continue;
        }

        final String? existing = _rootIdentifierByCategoryId[categoryId];
        if (existing == null || existing.isEmpty) {
          _rootIdentifierByCategoryId[categoryId] = sectionRoot;
        }
        if (sectionSlug != null) {
          final String? existingSlug = _slugByCategoryId[categoryId];
          if (existingSlug == null || existingSlug.isEmpty) {
            _slugByCategoryId[categoryId] = sectionSlug;
          }
        }
      }
    }
  }

  String? _resolveRootSlug(int? rootId) {
    return _getCachedRootIdentifier(rootId);
  }

  void _loadFeaturedSectionsForRoot(int? rootId) {
    final String? interfaceType =
        SliderInterfaceMapper.normalize(widget.adInterfaceType) ??
            widget.adInterfaceType?.trim();

    if (interfaceType == null || interfaceType.isEmpty) {
      return;
    }

    _hasRequestedInitialFeatured = true;
    _lastRequestedRootId = rootId;
    final String? rootIdentifier = _getCachedRootIdentifier(rootId);

    final String? resolvedSlug = _getSlugForRootIdentifier(rootIdentifier);

    context.read<FetchHomeScreenCubit>().loadFeaturedSections(
          interfaceType: interfaceType,
          rootIdentifier: rootIdentifier,
          slug: resolvedSlug,
        );
  }

  bool _matchesRoot(HomeScreenSection section, String? rootSlug, bool showAll) {
    final String? sectionRoot = section.rootIdentifier?.trim();
    if (showAll || rootSlug == null || rootSlug.isEmpty) {
      return true;
    }

    if (sectionRoot == null || sectionRoot.isEmpty) {
      return false;
    }

    return sectionRoot == rootSlug;
  }

  bool _itemMatchesCategory(ItemModel item, int targetCategoryId) {
    if (targetCategoryId <= 0) {
      return true;
    }

    bool matchesDynamic(dynamic value) {
      if (value == null) return false;
      if (value is int) return value == targetCategoryId;
      if (value is num) return value.toInt() == targetCategoryId;
      if (value is String) {
        final int? parsed = int.tryParse(value);
        if (parsed != null) {
          return parsed == targetCategoryId;
        }
      }
      return false;
    }

    if (matchesDynamic(item.categoryId) || matchesDynamic(item.category?.id)) {
      return true;
    }

    final String? allCategoryIds = item.allCategoryIds;
    if (allCategoryIds == null || allCategoryIds.trim().isEmpty) {
      return false;
    }

    for (final Match match in RegExp(r'\d+').allMatches(allCategoryIds)) {
      final String value = match.group(0)!;
      final int? parsed = int.tryParse(value);
      if (parsed != null && parsed == targetCategoryId) {
        return true;
      }
    }

    return false;
  }

  Widget _sectionsLoadingPlaceholder({required bool showAll}) {
    const int crossAxisCount = 2;
    final int shimmerRows = showAll ? 2 : 2;
    final int childCount = crossAxisCount * shimmerRows;

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate(
          (context, index) => _gridShimmer(context),
          childCount: childCount,
        ),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCountAndFixedHeight(
          crossAxisCount: crossAxisCount,
          height: _gridCardHeight,
          mainAxisSpacing: 7,
          crossAxisSpacing: 10,
        ),
      ),
    );
  }

  Widget _sectionsEmptyPlaceholder({VoidCallback? onRetry}) {
    final Widget content = const NoDataFound();

    if (onRetry == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: content,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onRetry,
        child: content,
      ),
    );
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
  double kAdSliderHPad = 12.0;

// نصف القطر
  double kAdSliderRadius = 12.0;

// ارتفاع نقاط المؤشر = ارتفاع الـ dots نفسها (SmoothPageIndicator.dotHeight)
  static const double _kIndicatorDotHeight = 8.0;

// حجز بسيط جدًا لنقاط السلايدر (الفراغ الذي يسبق المؤشر)
  double _dotsSpacingHeight(BuildContext ctx) => 8.rh(ctx);

// الارتفاع الكامل للمؤشر + الفراغ السابق له، مطابق لما في SliderComponent
  double _dotsReserveHeight(BuildContext ctx) =>
      _kIndicatorDotHeight + _dotsSpacingHeight(ctx);

// نفس نسبة SliderComponent (AspectRatio 395/150)
  double kSliderAspect = 390 / 150;

// حدود مرنة لارتفاع الصورة لضمان تطابقها مع SliderComponent على مختلف الشاشات
  double kMinImgH = 100.0;
  double kMaxImgH = 640.0;

  double _sliderContentWidth(BuildContext ctx) {
    return MediaQuery.sizeOf(ctx).width - (kAdSliderHPad * 2);
  }

  double _adSliderImageHeight(BuildContext ctx) {
    final h = _sliderContentWidth(ctx) / kSliderAspect;
    return h.clamp(kMinImgH, kMaxImgH);
  }

  double _adSliderTotalHeight(BuildContext ctx) {
    return _adSliderImageHeight(ctx) + _dotsReserveHeight(ctx);
  }

// اختياري: لوج سريع للتأكد من الأرقام
  void _logHeights(BuildContext ctx) {
    final img = _adSliderImageHeight(ctx);
    final tot = _adSliderTotalHeight(ctx);
    final reserve = _dotsReserveHeight(ctx);

    debugPrint('AD_SLIDER heights: image=$img, total=$tot, reserve=$reserve');
  }

// الارتفاع الأساسي حسب العرض والنسبة
  double _adSliderBaseHeight(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final contentW = w - (kAdSliderHPad * 2);
    final h = contentW / kSliderAspect;
    // قيود اختيارية (عدّلها حسب تصميمك)
    return h.clamp(kMinImgH, kMaxImgH);
  }

  @override
  Widget build(BuildContext context) {
    // ========= فواصل محسوبة مرّة واحدة =========
    final scrH = MediaQuery.sizeOf(context).height;
    final gapSmall = (scrH * 0.01).clamp(6, 16).toDouble();
    final gapMedium = (scrH * 0.02).clamp(12, 32).toDouble();

    // ✅ فيزياء التمرير حسب المنصة (أخف على أندرويد)
    final platform = Theme.of(context).platform;
    final ScrollPhysics physics = (platform == TargetPlatform.iOS)
        ? const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics())
        : const ClampingScrollPhysics();

    // ✅ هل نخفي الأقسام/التصنيفات عند وجود بحث/فلتر؟
    final hasQuery = widget.searchController.text.trim().isNotEmpty;
    final hasFilter = Constant.itemFilter != null;
    final hideBlocks = hasQuery || hasFilter;
    final int? selectedCategoryId = widget.selectedCategoryId.value;

    return ValueListenableBuilder<ViewMode>(
      valueListenable: widget.viewModeListenable,
      builder: (context, mode, _) {
        final bool isList = (mode == ViewMode.list);
        final String? interfaceType =
            SliderInterfaceMapper.normalize(widget.adInterfaceType) ??
                widget.adInterfaceType;
        final String? sliderInterfaceType =
            (interfaceType != null && interfaceType.isNotEmpty)
                ? interfaceType
                : null;
        final bool showAdSlider =
            widget.enableAdSlider && sliderInterfaceType != null;

        // ✅ استمع للتمرير هنا (بدل بعثرة المنطق داخل عناصر داخلية)
        return NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n is ScrollUpdateNotification && _isNearBottom(n)) {
              _maybeLoadMore();
            }
            return false;
          },
          child: CustomScrollView(
            controller: controller,
            physics: physics,
            cacheExtent: 800, // ✅ تحميل مسبق معتدل يقلل التقطيع
            slivers: [
              // ============= السلايدر =============

              SliverToBoxAdapter(
                child: showAdSlider
                    ? Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: kAdSliderHPad),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(kAdSliderRadius),
                          child: SizedBox(
                            height: _adSliderTotalHeight(context),
                            // صورة + دوتس (نفس الإجمالي)
                            width: double.infinity,
                            child: RepaintBoundary(
                              child: SliderWidget(
                                key: ValueKey(
                                    'slider_${sliderInterfaceType ?? 'default'}'),
                                interfaceType: sliderInterfaceType,
                              ),
                            ),
                          ),
                        ),
                      )
                    : (widget.enableAdSlider
                        ? _buildAdSliderShimmer()
                        : const SizedBox.shrink()),
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
                        _loadFeaturedSectionsForRoot(selectedId);
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

                          return SubcatsDeferredBlock(
                            enabled: widget
                                .enableSubcats, // ← لا نبدأ إلا بعد فتح القسم
                            rowHeight: rowHeight,
                            maxRows: maxRows,
                            shimmerBuilder:
                                (context, dynamicRowHeight, dynamicRows) {
                              final colorScheme = Theme.of(context).colorScheme;
                              final base = colorScheme.shimmerBaseColor;
                              final highlight =
                                  colorScheme.shimmerHighlightColor;
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
                                                          period:
                                                              const Duration(
                                                                  milliseconds:
                                                                      1150),
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
                                                                width:
                                                                    itemWidth,
                                                                decoration:
                                                                    BoxDecoration(
                                                                  color: base,
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
                                          children: List.generate(
                                              placeholderDots, (dotIndex) {
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
                                                  color: base,
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
                            },
                            // انتظر نجاح جلب التصنيفات (أو اكتمال مؤقت)
                            onDeferLoad: () async {
                              final catCubit =
                                  context.read<FetchCategoryCubit>();
                              if (catCubit.state is! FetchCategorySuccess) {
                                catCubit.fetchCategories();
                                try {
                                  await catCubit.stream
                                      .firstWhere(
                                          (s) => s is FetchCategorySuccess)
                                      .timeout(const Duration(seconds: 2));
                                } catch (_) {
                                  // تجاهل في حال انتهاء المهلة، سيستمر الشيمر حتى تتوفر البيانات
                                }
                              }
                            },
                            // المحتوى الحقيقي بعد الجاهزية
                            builderWhenReady: () {
                              final catState =
                                  context.watch<FetchCategoryCubit>().state;
                              if (catState is! FetchCategorySuccess) {
                                // لو لم تصل البيانات بعد، أبقِ على مساحة الشيمر
                                final double fallbackHeight =
                                    rowHeight * maxRows +
                                        _rowSpacing * (maxRows - 1);
                                return SizedBox(height: fallbackHeight);
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

                              final bool isTopLevel =
                                  (selectedId == null || selectedId == 0);

                              // إن كان "الكل" → الأب = الجذر، غير ذلك → الأب = التصنيف المختار إن وُجد، وإلا الجذر
                              final CategoryModel currentParent = isTopLevel
                                  ? root
                                  : (rootChildren.firstWhere(
                                      (c) => c.id == selectedId,
                                      orElse: () => root,
                                    ));

                              // لو الأب الحالي بلا أبناء، اعرض أبناء الجذر كي لا يختفي الشريط
                              final List<CategoryModel> subcats =
                                  (currentParent.children?.isNotEmpty ?? false)
                                      ? (currentParent.children!)
                                      : rootChildren;

                              if (subcats.isEmpty)
                                return const SizedBox.shrink();

                              final brand =
                                  Theme.of(context).colorScheme.primary;

                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SubcatsHorizontalGrid(
                                    subcats: subcats,
                                    selectedId:
                                        _activeSubcatId, // تظليل الفرعيّة المختارة
                                    brand: brand,
                                    isTopLevel: isTopLevel,
                                    onTap: (_) {},

                                    // في تبويب "الكل": اضغط فرعيّة ⇒ انقل شريط التصنيفات للفئة واضبط الجلب لها
                                    onTopCategoryPick: (c) {
                                      if (!isTopLevel) return;
                                      widget.selectedCategoryId.value = c.id;
                                      _activeSubcatId =
                                          null; // سنعرض أبناء الفئة المختارة الآن
                                      setState(() {});
                                      context
                                          .read<FetchItemSummaryCubit>()
                                          .fetchSummaries(
                                            categoryId: c.id ?? 0,
                                            search: widget.searchController.text
                                                .trim(),
                                            sortBy: widget.sortBy,
                                            filter: widget.filter?.copyWith(
                                              categoryId:
                                                  (c.id ?? 0).toString(),
                                            ),
                                          );
                                    },

                                    // في فئة علوية ≠ "الكل": اضغط فرعيّة ⇒ فلترة مباشرة وتظليل الفرعيّة
                                    onSubcatPick: (c) {
                                      if (isTopLevel) {
                                        widget.selectedCategoryId.value = c.id;
                                        _activeSubcatId = null;
                                        setState(() {});
                                        context
                                            .read<FetchItemSummaryCubit>()
                                            .fetchSummaries(
                                              categoryId: c.id ?? 0,
                                              search: widget
                                                  .searchController.text
                                                  .trim(),
                                              sortBy: widget.sortBy,
                                              filter: widget.filter?.copyWith(
                                                categoryId:
                                                    (c.id ?? 0).toString(),
                                              ),
                                            );
                                      } else {
                                        setState(() => _activeSubcatId = c.id);
                                        context
                                            .read<FetchItemSummaryCubit>()
                                            .fetchSummaries(
                                              categoryId: c.id ?? 0,
                                              search: widget
                                                  .searchController.text
                                                  .trim(),
                                              sortBy: widget.sortBy,
                                              filter: widget.filter?.copyWith(
                                                categoryId:
                                                    (c.id ?? 0).toString(),
                                              ),
                                            );
                                      }
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

              ..._sectionsBlock(selectedCategoryId, isList),

              // فاصل متوسط
              SliverToBoxAdapter(child: SizedBox(height: gapMedium)),

              // ============= القائمة الرئيسية (كما هي عندك) =============
              // ملاحظة: داخل _itemsSliver احرص على استخدام SliverList/SliverGrid
              // مع addRepaintBoundaries: true, addAutomaticKeepAlives: false,
              // ومفاتيح مستقرة + itemExtent/prototypeItem إن أمكن
              ..._buildItemsSlivers(isList),

              // فاصل أخير
              SliverToBoxAdapter(child: SizedBox(height: gapMedium)),
            ],
          ),
        );
      },
    );
  }

  // أقسام الهوم: SectionsAdapter أو شبكة منتجات للتصنيف المحدد

  List<Widget> _sectionsBlock(int? selectedId, bool _) {
    final bool showAll = selectedId == null || selectedId == 0;
    final FetchHomeScreenState state =
        context.watch<FetchHomeScreenCubit>().state;

    if (state is FetchHomeScreenInitial || state is FetchHomeScreenInProgress) {
      return <Widget>[
        _sectionsLoadingPlaceholder(showAll: showAll),
      ];
    }

    if (state is FetchHomeScreenFail) {
      return <Widget>[
        SliverToBoxAdapter(
          child: _sectionsEmptyPlaceholder(
            onRetry: () => _loadFeaturedSectionsForRoot(selectedId),
          ),
        ),
      ];
    }

    if (state is FetchHomeScreenSuccess) {
      final int? cachingRootId = _lastRequestedRootId ?? selectedId;
      _cacheRootIdentifiers(
        sections: state.sections,
        rootId: cachingRootId,
        requestedRootIdentifier: state.rootIdentifier,
      );

      final String? rootSlug = showAll ? null : _resolveRootSlug(selectedId);

      final List<HomeScreenSection> filteredSections = state.sections
          .where((s) => _matchesRoot(s, rootSlug, showAll))
          .toList();

      if (filteredSections.isEmpty) {
        return <Widget>[
          SliverToBoxAdapter(
            child: _sectionsEmptyPlaceholder(
              onRetry: () => _loadFeaturedSectionsForRoot(selectedId),
            ),
          ),
        ];
      }

      if (showAll) {
        return <Widget>[
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => SectionsAdapter(
                section: filteredSections[index],
              ),
              childCount: filteredSections.length,
            ),
          ),
        ];
      }

      final int targetCategoryId = selectedId ?? 0;
      final List<ItemModel> products = filteredSections
          .expand((s) => s.sectionData ?? const <ItemModel>[])
          .where((i) => _itemMatchesCategory(i, targetCategoryId))
          .toList();

      if (products.isEmpty) {
        return <Widget>[
          SliverToBoxAdapter(
            child: _sectionsEmptyPlaceholder(
              onRetry: () => _loadFeaturedSectionsForRoot(selectedId),
            ),
          ),
        ];
      }

      return <Widget>[
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (context, index) => ICard(item: products[index]),
              childCount: products.length,
            ),
            gridDelegate:
                SliverGridDelegateWithFixedCrossAxisCountAndFixedHeight(
              crossAxisCount: 2,
              height: _gridCardHeight,
              mainAxisSpacing: 7,
              crossAxisSpacing: 10,
            ),
          ),
        ),
      ];
    }

    return const <Widget>[
      SliverToBoxAdapter(child: SizedBox(height: 1)),
    ];
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
              crossAxisCount: 2,
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
                          ),
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
        return <Widget>[
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final _HomeTabEntry entry = entries[index];
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
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: UiUtils.progress(),
                    );
                }
              },
              childCount: entries.length,
              addAutomaticKeepAlives: false,
              addRepaintBoundaries: true,
            ),
          ),
        ];
      }

      return _buildGridModeSlivers(entries, state.items);
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
    List<_HomeTabEntry> entries,
    List<ItemSummary> items,
  ) {
    final List<Widget> slivers = <Widget>[];
    int cursor = 0;

    while (cursor < entries.length) {
      final _HomeTabEntry entry = entries[cursor];
      switch (entry.type) {
        case _HomeTabEntryType.item:
          final List<int> batchIndices = <int>[];
          while (cursor < entries.length &&
              entries[cursor].type == _HomeTabEntryType.item) {
            batchIndices.add(entries[cursor].itemIndex!);
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
                    crossAxisCount: 2,
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
          slivers.add(
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: UiUtils.progress(),
              ),
            ),
          );
          cursor++;
          break;
      }

      if (entry.type == _HomeTabEntryType.item) {
        // تم تحريك المؤشر داخل الحلقة الداخلية.
      }
    }

    return slivers;
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
  const _HomeTabEntry._(this.type, {this.itemIndex});

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
  const _KeepAliveNativeAd();

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
