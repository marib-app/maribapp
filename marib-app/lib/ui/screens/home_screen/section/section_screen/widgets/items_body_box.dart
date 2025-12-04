import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shimmer/shimmer.dart'; // طھط£ط«ظٹط± ط§ظ„طھظˆظ‡ط¬ ط£ط«ظ†ط§ط، طھط­ظ…ظٹظ„ ط§ظ„طµظˆط±

import 'package:marib/data/cubits/item/fetch_item_summary_cubit.dart';

import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/constant.dart';
import 'package:marib/utils/extensions/extensions.dart';

import 'home_tab_view.dart';

import 'slider_widget.dart';
import 'smart_search_app_bar.dart';
import 'package:marib/data/model/item_filter_model.dart'; // â†گ ظ…ظ‡ظ…

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
  final List<int>? sellerCategoryIds;
  final String? interfaceType;
  final Widget? storefrontHeader;

  // ط¬ط¯ظٹط¯: ظ„ط§ طھط¨ظ†ظٹ ط´ط±ظٹط· ط§ظ„طھطµظ†ظٹظپط§طھ/ط§ظ„ط³ظ„ط§ظٹط¯ط± ط¥ظ„ط§ ط¥ط°ط§ true
  final bool enableTopBar;
  final String? specialRequestSectionSlug;

  final bool enableAdSlider; // â†گ ط¬ط¯ظٹط¯
  final String? adInterfaceType; // â†گ ط¬ط¯ظٹط¯

  final bool enableFeaturedAds;
  final String? featuredStyleOverride;
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
    this.interfaceType,
    this.onCartTap,
    this.enableTopBar = false, // â†گ ط§ظپطھط±ط§ط¶ظٹ: ظ…ط®ظپظٹ
    this.enableAdSlider = false,
    this.adInterfaceType,
    this.enableFeaturedAds = false,
    this.featuredStyleOverride,
    this.sortBy, // â†گ ط¬ط¯ظٹط¯
    this.filter, // â†گ ط¬ط¯ظٹط¯
    this.enableSubcats =
        true, // â†گ ط¬ط¯ظٹط¯ (ط¨ط­ط§ظ„طھظ‡ ط§ظ„ط§ظپطھط±ط§ط¶ظٹط©)
    this.onLoadMore,
    required this.sliderRefreshToken,
    this.specialRequestSectionSlug,
    this.onScrollDirectionChanged,
    this.bottomContentPadding = 0.0,
    this.sellerCategoryIds,
    this.storefrontHeader,
    super.key,
  });

  @override
  State<ItemsBodyBox> createState() => _ItemsBodyBoxState();
}

class _ItemsBodyBoxState extends State<ItemsBodyBox> {
  // âœ… ظ†ط­ط³ط¨ ط§ظ„ظ€ categoryId ظ…ط±ط© ظˆط§ط­ط¯ط©
  late final int _catId = int.tryParse(widget.categoryId) ?? 0;
  List<int>? _sellerCategoryIds;

  // âœ… ظˆط¶ط¹ ط§ظ„ط¹ط±ط¶ (grid/list) ظ…ط¹ ValueNotifier ظ„طھظ‚ظ„ظٹظ„ setState
  final ValueNotifier<ViewMode> _viewMode =
      ValueNotifier<ViewMode>(ViewMode.grid);

  // âœ… ط¨ط­ط« ط¢ظ…ظ†: debounce + token ظ„ظ…ظ†ط¹ ط³ط¨ط§ظ‚ط§طھ ط§ظ„ظ†طھط§ط¦ط¬
  Timer? _debounce;
  int _searchToken = 0;
  String _lastExecutedQuery = "";

  @override
  void initState() {
    _sellerCategoryIds = _normalizeSellerCategoryIds(widget.sellerCategoryIds);
    super.initState();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _viewMode.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ItemsBodyBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.sellerCategoryIds, widget.sellerCategoryIds)) {
      _sellerCategoryIds =
          _normalizeSellerCategoryIds(widget.sellerCategoryIds);
    }
  }

  // =============================
  // ط¨ط­ط« ط¢ظ…ظ†: Debounce + Token
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
      perPage: FetchItemSummaryCubit.defaultPerPage,
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

        // ===== ط§ظ„ط¬ط³ظ…: ط´ط±ظٹط· ط§ظ„طھطµظ†ظٹظپط§طھ + ط§ظ„ظ…ط­طھظˆظ‰ =====

// ===== ط§ظ„ط¬ط³ظ…: ط´ط±ظٹط· ط§ظ„طھطµظ†ظٹظپط§طھ + ط§ظ„ظ…ط­طھظˆظ‰ =====
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            final List<Widget> slivers = <Widget>[];

            if (widget.storefrontHeader != null) {
              slivers.add(
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      widget.storefrontHeader!,
                      const SizedBox(height: 4),
                    ],
                  ),
                ),
              );
            }

            if (widget.enableTopBar || showTopPlaceholder) {
              final SliverOverlapAbsorberHandle overlapHandle =
                  NestedScrollView.sliverOverlapAbsorberHandleFor(context);
              slivers.add(
                SliverOverlapAbsorber(
                  handle: overlapHandle,
                  sliver: SliverPersistentHeader(
                    pinned: true,
                    delegate: _CategoryTabsHeaderDelegate(
                      showPlaceholder: showTopPlaceholder,
                      enableTopBar: widget.enableTopBar,
                      parentCategoryId: _catId,
                      selectedCategoryNotifier: widget.selectedCategoryId,
                      interfaceType: widget.interfaceType,
                      sellerCategoryIds: _sellerCategoryIds,
                      buildPlaceholder: _buildTopBarShimmerExact,
                      onCategorySelected: _handleCategorySelection,
                      contentColor: context.color.secondaryColor,
                    ),
                  ),
                ),
              );
            }

            return slivers;
          },
          body: Builder(
            builder: (bodyContext) {
              final SliverOverlapAbsorberHandle? overlapHandleBody =
                  (widget.enableTopBar || showTopPlaceholder)
                      ? NestedScrollView.sliverOverlapAbsorberHandleFor(
                          bodyContext,
                        )
                      : null;
              return RepaintBoundary(
                child: HomeTabView(
                  selectedCategoryId: widget.selectedCategoryId,
                  categoryId: widget.categoryId,
                  searchController: widget.searchController,
                  viewModeListenable: _viewMode,
                  bottomPadding: widget.bottomContentPadding,
                  showShimmer: widget.showShimmer,
                  sliderRefreshToken: widget.sliderRefreshToken,
                  sellerCategoryIds: _sellerCategoryIds,
                  interfaceType: widget.interfaceType,
                  rootCategoryName: widget.categoryName,
                  currentSortBy: widget.sortBy,
                  currentFilter: widget.filter,
                  enableSubcats: widget.enableSubcats,
                  onScrollDirectionChanged: widget.onScrollDirectionChanged,
                  specialRequestSectionSlug: widget.specialRequestSectionSlug,
                  enableAdSlider: widget.enableAdSlider,
                  adInterfaceType: widget.adInterfaceType,
                  showFeaturedAds: widget.enableFeaturedAds,
                  featuredStyleOverride: widget.featuredStyleOverride,
                  onLoadMore: widget.onLoadMore,
                  overlapHandle: overlapHandleBody,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  List<int>? _normalizeSellerCategoryIds(List<int>? ids) {
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
    final List<int> sorted = normalized.toList(growable: false)..sort();
    return sorted;
  }

  void _handleCategorySelection(int? id) {
    final int rawId = id ?? 0;
    final int effectiveId = rawId <= 0 ? _catId : rawId;
    if (widget.selectedCategoryId.value != rawId) {
      widget.selectedCategoryId.value = rawId;
    }
    final String query = widget.searchController.text.trim();
    final ItemFilterModel? baseFilter = widget.filter;
    final ItemFilterModel? nextFilter =
        baseFilter?.copyWith(categoryId: effectiveId.toString());
    context.read<FetchItemSummaryCubit>().fetchSummaries(
          categoryId: effectiveId,
          search: query,
          sortBy: widget.sortBy,
          filter: nextFilter,
          perPage: FetchItemSummaryCubit.defaultPerPage,
        );
    _lastExecutedQuery = query;
  }

  Widget _buildTopBarShimmerExact() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final base = colorScheme.shimmerBaseColor;
    final highlight = colorScheme.shimmerHighlightColor;
    final content = colorScheme.shimmerContentColor;

    const double chipHeight =
        34.0; // ظ†ظپط³ ط§ط±طھظپط§ط¹ ط§ظ„ط¹ظ†طµط± ط¯ط§ط®ظ„ PcSliderWidget
    const widths = [76.0, 92.0, 68.0, 108.0, 80.0, 96.0, 74.0];

    // â¬‡ï¸ڈ ظ†ظپط³ ط§ظ„ظ‡ظٹظƒظ„ طھظ…ط§ظ…ظ‹ط§ ظƒظ…ط§ ظپظٹ PcSliderWidget:
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

class _CategoryTabsHeaderDelegate extends SliverPersistentHeaderDelegate {
  static const double _tabsHeight = 70.0;

  _CategoryTabsHeaderDelegate({
    required this.showPlaceholder,
    required this.enableTopBar,
    required this.parentCategoryId,
    required this.selectedCategoryNotifier,
    required this.interfaceType,
    required this.sellerCategoryIds,
    required this.buildPlaceholder,
    required this.onCategorySelected,
    required this.contentColor,
  });

  final bool showPlaceholder;
  final bool enableTopBar;
  final int parentCategoryId;
  final ValueNotifier<int?> selectedCategoryNotifier;
  final String? interfaceType;
  final List<int>? sellerCategoryIds;
  final Widget Function() buildPlaceholder;
  final ValueChanged<int?> onCategorySelected;
  final Color contentColor;

  double get _effectiveHeight =>
      (enableTopBar || showPlaceholder) ? _tabsHeight : 0.0;

  @override
  double get minExtent => _effectiveHeight;

  @override
  double get maxExtent => _effectiveHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    if (_effectiveHeight == 0.0) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: _tabsHeight,
      child: Material(
        color: contentColor,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (enableTopBar && !showPlaceholder)
              ValueListenableBuilder<int?>(
                valueListenable: selectedCategoryNotifier,
                builder: (context, selectedId, _) {
                  return KeyedSubtree(
                    key: ValueKey('pcslider_$parentCategoryId'),
                    child: PcSliderWidget(
                      parentId: parentCategoryId,
                      selectedCategoryId: selectedId,
                      onCategorySelected: onCategorySelected,
                      interfaceType: interfaceType,
                      sellerCategoryIds: sellerCategoryIds,
                    ),
                  );
                },
              )
            else if (showPlaceholder)
              buildPlaceholder(),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _CategoryTabsHeaderDelegate oldDelegate) {
    return showPlaceholder != oldDelegate.showPlaceholder ||
        enableTopBar != oldDelegate.enableTopBar ||
        parentCategoryId != oldDelegate.parentCategoryId ||
        interfaceType != oldDelegate.interfaceType ||
        !listEquals(sellerCategoryIds, oldDelegate.sellerCategoryIds) ||
        contentColor != oldDelegate.contentColor;
  }
}
