import 'dart:async';
import 'home_tab_view.dart';
import 'package:marib/data/cubits/item/fetch_item_summary_cubit.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/constant.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:marib/ui/screens/settings/main_activity.dart';
import 'package:flutter/services.dart';
import 'package:marib/data/cubits/slider_cubit.dart';
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
import 'package:marquee/marquee.dart';
import 'package:marib/app/routes.dart';
import 'package:marib/data/cubits/category/fetch_category_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marib/data/model/category_model.dart';
import 'package:marquee/marquee.dart';
import 'package:marib/utils/screen_scaler.dart';
import 'dart:math'; // للعمليات الرياضية مثل min
import 'package:shimmer/shimmer.dart'; // تأثير التوهج أثناء تحميل الصور
import 'package:cached_network_image/cached_network_image.dart';

// Widgets

import 'package:marib/ui/screens/sliders/slider_widget.dart';

//import 'package:marib/ui/screens/home/section/Items_List/item/sections_adapter.dart';
import 'package:marib/ui/screens/item/cards/horizontal_card.dart';
import 'package:marib/ui/screens/native_ads_screen.dart';
import 'package:marib/ui/screens/widgets/errors/no_data_found.dart';
import 'package:marib/ui/screens/widgets/shimmerLoadingContainer.dart';
import 'package:marib/utils/sliver_grid_delegate_with_fixed_cross_axis_count_and_fixed_height.dart';


import 'package:marib/data/model/item_filter_model.dart'; // ← مهم

import 'package:marib/utils/screen_scaler.dart';

///==============================================================================
///                                   ItemsBodyBox
///==============================================================================
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/constant.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/ui_utils.dart';

import 'package:marib/data/cubits/item/fetch_item_summary_cubit.dart';
import 'package:marib/data/model/item_filter_model.dart';


import 'package:shimmer/shimmer.dart';
import 'package:marib/data/model/item_filter_model.dart';

import 'package:shimmer/shimmer.dart';

import 'package:marib/data/model/home/home_screen_section.dart';
import 'package:marib/utils/slider_interface_mapper.dart';
import 'package:marib/utils/featured_section_utils.dart';
import 'package:flutter/rendering.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marib/data/cubits/category/fetch_category_cubit.dart';
import 'package:marib/data/cubits/item/fetch_item_from_category_cubit.dart';
import 'package:marib/data/model/category_model.dart';
import 'package:marib/data/model/item/item_model.dart';
import 'package:marib/data/model/item_filter_model.dart';
import 'package:marib/ui/screens/home_screen/section/section_screen/widgets/filter_sort_bar/filter_sort_bar.dart';
import 'package:marib/ui/screens/item/cards/horizontal_card.dart';
import 'package:marib/ui/screens/item/cards/sections_adapter.dart';
import 'package:marib/ui/screens/sliders/slider_widget.dart';
import 'package:marib/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:marib/ui/screens/widgets/errors/no_data_found.dart';
import 'package:marib/ui/screens/widgets/errors/something_went_wrong.dart';
import 'package:marib/ui/screens/widgets/shimmerLoadingContainer.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/constant.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/ui_utils.dart';

class ItemsListShein extends StatefulWidget {
  final String categoryId;
  final String categoryName;
  final List<String> categoryIds;
  final String interfaceType;

  const ItemsListShein({
    super.key,
    required this.categoryId,
    required this.categoryName,
    required this.categoryIds,
    required this.interfaceType,
  });

  static Route route(RouteSettings routeSettings) {
    final Map<String, dynamic>? arguments =
    routeSettings.arguments as Map<String, dynamic>?;

    return BlurredRouter(
      builder: (_) => ItemsListShein(
        categoryId: arguments?['catID']?.toString() ?? '',
        categoryName: arguments?['catName']?.toString() ?? '',
        categoryIds: (arguments?['categoryIds'] as List<dynamic>? ?? <dynamic>[])
            .map((dynamic value) => value.toString())
            .toList(),
        interfaceType: arguments?['interfaceType']?.toString() ?? 'all',
      ),
    );
  }

  @override
  State<ItemsListShein> createState() => _ItemsListSheinState();
}

class _ItemsListSheinState extends State<ItemsListShein> {
  late final TextEditingController _searchController;
  late final ScrollController _scrollController;

  Timer? _searchDebounce;
  String _lastSubmittedQuery = '';
  bool _isGridMode = true;

  late String _activeCategoryId;
  late String _activeCategoryName;

  ItemFilterModel? _currentFilter;
  String? _currentSort;

  @override
  void initState() {
    super.initState();
    _activeCategoryId = widget.categoryId;
    _activeCategoryName = widget.categoryName;

    _searchController = TextEditingController();
    _scrollController = ScrollController();

    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_handleScrollPosition);

    Constant.itemFilter = null;

    final FetchCategoryCubit categoryCubit =
    context.read<FetchCategoryCubit>();
    if (categoryCubit.state is! FetchCategorySuccess) {
      categoryCubit.fetchCategories();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchItems();
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollController.removeListener(_handleScrollPosition);
    _scrollController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    Constant.itemFilter = null;
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {});
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      final String trimmedQuery = _searchController.text.trim();
      if (trimmedQuery == _lastSubmittedQuery) {
        return;
      }
      _lastSubmittedQuery = trimmedQuery;
      _fetchItems();
    });
  }

  void _handleScrollPosition() {
    if (!_scrollController.hasClients) return;
    final double maxScroll = _scrollController.position.maxScrollExtent;
    final double current = _scrollController.position.pixels;
    if (current + 200 >= maxScroll) {
      final FetchItemFromCategoryCubit cubit =
      context.read<FetchItemFromCategoryCubit>();
      if (cubit.hasMoreData()) {
        cubit.fetchItemFromCategoryMore(
          catId: _resolveCategoryId(_activeCategoryId),
          search: _searchController.text.trim(),
          sortBy: _currentSort,
          filter: _effectiveFilter,
        );
      }
    }
  }

  int _resolveCategoryId(String rawId) {
    return int.tryParse(rawId) ?? 0;
  }

  ItemFilterModel? get _effectiveFilter {
    if (_currentFilter == null) {
      return null;
    }

    final Map<String, dynamic>? rawFields =
    _currentFilter?.customFields != null
        ? Map<String, dynamic>.from(_currentFilter!.customFields!)
        : null;
    final Map<String, dynamic>? customFields =
    rawFields == null || rawFields.isEmpty ? null : rawFields;

    return ItemFilterModel(
      maxPrice: _normalizeText(_currentFilter?.maxPrice),
      minPrice: _normalizeText(_currentFilter?.minPrice),
      categoryId: _activeCategoryId,
      postedSince: _normalizeText(_currentFilter?.postedSince),
      city: _normalizeText(_currentFilter?.city),
      state: _normalizeText(_currentFilter?.state),
      country: _normalizeText(_currentFilter?.country),
      area: _normalizeText(_currentFilter?.area),
      areaId: _currentFilter?.areaId,
      radius: _currentFilter?.radius,
      latitude: _currentFilter?.latitude,
      longitude: _currentFilter?.longitude,
      currency: _normalizeText(_currentFilter?.currency),
      customFields: customFields,
    );
  }

  String? _normalizeText(String? value) {
    if (value == null) return null;
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<void> _fetchItems() async {
    final FetchItemFromCategoryCubit cubit =
    context.read<FetchItemFromCategoryCubit>();
    final String searchQuery = _searchController.text.trim();
    _lastSubmittedQuery = searchQuery;

    cubit.fetchItemFromCategory(
      categoryId: _resolveCategoryId(_activeCategoryId),
      search: searchQuery,
      sortBy: _currentSort,
      filter: _effectiveFilter,
    );
  }

  Future<void> _onRefresh() async {
    await _fetchItems();
  }

  void _applyFilter(ItemFilterModel? filter) {
    final ItemFilterModel? normalizedFilter = _normalizeFilter(filter);
    setState(() {
      _currentFilter = normalizedFilter;
      Constant.itemFilter = normalizedFilter;
    });
    _fetchItems();
  }

  ItemFilterModel? _normalizeFilter(ItemFilterModel? filter) {
    if (filter == null) {
      return null;
    }

    final Map<String, dynamic>? rawFields = filter.customFields != null
        ? Map<String, dynamic>.from(filter.customFields!)
        : null;
    final Map<String, dynamic>? customFields =
    rawFields == null || rawFields.isEmpty ? null : rawFields;

    final ItemFilterModel normalized = ItemFilterModel(
      maxPrice: _normalizeText(filter.maxPrice),
      minPrice: _normalizeText(filter.minPrice),
      categoryId: _activeCategoryId,
      postedSince: _normalizeText(filter.postedSince),
      city: _normalizeText(filter.city),
      state: _normalizeText(filter.state),
      country: _normalizeText(filter.country),
      area: _normalizeText(filter.area),
      areaId: filter.areaId,
      radius: filter.radius,
      latitude: filter.latitude,
      longitude: filter.longitude,
      currency: _normalizeText(filter.currency),
      customFields: customFields,
    );

    if (_isFilterEmpty(normalized)) {
      return null;
    }

    return normalized;
  }

  bool _isFilterEmpty(ItemFilterModel filter) {
    final bool hasPrice =
        (filter.minPrice?.isNotEmpty ?? false) || (filter.maxPrice?.isNotEmpty ?? false);
    final bool hasLocation =
        (filter.city?.isNotEmpty ?? false) || (filter.state?.isNotEmpty ?? false);
    final bool hasRecency = filter.postedSince?.isNotEmpty ?? false;
    final bool hasCurrency = filter.currency?.isNotEmpty ?? false;
    final bool hasArea =
        (filter.area?.isNotEmpty ?? false) || filter.areaId != null || filter.radius != null;
    final bool hasCoords = filter.latitude != null || filter.longitude != null;
    final bool hasCustomFields =
        filter.customFields != null && filter.customFields!.isNotEmpty;

    return !(hasPrice || hasLocation || hasRecency || hasCurrency || hasArea || hasCoords || hasCustomFields);
  }

  void _handleSortChanged(String sort) {
    setState(() {
      _currentSort = sort;
    });
    _fetchItems();
  }

  void _switchCategory(CategoryModel category) {
    final String? selectedId = category.id?.toString();
    if (selectedId == null || selectedId.isEmpty) return;
    if (selectedId == _activeCategoryId) return;

    setState(() {
      _activeCategoryId = selectedId;
      _activeCategoryName = category.name ?? _activeCategoryName;
      _currentFilter = null;
      Constant.itemFilter = null;
      _currentSort = null;
    });

    _fetchItems();
  }

  void _clearFilters() {
    setState(() {
      _currentFilter = null;
      Constant.itemFilter = null;
    });
    _fetchItems();
  }

  void _toggleLayout() {
    setState(() {
      _isGridMode = !_isGridMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion(
      value: UiUtils.getSystemUiOverlayStyle(
        context: context,
        statusBarColor: context.color.secondaryColor,
      ),
      child: PopScope(
        canPop: true,
        onPopInvoked: (_) => Constant.itemFilter = null,
        child: Scaffold(
          backgroundColor: context.color.primaryColor,
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildPinnedHeader(context),
                Expanded(
                  child: BlocBuilder<FetchItemFromCategoryCubit,
                      FetchItemFromCategoryState>(
                    builder: (context, state) {
                      return RefreshIndicator(
                        color: context.color.territoryColor,
                        onRefresh: _onRefresh,
                        child: _buildBodyForState(context, state),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPinnedHeader(BuildContext context) {
    final ColorScheme palette = context.color;

    final TextTheme textTheme = Theme.of(context).textTheme;

    return Container(
      color: palette.secondaryColor,
      padding: const EdgeInsetsDirectional.only(
        start: 16,
        end: 16,
        top: 12,
        bottom: 12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildBackButton(context),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _activeCategoryName.isEmpty
                      ? widget.categoryName
                      : _activeCategoryName,
                  style: textTheme.titleMedium?.copyWith(
                    color: palette.textDefaultColor,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                onPressed: _toggleLayout,
                tooltip: _isGridMode ? 'List view' : 'Grid view',
                icon: Icon(
                  _isGridMode ? Icons.view_list_rounded : Icons.grid_view_rounded,
                  color: palette.textSecondaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildSearchField(context),
          const SizedBox(height: 16),
          _buildStoriesBar(context),
          const SizedBox(height: 16),
          FilterSortBar(
            categoryIds: widget.categoryIds,
            categoryId: _activeCategoryId,
            searchController: _searchController,
            onFilterChanged: _applyFilter,
            onSortChanged: _handleSortChanged,
            showMapButton: false,
            currentFilter: _currentFilter,
            currentSort: _currentSort,
            currentCategoryList: _resolveCurrentCategoryList(context),
          ),
          if (_hasActiveFilters)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildActiveFilterChips(context)),
                  TextButton(
                    onPressed: _clearFilters,
                    child: Text('reset'.translate(context)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchField(BuildContext context) {
    final ColorSchemeExt palette = context.color;
    return Container(
      decoration: BoxDecoration(
        color: palette.primaryColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'searchHintLbl'.translate(context),
                border: InputBorder.none,
              ),
            ),
          ),
          if (_searchController.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                setState(() {
                  _searchController.clear();
                  _lastSubmittedQuery = '';
                });
                _fetchItems();
              },
              child: Icon(
                Icons.close_rounded,
                color: palette.textSecondaryColor,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStoriesBar(BuildContext context) {
    return SizedBox(
      height: 96,
      child: BlocBuilder<FetchCategoryCubit, FetchCategoryState>(
        builder: (context, state) {
          if (state is! FetchCategorySuccess) {
            return ListView.separated(
              padding: const EdgeInsetsDirectional.only(start: 4, end: 4),
              scrollDirection: Axis.horizontal,
              itemBuilder: (_, __) => _buildCategoryShimmer(),
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemCount: 6,
            );
          }

          final List<CategoryModel> categories = state.categories
              .where((CategoryModel category) =>
              widget.categoryIds.contains(category.id?.toString() ?? ''))
              .toList();

          if (categories.isEmpty) {
            return ListView.separated(
              padding: const EdgeInsetsDirectional.only(start: 4, end: 4),
              scrollDirection: Axis.horizontal,
              itemBuilder: (context, index) {
                final String fallbackId = widget.categoryIds
                    .elementAt(index % widget.categoryIds.length);
                return _buildStoryChip(
                  context,
                  CategoryModel(
                    id: int.tryParse(fallbackId),
                    name: fallbackId,
                  ),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemCount: widget.categoryIds.length,
            );
          }

          return ListView.separated(
            padding: const EdgeInsetsDirectional.only(start: 4, end: 4),
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              return _buildStoryChip(context, categories[index]);
            },
          );
        },
      ),
    );
  }

  Widget _buildBackButton(BuildContext context) {
    final ColorScheme palette = context.color;
    final TextDirection direction = Directionality.of(context);
    final IconData icon =
    direction == TextDirection.rtl ? Icons.arrow_forward_ios_rounded : Icons.arrow_back_ios_new_rounded;

    return InkWell(
      onTap: () => Navigator.of(context).maybePop(),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 40,
        width: 40,
        decoration: BoxDecoration(
          color: palette.primaryColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: palette.textDefaultColor,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildCategoryShimmer() {
    return Column(
      children: const [
        CustomShimmer(
          height: 64,
          width: 64,
          borderRadius: 32,
        ),
        SizedBox(height: 8),
        CustomShimmer(
          height: 12,
          width: 48,
          borderRadius: 12,
        ),
      ],
    );
  }

  Widget _buildStoryChip(BuildContext context, CategoryModel category) {
    final ColorScheme palette = context.color;
    final bool isSelected = category.id?.toString() == _activeCategoryId;
    final String displayName = category.name ?? '';


    final String? imageUrl = category.url?.trim();
    final bool hasValidImage = imageUrl != null && imageUrl.isNotEmpty;

    final Widget fallbackAvatar = Container(
      color: palette.primaryColor,
      alignment: Alignment.center,
      child: Icon(
        Icons.category_rounded,
        color: palette.textSecondaryColor,
      ),
    );


    return GestureDetector(
      onTap: () => _switchCategory(category),
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 66,
            width: 66,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: isSelected
                  ? LinearGradient(
                colors: [
                  palette.territoryColor,
                  palette.borderColor.withOpacity(0.6),
                ],
              )
                  : null,
              border: Border.all(
                color: isSelected
                    ? Colors.transparent
                    : palette.borderColor.withOpacity(0.6),
                width: 1.4,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: ClipOval(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    fallbackAvatar,
                    if (hasValidImage)
                      UiUtils.getImage(
                        imageUrl!,
                        fit: BoxFit.cover,
                        height: 56,
                        width: 56,
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 70,
            child: Text(
              displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: isSelected
                    ? palette.textDefaultColor
                    : palette.textSecondaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<CategoryModel>? _resolveCurrentCategoryList(BuildContext context) {
    final FetchCategoryState state = context.read<FetchCategoryCubit>().state;
    if (state is! FetchCategorySuccess) return null;
    return state.categories
        .where((CategoryModel category) =>
        widget.categoryIds.contains(category.id?.toString() ?? ''))
        .toList();
  }

  bool get _hasActiveFilters {
    final ItemFilterModel? filter = _currentFilter;
    if (filter == null) return false;
    final bool hasPrice =
        (filter.minPrice?.isNotEmpty ?? false) || (filter.maxPrice?.isNotEmpty ?? false);
    final bool hasRecency = filter.postedSince?.isNotEmpty ?? false;
    final bool hasCurrency = filter.currency?.isNotEmpty ?? false;
    final bool hasLocation =
        (filter.city?.isNotEmpty ?? false) || (filter.state?.isNotEmpty ?? false);
    final bool hasArea = filter.areaId != null || filter.radius != null;
    final bool hasCustomFields =
        filter.customFields != null && filter.customFields!.isNotEmpty;

    return hasPrice || hasRecency || hasCurrency || hasLocation || hasArea || hasCustomFields;
  }

  Widget _buildActiveFilterChips(BuildContext context) {
    final ItemFilterModel? filter = _currentFilter;
    if (filter == null) {
      return const SizedBox.shrink();
    }

    final List<_FilterDescriptor> descriptors = [];

    if (filter.minPrice?.isNotEmpty ?? false) {
      descriptors.add(_FilterDescriptor(
        label: '${'minLbl'.translate(context)}: ${filter.minPrice}',
        onRemove: () => _removeFilterValue(_FilterKey.minPrice),
      ));
    }
    if (filter.maxPrice?.isNotEmpty ?? false) {
      descriptors.add(_FilterDescriptor(
        label: '${'maxLbl'.translate(context)}: ${filter.maxPrice}',
        onRemove: () => _removeFilterValue(_FilterKey.maxPrice),
      ));
    }
    if (filter.currency?.isNotEmpty ?? false) {
      descriptors.add(_FilterDescriptor(
        label: 'Currency: ${filter.currency}',
        onRemove: () => _removeFilterValue(_FilterKey.currency),
      ));
    }
    if (filter.postedSince?.isNotEmpty ?? false) {
      descriptors.add(_FilterDescriptor(
        label: '${'postedSinceLbl'.translate(context)}: ${filter.postedSince}',
        onRemove: () => _removeFilterValue(_FilterKey.postedSince),
      ));
    }
    if (filter.city?.isNotEmpty ?? false) {
      descriptors.add(_FilterDescriptor(
        label: '${'city'.translate(context)}: ${filter.city}',
        onRemove: () => _removeFilterValue(_FilterKey.city),
      ));
    }
    if (filter.state?.isNotEmpty ?? false) {
      descriptors.add(_FilterDescriptor(
        label: '${'state'.translate(context)}: ${filter.state}',
        onRemove: () => _removeFilterValue(_FilterKey.state),
      ));
    }
    if (filter.areaId != null || (filter.area?.isNotEmpty ?? false)) {
      descriptors.add(_FilterDescriptor(
        label: 'area'.translate(context),
        onRemove: () => _removeFilterValue(_FilterKey.area),
      ));
    }
    if (filter.radius != null) {
      descriptors.add(_FilterDescriptor(
        label: '${UiUtils.getTranslatedLabel(context, 'radius')}: ${filter.radius}km',
        onRemove: () => _removeFilterValue(_FilterKey.radius),
      ));
    }
    if (filter.customFields != null && filter.customFields!.isNotEmpty) {
      filter.customFields!.forEach((String key, dynamic value) {
        descriptors.add(_FilterDescriptor(
          label: '${_resolveCustomFieldLabel(key)}: ${value.toString()}',
          onRemove: () => _removeCustomField(key),
        ));
      });
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: descriptors
          .map((descriptor) => InputChip(
        label: Text(descriptor.label),
        onDeleted: descriptor.onRemove,
      ))
          .toList(),
    );
  }

  String _resolveCustomFieldLabel(String key) {
    if (key.startsWith('custom_fields[')) {
      final int closingIndex = key.indexOf(']');
      if (closingIndex != -1) {
        return key.substring(13, closingIndex);
      }
    }
    return key;
  }

  void _removeFilterValue(_FilterKey key) {
    final ItemFilterModel? filter = _currentFilter;
    if (filter == null) return;

    final ItemFilterModel cleared = ItemFilterModel(
      categoryId: _activeCategoryId,
      minPrice: key == _FilterKey.minPrice ? null : filter.minPrice,
      maxPrice: key == _FilterKey.maxPrice ? null : filter.maxPrice,
      postedSince: key == _FilterKey.postedSince ? null : filter.postedSince,
      city: key == _FilterKey.city ? null : filter.city,
      state: key == _FilterKey.state ? null : filter.state,
      country: filter.country,
      area: key == _FilterKey.area ? null : filter.area,
      areaId: key == _FilterKey.area ? null : filter.areaId,
      radius: key == _FilterKey.radius ? null : filter.radius,
      latitude: key == _FilterKey.area ? null : filter.latitude,
      longitude: key == _FilterKey.area ? null : filter.longitude,
      currency: key == _FilterKey.currency ? null : filter.currency,
      customFields: filter.customFields != null
          ? Map<String, dynamic>.from(filter.customFields!)
          : null,
    );

    _applyFilter(_isFilterEmpty(cleared) ? null : cleared);
  }

  void _removeCustomField(String key) {
    final ItemFilterModel? filter = _currentFilter;
    if (filter == null || filter.customFields == null) return;

    final Map<String, dynamic> updated =
    Map<String, dynamic>.from(filter.customFields!);
    updated.remove(key);

    final ItemFilterModel rebuilt = ItemFilterModel(
      categoryId: _activeCategoryId,
      minPrice: filter.minPrice,
      maxPrice: filter.maxPrice,
      postedSince: filter.postedSince,
      city: filter.city,
      state: filter.state,
      country: filter.country,
      area: filter.area,
      areaId: filter.areaId,
      radius: filter.radius,
      latitude: filter.latitude,
      longitude: filter.longitude,
      currency: filter.currency,
      customFields: updated.isEmpty ? null : updated,
    );

    _applyFilter(_isFilterEmpty(rebuilt) ? null : rebuilt);
  }

  Widget _buildBodyForState(
      BuildContext context, FetchItemFromCategoryState state) {
    if (state is FetchItemFromCategoryInProgress ||
        state is FetchItemFromCategoryInitial) {
      return _buildLoadingView();
    }

    if (state is FetchItemFromCategoryFailure) {
      return _buildFailureView(state.errorMessage);
    }

    if (state is FetchItemFromCategorySuccess) {
      return _buildSuccessView(context, state);
    }

    return const SizedBox.shrink();
  }

  Widget _buildLoadingView() {
    return CustomScrollView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: SliderWidget(interfaceType: widget.interfaceType),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 14,
              childAspectRatio: 0.62,
            ),
            delegate: SliverChildBuilderDelegate(
                  (_, __) => _buildProductShimmerCard(),
              childCount: 8,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProductShimmerCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        CustomShimmer(height: 220, borderRadius: 18),
        SizedBox(height: 12),
        CustomShimmer(height: 14, width: 120, borderRadius: 8),
        SizedBox(height: 8),
        CustomShimmer(height: 12, width: 80, borderRadius: 8),
      ],
    );
  }

  Widget _buildFailureView(String message) {
    final String displayMessage = message.trim();


    return CustomScrollView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SomethingWentWrong(),
                if (displayMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    child: Text(
                      displayMessage,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                const SizedBox(height: 8),


                ElevatedButton(
                  onPressed: _fetchItems,
                  child: Text('retry'.translate(context)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessView(
      BuildContext context, FetchItemFromCategorySuccess state) {
    final List<ItemModel> items = state.itemSkeletons;

    return CustomScrollView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: SliderWidget(interfaceType: widget.interfaceType),
          ),
        ),
        if (items.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: NoDataFound(
                onTap: _fetchItems,
              ),
            ),
          )
        else ...[
          if (_isGridMode)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 18,
                  childAspectRatio: 0.58,
                ),
                delegate: SliverChildBuilderDelegate(
                      (context, index) {
                    final ItemModel item = items[index];
                    return ICard(
                      item: item,
                      bigCard: true,
                    );
                  },
                  childCount: items.length,
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                    (context, index) {
                  final ItemModel item = items[index];
                  return Padding(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ItemHorizontalCard(item: item),
                  );
                },
                childCount: items.length,
              ),
            ),
          if (state.isLoadingMore)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: SizedBox(
                    height: 32,
                    width: 32,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.6,
                      color: context.color.territoryColor,
                    ),
                  ),
                ),
              ),
            )
          else if (state.loadingMoreError)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    'somethingWentWrong'.translate(context),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

enum _FilterKey { minPrice, maxPrice, postedSince, city, state, area, radius, currency }

class _FilterDescriptor {
  final String label;
  final VoidCallback onRemove;

  _FilterDescriptor({required this.label, required this.onRemove});
}