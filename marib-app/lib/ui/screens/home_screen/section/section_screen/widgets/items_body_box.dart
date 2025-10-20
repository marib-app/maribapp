import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shimmer/shimmer.dart'; // تأثير التوهج أثناء تحميل الصور

import 'package:marib/data/cubits/item/fetch_item_summary_cubit.dart';

import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/constant.dart';
import 'package:marib/utils/extensions/extensions.dart';

import 'home_tab_view.dart';

import 'slider_widget.dart';
import 'smart_search_app_bar.dart';
import 'package:marib/data/model/item_filter_model.dart'; // ← مهم

///==============================================================================
///                                   ItemsBodyBox
///==============================================================================

class ItemsBodyBox extends StatefulWidget {
  final String categoryId;
  final ValueNotifier<int?> selectedCategoryId;
  final bool showShimmer;
  final TextEditingController searchController;
  final String? categoryName;
  final double bottomContentPadding;
  final bool showCartAction;
  final VoidCallback? onCartTap;
  final int sliderRefreshToken;

  // جديد: لا تبني شريط التصنيفات/السلايدر إلا إذا true
  final bool enableTopBar;
  final String? specialRequestSectionSlug;

  final bool enableAdSlider; // ← جديد
  final String? adInterfaceType; // ← جديد

  final bool enableSubcats;
  final String? sortBy;
  final ItemFilterModel? filter;
  final ValueChanged<bool>? onLoadMore;
  final ValueChanged<bool>? onScrollDirectionChanged;

  const ItemsBodyBox({
    required this.categoryId,
    required this.selectedCategoryId,
    required this.showShimmer,
    required this.searchController,
    this.categoryName,
    required this.showCartAction,
    this.onCartTap,
    this.enableTopBar = false, // ← افتراضي: مخفي
    this.enableAdSlider = false,
    this.adInterfaceType,
    this.sortBy, // ← جديد
    this.filter, // ← جديد
    this.enableSubcats = true, // ← جديد (بحالته الافتراضية)
    this.onLoadMore,
    required this.sliderRefreshToken,
    this.specialRequestSectionSlug,
    this.onScrollDirectionChanged,
    this.bottomContentPadding = 0.0,
    super.key,
  });

  @override
  State<ItemsBodyBox> createState() => _ItemsBodyBoxState();
}

class _ItemsBodyBoxState extends State<ItemsBodyBox> {
  // ✅ نحسب الـ categoryId مرة واحدة
  late final int _catId = int.tryParse(widget.categoryId) ?? 0;

  // ✅ وضع العرض (grid/list) مع ValueNotifier لتقليل setState
  final ValueNotifier<ViewMode> _viewMode =
      ValueNotifier<ViewMode>(ViewMode.grid);

  // ✅ بحث آمن: debounce + token لمنع سباقات النتائج
  Timer? _debounce;
  int _searchToken = 0;
  String _lastExecutedQuery = "";

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _viewMode.dispose();
    super.dispose();
  }

  // =============================
  // بحث آمن: Debounce + Token
  // =============================
  void _onSearchInput(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _triggerSearch(value);
    });
  }

  void _triggerSearch(String raw) {
    final q = raw.trim();
    if (q == _lastExecutedQuery) return;

    final int myToken = ++_searchToken;
    _lastExecutedQuery = q;

    final fetchCubit = context.read<FetchItemSummaryCubit>();
    final currentState = fetchCubit.state;

    final int effectiveCategoryId;
    if (currentState is FetchItemSummarySuccess) {
      effectiveCategoryId = currentState.categoryId;
    } else {
      final int? selectedCategoryId = widget.selectedCategoryId.value;
      effectiveCategoryId =
          (selectedCategoryId == null || selectedCategoryId <= 0)
              ? _catId
              : selectedCategoryId;
    }

    final ItemFilterModel? sourceFilter =
        (currentState is FetchItemSummarySuccess && currentState.filter != null)
            ? currentState.filter
            : widget.filter;

    final ItemFilterModel? normalizedFilter = sourceFilter?.copyWith(
      categoryId: effectiveCategoryId.toString(),
    );

    fetchCubit
        .fetchSummaries(
      categoryId: effectiveCategoryId,
      search: q,
      sortBy: widget.sortBy,
      filter: normalizedFilter,
    )
        .whenComplete(() {
      if (!mounted || myToken != _searchToken) return;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isLoading = context.select<FetchItemSummaryCubit, bool>(
      (c) => c.state is FetchItemSummaryLoading,
    );
    final bool showTopPlaceholder = widget.showShimmer || !widget.enableTopBar;

    return PopScope(
      canPop: true,
      onPopInvoked: (_) => Constant.itemFilter = null,
      child: Scaffold(
        backgroundColor: context.color.primaryColor,

        // ===== AppBar =====
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: ValueListenableBuilder<ViewMode>(
            valueListenable: _viewMode,
            builder: (context, mode, _) {
              final String? sanitizedCategoryName = widget.categoryName?.trim();
              final String effectiveAppBarTitle =
                  (sanitizedCategoryName != null &&
                          sanitizedCategoryName.isNotEmpty)
                      ? sanitizedCategoryName
                      : "realestate";
              return SmartSearchAppBar(
                appBarTitle: effectiveAppBarTitle,
                searchController: widget.searchController,
                onSearchTap: () {},
                onSearchChanged: _onSearchInput,
                onClearSearch: () => _onSearchInput(""),
                onSearchEditingComplete: () {
                  _triggerSearch(widget.searchController.text);
                  FocusScope.of(context).unfocus();
                  HapticFeedback.selectionClick();
                },
                viewMode: mode,
                onCycleViewMode: () {
                  _viewMode.value =
                      (mode == ViewMode.grid) ? ViewMode.list : ViewMode.grid;
                },
                isLoading: isLoading,
                showCartAction: widget.showCartAction,
                onCartTap: widget.onCartTap,
              );
            },
          ),
        ),

        // ===== الجسم: شريط التصنيفات + المحتوى =====

// ===== الجسم: شريط التصنيفات + المحتوى =====
        body: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            // ✅ نفس الهيكل والهوامش للحالتين (شيمر/حقيقي)
            Material(
              color: context.color.secondaryColor,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.enableTopBar && !showTopPlaceholder)
                    ValueListenableBuilder<int?>(
                      valueListenable: widget.selectedCategoryId,
                      builder: (context, selectedId, _) {
                        return KeyedSubtree(
                          key: ValueKey('pcslider_${widget.categoryId}'),
                          child: PcSliderWidget(
                            parentId: _catId,
                            selectedCategoryId: selectedId,
                            onCategorySelected: (id) {
                              final int rawId = id ?? 0;
                              final int effectiveId =
                                  rawId <= 0 ? _catId : rawId;
                              if (widget.selectedCategoryId.value != rawId) {
                                widget.selectedCategoryId.value = rawId;
                              }
                              final query = widget.searchController.text.trim();
                              final ItemFilterModel? baseFilter = widget.filter;
                              final ItemFilterModel? nextFilter =
                                  baseFilter == null
                                      ? null
                                      : baseFilter.copyWith(
                                          categoryId: effectiveId.toString(),
                                        );
                              context
                                  .read<FetchItemSummaryCubit>()
                                  .fetchSummaries(
                                    categoryId: effectiveId,
                                    search: query,
                                    sortBy: widget.sortBy,
                                    filter: nextFilter,
                                  );
                              _lastExecutedQuery = query;
                            },
                          ),
                        );
                      },
                    )
                  else if (showTopPlaceholder)
                    _buildTopBarShimmerExact(), // ← شيمر مطابق تمامًا للهيكل

                  const SizedBox(height: 6), // ← نفس الفاصل في الحالتين
                ],
              ),
            ),

            // باقي الجسم (السلايدر/القوائم...)
            Expanded(
              child: RepaintBoundary(
                child: HomeTabView(
                  selectedCategoryId: widget.selectedCategoryId,
                  categoryId: widget.categoryId,
                  searchController: widget.searchController,
                  viewModeListenable: _viewMode,
                  bottomPadding: widget.bottomContentPadding,
                  showShimmer: widget.showShimmer,
                  sliderRefreshToken: widget.sliderRefreshToken,

                  // موجودة عندك مسبقًا:
                  currentSortBy: widget.sortBy,
                  currentFilter: widget.filter,
                  enableSubcats: widget.enableSubcats,
                  onScrollDirectionChanged: widget.onScrollDirectionChanged,
                  specialRequestSectionSlug: widget.specialRequestSectionSlug,

                  // ✨ المهم: مرر مفاتيح السلايدر الإعلاني
                  enableAdSlider: widget.enableAdSlider,
                  // ← أضِف هذا
                  adInterfaceType: widget.adInterfaceType,
                  // ← وأيضًا هذا
                  onLoadMore: widget.onLoadMore,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBarShimmerExact() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final base = colorScheme.shimmerBaseColor;
    final highlight = colorScheme.shimmerHighlightColor;
    final content = colorScheme.shimmerContentColor;

    const double chipHeight = 34.0; // نفس ارتفاع العنصر داخل PcSliderWidget
    const widths = [76.0, 92.0, 68.0, 108.0, 80.0, 96.0, 74.0];

    // ⬇️ نفس الهيكل تمامًا كما في PcSliderWidget:
    // Padding(0,10,0,12)  +  Container(height:35, padding:bottom 2, border...) + ListView.h
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 10, 0, 12),
      child: Container(
        height: 35,
        padding: const EdgeInsets.only(bottom: 2),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: theme.dividerColor.withOpacity(0.1),
              width: 0,
            ),
          ),
        ),
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          scrollDirection: Axis.horizontal,
          itemCount: 10,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) => Shimmer.fromColors(
            baseColor: base,
            highlightColor: highlight,
            period: const Duration(milliseconds: 1100),
            child: Container(
              width: widths[i % widths.length],
              height: chipHeight,
              decoration: BoxDecoration(
                color: content,
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
