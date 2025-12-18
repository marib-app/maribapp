// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flick_video_player/flick_video_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:marib/app/routes.dart';
import 'package:marib/data/constants/color_catalog.dart';
import 'package:marib/data/cubits/cart/cart_cubit.dart';

import 'package:marib/data/cubits/chat/delete_message_cubit.dart';
import 'package:marib/data/cubits/chat/load_chat_messages.dart';
import 'package:marib/data/cubits/chat/make_an_offer_item_cubit.dart';
import 'package:marib/data/cubits/chat/send_message.dart';
import 'package:marib/data/cubits/custom_field/fetch_custom_fields_cubit.dart';
import 'package:marib/data/cubits/favorite/favorite_cubit.dart';
import 'package:marib/data/cubits/favorite/manage_fav_cubit.dart';
import 'package:marib/data/cubits/item/change_my_items_status_cubit.dart';
import 'package:marib/data/cubits/item/create_featured_ad_cubit.dart';
import 'package:marib/data/cubits/item/delete_item_cubit.dart';
import 'package:marib/data/cubits/item/fetch_item_purchase_options_cubit.dart';
import 'package:marib/data/cubits/item/fetch_my_item_cubit.dart';
import 'package:marib/data/cubits/item/item_total_click_cubit.dart';
import 'package:marib/data/cubits/item/related_item_cubit.dart';
import 'package:marib/data/cubits/renew_item_cubit.dart';
import 'package:marib/data/cubits/report/fetch_item_report_reason_list.dart';
import 'package:marib/data/cubits/report/item_report_cubit.dart';
import 'package:marib/data/cubits/report/update_report_items_list_cubit.dart';
import 'package:marib/data/cubits/safety_tips_cubit.dart';
import 'package:marib/data/cubits/seller/fetch_seller_ratings_cubit.dart';
import 'package:marib/data/cubits/subscription/fetch_ads_listing_subscription_packages_cubit.dart';
import 'package:marib/data/cubits/subscription/fetch_user_package_limit_cubit.dart';
import 'package:marib/data/model/cart/cart_safety_tip.dart';
import 'package:marib/data/model/custom_field/custom_field_model.dart';
import 'package:marib/data/model/item/cart_model.dart';
import 'package:marib/data/model/item/item_model.dart';
import 'package:marib/data/model/item/purchase_options.dart';
import 'package:marib/data/model/report_item/reason_model.dart';
import 'package:marib/data/model/subscription_pacakage_model.dart';
import 'package:marib/data/repositories/favourites_repository.dart';
import 'package:marib/data/repositories/item/item_purchase_options_repository.dart';
import 'package:marib/data/repositories/item/item_repository.dart';
import 'package:marib/ui/screens/ad_banner_screen.dart';
import 'package:marib/ui/screens/google_map_screen.dart';
import 'package:marib/ui/screens/home/widgets/grid_list_adapter.dart';
import 'package:marib/ui/screens/home_screen/home_screen.dart';
import 'package:marib/ui/screens/item/add_item_screen/custom_filed_structure/custom_field.dart';
import 'package:marib/ui/screens/item/cards/sections_adapter.dart';
import 'package:marib/ui/screens/subscription/widget/featured_ads_subscription_plan_item.dart';
import 'package:marib/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:marib/ui/screens/widgets/blurred_dialoge_box.dart';
import 'package:marib/ui/screens/widgets/errors/no_data_found.dart';
import 'package:marib/ui/screens/widgets/errors/no_internet.dart';
import 'package:marib/ui/screens/widgets/errors/something_went_wrong.dart';
import 'package:marib/ui/screens/widgets/shimmerLoadingContainer.dart';
import 'package:marib/ui/screens/item/ad_details_screen/cart_tip_sheet_controller.dart';

import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/api.dart';
import 'package:marib/utils/app_icon.dart';
import 'package:marib/utils/app_telemetry.dart';
import 'package:marib/utils/cloudState/cloud_state.dart';
import 'package:marib/utils/color_palette_utils.dart';
import 'package:marib/utils/constant.dart';
import 'package:marib/utils/currency_utils.dart';
import 'package:marib/ui/screens/item/ad_details_screen/cart_tip_sheet.dart';
import 'package:marib/utils/delivery_department.dart';
import 'package:marib/utils/ecommerce_department.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/geo_rules.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:marib/utils/hive_utils.dart';
import 'package:marib/utils/item_category_ids.dart';
import 'package:marib/utils/responsiveSize.dart';
import 'package:marib/utils/slider_interface_mapper.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:marib/utils/validator.dart';
import 'package:marquee/marquee.dart';
import 'package:marib/ui/screens/widgets/video_view_screen.dart';
import 'package:meta/meta.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import 'AdImagesHeader.dart';
import 'AdInfoSection.dart';
import 'Custom_Fields_Widget.dart';
import 'Description.dart';
import 'Seller_Profile.dart';
import 'ad_custom_fields.dart';
import 'ad_image_source.dart';
import 'add_cart_sheet.dart';
import 'bottom_buttons.dart';
import 'fetch_item_details_cubit.dart'
    show
        FetchItemDetailsCubit,
        FetchItemDetailsFailure,
        FetchItemDetailsState,
        FetchItemDetailsSuccess,
        ItemDetailsRepository;
import 'map_preview_box.dart';
import 'owner_view.dart';

import 'widgets/attribute_selector_section.dart';
import 'widgets/color_attribute_selector.dart';
import 'widgets/delivery_size_display.dart';
import 'widgets/quantity_selector.dart';
import 'widgets/variant_stock_info.dart';

class _AdItemDetailsRepository implements ItemDetailsRepository {
  _AdItemDetailsRepository(this._itemRepository, {this.fallbackSlug});

  final ItemRepository _itemRepository;
  final String? fallbackSlug;

  @override
  Future<ItemModel> fetchById(int id) async {
    final result = await _itemRepository.fetchItemFromItemId(id);
    if (result.modelList.isNotEmpty) {
      return result.modelList.first;
    }

    if (fallbackSlug != null && fallbackSlug!.isNotEmpty) {
      final slugResult =
          await _itemRepository.fetchItemFromItemSlug(fallbackSlug!);
      if (slugResult.modelList.isNotEmpty) {
        return slugResult.modelList.first;
      }
    }

    throw Exception('item-not-found');
  }
}

const double sidePadding = 16;

class _ItemDetailsRepositoryImpl implements ItemDetailsRepository {
  _ItemDetailsRepositoryImpl(
    this._itemRepository, {
    required ItemModel? initialItem,
  }) : _initialItem = initialItem;

  final ItemRepository _itemRepository;
  final ItemModel? _initialItem;

  bool get _shouldUseOwnerEndpoint {
    final String? ownerId =
        _initialItem?.user?.id?.toString() ?? _initialItem?.userId?.toString();
    final String? myId = HiveUtils.getUserId();
    if (ownerId == null || myId == null) {
      return false;
    }
    return ownerId == myId;
  }

  bool get _hasInitialDetails {
    final ItemModel? item = _initialItem;
    if (item == null) {
      return false;
    }

    bool hasText(String? value) => value != null && value.isNotEmpty;

    return hasText(item.name) ||
        hasText(item.description) ||
        hasText(item.image) ||
        hasText(item.status) ||
        item.price != null;
  }

  @override
  Future<ItemModel> fetchById(int id) async {
    Object? lastError;

    if (_shouldUseOwnerEndpoint) {
      try {
        final result = await _itemRepository.fetchMyItemFromItemId(id);
        if (result.modelList.isNotEmpty) {
          return result.modelList.first;
        }
      } catch (error) {
        lastError = error;
      }
    }
    try {
      final result = await _itemRepository.fetchItemFromItemId(id);
      if (result.modelList.isNotEmpty) {
        return result.modelList.first;
      }
    } catch (error) {
      lastError = error;
    }

    if (_hasInitialDetails) {
      return _initialItem!;
    }

    if (lastError != null) {
      if (lastError is Exception) {
        throw lastError;
      }
      throw Exception(lastError.toString());
    }

    throw Exception('Item not found');
  }
}

class AdDetailsScreen extends StatefulWidget {
  final ItemModel model;
  final Object? initialSummary;

  const AdDetailsScreen({
    super.key,
    required this.model,
    this.initialSummary,
  });

  @override
  AdDetailsScreenState createState() => AdDetailsScreenState();

  static Route route(RouteSettings routeSettings) {
    final Map? arguments = routeSettings.arguments as Map?;
    final ItemModel initialModel = arguments?['model'] as ItemModel;

    final _AdDetailsRouteConfig config =
        _AdDetailsRouteConfig.from(routeSettings.arguments);

    return BlurredRouter(
      builder: (_) => MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) => FetchMyItemsCubit(),
          ),
          BlocProvider(
            create: (context) => ChangeMyItemStatusCubit(),
          ),
          BlocProvider(
            create: (context) => CreateFeaturedAdCubit(),
          ),
          BlocProvider(
            create: (context) => FetchItemReportReasonsListCubit(),
          ),
          BlocProvider(
            create: (context) => ItemReportCubit(),
          ),
          BlocProvider(
            create: (context) => MakeAnOfferItemCubit(),
          ),
          BlocProvider(
            create: (context) {
              late final ItemRepository repository;
              try {
                final providedRepository =
                    RepositoryProvider.of<ItemRepository>(
                  context,
                  listen: false,
                );
                repository = providedRepository;
              } on ProviderNotFoundException {
                repository = ItemRepository();
              } on TypeError {
                repository = ItemRepository();
              }

              return FetchItemDetailsCubit(
                _ItemDetailsRepositoryImpl(
                  repository,
                  initialItem: config.initialModel,
                ),
              );
            },
          ),
          BlocProvider(
            create: (context) =>
                FetchItemPurchaseOptionsCubit(ItemPurchaseOptionsRepository()),
          ),
        ],
        child: AdDetailsScreen(
          model: config.initialModel,
          initialSummary: config.initialSummary,
        ),
      ),
    );
  }
}

class _AdDetailsRouteConfig {
  _AdDetailsRouteConfig({
    required this.itemId,
    required this.initialModel,
    this.initialSummary,
  });

  final int itemId;
  final ItemModel initialModel;
  final Object? initialSummary;

  factory _AdDetailsRouteConfig.from(dynamic arguments) {
    ItemModel? initialModel;
    Object? initialSummary;
    int? itemId;

    void inspect(dynamic value) {
      if (value == null) {
        return;
      }

      if (value is ItemModel) {
        initialModel = value;
        itemId ??= value.id;
        return;
      }

      final ItemModel? summaryModel = _tryConvertSummaryToModel(value);
      if (summaryModel != null) {
        initialSummary ??= value;
        initialModel ??= summaryModel;
        itemId ??= summaryModel.id ?? _extractItemId(value);
        return;
      }

      final int? extractedId = _extractItemId(value);
      if (extractedId != null) {
        itemId ??= extractedId;
        return;
      }

      if (value is Map) {
        inspect(value['model']);
        inspect(value['summary']);
        inspect(value['itemSummary']);
        inspect(value['item']);
        inspect(value['itemId']);
        inspect(value['item_id']);
        inspect(value['id']);
      }
    }

    inspect(arguments);

    if (itemId == null) {
      throw ArgumentError('AdDetailsScreen expects an item id argument.');
    }

    if (initialModel == null) {
      initialModel = ItemModel(id: itemId);
    } else if (initialModel!.id != itemId) {
      initialModel = initialModel!.copyWith(id: itemId);
    }

    return _AdDetailsRouteConfig(
      itemId: itemId!,
      initialModel: initialModel!,
      initialSummary: initialSummary,
    );
  }
}

ItemModel? _tryConvertSummaryToModel(dynamic candidate) {
  try {
    final dynamic result = candidate.toItemModelSkeleton();
    if (result is ItemModel) {
      return result;
    }
  } catch (_) {
    // Ignored: object is not an ItemSummary instance.
  }
  return null;
}

int? _extractItemId(dynamic value) {
  if (value == null) {
    return null;
  }

  if (value is int) {
    return value;
  }

  if (value is String) {
    return int.tryParse(value);
  }

  if (value is ItemModel) {
    return value.id;
  }

  if (value is Map) {
    return _extractItemId(
      value['itemId'] ?? value['item_id'] ?? value['id'],
    );
  }

  try {
    final dynamic idValue = value.id;
    if (idValue is int) {
      return idValue;
    }
    if (idValue is String) {
      return int.tryParse(idValue);
    }
  } catch (_) {
    // Ignored: value does not expose an id getter.
  }

  return null;
}

class AdDetailsScreenState extends CloudState<AdDetailsScreen> {
  static const Set<String> _mapSupportedSections = <String>{
    'public_ads',
    'real_estate_services',
  };

  //ImageView
  int currentPage = 0;
  bool? isFeaturedLimit;
  List<String> selectedFeaturedAdsOptions = [];
  int currentIndex = 0;
  bool isFavorite = false;

  bool isShowReportAds = true;
  final PageController pageController = PageController();
  final List<String?> images = [];
  final List<AdImageSource> imageSources = [];
  final Completer<GoogleMapController> _controller =
      Completer<GoogleMapController>();
  late final ScrollController _pageScrollController = ScrollController();
  static const int _customReportReasonId = -10;

  List<ReportReason> _reportReasons = <ReportReason>[];

  late int selectedId;
  bool _reportReasonsInitialized = false;

  final TextEditingController _reportmessageController =
      TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey();
  final TextEditingController _makeAnOffermessageController =
      TextEditingController();
  final GlobalKey<FormState> _offerFormKey = GlobalKey();
  int? _selectedPackageIndex;
  List<CustomFieldBuilder> moreDetailDynamicFields = [];
  late ItemModel _currentItem;
  CartSafetyTipsPayload? _lastCartSafetyTips;
  ItemPurchaseOptions? _purchaseOptions;

  ItemModel? _initialSummaryModel;
  bool _initialSummaryModelResolved = false;

  bool _purchaseOptionsLoading = false;
  String? _purchaseOptionsError;
  Map<String, String> _selectedAttributes = <String, String>{};
  String? _selectedVariantKey;
  ItemVariantStockOption? _selectedVariantStock;
  int? _lastPurchaseOptionsItemId;
  int _selectedQuantity = 1;
  bool _isEcommerceItem = false;

  bool get isAddedByMe =>
      (_currentItem.user?.id != null
          ? _currentItem.user!.id.toString()
          : _currentItem.userId?.toString() ?? "") ==
      HiveUtils.getUserId();

  bool get _hasLocalItemDetails {
    final ItemModel item = _currentItem;
    bool hasText(String? value) => value != null && value.isNotEmpty;
    return hasText(item.name) ||
        hasText(item.description) ||
        hasText(item.image) ||
        hasText(item.status) ||
        item.price != null;
  }

  bool isFeaturedWidget = true;
  String youtubeVideoThumbnail = "";
  int? categoryId;
  FlickManager? flickManager;

  // Helper method to safely get model id
  int get safeModelId => _currentItem.id ?? 0;

  bool get _hasValidItemId => (_currentItem.id ?? widget.model.id ?? 0) > 0;

  bool _shouldHideQuantitySelectorForItem(ItemModel item) =>
      _supportsMapSectionForItem(item);

  // تبديل حالة الإعجاب + ربطها بكيوبيت المفضلة
  void _onToggleFavorite() {
    if (_currentItem.id == null) return;
    setState(() => isFavorite = !isFavorite);
  }

  Future<bool> _changeAdStatus(String newStatus) async {
    if (newStatus.trim().toLowerCase() == 'active') {
      throw ArgumentError(
        'استخدم تدفّق المراجعة قبل النشر بدلاً من استدعاء _changeAdStatus بحالة "active".',
      );
    }
    final cubit = context.read<ChangeMyItemStatusCubit>();
    final int? id = _currentItem.id ?? widget.model.id;
    if (id == null) {
      throw Exception('لا يمكن تغيير حالة إعلان بدون معرف صالح');
    }

    final int? userId = _currentItem.userId ?? widget.model.userId;
    await cubit.changeMyItemStatus(
      id: id,
      status: newStatus,
      userId: userId,
    );

    final ChangeMyItemStatusState statusState = cubit.state;
    if (statusState is ChangeMyItemStatusSuccess) {
      if (mounted) {
        setState(() {
          _currentItem.status = newStatus;
          if (newStatus == 'inactive') {
            _currentItem.active = false;
          } else if (newStatus == 'sold out') {
            _currentItem.active = false;
          } else if (newStatus == 'approved') {
            _currentItem.active = true;
          }
        });
      }
      return true;
    }
    if (statusState is ChangeMyItemStatusFailure) {
      throw Exception(statusState.errorMessage);
    }

    return false;
  }

  void _fetchCustomFieldsForCurrentItem() {
    final allCategoryIds = _currentItem.allCategoryIds;
    if (allCategoryIds != null && allCategoryIds.isNotEmpty) {
      context
          .read<FetchCustomFieldsCubit>()
          .fetchCustomFields(categoryIds: allCategoryIds);
    } else {
      final categoryIds = _currentItem.categoryId?.toString() ??
          _currentItem.category?.id?.toString() ??
          "1";
      context
          .read<FetchCustomFieldsCubit>()
          .fetchCustomFields(categoryIds: categoryIds);
    }
  }

  void _fetchPurchaseOptionsForCurrentItem({bool forceRefresh = false}) {
    final int? itemId = _currentItem.id ?? widget.model.id;
    if (itemId == null) {
      return;
    }

    if (!forceRefresh &&
        _lastPurchaseOptionsItemId == itemId &&
        _purchaseOptions != null) {
      return;
    }

    _lastPurchaseOptionsItemId = itemId;

    void updateState() {
      _purchaseOptionsLoading = true;
      if (forceRefresh) {
        _purchaseOptionsError = null;
      }
    }

    if (mounted) {
      setState(updateState);
    } else {
      updateState();
    }

    context
        .read<FetchItemPurchaseOptionsCubit>()
        .fetch(itemId: itemId, forceRefresh: forceRefresh);
  }

  void _handlePurchaseOptionsState(
    BuildContext context,
    FetchItemPurchaseOptionsState state,
  ) {
    if (state is FetchItemPurchaseOptionsInProgress) {
      void update() {
        _purchaseOptionsLoading = true;
        _purchaseOptionsError = null;
      }

      if (mounted) {
        setState(update);
      } else {
        update();
      }
      return;
    }

    if (state is FetchItemPurchaseOptionsSuccess) {
      _applyPurchaseOptions(state.options);
      return;
    }

    if (state is FetchItemPurchaseOptionsFailure) {
      void update() {
        _purchaseOptionsLoading = false;
        _purchaseOptionsError = state.message;
      }

      if (mounted) {
        setState(update);
      } else {
        update();
      }
    }
  }

  void _applyPurchaseOptions(ItemPurchaseOptions options) {
    final Map<String, String> sanitized = _sanitizeSelections(options);

    void update() {
      _purchaseOptions = options;
      _purchaseOptionsLoading = false;
      _purchaseOptionsError = null;
      _selectedAttributes = sanitized;
      _selectedVariantKey = _computeVariantKey(options, sanitized);
      _selectedVariantStock = _findVariantStock(_selectedVariantKey);
      _selectedQuantity = 1;
      _enforceQuantityConstraints();
      _currentItem = _currentItem.copyWith(
        price: options.basePrice,
        finalPrice: options.finalPrice,
        discount: options.discount ?? _currentItem.discount,
      );
    }

    if (mounted) {
      setState(update);
    } else {
      update();
    }
  }

  Map<String, String> _sanitizeSelections(
    ItemPurchaseOptions options, {
    Map<String, String>? seed,
  }) {
    final Map<String, String> source = seed != null
        ? Map<String, String>.from(seed)
        : Map<String, String>.from(_selectedAttributes);
    final Map<String, String> sanitized = <String, String>{};

    for (final ItemPurchaseAttributeOption attribute in options.attributes) {
      final List<String> allowed = attribute.allowedValues.isNotEmpty
          ? attribute.allowedValues
          : attribute.values;
      final String key = attribute.key;
      final String? rawValue = source[key]?.trim();

      if (rawValue != null &&
          rawValue.isNotEmpty &&
          (allowed.isEmpty || allowed.contains(rawValue))) {
        sanitized[key] = rawValue;
        continue;
      }

      final String? defaultValue = attribute.defaultValue?.trim();
      if (defaultValue != null &&
          defaultValue.isNotEmpty &&
          (allowed.isEmpty || allowed.contains(defaultValue))) {
        sanitized[key] = defaultValue;
        continue;
      }

      if (attribute.requiredForCheckout && allowed.isNotEmpty) {
        sanitized[key] = allowed.first;
      }
    }

    return sanitized;
  }

  String? _computeVariantKey(
    ItemPurchaseOptions options,
    Map<String, String> selections,
  ) {
    final bool hasVariantSpecificStock = options.variantStocks.any(
      (ItemVariantStockOption stock) {
        final String key = (stock.variantKey ?? '').trim();
        return key.isNotEmpty;
      },
    );

    if (!hasVariantSpecificStock) {
      return null;
    }

    final List<MapEntry<String, String>> affecting =
        <MapEntry<String, String>>[];

    for (final ItemPurchaseAttributeOption attribute in options.attributes) {
      if (!attribute.affectsStock) {
        continue;
      }

      final String? value = selections[attribute.key]?.trim();
      if (value != null && value.isNotEmpty) {
        affecting.add(MapEntry(attribute.key.trim(), value));
      }
    }

    if (affecting.isEmpty) {
      return null;
    }

    affecting.sort(
      (MapEntry<String, String> a, MapEntry<String, String> b) =>
          a.key.toLowerCase().compareTo(b.key.toLowerCase()),
    );

    return affecting
        .map(
          (MapEntry<String, String> entry) =>
              '${Uri.encodeComponent(entry.key)}=${Uri.encodeComponent(entry.value)}',
        )
        .join('|');
  }

  ItemVariantStockOption? _findVariantStock(String? variantKey) {
    final ItemPurchaseOptions? options = _purchaseOptions;
    if (options == null) {
      return null;
    }

    if (variantKey == null || variantKey.isEmpty) {
      for (final ItemVariantStockOption stock in options.variantStocks) {
        final String key = (stock.variantKey ?? '').trim();
        if (key.isEmpty) {
          return stock;
        }
      }
      if (options.variantStocks.length == 1) {
        return options.variantStocks.first;
      }
      return null;
    }

    for (final ItemVariantStockOption stock in options.variantStocks) {
      if (stock.variantKey == variantKey) {
        return stock;
      }
    }

    return null;
  }

  void _onAttributeSelectionChanged(String key, String? value) {
    final ItemPurchaseOptions? options = _purchaseOptions;
    if (options == null) {
      return;
    }

    final String normalizedKey = key.trim();
    final String? normalizedValue = value?.trim();
    final Map<String, String> nextSelections =
        Map<String, String>.from(_selectedAttributes);

    if (normalizedValue == null || normalizedValue.isEmpty) {
      nextSelections.remove(normalizedKey);
    } else {
      nextSelections[normalizedKey] = normalizedValue;
    }

    final Map<String, String> sanitized =
        _sanitizeSelections(options, seed: nextSelections);

    void update() {
      _selectedAttributes = sanitized;
      _selectedVariantKey = _computeVariantKey(options, sanitized);
      _selectedVariantStock = _findVariantStock(_selectedVariantKey);
      _enforceQuantityConstraints();
    }

    if (mounted) {
      setState(update);
    } else {
      update();
    }
  }

  void _enforceQuantityConstraints() {
    if (_selectedQuantity < 1) {
      _selectedQuantity = 1;
    }

    final int? limit = _selectedVariantStock?.availableStock;
    if (limit != null) {
      if (limit <= 0) {
        _selectedQuantity = 1;
      } else if (_selectedQuantity > limit) {
        _selectedQuantity = limit;
      }
    }
  }

  void _incrementQuantity() {
    final int? limit = _selectedVariantStock?.availableStock;
    if (limit != null) {
      if (limit <= 0) {
        _notifyQuantityRestriction(
          'This variant is out of stock.',
          color: Theme.of(context).colorScheme.error,
        );
        return;
      }
      if (_selectedQuantity >= limit) {
        _notifyQuantityRestriction(
          'No additional quantity available for this variant.',
          color: Theme.of(context).colorScheme.primary,
        );
        return;
      }
    }

    setState(() {
      _selectedQuantity += 1;
      _enforceQuantityConstraints();
    });
  }

  void _decrementQuantity() {
    if (_selectedQuantity <= 1) {
      return;
    }

    setState(() {
      _selectedQuantity -= 1;
      _enforceQuantityConstraints();
    });
  }

  int? _resolveSellerId(ItemModel item) {
    if (item.user?.id != null) {
      return item.user!.id!;
    }
    return item.userId;
  }

  String? _resolveSafetyTipsDepartment(ItemModel item) {
    final List<String?> candidates = <String?>[
      item.itemType,
      item.type,
      item.category?.description,
      item.category?.name,
    ];

    for (final String? candidate in candidates) {
      final String? normalized = normalizeDeliveryDepartment(candidate);
      if (normalized != null) {
        return normalized;
      }
    }

    final Set<int> categoryIds = <int>{};
    if (item.categoryId != null) {
      categoryIds.add(item.categoryId!);
    }
    if (item.category?.id != null) {
      categoryIds.add(item.category!.id!);
    }

    final String? allCategoryIds = item.allCategoryIds;
    if (allCategoryIds != null && allCategoryIds.isNotEmpty) {
      final Iterable<RegExpMatch> matches =
          RegExp(r'\d+').allMatches(allCategoryIds);
      for (final RegExpMatch match in matches) {
        final int? value = int.tryParse(match.group(0)!);
        if (value != null) {
          categoryIds.add(value);
        }
      }
    }

    final String? resolvedFromIds =
        resolveDeliveryDepartmentFromCategoryIds(categoryIds);
    if (resolvedFromIds != null) {
      return resolvedFromIds;
    }

    for (final String? candidate in candidates) {
      final String? sanitized = candidate?.trim();
      if (sanitized == null || sanitized.isEmpty) continue;
      final String? normalized = normalizeDeliveryDepartment(sanitized);
      if (normalized != null) {
        return normalized;
      }
    }

    return null;
  }

  void _fetchAuxiliaryDataForCurrentItem() {
    // customField();
    if (!isAddedByMe) {
      context.read<FetchItemReportReasonsListCubit>().fetch();
      final int? itemId = _currentItem.id;
      final String? department =
          itemId != null ? _resolveSafetyTipsDepartment(_currentItem) : null;
      if (itemId != null && department != null) {
        context.read<FetchSafetyTipsListCubit>().fetchSafetyTips(
              department: department,
              itemId: itemId,
            );
      }

      final sellerId = _resolveSellerId(_currentItem);
      if (sellerId != null && sellerId != 0) {
        context.read<FetchSellerRatingsCubit>().fetch(sellerId: sellerId);
      }
    } else {
      context.read<FetchAdsListingSubscriptionPackagesCubit>().fetchPackages();
    }
  }

  void _syncSelectedReportReason(List<ReportReason> reasons) {
    if (!mounted) {
      return;
    }

    final bool hasSelection =
        reasons.any((ReportReason reason) => reason.id == selectedId);
    int? newSelection;

    if (reasons.isEmpty) {
      if (selectedId != _customReportReasonId) {
        newSelection = _customReportReasonId;
      }
    } else if (!_reportReasonsInitialized) {
      newSelection = reasons.first.id;
    } else if (!hasSelection) {
      newSelection = reasons.first.id;
    }

    setState(() {
      _reportReasons = reasons;
      if (newSelection != null) {
        selectedId = newSelection;
      }
      _reportReasonsInitialized = true;
    });
  }

  // دالة النصائح new

  void _handleCartTipsUpdate(
      BuildContext context, CartSafetyTipsPayload? payload) {
    final bool hasContent = payload != null &&
        (payload.hasDisplayableContent || payload.isSheinDepartment);
    if (!hasContent) {
      _clearCartTipBanner(context);
      _lastCartSafetyTips = null;
      return;
    }

    if (identical(_lastCartSafetyTips, payload)) {
      return;
    }

    _lastCartSafetyTips = payload;

    _clearCartTipBanner(context);
    unawaited(_showCartTipBottomSheet(context, payload));
  }

  bool _isTipActionSupported(CartSafetyTipAction action) {
    if (action.isNavigate) {
      return action.navigatesToCart;
    }
    if (action.isOpenUrl) {
      final String? url = action.resolvedProductLink ?? action.target;
      return url != null && url.trim().isNotEmpty;
    }
    return false;
  }

  List<String> _resolveTipActionCommands(
    CartSafetyTipsPayload payload, {
    CartSafetyTip? tip,
  }) {
    final List<String> commands = <String>[];
    final Set<String> seen = <String>{};

    void addCommand(dynamic value) {
      if (value == null) {
        return;
      }
      if (value is String) {
        final String normalized = value.trim().toLowerCase();
        if (normalized.isEmpty) {
          return;
        }
        if (seen.add(normalized)) {
          commands.add(normalized);
        }
        return;
      }
      if (value is Iterable) {
        for (final dynamic entry in value) {
          addCommand(entry);
        }
      }
    }

    if (tip?.raw != null) {
      addCommand(tip!.raw!['actions']);
    }
    addCommand(payload.raw?['actions']);

    return commands;
  }

  Future<void> _showCartTipBottomSheet(
      BuildContext context, CartSafetyTipsPayload payload) async {
    final Map<String, CartAttributeLabel> attributeLabels =
        <String, CartAttributeLabel>{};
    final ItemPurchaseOptions? options = _purchaseOptions;
    if (options != null) {
      for (final ItemPurchaseAttributeOption attribute in options.attributes) {
        final String key = attribute.key.trim();
        if (key.isEmpty) continue;
        final String displayName =
            attribute.name.isNotEmpty ? attribute.name : key;
        final bool isColor = _isColorAttribute(attribute);
        attributeLabels[key.toLowerCase()] =
            CartAttributeLabel(label: displayName, isColor: isColor);
        attributeLabels[key] =
            CartAttributeLabel(label: displayName, isColor: isColor);
      }
    }

    final CartTipSheetController controller = CartTipSheetController(
      cartCubit: context.read<CartCubit>(),
      payload: payload,
      resolvedDepartmentSlug:
          (payload.departmentKey ?? _resolveSafetyTipsDepartment(_currentItem))
              ?.toLowerCase()
              .trim(),
      tip: payload.primaryTip,
      navigateAction: null,
      externalAction: null,
      attributeLabels: attributeLabels,
    );

    await controller.show(context);
  }

  void _clearCartTipBanner(BuildContext context) {
    final ScaffoldMessengerState? messenger =
        ScaffoldMessenger.maybeOf(context);
    messenger?.clearMaterialBanners();
  }

  Future<void> _handleCartTipAction(
      BuildContext context, CartSafetyTipAction action) async {
    if (!mounted) return;
    final CartCubit cubit = context.read<CartCubit>();

    try {
      _clearCartTipBanner(context);
      if (action.isNavigate && action.navigatesToCart) {
        await Navigator.of(context).pushNamed(Routes.cart);
      } else if (action.isOpenUrl) {
        final String? url = action.resolvedProductLink ?? action.target;
        if (url != null && url.trim().isNotEmpty) {
          final Uri? uri = Uri.tryParse(url);
          if (uri != null) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        }
      }
    } finally {
      if (mounted) {
        cubit.clearSafetyTips();
      }
    }
  }

  void _setCurrentItem(
    ItemModel item, {
    bool triggerDependentFetches = false,
    bool fromInit = false,
  }) {
    final previousCategoryId = categoryId;
    _currentItem = item;

    void updateState() {
      _isEcommerceItem = isEcommerceItem(_currentItem);
      categoryId = _currentItem.category?.id ?? _currentItem.categoryId;
      _purchaseOptions = null;
      _purchaseOptionsError = null;
      _purchaseOptionsLoading = false;
      _lastPurchaseOptionsItemId = null;
      combineImages();
      currentPage = 0;
      currentIndex = 0;
      _selectedQuantity = 1;
      _selectedAttributes = <String, String>{};
      _selectedVariantKey = null;
      _selectedVariantStock = null;
      if (pageController.hasClients) {
        pageController.jumpToPage(0);
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (pageController.hasClients) {
            pageController.jumpToPage(0);
          }
        });
      }
    }

    if (fromInit) {
      updateState();
    } else {
      if (mounted) {
        setState(updateState);
      } else {
        updateState();
      }
    }

    if (triggerDependentFetches) {
      _fetchCustomFieldsForCurrentItem();
      if (_isEcommerceItem) {
        _fetchPurchaseOptionsForCurrentItem(forceRefresh: true);
      }
      _fetchAuxiliaryDataForCurrentItem();
      setItemClick();
    }

    final shouldFetchRelated =
        triggerDependentFetches || previousCategoryId != categoryId;
    if (shouldFetchRelated) {
      final int? relatedCategoryId = _resolveRelatedCategoryId();
      if (relatedCategoryId != null) {
        context
            .read<FetchRelatedItemsCubit>()
            .fetchRelatedItems(categoryId: relatedCategoryId);
      }
    }
  }

  ItemModel? _resolveInitialSummaryModel() {
    if (_initialSummaryModelResolved) {
      return _initialSummaryModel;
    }
    _initialSummaryModelResolved = true;

    final Object? summary = widget.initialSummary;
    if (summary == null) {
      return _initialSummaryModel;
    }

    if (summary is ItemModel) {
      _initialSummaryModel = summary;
      return _initialSummaryModel;
    }

    final ItemModel? converted = _tryConvertSummaryToModel(summary);
    if (converted != null) {
      _initialSummaryModel = converted;
      return _initialSummaryModel;
    }

    if (summary is Map) {
      String? extractString(dynamic value) {
        if (value is String) {
          final String trimmed = value.trim();
          if (trimmed.isNotEmpty) {
            return trimmed;
          }
        }
        return null;
      }

      final Map<dynamic, dynamic> data = summary;
      final String? department = extractString(data['department']) ??
          extractString(data['department_slug']) ??
          extractString(data['section']) ??
          extractString(data['department_advertiser']);

      final String? itemType =
          extractString(data['item_type']) ?? extractString(data['itemType']);

      if (department != null || itemType != null) {
        _initialSummaryModel = ItemModel(
          departmentSlug: department,
          itemType: itemType,
        );
      }
    }

    return _initialSummaryModel;
  }

  bool _supportsMapSectionForItem(ItemModel item) {
    final List<int> categoryIds = buildItemCategoryIds(item);
    final bool belongsToForcedMapRoot = categoryIds.contains(
          Constant.realEstateRootCategoryId,
        ) ||
        categoryIds.contains(Constant.publicRootCategoryId);

    if (belongsToForcedMapRoot) {
      return true;
    }
    return _isMapSupportedInterface(item.departmentSlug) ||
        _isMapSupportedInterface(item.itemType);
  }

  @visibleForTesting
  bool supportsMapSectionForTesting(ItemModel item) =>
      _supportsMapSectionForItem(item);

  @visibleForTesting
  bool shouldHideQuantitySelectorForTesting(ItemModel item) =>
      _shouldHideQuantitySelectorForItem(item);

  bool _isMapSupportedInterface(String? value) {
    if (value == null) {
      return false;
    }

    final String? normalized = SliderInterfaceMapper.normalize(value);
    if (normalized == null || normalized.isEmpty) {
      return false;
    }

    return _mapSupportedSections.contains(normalized);
  }

  @override
  void initState() {
    super.initState();

    selectedId = _customReportReasonId;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final List<ReportReason>? reasons =
          context.read<FetchItemReportReasonsListCubit>().getList();
      if (reasons != null) {
        _syncSelectedReportReason(reasons);
      }
    });

    _setCurrentItem(
      widget.model,
      triggerDependentFetches: true,
      fromInit: true,
    );

    final itemId = _currentItem.id;
    if (itemId != null) {
      context.read<FetchItemDetailsCubit>().fetch(itemId);
    }

    pageController.addListener(() {
      if (!pageController.hasClients) {
        return;
      }

      final double? page = pageController.page;
      if (page == null) {
        return;
      }

      final int roundedPage = page.round();
      if (!mounted) {
        currentPage = roundedPage;
        return;
      }

      if (currentPage != roundedPage) {
        setState(() {
          currentPage = roundedPage;
        });
      }
    });

    _pageScrollController.addListener(_pageScroll);
  }

  void _pageScroll() {
    if (_pageScrollController.isEndReached()) {
      if (context.read<FetchRelatedItemsCubit>().hasMoreData()) {
        final int? relatedCategoryId = _resolveRelatedCategoryId();
        if (relatedCategoryId != null) {
          context
              .read<FetchRelatedItemsCubit>()
              .fetchRelatedItemsMore(categoryId: relatedCategoryId);
        }
      }
    }
  }

  int? _resolveRelatedCategoryId() {
    return categoryId ?? _currentItem.category?.id ?? _currentItem.categoryId;
  }

  CameraPosition get _kInitialPlace => CameraPosition(
        target: LatLng(
          _currentItem.latitude ?? 0,
          _currentItem.longitude ?? 0,
        ),
        zoom: 14.4746,
      );

  @override
  void dispose() {
    flickManager?.dispose();
    pageController.dispose();
    _pageScrollController.dispose();
    _reportmessageController.dispose();
    _makeAnOffermessageController.dispose();

    super.dispose();
  }

  void combineImages() {
    final item = _currentItem;
    final List<String?> combined = <String?>[];
    final List<AdImageSource> optimized = <AdImageSource>[];
    final Set<String> seenFallbacks = <String>{};

    String? sanitize(String? value) {
      if (value == null) {
        return null;
      }
      final String trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    void addImageVariant({String? detailUrl, String? fallbackUrl}) {
      final String? safeDetail = sanitize(detailUrl);
      final String? safeFallback = sanitize(fallbackUrl);
      if (safeDetail == null && safeFallback == null) {
        return;
      }

      final AdImageSource source = AdImageSource.from(
        detailUrl: safeDetail,
        fallbackUrl: safeFallback ?? safeDetail,
      );

      if (seenFallbacks.add(source.fallbackDisplayUrl)) {
        optimized.add(source);
        combined.add(source.displayUrl);
      }
    }

    addImageVariant(
      detailUrl: item.detailImageUrl,
      fallbackUrl: item.detailImageFallbackUrl ?? item.image,
    );

    if (item.galleryImages != null && item.galleryImages!.isNotEmpty) {
      for (final element in item.galleryImages!) {
        addImageVariant(
          detailUrl: element.detailImageUrl,
          fallbackUrl: element.detailImageFallbackUrl ?? element.image,
        );
      }
    }

    if (optimized.isEmpty && sanitize(item.image) != null) {
      addImageVariant(detailUrl: item.image, fallbackUrl: item.image);
    }

    imageSources
      ..clear()
      ..addAll(optimized);

    images
      ..clear()
      ..addAll(combined.isEmpty ? <String?>[item.image] : combined);

    youtubeVideoThumbnail = "";

    final videoLink = item.videoLink;
    if (videoLink != null && videoLink.isNotEmpty) {
      images.removeWhere((source) => source == videoLink);
      images.insert(0, videoLink);
    }

    flickManager?.dispose();
    flickManager = null;

    if (videoLink != null &&
        videoLink.isNotEmpty &&
        !HelperUtils.isYoutubeVideo(videoLink)) {
      flickManager = FlickManager(
        videoPlayerController: VideoPlayerController.networkUrl(
          Uri.parse(videoLink),
        ),
      );
      flickManager?.onVideoEnd = () {};
    }
    if (videoLink != null &&
        videoLink.isNotEmpty &&
        HelperUtils.isYoutubeVideo(videoLink)) {
      final String? videoId = YoutubePlayer.convertUrlToId(videoLink);
      if (videoId != null) {
        youtubeVideoThumbnail = YoutubePlayer.getThumbnail(videoId: videoId);
      }
    }
  }

  void _openVideoLink(String rawLink) {
    final String link = rawLink.trim();
    if (link.isEmpty) return;

    final FlickManager? manager =
        HelperUtils.isYoutubeVideo(link) ? null : flickManager;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VideoViewScreen(
          videoUrl: link,
          flickManager: manager,
        ),
      ),
    );
  }

  void setItemClick() {
    if (!isAddedByMe) {
      context.read<ItemTotalClickCubit>().itemTotalClick(safeModelId);
    }
  }

  Widget _buildPurchaseOptionsSection() {
    if (!_isEcommerceItem) {
      return const SizedBox.shrink();
    }

    final bool hideQuantitySelector =
        _shouldHideQuantitySelectorForItem(_currentItem);

    if (_purchaseOptionsLoading && _purchaseOptions == null) {
      return const SizedBox.shrink();
    }

    if (_purchaseOptionsError != null && _purchaseOptions == null) {
      final ThemeData theme = Theme.of(context);
      final ColorScheme colorScheme = theme.colorScheme;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.error.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: colorScheme.error.withOpacity(0.25), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.error_outline, color: colorScheme.error, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Unable to load purchase options for this item. Please refresh to try again.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.error,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colorScheme.error,
                    side: BorderSide(color: colorScheme.error.withOpacity(0.5)),
                  ),
                  onPressed: () =>
                      _fetchPurchaseOptionsForCurrentItem(forceRefresh: true),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final ItemPurchaseOptions? options = _purchaseOptions;
    if (options == null) {
      if (hideQuantitySelector) {
        return const SizedBox.shrink();
      }

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: _buildQuantitySelector(),
      );
    }

    final double? deliverySizePerUnit = options.deliverySize;
    final bool hasDeliverySize =
        deliverySizePerUnit != null && deliverySizePerUnit > 0;
    final double? deliverySizeTotal = hasDeliverySize
        ? (deliverySizePerUnit! * _selectedQuantity)
        : null;
    final String? deliverySizeText = deliverySizeTotal != null
        ? _formatDeliverySize(deliverySizeTotal)
        : null;
    final int? stockLimit = _selectedVariantStock?.availableStock;
    final bool isOutOfStock = stockLimit != null && stockLimit <= 0;
    final List<Widget> children = <Widget>[];

    if (_purchaseOptionsLoading) {
      children.add(const LinearProgressIndicator());
      children.add(const SizedBox(height: 12));
    }

    if (!hideQuantitySelector &&
        options.attributes.isNotEmpty &&
        !isOutOfStock) {
      children.add(
        Text(
          'Choose options',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
      );
      children.add(const SizedBox(height: 12));

      for (final ItemPurchaseAttributeOption attribute in options.attributes) {
        children.add(_buildAttributeSelector(attribute));
        children.add(const SizedBox(height: 12));
      }

      children.add(
        VariantStockInfo(
          availableStock: _selectedVariantStock?.availableStock,
          hasVariantStocks: options.variantStocks.isNotEmpty,
        ),
      );
    }

    if (!hideQuantitySelector) {
      if (children.isNotEmpty) {
        children.add(const SizedBox(height: 20));
      }
      if (isOutOfStock) {
        children.add(
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.error.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.error.withOpacity(0.25),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Theme.of(context).colorScheme.error,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Requested quantity is not available',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        children.add(_buildQuantitySelector());
        if (hasDeliverySize && deliverySizeText != null) {
          children.add(const SizedBox(height: 12));
          children.add(DeliverySizeDisplay(valueText: deliverySizeText));
        }
      }
    }

    if (children.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildAttributeSelector(ItemPurchaseAttributeOption attribute) {
    final List<String> values = attribute.allowedValues.isNotEmpty
        ? attribute.allowedValues
        : attribute.values;
    final bool isRequired = attribute.requiredForCheckout;
    final String? currentValueRaw = _selectedAttributes[attribute.key];

    if (values.isEmpty) {
      return AttributeSelectorSection(
        title: attribute.name,
        values: const <String>[],
        selectedValue: currentValueRaw ?? '',
        onValueSelected: (_) {},
        isRequired: isRequired,
      );
    }

    if (_isColorAttribute(attribute)) {
      return ColorAttributeSelectorSection(
        title: attribute.name,
        values: values,
        selectedValue: currentValueRaw,
        isRequired: isRequired,
        onValueSelected: (value) =>
            _onAttributeSelectionChanged(attribute.key, value),
      );
    }

    final String effectiveValue =
        currentValueRaw == null || (currentValueRaw.isEmpty && !isRequired)
            ? (isRequired && values.isNotEmpty ? values.first : '')
            : currentValueRaw;
    return AttributeSelectorSection(
      title: attribute.name,
      values: values,
      selectedValue: effectiveValue,
      isRequired: isRequired,
      showOptionalChoice: !isRequired,
      onValueSelected: (value) =>
          _onAttributeSelectionChanged(attribute.key, value),
    );
  }

  bool _isColorAttribute(ItemPurchaseAttributeOption attribute) {
    final String key = attribute.key.toLowerCase();
    final String? type = attribute.type?.toLowerCase();
    final String? uiType = attribute.uiType?.toLowerCase();

    if (type == 'color' || uiType == 'color') {
      return true;
    }

    if (key.contains('color') ||
        key.contains('colour') ||
        key.contains('لون')) {
      return true;
    }

    final String name = attribute.name.toLowerCase();
    if (name.contains('color') ||
        name.contains('colour') ||
        name.contains('لون')) {
      return true;
    }

    return false;
  }

  Widget _buildQuantitySelector() {
    final int? stockLimit = _selectedVariantStock?.availableStock;
    final bool isOutOfStock = stockLimit != null && stockLimit <= 0;
    final bool canIncrement;
    final bool canDecrement = _selectedQuantity > 1 && !isOutOfStock;
    if (stockLimit == null) {
      canIncrement = true;
    } else if (stockLimit <= 0) {
      canIncrement = false;
    } else {
      canIncrement = _selectedQuantity < stockLimit;
    }

    final int? remainingAfterSelection =
        stockLimit != null ? (stockLimit - _selectedQuantity) : null;
    return QuantitySelector(
      quantity: _selectedQuantity,
      onIncrement: _incrementQuantity,
      onDecrement: _decrementQuantity,
      onRestriction: _notifyQuantityRestriction,
      stockLimit: stockLimit,
      remainingAfterSelection: remainingAfterSelection,
      canIncrement: canIncrement,
      canDecrement: canDecrement,
      isOutOfStock: isOutOfStock,
    );
  }

  void _notifyQuantityRestriction(String message, {Color? color}) {
    if (!mounted) {
      return;
    }
    final ThemeData theme = Theme.of(context);
    UiUtils.showSoftSnackBar(
      context,
      message: message,
      backgroundColor: (color ?? theme.colorScheme.error),
      backgroundOpacity: 0.88,
      textColor: Colors.white,
    );
  }

  String? _formatDeliverySize(double? value) {
    if (value == null || value <= 0) {
      return null;
    }

    String formatted = value.toStringAsFixed(3);
    if (formatted.contains('.')) {
      formatted = formatted.replaceFirst(RegExp(r'0+$'), '');
      if (formatted.endsWith('.')) {
        formatted = formatted.substring(0, formatted.length - 1);
      }
    }

    final String unit =
        UiUtils.getTranslatedLabel(context, 'kilogramUnit').trim();
    return unit.isEmpty ? formatted : '$formatted $unit';
  }

  String _formatPrice(double value) {
    final String localeTag = UiUtils.resolveLocaleTag(context);
    final NumberFormat formatter = NumberFormat.currency(
      locale: localeTag,
      symbol: '',
      decimalDigits: 2,
    );
    final String formatted = formatter.format(value).trim();
    final String? currency = _currentItem.currency?.trim();
    if (currency == null || currency.isEmpty) {
      return formatted;
    }
    return '$formatted $currency';
  }

  Cart _buildCartItemForCurrentSelection({
    List<Map<String, dynamic>>? selectedCustomFields,
  }) {
    final ItemModel item = _currentItem;
    if (item.id == null) {
      throw CartBuildException('لا يمكن إضافة هذا المنتج إلى السلة حالياً.');
    }

    final ItemPurchaseOptions? options = _purchaseOptions;
    if (_purchaseOptionsLoading && options == null) {
      throw CartBuildException(
          'يتم تحميل خيارات المنتج، يرجى الانتظار قليلاً قبل الإضافة.');
    }

    final Map<String, String> selections = options != null
        ? _sanitizeSelections(options, seed: _selectedAttributes)
        : Map<String, String>.from(_selectedAttributes);

    if (options != null) {
      for (final ItemPurchaseAttributeOption attribute in options.attributes) {
        final String key = attribute.key;
        final String displayName =
            attribute.name.isNotEmpty ? attribute.name : key;
        final String value = selections[key]?.trim() ?? '';

        if (attribute.requiredForCheckout && value.isEmpty) {
          throw CartBuildException(
            'Please select "$displayName" before continuing.',
          );
        }
        if (attribute.affectsStock && options.variantStocks.isNotEmpty) {
          if (value.isEmpty) {
            throw CartBuildException(
              'Select "$displayName" to set stock for this variant.',
            );
          }
        }
      }
    }

    String? variantKey = options != null
        ? _computeVariantKey(options, selections)
        : _selectedVariantKey;

    final ItemVariantStockOption? stockOption =
        options != null ? _findVariantStock(variantKey) : _selectedVariantStock;
    if (stockOption != null && stockOption.availableStock <= 0) {
      throw CartBuildException('This variant is out of stock.');
    }

    if (variantKey != null &&
        options != null &&
        options.variantStocks.isNotEmpty &&
        stockOption == null) {
      throw CartBuildException('No matching variant stock was found.');
    }

    if (stockOption != null &&
        stockOption.availableStock > 0 &&
        _selectedQuantity > stockOption.availableStock) {
      throw CartBuildException(
          'الكمية المطلوبة تتجاوز المتاح للتوليفة الحالية.');
    }

    final double unitPrice =
        options?.finalPrice ?? item.finalPrice ?? item.price ?? 0.0;

    final Map<String, dynamic>? variantAttributes =
        selections.isEmpty ? null : Map<String, dynamic>.from(selections);

    final Map<String, dynamic>? stockSnapshot = stockOption != null
        ? <String, dynamic>{
            'variant_key': stockOption.variantKey,
            'stock': stockOption.stock,
            'reserved_stock': stockOption.reservedStock,
            'available_stock': stockOption.availableStock,
          }
        : null;

    final List<Map<String, dynamic>>? customFields =
        (selectedCustomFields == null || selectedCustomFields.isEmpty)
            ? null
            : selectedCustomFields;

    return Cart.fromItemModel(
      item,
      quantity: _selectedQuantity,
      selectedCustomFields: customFields,
      variantKey: variantKey,
      variantAttributes: variantAttributes,
      stockSnapshot: stockSnapshot,
      unitPrice: unitPrice,
      unitPriceLocked: unitPrice,
      currency: item.currency,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<FetchItemDetailsCubit, FetchItemDetailsState>(
          listener: (context, state) {
            if (state is FetchItemDetailsSuccess) {
              _setCurrentItem(
                state.item,
                triggerDependentFetches: true,
              );
            } else if (state is FetchItemDetailsFailure &&
                isAddedByMe &&
                _hasLocalItemDetails) {
              context.read<FetchItemDetailsCubit>().seed(_currentItem);
            }
          },
        ),
        BlocListener<FetchItemReportReasonsListCubit,
            FetchItemReportReasonsListState>(
          listener: (context, state) {
            if (state is FetchItemReportReasonsSuccess) {
              _syncSelectedReportReason(state.reasons);
            }
          },
        ),
        BlocListener<FetchItemPurchaseOptionsCubit,
            FetchItemPurchaseOptionsState>(
          listener: _handlePurchaseOptionsState,
        ),
      ],
      child: BlocBuilder<FetchItemDetailsCubit, FetchItemDetailsState>(
        builder: (context, state) {
          return _buildContentForState(context, state);
        },
      ),
    );
  }

  Widget _buildContentForState(
    BuildContext context,
    FetchItemDetailsState state,
  ) {
    final overlayStyle = SystemUiOverlayStyle(
      statusBarColor: context.color.secondaryDetailsColor,
    );
    final Widget scaffold = _buildScaffoldForState(context, state);

    return BlocListener<CartCubit, CartState>(
      listenWhen: (CartState previous, CartState current) =>
          previous.safetyTips != current.safetyTips,
      listener: (BuildContext listenerContext, CartState cartState) {
        _handleCartTipsUpdate(listenerContext, cartState.safetyTips);
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: overlayStyle,
        child: scaffold,
      ),
    );
  }

  Widget _buildScaffoldForState(
    BuildContext context,
    FetchItemDetailsState state,
  ) {
    final bool isOwner = isAddedByMe;
    final bool shouldShowLoadingLayout =
        _isEcommerceItem && _purchaseOptions == null && _purchaseOptionsLoading;

    if (state is FetchItemDetailsFailure) {
      return Scaffold(
        backgroundColor: context.color.secondaryDetailsColor,
        body: _FetchErrorView(
          message: state.message,
          onRetry: _hasValidItemId ? _retryFetchItemDetails : null,
        ),
      );
    }

    if (state is FetchItemDetailsSuccess && !shouldShowLoadingLayout) {
      return Scaffold(
        backgroundColor: context.color.secondaryDetailsColor,
        bottomNavigationBar: isOwner
            ? _buildOwnerBottomBar(context)
            : _buildPublicBottomBar(context),
        body: isOwner ? _buildOwnerBody(context) : _buildPublicBody(context),
      );
    }

    return Scaffold(
      backgroundColor: context.color.secondaryDetailsColor,
      bottomNavigationBar: _buildLoadingBottomBar(context, isOwner),
      body: _AdDetailsLoadingBody(isOwner: isOwner),
    );
  }

  String _buildSyntheticVariantSignature(
    Map<String, dynamic>? variantAttributes,
    List<Map<String, dynamic>>? customFields,
  ) {
    String normalize(dynamic value) {
      if (value is Map) {
        final entries = value.entries
            .map((e) => MapEntry(e.key.toString(), normalize(e.value)))
            .toList()
          ..sort((a, b) => a.key.compareTo(b.key));
        return jsonEncode({for (final e in entries) e.key: e.value});
      }
      if (value is List) return jsonEncode(value.map(normalize).toList());
      return value.toString();
    }

    final Map<String, dynamic> scf = <String, dynamic>{};
    for (final Map<String, dynamic> field
        in customFields ?? const <Map<String, dynamic>>[]) {
      final dynamic key =
          field['id'] ?? field['field_id'] ?? field['name'] ?? field['label'];
      if (key == null) continue;
      scf[key.toString()] = normalize(field['value'] ?? field['values']);
    }

    return '${normalize(variantAttributes ?? <String, dynamic>{})}|${normalize(scf)}';
  }

  int _stableHash(String input) {
    final int hash = input.hashCode & 0x7fffffff;
    return hash == 0 ? 1 : hash;
  }

  Widget _buildOwnerBottomBar(BuildContext context) {
    return MediaQuery.removePadding(
      context: context,
      removeLeft: true,
      removeRight: true,
      child: OwnerViewBar(
        model: _currentItem,
        isAddedByMe: isAddedByMe,
        moreDetailDynamicFields: moreDetailDynamicFields,
        onRenewPressed: () {},
        onUpdateFields: (newFields) =>
            setState(() => moreDetailDynamicFields = newFields),
        onPausePressed: () => _changeAdStatus('inactive'),
        onResumePressed: () => _changeAdStatus('approved'),
      ),
    );
  }

  Widget _buildPublicBottomBar(BuildContext context) {
    return MediaQuery.removePadding(
      context: context,
      removeLeft: true,
      removeRight: true,
      removeTop: true,
      removeBottom: false,
      child: bottomButtonWidget(
        context: context,
        model: _currentItem,
        isAddedByMe: isAddedByMe,
        onPausePressed: () => _changeAdStatus('inactive'),
        onResumePressed: () => _changeAdStatus('approved'),
        moreDetailDynamicFields: moreDetailDynamicFields,
        onRenewPressed: () {},

        // 👇 هذا الجديد
        onMakeOffer: () => makeOfferBottomSheet(_currentItem),

        cartBuilder: ({List<Map<String, dynamic>>? selectedCustomFields}) =>
            _buildCartItemForCurrentSelection(
          selectedCustomFields: selectedCustomFields,
        ),

        onUpdateFields: (newFields) {
          setState(() {
            moreDetailDynamicFields = newFields;
          });
        },
      ),
    );
  }

  Widget _buildOwnerBody(BuildContext context) {
    final bool supportsMapSection = _supportsMapSectionForItem(_currentItem);
    final bool hideLocation =
        supportsMapSection ? false : GeoRules.isDisabledForItem(_currentItem);

    return OwnerAdDetailsBody(
      model: _currentItem,
      images: images,
      imageSources: imageSources,
      pageController: pageController,
      currentIndex: currentIndex,
      onPageChanged: (i) => setState(() => currentIndex = i),
      isFavorite: isFavorite,
      onToggleFavorite: () async {
        await FavoriteRepository().manageFavorites(_currentItem.id ?? 0);
        setState(() => isFavorite = !isFavorite);
      },
      moreDetailDynamicFields: moreDetailDynamicFields,
      onRenewPressed: showPackageSelectBottomSheet,
      onOpenMap: () => _navigateToGoogleMapScreen(context),
      featuredSection: (_currentItem.isFeature != true)
          ? createFeaturesAds()
          : const SizedBox.shrink(),
      videoUrl: (_currentItem.videoLink ?? '').trim().isNotEmpty
          ? _currentItem.videoLink!.trim()
          : null,
      videoThumbnail:
          youtubeVideoThumbnail.isNotEmpty ? youtubeVideoThumbnail : null,
      onVideoTap: () {
        final String? link = _currentItem.videoLink?.trim();
        if (link != null && link.isNotEmpty) {
          _openVideoLink(link);
        }
      },
      hideLocation: hideLocation,
      supportsMapSection: supportsMapSection,
      addCloudDataFn: (k, v) => addCloudData(k, v),
    );
  }

  void _retryFetchItemDetails() {
    final int? id = _currentItem.id ?? widget.model.id;
    if (id != null && id > 0) {
      context.read<FetchItemDetailsCubit>().fetch(id, forceRefresh: true);
    }
  }

  Widget _buildLoadingBottomBar(BuildContext context, bool isOwner) {
    final theme = Theme.of(context);
    final shadowColor = Colors.black
        .withOpacity(theme.brightness == Brightness.dark ? 0.3 : 0.05);

    final decoration = BoxDecoration(
      color: context.color.secondaryDetailsColor,
      boxShadow: [
        BoxShadow(
          color: shadowColor,
          blurRadius: 16,
          offset: const Offset(0, -6),
        ),
      ],
    );

    final safeArea = SafeArea(
      top: false,
      left: false,
      right: false,
      bottom: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: isOwner
            ? Row(
                children: const [
                  Expanded(
                    child: CustomShimmer(
                      height: 48,
                      borderRadius: 14,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: CustomShimmer(
                      height: 48,
                      borderRadius: 14,
                    ),
                  ),
                ],
              )
            : const CustomShimmer(
                height: 48,
                borderRadius: 14,
              ),
      ),
    );

    final content = Container(
      decoration: decoration,
      child: safeArea,
    );

    if (isOwner) {
      return MediaQuery.removePadding(
        context: context,
        removeLeft: true,
        removeRight: true,
        child: content,
      );
    }
    return MediaQuery.removePadding(
      context: context,
      removeLeft: true,
      removeRight: true,
      removeTop: true,
      removeBottom: false,
      child: content,
    );
  }

  Widget _buildPublicBody(BuildContext context) {
    final item = _currentItem;
    final adInfo = AdInfoSection(
      context: context,
      model: item,
      isAddedByMe: false,
    );
    final bool supportsMapSection = _supportsMapSectionForItem(item);
    final bool hideLocation =
        supportsMapSection ? false : GeoRules.isDisabledForItem(item);

    final List<Widget> statusAlerts = _buildStatusAlerts(item);

    return CustomScrollView(
      slivers: [
        // =======================
        // 1️⃣ SliverAppBar للسلايدر
        // =======================
        // --- داخل build أو داخل headerSliverBuilder في AdDetailsScreenState --- //
        SliverAppBar(
          pinned: true,
          stretch: true,
          expandedHeight: MediaQuery.of(context).size.height * 0.40,
          backgroundColor: context.color.secondaryDetailsColor,
          flexibleSpace: FlexibleSpaceBar(
            background: AdImageHeader(
              // عرض السلايدر
              currentIndex: currentIndex,
              currentImageIndex: currentIndex,
              images: imageSources,
              pageController: pageController,
              onImagePageChanged: (i) => setState(() => currentIndex = i),
              videoUrl: (_currentItem.videoLink ?? '').trim().isNotEmpty
                  ? _currentItem.videoLink!.trim()
                  : null,
              videoThumbnail:
                  youtubeVideoThumbnail.isNotEmpty ? youtubeVideoThumbnail : null,
              onVideoTap: () {
                final String? link = _currentItem.videoLink?.trim();
                if (link != null && link.isNotEmpty) {
                  _openVideoLink(link);
                }
              },

              // حالة المفضلة (الإعجاب)
              isFavorite: isFavorite,
              onToggleFavorite: _onToggleFavorite,
              // 👈 دالة بالأسفل

              // تمرير الموديل والمعرّف الآمن
              model: item,
              isAddedByMe: isAddedByMe,
              safeModelId: (item.id ?? 0).toString(),
              modelId: (item.id ?? 0).toString(),

              // ✅ أزرار التراكب العلوي
              onShare: () {
                // مشاركة ذكية بالرابط/السلَج
                final slug = item.slug ?? "${item.id}";
                HelperUtils.share(context, slug, model: item);
              },
              onReport: () {
                final int? itemId = item.id ?? widget.model.id;
                if (itemId == null || itemId <= 0) {
                  HelperUtils.showSnackBarMessage(
                    context,
                    'لا يمكن الإبلاغ عن هذا الإعلان حالياً. حاول لاحقاً.',
                  );
                  return;
                }
                _bottomSheet(itemId);
              },

              // نفس دالتك الحالية

              // ✅ زر إعجاب احترافي متوافق مع الثيم

              likeButton: Builder(
                builder: (ctx) =>
                    favButton(item: item, size: 40), // دالتك كما هي
              ), // (اختياري) لو تحب تستعمل دوال الفتح المخصصة:
              // openShareSheet: (ctx) async => HelperUtils.share(ctx, model.slug ?? "${model.id}", model: model),
              // openReportDialog: (ctx) async => _bottomSheet(model.id!),
            ),
          ),
        ),

        // =========================
        // 2️⃣ باقي محتوى الإعلان
        // =========================
        SliverPadding(
          padding: const EdgeInsets.all(13.0),
          sliver: SliverList(
            delegate: SliverChildListDelegate(
              [
                // العنوان
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(item.name ?? "Unknown Item")
                      .size(context.font.large)
                      .setMaxLines(lines: 2)
                      .color(context.color.textDefaultColor),
                ),

                if (statusAlerts.isNotEmpty) ...<Widget>[
                  ...statusAlerts,
                  const SizedBox(height: 12),
                ],

                // السعر والحالة
                adInfo.priceAndStatus(),

                _buildPurchaseOptionsSection(),

                // العنوان والتاريخ (لو فيه عنوان)
                if (!hideLocation && item.address != null)
                  adInfo.titleAndDate(isDate: true),
                // الحقول المخصصة
                AdCustomFieldsSection(
                  fields: item.customFields ?? const <CustomFieldModel>[],
                ),
                Divider(
                  thickness: 1,
                  color: context.color.textDefaultColor.withOpacity(0.1),
                ),

                // الوصف
                AdDescriptionSection(description: item.description),

                Divider(
                  thickness: 1,
                  color: context.color.textDefaultColor.withOpacity(0.1),
                ),

                // بيانات البائع (للزائر فقط)
                if (!isAddedByMe && item.user != null)
                  setSellerDetails(context, item),

                // الخريطة (لو الإحداثيات متوفرة)
                if (!hideLocation &&
                    supportsMapSection &&
                    item.latitude != null &&
                    item.longitude != null)
                  MapPreviewBox(
                    latitude: item.latitude!,
                    longitude: item.longitude!,
                    isDarkMode: Theme.of(context).brightness == Brightness.dark,
                    addressWidget: AdInfoSection(
                      context: context,
                      model: item,
                      isAddedByMe: false,
                    ).titleAndDate(isDate: false),
                    onTap: () => _navigateToGoogleMapScreen(context),
                  ),

                if (_isEcommerceItem &&
                    (item.tips?.returnPolicyText?.trim().isNotEmpty ?? false))
                  Padding(
                    padding: const EdgeInsets.only(top: 18.0),
                    child: _buildReturnPolicyCard(
                      item.tips!.returnPolicyText!.trim(),
                    ),
                  ),

                const SizedBox(height: 8),

                // زر الإبلاغ
                if (!isAddedByMe) reportedAdsWidget(),

                const SizedBox(height: 8),

                // إعلانات مشابهة
                relatedAds(),

                // إعلان بنر (اختياري)
                if (Constant.isGoogleBannerAdsEnabled == "1") ...[
                  Divider(
                    thickness: 1,
                    color: context.color.textDefaultColor.withOpacity(0.1),
                  ),
                  Container(
                    alignment: AlignmentDirectional.center,
                    child: AdBannerWidget(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildStatusAlerts(ItemModel item) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final List<Widget> alerts = <Widget>[];

    void addAlert({
      required IconData icon,
      required Color color,
      required String message,
    }) {
      alerts.add(
        Padding(
          padding: EdgeInsets.only(top: alerts.isEmpty ? 0 : 6),
          child: _buildStatusAlertBanner(
            theme: theme,
            icon: icon,
            color: color,
            message: message,
          ),
        ),
      );
    }

    final String? normalizedStatus = item.status?.toLowerCase().trim();
    switch (normalizedStatus) {
      case 'sold out':
      case 'sold_out':
        addAlert(
          icon: Icons.do_not_disturb_alt_rounded,
          color: theme.colorScheme.error,
          message: 'تم بيع هذا المنتج بالكامل ولم يعد متاحاً للطلب.',
        );
        break;
      case 'inactive':
        addAlert(
          icon: Icons.pause_circle_outline,
          color: colorScheme.tertiary,
          message: 'الإعلان متوقف حالياً وقد لا تتوفر إمكانية الطلب حتى عودته.',
        );
        break;
      case 'review':
        addAlert(
          icon: Icons.search_rounded,
          color: colorScheme.primary,
          message: 'الإعلان قيد المراجعة من فريقنا وقد يتغير توفره قريباً.',
        );
        break;
      case 'rejected':
        addAlert(
          icon: Icons.report_gmailerrorred,
          color: theme.colorScheme.error,
          message: 'تم رفض هذا الإعلان ولا يمكن إكمال الطلب عليه حالياً.',
        );
        break;
      default:
        break;
    }

    if ((item.isPurchased ?? 0) == 1) {
      addAlert(
        icon: Icons.shopping_bag,
        color: colorScheme.secondary,
        message:
            'لقد قمت بشراء هذا المنتج مسبقاً. تحقق من الطلبات لمتابعة التفاصيل.',
      );
    }

    return alerts;
  }

  Widget _buildStatusAlertBanner({
    required ThemeData theme,
    required IconData icon,
    required Color color,
    required String message,
  }) {
    final Color background = color.withOpacity(
      theme.brightness == Brightness.dark ? 0.18 : 0.12,
    );

    return Semantics(
      container: true,
      label: 'تنبيه مهم: $message',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.4), width: 1),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReturnPolicyCard(String text) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final Color baseBackground = colorScheme.surfaceVariant;
    final Color background = baseBackground.withOpacity(
      theme.brightness == Brightness.dark ? 0.35 : 0.55,
    );

    return Semantics(
      container: true,
      label: 'سياسة الاسترجاع الخاصة بالقسم',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colorScheme.outline.withOpacity(0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.assignment_return, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'سياسة الاسترجاع',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color:
                    theme.textTheme.bodyMedium?.color ?? colorScheme.onSurface,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget reportedAdsWidget() {
    return BlocBuilder<UpdatedReportItemCubit, UpdatedReportItemState>(
      builder: (context, state) {
        bool isItemInCubit = context
            .read<UpdatedReportItemCubit>()
            .containsItem(_currentItem.id!);

        if (!isItemInCubit) {
          if (_currentItem.isAlreadyReported != null &&
              !_currentItem.isAlreadyReported!) {
            return setReportAd();
          } else {
            return SizedBox(); // Return an empty widget if conditions are not met
          }
        } else {
          return SizedBox(); // Return an empty widget if item is not in cubit
        }
      },
    );
  }

  Widget relatedAds() {
    return BlocBuilder<FetchRelatedItemsCubit, FetchRelatedItemsState>(
        builder: (context, state) {
      if (state is FetchRelatedItemsInProgress) {
        return relatedItemShimmer();
      }
      if (state is FetchRelatedItemsFailure) {
        if (state.errorMessage is ApiException) {
          if (state.errorMessage == "no-internet") {
            return NoInternet(
              onRetry: () {
                final int? relatedCategoryId = _resolveRelatedCategoryId();
                if (relatedCategoryId != null) {
                  context
                      .read<FetchRelatedItemsCubit>()
                      .fetchRelatedItems(categoryId: relatedCategoryId);
                }
              },
            );
          }
        }

        return const SomethingWentWrong();
      }

      if (state is FetchRelatedItemsSuccess) {
        if (state.itemSummaries.isEmpty || state.itemSummaries.length == 1) {
          return SizedBox.shrink();
        }

        return buildRelatedListWidget(state);
      }

      return const SizedBox.square();
    });
  }

  /// عرض قائمة الإعلانات المشابهة بطريقة محسنة (تجاهل الإعلان الحالي + عرض نظيف)
  Widget buildRelatedListWidget(FetchRelatedItemsSuccess state) {
    // ✅ تصفية العناصر: نحذف الإعلان الحالي من القائمة قبل البناء
    final relatedItems = state.itemSummaries
        .where((summary) => summary.id != _currentItem.id)
        .map((summary) => summary.toItemModelSkeleton())
        .toList();

    return Padding(
      padding: const EdgeInsets.only(top: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// 🏷️ العنوان "إعلانات مشابهة"
          Text("relatedAds".translate(context))
              .size(context.font.large)
              .bold(weight: FontWeight.w600)
              .setMaxLines(lines: 1),

          const SizedBox(height: 15),

          /// ✅ القائمة الأفقية للعناصر المرتبطة
          GridListAdapter(
            type: ListUiType.List,
            // عرض أفقي (كأنها ListView)
            height: MediaQuery.of(context).size.height / 3.5.rh(context),
            controller: _pageScrollController,
            listAxis: Axis.horizontal,
            listSaperator: (context, index) => const SizedBox(width: 14),
            isNotSidePadding: true,

            /// ✅ عرض البطاقات بدون إعلان مكرر
            builder: (context, index, _) {
              final item = relatedItems[index];
              return ICard(item: item, width: 162);
            },

            total: relatedItems.length, // ✅ عدد العناصر بعد التصفية
          ),
        ],
      ),
    );
  }

  /// 🎯 ويدجت عرض تأثير التحميل (Shimmer) أثناء تحميل الإعلانات المشابهة
  Widget relatedItemShimmer({
    int itemCount = 5, // عدد العناصر الوهمية القابلة للتعديل
    double cardWidth = 162, // نفس عرض ItemCard الحقيقي
    double cardHeight = 220, // نفس ارتفاع البطاقة الفعلية
  }) {
    return Column(
      children: [
        const SizedBox(height: 10), // مسافة علوية قبل القائمة

        SizedBox(
          height: cardHeight, // ✅ ارتفاع البطاقة الحقيقي لتناسق الواجهة
          child: ListView.separated(
            itemCount: itemCount,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: sidePadding),

            /// ✅ إنشاء كل عنصر Shimmer (بطاقة وهمية)
            itemBuilder: (context, index) {
              return CustomShimmer(
                height: cardHeight,
                width: cardWidth,
                borderRadius: 12, // إن أردت جعل الحواف ناعمة مثل البطاقات
              );
            },

            /// ✅ فاصل موحد بين كل عنصر وآخر
            separatorBuilder: (context, index) => const SizedBox(width: 12),
          ),
        ),

        const SizedBox(height: 16), // مسافة سفلية بعد القائمة
      ],
    );
  }

  // الاعلانات المميزة

  Widget createFeaturesAds() {
    if (_currentItem.status == "active" || _currentItem.status == "approved") {
      return MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) => CreateFeaturedAdCubit(),
          ),
          BlocProvider(
            create: (context) => FetchUserPackageLimitCubit(),
          ),
        ],
        child: Builder(builder: (context) {
          return BlocListener<CreateFeaturedAdCubit, CreateFeaturedAdState>(
            listener: (context, state) {
              if (state is CreateFeaturedAdInSuccess) {
                context
                    .read<FetchUserPackageLimitCubit>()
                    .fetchUserPackageLimit(packageType: 'advertisement');

                HelperUtils.showSnackBarMessage(
                    context, state.responseMessage.toString(),
                    messageDuration: 3);

                Navigator.pop(context, "refresh");
              }
              if (state is CreateFeaturedAdFailure) {
                HelperUtils.showSnackBarMessage(context, state.error.toString(),
                    messageDuration: 3);
              }
            },
            child: BlocListener<FetchUserPackageLimitCubit,
                FetchUserPackageLimitState>(
              listener: (context, state) async {
                if (state is FetchUserPackageLimitFailure) {
                  final rawMessage = (state.error ?? '').toString().trim();
                  if (HelperUtils.isConnectivityOrServerError(rawMessage)) {
                    final lowerCaseMessage = rawMessage.toLowerCase();
                    final message = rawMessage.isNotEmpty &&
                            !lowerCaseMessage
                                .contains('server-not-available') &&
                            !lowerCaseMessage.contains('server not available')
                        ? rawMessage
                        : "somethingWentWrong".translate(context);

                    HelperUtils.showSnackBarMessage(
                      context,
                      message,
                      type: MessageType.error,
                    );
                    return;
                  }

                  if (HelperUtils.isPackageLimitError(rawMessage)) {
                    UiUtils.noPackageAvailableDialog(context);
                    return;
                  }

                  final readableMessage =
                      HelperUtils.readableErrorMessage(context, rawMessage);

                  HelperUtils.showSnackBarMessage(
                    context,
                    readableMessage,
                    type: MessageType.error,
                  );
                  return;
                }
                if (state is FetchUserPackageLimitInSuccess) {
                  final summary = UiUtils.subscriptionLimitSummary(
                    context,
                    state.limit,
                  );
                  if (summary != null && summary.isNotEmpty) {
                    HelperUtils.showSnackBarMessage(
                      context,
                      summary,
                      messageDuration: 3,
                    );
                  }

                  if (state.canCreateListing) {
                    final confirmSummary = UiUtils.subscriptionLimitSummary(
                      context,
                      state.limit,
                      includeExpiry: false,
                    );
                    final expiryText =
                        UiUtils.subscriptionLimitExpiry(context, state.limit);
                    final allowedMessage = UiUtils.getTranslatedLabel(
                        context, 'subscriptionLimitActionAllowed');

                    await UiUtils.showBlurredDialoge(
                      context,
                      dialoge: BlurredDialogBox(
                        title: "createFeaturedAd".translate(context),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "areYouSureToCreateThisItemAsAFeaturedAd"
                                  .translate(context),
                            ),
                            if (allowedMessage.trim().isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  allowedMessage,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: context.color.territoryColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ),
                            if (confirmSummary != null &&
                                confirmSummary.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  confirmSummary,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                            if (expiryText != null && expiryText.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  expiryText,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withOpacity(0.7),
                                      ),
                                ),
                              ),
                          ],
                        ),
                        isAcceptContainesPush: true,
                        onAccept: () => Future.value().then((_) {
                          Future.delayed(
                            Duration.zero,
                            () {
                              context
                                  .read<CreateFeaturedAdCubit>()
                                  .createFeaturedAds(
                                    itemId: _currentItem.id!,
                                  );
                              Navigator.pop(context);
                              return;
                            },
                          );
                        }),
                      ),
                    );
                  } else {
                    if (state.responseMessage.isNotEmpty) {
                      HelperUtils.showSnackBarMessage(
                        context,
                        state.responseMessage,
                        messageDuration: 3,
                      );
                    }
                    UiUtils.noPackageAvailableDialog(
                      context,
                      limit: state.limit,
                    );
                  }
                }
              },
              child: AnimatedCrossFade(
                duration: Duration(milliseconds: 500),
                crossFadeState: isFeaturedWidget
                    ? CrossFadeState.showFirst
                    : CrossFadeState.showSecond,
                firstChild: Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(width: 20),
                    ],
                  ),
                ),
                secondChild: SizedBox.shrink(),
              ),
            ),
          );
        }),
      );
    } else {
      return SizedBox.shrink();
    }
  }

  Widget favButton({required ItemModel item, required double size}) {
    bool isLike = context.read<FavoriteCubit>().isItemFavorite(item.id!);

    return BlocProvider(
      create: (context) => UpdateFavoriteCubit(FavoriteRepository()),
      child: BlocConsumer<FavoriteCubit, FavoriteState>(
        bloc: context.read<FavoriteCubit>(),
        listener: (context, state) {
          if (state is FavoriteFetchSuccess) {
            isLike = context.read<FavoriteCubit>().isItemFavorite(item.id!);
          }
        },
        builder: (context, likeAndDislikeState) {
          return BlocConsumer<UpdateFavoriteCubit, UpdateFavoriteState>(
            bloc: context.read<UpdateFavoriteCubit>(),
            listener: (context, state) {
              if (state is UpdateFavoriteSuccess) {
                if (state.wasProcess) {
                  context.read<FavoriteCubit>().addFavoriteitem(state.item);
                } else {
                  context.read<FavoriteCubit>().removeFavoriteItem(state.item);
                }
              }
            },
            builder: (context, state) {
              final inProgress = state is UpdateFavoriteInProgress;

              return CircleAvatar(
                backgroundColor: Colors.black54, // ✅ نفس باقي الأزرار
                radius: size / 2,
                child: IconButton(
                  icon: inProgress
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : UiUtils.getSvg(
                          isLike ? AppIcons.like_fill : AppIcons.like,
                          width: 22,
                          height: 22,
                          color: isLike ? Colors.redAccent : Colors.white,
                        ),
                  onPressed: inProgress
                      ? null
                      : () {
                          UiUtils.checkUser(
                            onNotGuest: () {
                              context
                                  .read<UpdateFavoriteCubit>()
                                  .setFavoriteItem(
                                    item: item,
                                    type: isLike ? 0 : 1,
                                  );

                              UiUtils.showSoftSnackBar(
                                context,
                                message: isLike
                                    ? "تمت الإزالة من المفضلة"
                                    : "تمت الإضافة إلى المفضلة",
                              );
                            },
                            context: context,
                          );
                        },
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget itemData(
      int index, SubscriptionPackageModel model, StateSetter stateSetter) {
    return Padding(
      padding: const EdgeInsets.only(top: 7.0),
      child: Stack(
        alignment: Alignment.topLeft,
        children: [
          if (model.isActive == true)
            Padding(
              padding: EdgeInsetsDirectional.only(start: 13.0),
              child: ClipPath(
                clipper: CapShapeClipper(),
                child: Container(
                  color: context.color.territoryColor,
                  width: MediaQuery.of(context).size.width / 3,
                  height: 17,
                  padding: EdgeInsets.only(top: 3),
                  child: Text('activePlanLbl'.translate(context))
                      .color(context.color.secondaryColor)
                      .centerAlign()
                      .bold(weight: FontWeight.w500)
                      .size(12),
                ),
              ),
            ),
          InkWell(
            onTap: () {
              _selectedPackageIndex = index;
              stateSetter(() {});
              setState(() {});
            },
            child: Container(
              margin: EdgeInsets.only(top: 17),
              padding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16.0),
                  border: Border.all(
                      color: index == _selectedPackageIndex
                          ? context.color.territoryColor
                          : context.color.textDefaultColor.withOpacity(0.1),
                      width: 1.5)),
              child:
                  !model.isActive! ? adsWidget(model) : activeAdsWidget(model),
            ),
          ),
        ],
      ),
    );
  }

  // دالة مبسطة لعرض الباقات

  Widget adsWidget(SubscriptionPackageModel model) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      mainAxisSize: MainAxisSize.min,
      children: [
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(model.name ?? "Unknown Package")
                  .firstUpperCaseWidget()
                  .bold(weight: FontWeight.w600)
                  .size(context.font.large),
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${model.limit == "unlimited" ? "unlimitedLbl".translate(context) : model.limit.toString()}\t${"adsLbl".translate(context)}\t\t·\t\t',
                    overflow: TextOverflow.ellipsis,
                    softWrap: true,
                  ).color(context.color.textDefaultColor.withOpacity(0.5)),
                  Flexible(
                    child: Text(
                      '${model.duration.toString()}\t${"days".translate(context)}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      softWrap: true,
                    ).color(context.color.textDefaultColor.withOpacity(0.5)),
                  ),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsetsDirectional.only(start: 10.0),
          child: Text(
            (model.finalPrice ?? 0) > 0
                ? "${Constant.currencySymbol}${model.finalPrice?.toString() ?? "0"}"
                : "free".translate(context),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  // دالة متابعة الباقة و والاشتراك
  Widget activeAdsWidget(SubscriptionPackageModel model) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      mainAxisSize: MainAxisSize.min,
      children: [
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(model.name ?? "Unknown Package")
                  .firstUpperCaseWidget()
                  .bold(weight: FontWeight.w600)
                  .size(context.font.large),
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      text: model.limit == "unlimited"
                          ? "${"unlimitedLbl".translate(context)}\t${"adsLbl".translate(context)}\t\t·\t\t"
                          : '',
                      style: TextStyle(
                        color: context.color.textDefaultColor.withOpacity(0.5),
                      ),
                      children: [
                        if (model.limit != "unlimited")
                          TextSpan(
                            text:
                                '${model.userPurchasedPackages?[0].remainingItemLimit ?? 0}',
                            style: TextStyle(
                                color: context.color.textDefaultColor),
                          ),
                        if (model.limit != "unlimited")
                          TextSpan(
                            text:
                                '/${model.limit.toString()}\t${"adsLbl".translate(context)}\t\t·\t\t',
                          ),
                      ],
                    ),
                    overflow: TextOverflow.ellipsis,
                    softWrap: true,
                  ),
                  Flexible(
                    child: Text.rich(
                      TextSpan(
                        text: model.duration == "unlimited"
                            ? "${"unlimitedLbl".translate(context)}\t${"days".translate(context)}"
                            : '',
                        style: TextStyle(
                          color:
                              context.color.textDefaultColor.withOpacity(0.5),
                        ),
                        children: [
                          if (model.duration != "unlimited")
                            TextSpan(
                              text:
                                  '${model.userPurchasedPackages?[0].remainingDays ?? 0}',
                              style: TextStyle(
                                  color: context.color.textDefaultColor),
                            ),
                          if (model.duration != "unlimited")
                            TextSpan(
                              text:
                                  '/${model.duration.toString()}\t${"days".translate(context)}',
                            ),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      softWrap: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsetsDirectional.only(start: 10.0),
          child: Text(
            (model.finalPrice ?? 0) > 0
                ? "${Constant.currencySymbol}${model.finalPrice?.toString() ?? "0"}"
                : "free".translate(context),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  showPackageSelectBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.color.secondaryColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(15.0),
          topRight: Radius.circular(15.0),
        ),
      ),
      isScrollControlled: true,
      useSafeArea: true,
      constraints: BoxConstraints(maxHeight: context.screenHeight * 0.85),
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: context.color.secondaryColor,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(15),
              topRight: Radius.circular(15),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      color: context.color.borderColor,
                    ),
                    height: 6,
                    width: 60,
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(vertical: 17, horizontal: 20),
                child: Text(
                  'selectPackage'.translate(context),
                  textAlign: TextAlign.start,
                ).bold(weight: FontWeight.bold).size(context.font.large),
              ),

              Divider(height: 1), // Add some space between title and options
              Expanded(child: packageList()),
            ],
          ),
        );
      },
    );
  }

  // دالة عرض واجهة واختيار الباقات

  Widget packageList() {
    return BlocBuilder<FetchAdsListingSubscriptionPackagesCubit,
        FetchAdsListingSubscriptionPackagesState>(
      builder: (context, state) {
        print("state package***$state");
        if (state is FetchAdsListingSubscriptionPackagesInProgress) {
          return Center(
            child: UiUtils.progress(),
          );
        }
        if (state is FetchAdsListingSubscriptionPackagesFailure) {
          if (state.errorMessage is ApiException) {
            if (state.errorMessage == "no-internet") {
              return NoInternet(
                onRetry: () {
                  context
                      .read<FetchAdsListingSubscriptionPackagesCubit>()
                      .fetchPackages();
                },
              );
            }
          }

          return const SomethingWentWrong();
        }
        if (state is FetchAdsListingSubscriptionPackagesSuccess) {
          print(
              "subscription plan list***${state.subscriptionPackages.length}");
          if (state.subscriptionPackages.isEmpty) {
            return NoDataFound(
              onTap: () {
                context
                    .read<FetchAdsListingSubscriptionPackagesCubit>()
                    .fetchPackages();
              },
              category: EmptyStateCategory.subscriptions,
            );
          }

          return StatefulBuilder(
              builder: (BuildContext context, StateSetter setStater) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(
                  child: ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.symmetric(horizontal: 18),
                      itemBuilder: (context, index) {
                        return itemData(index,
                            state.subscriptionPackages[index], setStater);
                      },
                      itemCount: state.subscriptionPackages.length),
                ),
                Builder(builder: (context) {
                  return BlocListener<RenewItemCubit, RenewItemState>(
                    listener: (context, changeState) {
                      if (changeState is RenewItemInSuccess) {
                        HelperUtils.showSnackBarMessage(
                            context, changeState.responseMessage);
                        Future.delayed(Duration.zero, () {
                          Navigator.pop(context);
                          Navigator.pop(context, "refresh");
                        });
                      } else if (changeState is RenewItemFailure) {
                        Navigator.pop(context);
                        HelperUtils.showSnackBarMessage(
                            context, changeState.error);
                      }
                    },
                    child: UiUtils.buildButton(context, onPressed: () {
                      if (state.subscriptionPackages[_selectedPackageIndex!]
                          .isActive!) {
                        Future.delayed(Duration.zero, () {
                          context.read<RenewItemCubit>().renewItem(
                              packageId: state
                                  .subscriptionPackages[_selectedPackageIndex!]
                                  .id!,
                              itemId: _currentItem.id!);
                        });
                      } else {
                        Navigator.pop(context);
                        HelperUtils.showSnackBarMessage(context,
                            "pleasePurchasePackage".translate(context));
                        Navigator.pushNamed(
                            context, Routes.subscriptionPackageListRoute);
                      }
                    },
                        radius: 10,
                        height: 46,
                        disabled: _selectedPackageIndex == null,
                        disabledColor:
                            context.color.textLightColor.withOpacity(0.3),
                        fontSize: context.font.large,
                        buttonColor: context.color.territoryColor,
                        textColor: context.color.secondaryColor,
                        buttonTitle: "renewItem".translate(context),
                        outerPadding: const EdgeInsets.all(20)),
                  );
                })
              ],
            );
          });
        }

        return Container();
      },
    );
  }

  // دالة عرض النصائح قبل الشراء

  Widget checkmarkPoint(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UiUtils.getSvg(
            AppIcons.active_mark,
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Text(
            text.firstUpperCase(),
            textAlign: TextAlign.start,
          )
                  .color(
                    context.color.textDefaultColor,
                  )
                  .size(context.font.large)),
        ],
      ),
    );
  }

  Widget setTopRowItem(
      {required AlignmentDirectional alignment,
      required double marginVal,
      required double cornerRadius,
      required Color backgroundColor,
      required Widget childWidget}) {
    return Align(
        alignment: alignment,
        child: Container(
            margin: EdgeInsets.all(marginVal),
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(cornerRadius),
                color: backgroundColor),
            child: childWidget)
        //TODO: swap icons according to liked and non-liked -- favorite_border_rounded and favorite_rounded
        );
  }

  Widget buildDot(int index) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 3.0),
      width: currentPage == index ? 12.0 : 8.0,
      height: 8.0,
      decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: currentPage == index ? Colors.white : Colors.grey),
    );
  }

  // دالة تقديم بلاغ
  Widget setRejectedReason() {
    if (_currentItem.status == "rejected" &&
        (_currentItem.rejectedReason != null ||
            _currentItem.rejectedReason != "")) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: context.color.textDefaultColor.withOpacity(0.1)),

          // Background color
        ),
        margin: const EdgeInsets.symmetric(vertical: 15),
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 15),
        child: Row(
            //crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.report,
                size: 20,
                color: Colors.red, // Icon color can be adjusted
              ),
              SizedBox(
                width: 5,
              ),
              Expanded(
                child: Text(
                  '${"rejection_reason".translate(context)}: ${_currentItem.rejectedReason}',
                )
                    .color(context.color.textDefaultColor)
                    .size(context.font.large),
              ),
            ]),
      );
    } else {
      return SizedBox.shrink();
    }
  }

  void _navigateToGoogleMapScreen(BuildContext context) {
    Navigator.push(
      context,
      BlurredRouter(
        barrierDismiss: true,
        builder: (context) {
          return GoogleMapScreen(
            item: _currentItem,
            kInitialPlace: _kInitialPlace,
            controller: _controller,
          );
        },
      ),
    );
  }

  Widget setReportAd() {
    return AnimatedCrossFade(
      duration: Duration(milliseconds: 500),
      crossFadeState: isShowReportAds
          ? CrossFadeState.showFirst
          : CrossFadeState.showSecond,
      firstChild: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: context.color.textDefaultColor.withOpacity(0.1)),

          // Background color
        ),
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
                //crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.report,
                    size: 20,
                    color: Colors.red, // Icon color can be adjusted
                  ),
                  SizedBox(
                    width: 5,
                  ),
                  Expanded(
                    child: Text(
                      "didYouFindAnyProblemWithThisItem".translate(context),
                      maxLines: 2,
                    )
                        .color(context.color.textDefaultColor)
                        .size(context.font.large),
                  ),
                ]),
            SizedBox(height: 15),
            BlocListener<ItemReportCubit, ItemReportState>(
              listener: (context, state) {
                if (state is ItemReportFailure) {
                  HelperUtils.showSnackBarMessage(
                      context, state.error.toString());
                }
                if (state is ItemReportInSuccess) {
                  HelperUtils.showSnackBarMessage(
                      context, state.responseMessage.toString());
                  context.read<UpdatedReportItemCubit>().addItem(_currentItem);
                }

                if (!Constant.isDemoModeOn)
                  setState(() {
                    isShowReportAds = false;
                  });
              },
              child: GestureDetector(
                onTap: () {
                  UiUtils.checkUser(
                      onNotGuest: () {
                        _bottomSheet(_currentItem.id!);
                      },
                      context: context);
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: context.color.territoryColor
                        .withOpacity(0.1), // Button color can be adjusted
                  ),
                  child: Text(
                    "reportThisAd".translate(context),
                  )
                      .color(context.color.territoryColor)
                      .size(context.font.normal),
                ),
              ),
            )
          ],
        ),
      ),
      secondChild: SizedBox.shrink(),
    );
  }

  // دالة تقديم عرض
  void makeOfferBottomSheet(ItemModel model) async {
    await UiUtils.showBlurredDialoge(
      context,
      dialoge: BlurredDialogBox(
        content: makeAnOffer(),
        onCancel: () {
          _makeAnOffermessageController.clear();
        },
        acceptButtonName: "send".translate(context),
        isAcceptContainesPush: true,
        onAccept: () => Future.value().then((_) {
          if (_offerFormKey.currentState!.validate()) {
            context.read<MakeAnOfferItemCubit>().makeAnOfferItem(
                id: _currentItem.id!,
                from: "offer",
                amount:
                    double.parse(_makeAnOffermessageController.text.trim()));
            Navigator.pop(context);
            return;
          }
        }),
      ),
    );
  }

  // تتبع تقديم عرض سعر
  Widget makeAnOffer() {
    double bottomPadding = (MediaQuery.of(context).viewInsets.bottom - 50);
    bool isBottomPaddingNagative = bottomPadding.isNegative;
    return SizedBox(
      width: MediaQuery.of(context).size.width,
      child: SingleChildScrollView(
        child: Form(
          key: _offerFormKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("makeAnOffer".translate(context))
                  .size(context.font.larger)
                  .centerAlign()
                  .bold(),
              Divider(
                thickness: 1,
                color: context.color.borderColor.darken(30),
              ),
              const SizedBox(
                height: 15,
              ),
              RichText(
                text: TextSpan(
                  text: "sellerPrice".translate(context),
                  style: TextStyle(
                      color: context.color.textDefaultColor.withOpacity(0.5),
                      fontSize: 16),
                  children: <TextSpan>[
                    TextSpan(
                      text: "\t${Constant.currencySymbol}${_currentItem.price}",
                      style: TextStyle(
                          color: context.color.textDefaultColor,
                          fontSize: 16,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsetsDirectional.only(
                    bottom: isBottomPaddingNagative ? 0 : bottomPadding,
                    start: 20,
                    end: 20,
                    top: 18),
                child: TextFormField(
                  maxLines: null,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                      color: context.color.textDefaultColor),
                  controller: _makeAnOffermessageController,
                  cursorColor: context.color.territoryColor,
                  //autovalidateMode: AutovalidateMode.always,
                  validator: (val) {
                    if (val == null || val.isEmpty) {
                      return Validator.nullCheckValidator(val,
                          context: context);
                    } else {
                      double parsedVal = double.parse(val);
                      if (parsedVal <= 0.0) {
                        return "valueMustBeGreaterThanZeroLbl"
                            .translate(context);
                      }
                      final price = _currentItem.price;
                      if (price != null && parsedVal > price) {
                        return "offerPriceWarning".translate(context);
                      }
                      return null;
                    }
                  },
                  decoration: InputDecoration(
                      fillColor: context.color.borderColor.darken(20),
                      filled: true,
                      contentPadding:
                          EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                      hintText: "yourOffer".translate(context),
                      hintStyle: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                          color:
                              context.color.textDefaultColor.withOpacity(0.3)),
                      focusColor: context.color.territoryColor,
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                              color: context.color.borderColor.darken(60))),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                              color: context.color.borderColor.darken(60))),
                      focusedBorder: OutlineInputBorder(
                          borderSide:
                              BorderSide(color: context.color.territoryColor))),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _bottomSheet(int itemId) async {
    await _refreshReportReasons();
    await UiUtils.showBlurredDialoge(
      context,
      dialoge: BlurredDialogBox(
          title: "reportItem".translate(context),
          content: reportReason(),
          isAcceptContainesPush: true,
          onAccept: () => Future.value().then((_) {
                if (selectedId.isNegative) {
                  if (_formKey.currentState!.validate()) {
                    context.read<ItemReportCubit>().report(
                          item_id: _currentItem.id!,
                          reason_id: selectedId,
                          message: _reportmessageController.text,
                        );
                    Navigator.pop(context);
                    return;
                  }
                } else {
                  context.read<ItemReportCubit>().report(
                        item_id: _currentItem.id!,
                        reason_id: selectedId,
                      );
                  Navigator.pop(context);
                  return;
                }
              })),
    );
  }

  Future<void> _refreshReportReasons() async {
    final List<ReportReason> reasons = await context
        .read<FetchItemReportReasonsListCubit>()
        .fetch(forceRefresh: true);
    if (!mounted) return;
    _syncSelectedReportReason(reasons);
  }

  String formatPhoneNumber(String fullNumber, String countryCode) {
    // Normalize the country code (remove '+' if present)
    countryCode = countryCode.replaceAll('+', '');

    // Remove '+' from fullNumber if present
    fullNumber = fullNumber.replaceAll('+', '');

    // Check if the fullNumber already starts with the country code
    if (!fullNumber.startsWith(countryCode)) {
      // If not, prepend the country code
      fullNumber = countryCode + fullNumber;
    }

    // Add '+' to the beginning of the full number
    fullNumber = '+' + fullNumber;

    return fullNumber;
  }

  Widget setIconButtons({
    required String assetName,
    required void Function() onTap,
    Color? color,
    double? height,
    double? width,
  }) {
    return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: context.color.borderColor.darken(30))),
        child: Padding(
            padding: const EdgeInsets.all(5),
            child: InkWell(
                onTap: onTap,
                child: SvgPicture.asset(
                  assetName,
                  colorFilter: color == null
                      ? ColorFilter.mode(
                          context.color.territoryColor, BlendMode.srcIn)
                      : ColorFilter.mode(color, BlendMode.srcIn),
                ))));
  }

  // دالة اختيار سبب البلاغ

  Widget reportReason() {
    double bottomPadding = MediaQuery.of(context).viewInsets.bottom - 50;
    bool isBottomPaddingNegative = bottomPadding.isNegative;
    final List<ReportReason> reasons = _reportReasons;

    return StatefulBuilder(builder: (context, setState) {
      return SizedBox(
        width: MediaQuery.of(context).size.width,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListView.separated(
                  shrinkWrap: true,
                  itemCount: reasons.length,
                  physics: const NeverScrollableScrollPhysics(),
                  separatorBuilder: (context, index) {
                    return const SizedBox(height: 10);
                  },
                  itemBuilder: (context, index) {
                    return InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () {
                        setState(() {
                          selectedId = reasons[index].id;
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: context.color.primaryColor,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: selectedId == reasons[index].id
                                ? context.color.territoryColor
                                : context.color.borderColor,
                            width: 1.5,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14.0),
                          child: Text(
                            reasons[index].reason.firstUpperCase() ?? "",
                          ).color(
                            selectedId == reasons[index].id
                                ? context.color.territoryColor
                                : context.color.textColorDark,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                if (selectedId.isNegative)
                  Padding(
                    padding: EdgeInsetsDirectional.only(
                      bottom: isBottomPaddingNegative ? 0 : bottomPadding,
                      start: 0,
                      end: 0,
                    ),
                    child: TextFormField(
                      maxLines: null,
                      controller: _reportmessageController,
                      cursorColor: context.color.territoryColor,
                      validator: (val) {
                        if (val == null || val.isEmpty) {
                          return "addReportReason".translate(context);
                        } else {
                          return null;
                        }
                      },
                      decoration: InputDecoration(
                        hintText: "writeReasonHere".translate(context),
                        focusColor: context.color.territoryColor,
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: context.color.territoryColor,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    });
  }

  // اختصارات العملة
  String _getCurrencySymbol(String? currency) {
    final String? preferred = CurrencyUtils.preferredDisplayFor(currency);
    if (preferred != null) {
      return preferred;
    }

    final String? upper = currency?.toUpperCase();
    if (upper == 'YRI' || upper == 'YERR') {
      return CurrencyUtils.preferredDisplayFor('YER') ??
          Constant.currencySymbol;
    }
    return currency ?? Constant.currencySymbol;
  }
}

class _BlurredImageInternal extends StatefulWidget {
  final String imageUrl;
  final double width;
  final double height;
  final double borderRadius;
  final BoxFit fit;

  const _BlurredImageInternal({
    required this.imageUrl,
    required this.width,
    required this.height,
    this.borderRadius = 14,
    this.fit = BoxFit.cover,
  });

  @override
  State<_BlurredImageInternal> createState() => _BlurredImageInternalState();
}

class _BlurredImageInternalState extends State<_BlurredImageInternal>
    with SingleTickerProviderStateMixin {
  bool _isLoaded = false;
  late AnimationController _controller;
  late Animation<double> _blurAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _blurAnimation =
        Tween<double>(begin: 90.0, end: 0.0).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: Stack(
        children: [
          Image.network(
            widget.imageUrl,
            width: widget.width,
            height: widget.height,
            fit: widget.fit,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null && !_isLoaded) {
                _controller.forward();
                Future.microtask(() {
                  if (mounted) setState(() => _isLoaded = true);
                });
              }
              return child;
            },
            errorBuilder: (context, error, stackTrace) =>
                const Center(child: Icon(Icons.broken_image)),
          ),
          if (!_isLoaded)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _blurAnimation,
                builder: (_, __) {
                  final double opacity =
                      ((_blurAnimation.value / 90).clamp(0.0, 1.0)) * 0.6;
                  return BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: _blurAnimation.value,
                      sigmaY: _blurAnimation.value,
                    ),
                    child: Container(
                      color: Colors.black.withOpacity(opacity),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

/// ✅ الصق هذا الكود هنا قبل build()
Widget buildBlurredImage({
  required String imageUrl,
  required double width,
  required double height,
  double borderRadius = 14,
  BoxFit fit = BoxFit.cover,
}) {
  return _BlurredImageInternal(
    imageUrl: imageUrl,
    width: width,
    height: height,
    borderRadius: borderRadius,
    fit: fit,
  );
}

// 2) زر إعجاب موحّد الشكل ومربوط بالمفضّلة
class _FavBtn extends StatelessWidget {
  final ItemModel model;

  const _FavBtn({required this.model});

  @override
  Widget build(BuildContext context) {
    final fav = context.watch<FavoriteCubit>();
    final bool liked = (model.id != null) && fav.isItemFavorite(model.id!);

    return CircleAvatar(
      backgroundColor: Colors.black54, // نفس خلفية بقية الأزرار
      child: IconButton(
        icon: Icon(
          liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          color: liked ? Colors.redAccent : Colors.white,
        ),
        onPressed: () {
          if (model.id == null) return;
          if (liked) {
            fav.removeFavoriteItem(model); // إزالة من المفضلة
          } else {
            fav.addFavoriteitem(model); // إضافة إلى المفضلة
          }
        },
      ),
    );
  }
}

class _AdDetailsLoadingBody extends StatelessWidget {
  const _AdDetailsLoadingBody({required this.isOwner});

  final bool isOwner;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          stretch: true,
          expandedHeight: size.height * 0.40,
          backgroundColor: context.color.secondaryDetailsColor,
          flexibleSpace: FlexibleSpaceBar(
            background: LayoutBuilder(
              builder: (context, constraints) {
                return SizedBox.expand(
                  child: CustomShimmer(
                    height: constraints.maxHeight,
                    width: constraints.maxWidth,
                    borderRadius: 0,
                  ),
                );
              },
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(13.0),
            child: _LoadingDetailsContent(isOwner: isOwner),
          ),
        ),
      ],
    );
  }
}

class _LoadingDetailsContent extends StatelessWidget {
  const _LoadingDetailsContent({required this.isOwner});

  final bool isOwner;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      const SizedBox(height: 10),
      _buildTitle(context),
      const SizedBox(height: 12),
      _buildPriceAndStatus(context),
      if (isOwner) ...[
        const SizedBox(height: 16),
        _buildOwnerStats(context),
      ],
      const SizedBox(height: 16),
      _buildAddressAndDate(context),
      const SizedBox(height: 24),
      _buildCustomFields(context),
      const SizedBox(height: 24),
      _buildDivider(context),
      const SizedBox(height: 16),
      _buildDescription(context),
      const SizedBox(height: 24),
      _buildDivider(context),
      const SizedBox(height: 16),
      _buildSeller(context),
      const SizedBox(height: 24),
      _buildMap(context),
      const SizedBox(height: 24),
      _buildActionButton(context),
      const SizedBox(height: 24),
      _buildRelatedHeader(context),
      const SizedBox(height: 12),
      _buildRelatedList(context),
    ];

    if (Constant.isGoogleBannerAdsEnabled == "1") {
      children
        ..add(const SizedBox(height: 24))
        ..add(_buildDivider(context))
        ..add(const SizedBox(height: 16))
        ..add(_buildBanner(context));
    }

    children.add(const SizedBox(height: 24));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  static Widget _buildTitle(BuildContext context) {
    return const CustomShimmer(
      height: 28,
      width: double.infinity,
      borderRadius: 12,
    );
  }

  static Widget _buildPriceAndStatus(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return Row(
      children: [
        CustomShimmer(
          height: 20,
          width: width * 0.45,
          borderRadius: 12,
        ),
        const SizedBox(width: 12),
        CustomShimmer(
          height: 20,
          width: width * 0.25,
          borderRadius: 12,
        ),
      ],
    );
  }

  static Widget _buildOwnerStats(BuildContext context) {
    return Row(
      children: const [
        Expanded(
          child: CustomShimmer(
            height: 44,
            borderRadius: 16,
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: CustomShimmer(
            height: 44,
            borderRadius: 16,
          ),
        ),
      ],
    );
  }

  static Widget _buildAddressAndDate(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CustomShimmer(
          height: 16,
          width: width * 0.5,
          borderRadius: 10,
        ),
        const SizedBox(height: 8),
        CustomShimmer(
          height: 14,
          width: width * 0.35,
          borderRadius: 10,
        ),
      ],
    );
  }

  static Widget _buildCustomFields(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: List.generate(3, (index) {
        return const CustomShimmer(
          height: 34,
          width: 110,
          borderRadius: 18,
        );
      }),
    );
  }

  static Widget _buildDivider(BuildContext context) {
    return CustomShimmer(
      height: 1,
      width: double.infinity,
      borderRadius: 1,
    );
  }

  static Widget _buildDescription(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(4, (index) {
        final factor = index == 3 ? 0.6 : 0.9;
        return Padding(
          padding: EdgeInsets.only(bottom: index == 3 ? 0 : 8),
          child: CustomShimmer(
            height: 12,
            width: width * factor,
            borderRadius: 8,
          ),
        );
      }),
    );
  }

  static Widget _buildSeller(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return Row(
      children: [
        const CustomShimmer(
          height: 52,
          width: 52,
          borderRadius: 26,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomShimmer(
                height: 14,
                width: width * 0.4,
                borderRadius: 8,
              ),
              const SizedBox(height: 8),
              CustomShimmer(
                height: 12,
                width: width * 0.3,
                borderRadius: 8,
              ),
            ],
          ),
        ),
      ],
    );
  }

  static Widget _buildMap(BuildContext context) {
    return const CustomShimmer(
      height: 170,
      width: double.infinity,
      borderRadius: 16,
    );
  }

  static Widget _buildActionButton(BuildContext context) {
    return const CustomShimmer(
      height: 48,
      width: double.infinity,
      borderRadius: 14,
    );
  }

  static Widget _buildRelatedHeader(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return CustomShimmer(
      height: 18,
      width: width * 0.35,
      borderRadius: 10,
    );
  }

  static Widget _buildRelatedList(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final cardWidth = width * 0.6;
    return SizedBox(
      height: 170,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemBuilder: (context, index) {
          return CustomShimmer(
            height: 170,
            width: cardWidth,
            borderRadius: 16,
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemCount: 3,
      ),
    );
  }

  static Widget _buildBanner(BuildContext context) {
    return const CustomShimmer(
      height: 60,
      width: double.infinity,
      borderRadius: 14,
    );
  }
}

class _FetchErrorView extends StatelessWidget {
  const _FetchErrorView({
    required this.message,
    this.onRetry,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = context.color.textDefaultColor;
    final displayMessage = message.trim().isNotEmpty
        ? message
        : 'something_went_wrong'.translate(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              color: theme.colorScheme.error,
              size: 56,
            ),
            const SizedBox(height: 16),
            Text(
              displayMessage,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                  ) ??
                  TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: onRetry,
                child: Text('retry'.translate(context)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

