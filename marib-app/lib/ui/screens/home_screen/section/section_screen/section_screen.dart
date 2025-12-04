import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marib/data/cubits/home/fetch_home_screen_cubit.dart';
import 'package:marib/data/cubits/item/fetch_item_summary_cubit.dart';
import 'package:marib/data/cubits/merchant/storefront_cubit.dart';
import 'package:marib/data/model/item_filter_model.dart';
import 'package:marib/data/model/merchant/storefront_model.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/constant.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:marib/utils/hive_utils.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:marib/data/cubits/slider_cubit.dart';

import 'package:marib/utils/ui_utils.dart';
import 'package:marib/ui/screens/widgets/animated_routes/blur_page_route.dart';

import 'widgets/filter_sort_bar/filter_sort_bar.dart';
import 'widgets/items_body_box.dart';
import 'widgets/storefront_header.dart';
import 'package:marib/utils/slider_interface_mapper.dart';
import 'package:marib/utils/featured_section_utils.dart';
import 'package:marib/utils/logger.dart';
import 'package:marib/utils/featured_ads_config.dart';
import 'package:marib/app/routes.dart';
import 'dart:convert';

class Section_screen extends StatefulWidget {
  final String categoryId; // ظ…ط¹ط±ظپ ط§ظ„ظپط¦ط© ط§ظ„ط­ط§ظ„ظٹط©
  final String categoryName; // ط§ط³ظ… ط§ظ„ظپط¦ط© ط§ظ„ط­ط§ظ„ظٹط©
  final List<String> categoryIds; // ظ‚ط§ط¦ظ…ط© ظ…ط¹ط±ظپط§طھ ط§ظ„ظپط¦ط§طھ
  final String? interfaceType;
  final int? sellerId;
  final String? storefrontId;
  final Map<String, dynamic>? storefrontSnapshot;
  final List<int>? sellerCategoryIds;

  const Section_screen({
    super.key,
    required this.categoryId,
    required this.categoryName,
    required this.categoryIds,
    this.interfaceType,
    this.sellerId,
    this.storefrontId,
    this.storefrontSnapshot,
    this.sellerCategoryIds,
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
    final int? sellerId = _parseSellerId(arguments?['sellerId']);
    final String? storefrontId = _parseStoreIdentifier(arguments?['storeId']);
    final Map<String, dynamic>? storefrontSnapshot =
        _parseStorefrontSnapshot(arguments?['storeSnapshot']);
    final List<int>? sellerCategoryIds =
        _parseSellerCategoryIds(arguments?['sellerCategoryIds']);
    return BlurredRouter(
      builder: (_) {
        final providers = <BlocProvider<dynamic>>[
          BlocProvider<FetchHomeScreenCubit>(
            create: (context) =>
                FetchHomeScreenCubit(defaultInterfaceType: interfaceType),
          ),
        ];

        if (storefrontId != null) {
          providers.add(
            BlocProvider<StorefrontCubit>(
              create: (context) => StorefrontCubit()..load(storefrontId),
            ),
          );
        }

        return MultiBlocProvider(
          providers: providers,
          child: Section_screen(
            categoryId: arguments?['catID'] as String,
            categoryName: arguments?['catName'],
            categoryIds: arguments?['categoryIds'],
            interfaceType: interfaceType,
            sellerId: sellerId,
            storefrontId: storefrontId,
            storefrontSnapshot: storefrontSnapshot,
            sellerCategoryIds: sellerCategoryIds,
          ),
        );
      },
    );
  }

  static int? _parseSellerId(dynamic raw) {
    if (raw == null) {
      return null;
    }
    if (raw is int) {
      return raw;
    }
    if (raw is String) {
      final String trimmed = raw.trim();
      if (trimmed.isEmpty) {
        return null;
      }
      return int.tryParse(trimmed);
    }
    return null;
  }

  static List<int>? _parseSellerCategoryIds(dynamic raw) {
    if (raw == null) {
      return null;
    }

    Iterable<dynamic>? iterable;
    if (raw is List) {
      iterable = raw;
    } else if (raw is String) {
      final String trimmed = raw.trim();
      if (trimmed.isEmpty) {
        return null;
      }
      try {
        final dynamic decoded = json.decode(trimmed);
        if (decoded is List) {
          iterable = decoded;
        }
      } catch (_) {
        iterable = trimmed.split(',');
      }
    }

    if (iterable == null) {
      return null;
    }

    final Set<int> result = <int>{};
    for (final dynamic entry in iterable) {
      if (entry == null) {
        continue;
      }
      if (entry is int) {
        if (entry > 0) {
          result.add(entry);
        }
        continue;
      }
      if (entry is num) {
        final int normalized = entry.toInt();
        if (normalized > 0) {
          result.add(normalized);
        }
        continue;
      }
      if (entry is String) {
        final int? parsed = int.tryParse(entry.trim());
        if (parsed != null && parsed > 0) {
          result.add(parsed);
        }
      }
    }

    if (result.isEmpty) {
      return null;
    }

    return result.toList(growable: false)..sort();
  }

  static String? _parseStoreIdentifier(dynamic raw) {
    if (raw == null) {
      return null;
    }

    if (raw is num) {
      final int value = raw.toInt();
      return value > 0 ? value.toString() : null;
    }

    if (raw is String) {
      final String trimmed = raw.trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    return null;
  }

  static Map<String, dynamic>? _parseStorefrontSnapshot(dynamic raw) {
    if (raw == null) {
      return null;
    }

    if (raw is Map<String, dynamic>) {
      return Map<String, dynamic>.from(raw);
    }

    if (raw is Map) {
      return raw.map(
        (key, value) => MapEntry(key.toString(), value),
      );
    }

    if (raw is String) {
      final String trimmed = raw.trim();
      if (trimmed.isEmpty) {
        return null;
      }
      try {
        final dynamic decoded = json.decode(trimmed);
        if (decoded is Map<String, dynamic>) {
          return Map<String, dynamic>.from(decoded);
        }
        if (decoded is Map) {
          return decoded.map(
            (key, value) => MapEntry(key.toString(), value),
          );
        }
      } catch (_) {
        return null;
      }
    }

    return null;
  }
}

class Section_screenState extends State<Section_screen> {
  // =========================
  // ظ…طھط؛ظٹط±ط§طھ ط§ظ„ط­ط§ظ„ط© / ط§ظ„ط£ط¯ط§ط،
  // =========================

  static const double _kFilterSortBarVerticalPadding = 16.0;
  static const double _kFilterSortBarMinButtonHeight = 44.0;
  static const double _kFilterSortBarMaxButtonHeight = 52.0;
  static const double _kBottomBarMinimumSafeArea = 12.0;

  static const Duration _bottomBarAnimationDuration =
      Duration(milliseconds: 320);

  // âœ… طھط­ظˆظٹظ„ categoryId ظ…ط±ط© ظˆط§ط­ط¯ط©
  static const int _defaultCategoryId = 0;

  late final int _catId;
  bool _catIdUsedFallback = false;
  bool _hasLoggedFallbackFetch = false;

  // âœ… ط­ظ‚ظ„ ط§ظ„ط¨ط­ط« + ط¯ظٹط¨ط§ظˆظ†ط³
  final TextEditingController searchController = TextEditingController();
  List<int>? _sellerCategoryIds;
  StorefrontDetails? _snapshotStorefront;

  // âœ… طھط­ظ…ظٹظ„ ط§ظ„ظ…ط²ظٹط¯
  bool _isLoadingMore = false;

  // âœ… ط¥ط¸ظ‡ط§ط± shimmer
  bool showShimmer = true;
  int _sliderRefreshToken = 0;

  // âœ… ظپط±ط² ظˆظپظ„ط§طھط±
  String? sortBy;
  ItemFilterModel? filter;
  ItemFilterModel? _initialFilter;

  // âœ… طھط¨ظ„ظٹط؛ ط§ظ„ظپط¦ط© ط§ظ„ظ…ط®طھط§ط±ط©
  final ValueNotifier<int?> selectedCategoryId = ValueNotifier<int?>(0);

  // âœ… طھط­ظƒظ… ط¸ظ‡ظˆط± ط´ط±ظٹط· ط§ظ„طھطµظ†ظٹظپط§طھ ط§ظ„ط­ظ‚ظٹظ‚ظٹ
  bool _showSlider = false;

  // âœ… طھط­ظƒظ… ظپظٹ ط¸ظ‡ظˆط± ط´ط±ظٹط· ط§ظ„ظپظ„طھط±ط©/ط§ظ„ظپط±ط² ط§ظ„ط³ظپظ„ظٹ ط­ط³ط¨ ط§ظ„طھظ…ط±ظٹط±
  final ValueNotifier<bool> _showBottomBar = ValueNotifier<bool>(true);

  // âœ… ظ„ط¥ط¬ط¨ط§ط± ط¥ط¸ظ‡ط§ط± ط§ظ„ط´ظٹظ…ط± ظپطھط±ط© ط¯ظ†ظٹط§ ط¨ط¹ط¯ ط£ظˆظ„ Loading
  bool _sawLoading = false;
  DateTime? _loadingStart;
  static const Duration _minShimmer = Duration(milliseconds: 350);
  static const Set<int> _featuredAdRootIds = <int>{
    Constant.realEstateRootCategoryId,
    Constant.sheinRootCategoryId,
    Constant.computerRootCategoryId,
    Constant.publicRootCategoryId,
  };
  FeaturedAdsConfig? _featuredAdsConfig;
  String? _featuredStyleOverride;
  String? _featuredOrderMode;

  late final String _sliderInterfaceType;

  late final bool _hasAdSlider;

  bool _showAdSlider = false;
  bool _requestedSlider = false;

  late final String? _requestSectionSlug;
  late final bool _enableFeaturedAds;
  bool get _hasStorefrontContext =>
      widget.storefrontId != null || widget.storefrontSnapshot != null;

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
    return normalized.toList(growable: false)..sort();
  }

  bool _areIntListsEqual(List<int>? a, List<int>? b) {
    if (identical(a, b)) {
      return true;
    }
    if (a == null || b == null) {
      return a == null && b == null;
    }
    if (a.length != b.length) {
      return false;
    }
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
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
    final int? sellerId = widget.sellerId;

    if (source == null) {
      return ItemFilterModel(
        categoryId: resolvedCategoryId,
        userId: sellerId,
      );
    }

    return source.copyWith(
      categoryId: resolvedCategoryId,
      userId: sellerId ?? source.userId,
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
    if (!_enableFeaturedAds) {
      return;
    }

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
          orderMode: _featuredOrderMode,
          styleKey: _featuredStyleOverride,
          rootCategoryId: effectiveRootId,
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
          perPage: FetchItemSummaryCubit.defaultPerPage,
        );
  }

  @override
  void initState() {
    super.initState();
    // =========================
    // ط¥ط¹ط¯ط§ط¯ ظ…ط¹ط±ظپ ط§ظ„ظپط¦ط© ط§ظ„ط£ط³ط§ط³ظٹ
    // =========================
    _catId = _parseInitialCategoryId(widget.categoryId);
    final String? normalizedInterfaceType =
        SliderInterfaceMapper.normalize(widget.interfaceType) ??
            widget.interfaceType?.trim();
    _featuredAdsConfig = FeaturedAdsConfigProvider.resolve(
      _catId,
      interfaceType: normalizedInterfaceType,
    );
    _featuredStyleOverride = _featuredAdsConfig?.styleOverride;
    _featuredOrderMode = _featuredAdsConfig?.orderMode;
    _enableFeaturedAds = _featuredAdsConfig?.enableFeaturedAds ??
        _featuredAdRootIds.contains(_catId);
    _sellerCategoryIds = _normalizeSellerCategoryIds(widget.sellerCategoryIds);
    _snapshotStorefront = _deriveSnapshotDetails(widget.storefrontSnapshot);

    // (ط§ط®طھظٹط§ط±ظٹ) ظ„ظˆ ظ‡ط°ظ‡ ط§ظ„ظ…طھط؛ظٹط±ط§طھ ط¹ظ†ط¯ظƒ ط£طµظ„ط§ظ‹ â€” ظˆط¥ظ„ط§ ط§ط­ط°ظپ ط§ظ„ط³ط·ظˆط± ط§ظ„ط«ظ„ط§ط«ط©:
    // searchbody = {};
    // selectedcategoryId = widget.categoryId;
    // selectedcategoryName = widget.categoryName;
    // searchbody[Api.categoryId] = widget.categoryId;

    // 2) ط§ظ„ط¬ظ„ط¨ ط§ظ„ط£ظˆظ„ظٹ ط¨ط¹ظˆط§ظ…ظ„ ط§ظ„ظ…ظˆظ‚ط¹
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
      userId: widget.sellerId,
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

    // ظ„ط¶ظ…ط§ظ† طھظˆظپط± ط§ظ„ط¨ظٹط§ظ†ط§طھ ظ‚ط¨ظ„ ط¨ظ†ط§ط، HomeTabView.
    if (_enableFeaturedAds) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _requestFeaturedSections(rootId: _catId);
      });
    }

    _sliderInterfaceType =
        (normalizedInterfaceType == null || normalizedInterfaceType.isEmpty)
            ? 'homepage'
            : normalizedInterfaceType;
    _hasAdSlider = (_featuredAdsConfig?.enableAdSlider ?? true) &&
        _sliderInterfaceType.isNotEmpty;
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

    // 3) ط­ط§ظ„ط© ط§ظ„ط¨ط¯ط§ظٹط©: ط§ط¹طھط¨ط± ط£ظ†ظ†ط§ ط³ظ†ط±ظ‰ Loading ط­ط§ظ„ظ‹ط§
    showShimmer = true;
    _showSlider = false;
    _showAdSlider = _hasAdSlider;
  }

  @override
  void didUpdateWidget(covariant Section_screen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_areIntListsEqual(
        oldWidget.sellerCategoryIds, widget.sellerCategoryIds)) {
      _sellerCategoryIds =
          _normalizeSellerCategoryIds(widget.sellerCategoryIds);
    }
    if (!mapEquals(oldWidget.storefrontSnapshot, widget.storefrontSnapshot)) {
      _snapshotStorefront = _deriveSnapshotDetails(widget.storefrontSnapshot);
    }
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
  // طھط­ظ…ظٹظ„ ظ„ط§ظ†ظ‡ط§ط¦ظٹ
  // =========================
  void _handleLoadMoreState(bool isLoading) {
    if (_isLoadingMore == isLoading) return;

    if (!mounted) {
      // ظٹط­ظ…ظٹ setState ظ…ظ† ط§ط³طھط¯ط¹ط§ط،ط§طھ onLoadMore ط§ظ„ظ…طھط£ط®ط±ط© ط¨ط¹ط¯ ط§ظ„طھط®ظ„طµ ظ…ظ† ط§ظ„ظˆط¯ط¬طھ.
      return;
    }

    setState(() => _isLoadingMore = isLoading);
  }

  // =========================
  // ط³ط­ط¨ ظ„ظ„طھط­ط¯ظٹط«
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
            perPage: FetchItemSummaryCubit.defaultPerPage,
          );

      // ط¥ط¹ط§ط¯ط© طھط­ظ…ظٹظ„ ط£ظ‚ط³ط§ظ… ط§ظ„ط¥ط¹ظ„ط§ظ†ط§طھ ط§ظ„ظ…ظ…ظٹط²ط© ط¹ظ†ط¯ ط§ظ„ط³ط­ط¨ ظ„ظ„طھط­ط¯ظٹط«
      if (_enableFeaturedAds) {
        _requestFeaturedSections(
          rootId: resolvedCategoryId,
        );
      }

      // (ط§ط®طھظٹط§ط±ظٹ)
      // Constant.itemFilter = null;
      // searchbody = {};
    } finally {
      if (mounted) {
        setState(() {
          final bool wasShimmering = showShimmer;
          showShimmer = false;
          if (wasShimmering) {
            _sliderRefreshToken++;
          }
        });
      }
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
              _showSlider = false; // ط§ط®ظپظگ ط´ط±ظٹط· ط§ظ„طھطµظ†ظٹظپط§طھ
              _showAdSlider =
                  _hasAdSlider; // ط­ط§ظپط¸ ط¹ظ„ظ‰ ط­ط§ظ„ط© ط§ظ„ط³ظ„ط§ظٹط¯ط± ط§ظ„ط¥ط¹ظ„ط§ظ†ظٹ
            });
            return;
          }

          if (state is FetchItemSummarySuccess) {
            debugPrint('[Realestate] state=Success');

            // ظپط±ط¶ ظ…ط¯ط© ط¯ظ†ظٹط§ ظ„ظ„ط´ظٹظ…ط±
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
              final bool wasShimmering = showShimmer;
              showShimmer = false;
              if (wasShimmering) {
                _sliderRefreshToken++;
              }
              _showSlider = true; // ط£ط¸ظ‡ط± ط§ظ„طھطµظ†ظٹظپط§طھ
              _showAdSlider =
                  _hasAdSlider; // ط£ط¸ظ‡ط± ط§ظ„ط³ظ„ط§ظٹط¯ط± ط§ظ„ط¥ط¹ظ„ط§ظ†ظٹ (ظٹط¨ط¯ط£ ط§ظ„ط¬ظ„ط¨ ط§ظ„ط¢ظ†)
            });

            _sawLoading = false;
            _loadingStart = null;
            return;
          }

          if (state is FetchItemSummaryFailure) {
            debugPrint('[Realestate] state=Failure');
            setState(() {
              final bool wasShimmering = showShimmer;
              showShimmer = false;
              if (wasShimmering) {
                _sliderRefreshToken++;
              }
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
                          builder: (context, _, __) {
                            final bool showMap = !{
                              Constant.computerRootCategoryId,
                              Constant.sheinRootCategoryId,
                              Constant.storeRootCategoryId,
                            }.contains(_catId);
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
                                      perPage:
                                          FetchItemSummaryCubit.defaultPerPage,
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
                                      perPage:
                                          FetchItemSummaryCubit.defaultPerPage,
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
                appBar: null, // AppBar ط¯ط§ط®ظ„ ItemsBodyBox
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
                                    sellerCategoryIds: _sellerCategoryIds,
                                    bottomContentPadding: bottomContentPadding,
                                    storefrontHeader: _buildStorefrontHeader(),

                                    showCartAction: showCartAction,
                                    onCartTap: onCartTap,

                                    selectedCategoryId: selectedCategoryId,
                                    showShimmer: showShimmer,
                                    sliderRefreshToken: _sliderRefreshToken,
                                    searchController: searchController,
                                    specialRequestSectionSlug:
                                        _requestSectionSlug,
                                    interfaceType: _sliderInterfaceType,
                                    enableTopBar: _showSlider,
                                    enableAdSlider: _hasStorefrontContext
                                        ? false
                                        : _showAdSlider,
                                    // ط¥ظ† ظƒط§ظ†طھ ظ…ظˆط¬ظˆط¯ط© ط¹ظ†ط¯ظƒ
                                    adInterfaceType: _sliderInterfaceType,
                                    // â†گ طھظ…ط±ظٹط± ط§ظ„ظˆط§ط¬ظ‡ط© ط§ظ„ظ…ط¹طھظ…ط¯ط© ط¯ط§ط¦ظ…ظ‹ط§
                                    sortBy: sortBy,
                                    // â†گ ط¬ط¯ظٹط¯
                                    filter: filter,
                                    // â†گ ط¬ط¯ظٹط¯
                                    enableSubcats: _showSlider,
                                    // â†گ ظ†ظپط³ ظ…ظ†ط·ظ‚ ط§ظ„طھط£ط¬ظٹظ„ (ط£ط¸ظ‡ط± ط¨ط¹ط¯ Success)
                                    onLoadMore: _handleLoadMoreState,
                                    onScrollDirectionChanged: (isScrollingUp) {
                                      if (_showBottomBar.value !=
                                          isScrollingUp) {
                                        _showBottomBar.value = isScrollingUp;
                                      }
                                    },
                                    enableFeaturedAds: _hasStorefrontContext
                                        ? false
                                        : _enableFeaturedAds,
                                    featuredStyleOverride:
                                        _featuredStyleOverride,
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

  Widget? _buildStorefrontHeader() {
    final String? storeIdentifier = widget.storefrontId;
    final StorefrontDetails? snapshot = _snapshotStorefront;

    if (storeIdentifier == null && snapshot == null) {
      return null;
    }

    if (storeIdentifier == null && snapshot != null) {
      return _buildStorefrontHeaderFromDetails(snapshot);
    }

    return BlocBuilder<StorefrontCubit, StorefrontState>(
      builder: (context, state) {
        if (state is StorefrontSuccess) {
          return _buildStorefrontHeaderFromDetails(state.details);
        }

        if (state is StorefrontFailure) {
          if (snapshot != null) {
            return _buildStorefrontHeaderFromDetails(snapshot);
          }
          return _StorefrontHeaderMessage(
            message: 'somethingWentWrong'.translate(context),
            onRetry: () =>
                context.read<StorefrontCubit>().load(storeIdentifier!),
          );
        }

        if (state is StorefrontLoading) {
          if (snapshot != null) {
            return _buildStorefrontHeaderFromDetails(snapshot);
          }
          return const _StorefrontHeaderPlaceholder();
        }

        if (snapshot != null) {
          return _buildStorefrontHeaderFromDetails(snapshot);
        }

        return const _StorefrontHeaderPlaceholder();
      },
    );
  }

  Widget _buildStorefrontHeaderFromDetails(StorefrontDetails details) {
    final StorefrontContact? contact = details.contact;
    final String? phone = contact?.phone;
    final String? whatsapp = contact?.whatsapp ?? contact?.phone;

    return MerchantStorefrontHeader(
      details: details,
      onCallTap: _hasContactValue(phone) ? () => _launchPhone(phone) : null,
      onWhatsappTap:
          _hasContactValue(whatsapp) ? () => _launchWhatsApp(whatsapp) : null,
      onDirectionsTap: details.location != null
          ? () => _launchDirections(details.location)
          : null,
      onFollowTap: () {
        HelperUtils.showSnackBarMessage(
          context,
          'storefrontFollowComingSoon'.translate(context),
        );
      },
    );
  }

  StorefrontDetails? _deriveSnapshotDetails(
    Map<String, dynamic>? snapshot,
  ) {
    if (snapshot == null) {
      return null;
    }
    try {
      return StorefrontDetails.fromSnapshot(snapshot);
    } catch (_) {
      return null;
    }
  }

  bool _hasContactValue(String? raw) {
    return raw?.trim().isNotEmpty == true;
  }

  Future<void> _launchPhone(String? raw) async {
    final String? normalized =
        _normalizeContactValue(raw, keepLeadingPlus: true);
    if (normalized == null) {
      _showContactError();
      return;
    }
    await _launchExternalUri(Uri.parse('tel:$normalized'));
  }

  Future<void> _launchWhatsApp(String? raw) async {
    final String? normalized =
        _normalizeContactValue(raw, keepLeadingPlus: false);
    if (normalized == null) {
      _showContactError();
      return;
    }
    await _launchExternalUri(Uri.parse('https://wa.me/$normalized'));
  }

  Future<void> _launchDirections(StorefrontLocation? location) async {
    if (location == null) {
      _showContactError();
      return;
    }
    String? query;
    if (location.latitude != null && location.longitude != null) {
      query = '${location.latitude},${location.longitude}';
    } else {
      query = location.primaryLine;
    }
    if (query == null || query.trim().isEmpty) {
      _showContactError();
      return;
    }
    final Uri uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}',
    );
    await _launchExternalUri(uri);
  }

  Future<void> _launchExternalUri(Uri? uri) async {
    if (!mounted || uri == null) {
      _showContactError();
      return;
    }
    try {
      final bool launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        _showContactError();
      }
    } catch (_) {
      _showContactError();
    }
  }

  String? _normalizeContactValue(
    String? raw, {
    required bool keepLeadingPlus,
  }) {
    final String trimmed = raw?.trim() ?? '';
    if (trimmed.isEmpty) {
      return null;
    }
    final String digits = trimmed.replaceAll(RegExp(r'[^0-9+]'), '');
    if (digits.isEmpty) {
      return null;
    }
    final String numbersOnly = digits.replaceAll('+', '');
    if (keepLeadingPlus && trimmed.startsWith('+')) {
      return '+$numbersOnly';
    }
    return numbersOnly;
  }

  void _showContactError() {
    if (!mounted) return;
    HelperUtils.showSnackBarMessage(
      context,
      'somethingWentWrong'.translate(context),
    );
  }
}

class _StorefrontHeaderPlaceholder extends StatelessWidget {
  const _StorefrontHeaderPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: const Center(
        child: SizedBox(
          height: 28,
          width: 28,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
      ),
    );
  }
}

class _StorefrontHeaderMessage extends StatelessWidget {
  const _StorefrontHeaderMessage({
    required this.message,
    this.onRetry,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: colors.errorContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Icon(
            Icons.storefront_rounded,
            color: colors.error,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.error,
              ),
            ),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              child: Text('retry'.translate(context)),
            ),
        ],
      ),
    );
  }
}
