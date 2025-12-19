import 'package:marib/data/model/user_model.dart';
import 'dart:async';

import 'package:marib/data/cubits/item/fetch_item_from_category_cubit.dart';
import 'package:marib/ui/screens/sliders/slider_widget.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:intl/intl.dart';
import 'package:marib/utils/constant.dart';
import 'package:marib/utils/hive_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:marib/data/model/item_filter_model.dart';
import 'package:marib/data/model/item/item_model.dart';

import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/api.dart';

import 'package:marib/utils/ui_utils.dart';
import 'package:marib/ui/screens/widgets/errors/no_data_found.dart';
import 'package:marib/ui/screens/widgets/errors/something_went_wrong.dart';
import 'package:marib/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:marib/data/cubits/seller/fetch_sellers_cubit.dart';
import 'package:marib/data/repositories/seller/seller_repository.dart';
import 'package:marib/ui/screens/widgets/shimmerLoadingContainer.dart';
import 'package:marib/app/routes.dart';
import 'package:marib/utils/seller_category_utils.dart'
    as seller_category_utils;
import 'seller_card.dart';

class ItemsListSeller extends StatefulWidget {
  final String categoryId, categoryName;
  final List<String> categoryIds;

  ItemsListSeller(
      {super.key,
      required this.categoryId,
      required this.categoryName,
      required this.categoryIds});

  @override
  ItemsListListState createState() => ItemsListListState();

  static Route route(RouteSettings routeSettings) {
    Map? arguments = routeSettings.arguments as Map?;
    return BlurredRouter(
      builder: (_) => BlocProvider<FetchSellersCubit>(
        create: (context) => FetchSellersCubit(SellerRepository()),
        child: ItemsListSeller(
          categoryId: arguments?['catID'] as String,
          categoryName: arguments?['catName'],
          categoryIds: arguments?['categoryIds'],
        ),
      ),
    );
  }
}

class ItemsListListState extends State<ItemsListSeller> {
  late ScrollController controller;
  static TextEditingController searchController = TextEditingController();
  String previousSearchQuery = "";
  Timer? _searchDelay;
  String _searchQuery = "";
  String? sortBy;
  ItemFilterModel? filter;
  late Map<String, dynamic> searchbody;
  String selectedcategoryId = "";
  String selectedcategoryName = "";
  int lastSellersCount = 8; // Default shimmer count

  @override
  void initState() {
    super.initState();
    searchbody = {};
    Constant.itemFilter = null;
    searchController = TextEditingController();
    searchController.addListener(searchItemListener);
    controller = ScrollController()..addListener(_loadMore);

    context.read<FetchItemFromCategoryCubit>().fetchItemFromCategory(
        categoryId: int.parse(
          widget.categoryId,
        ),
        search: "",
        filter: ItemFilterModel(
            country: HiveUtils.getCountryName() ?? "",
            areaId: HiveUtils.getAreaId() != null
                ? int.parse(HiveUtils.getAreaId().toString())
                : null,
            city: HiveUtils.getCityName() ?? "",
            state: HiveUtils.getStateName() ?? "",
            categoryId: widget.categoryId,
            radius: HiveUtils.getNearbyRadius() ?? null,
            latitude: HiveUtils.getLatitude() ?? null,
            longitude: HiveUtils.getLongitude() ?? null));

    Future.delayed(Duration.zero, () {
      selectedcategoryId = widget.categoryId;
      selectedcategoryName = widget.categoryName;
      searchbody[Api.categoryId] = widget.categoryId;
      setState(() {});
    });
    context.read<FetchSellersCubit>().fetchSellers(accountType: 3);
  }

  @override
  void dispose() {
    controller.removeListener(_loadMore);
    controller.dispose();
    searchController.dispose();
    super.dispose();
  }

  //this will listen and manage search
  void searchItemListener() {
    _searchDelay?.cancel();
    searchCallAfterDelay();
  }

//This will create delay so we don't face rapid api call
  void searchCallAfterDelay() {
    _searchDelay = Timer(const Duration(milliseconds: 500), itemSearch);
  }

  ///This will call api after some delay
  void itemSearch() {
    if (previousSearchQuery != searchController.text) {
      setState(() {
        _searchQuery = searchController.text;
      });
      context.read<FetchItemFromCategoryCubit>().fetchItemFromCategory(
          categoryId: int.parse(
            widget.categoryId,
          ),
          search: searchController.text);
      previousSearchQuery = searchController.text;
      sortBy = null;
      setState(() {});
    }
  }

  void _loadMore() async {
    if (controller.isEndReached()) {
      if (context.read<FetchItemFromCategoryCubit>().hasMoreData()) {
        context.read<FetchItemFromCategoryCubit>().fetchItemFromCategoryMore(
            catId: int.parse(
              widget.categoryId,
            ),
            search: searchController.text,
            sortBy: sortBy,
            filter: ItemFilterModel(
              country: HiveUtils.getCountryName() ?? "",
              areaId: HiveUtils.getAreaId() != null
                  ? int.parse(HiveUtils.getAreaId().toString())
                  : null,
              city: HiveUtils.getCityName() ?? "",
              state: HiveUtils.getStateName() ?? "",
              categoryId: widget.categoryId,
            ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return bodyWidget();
  }

  Widget bodyWidget() {
    return AnnotatedRegion(
      value: UiUtils.getSystemUiOverlayStyle(
        context: context,
        statusBarColor: context.color.secondaryColor,
      ),
      child: PopScope(
        canPop: true,
        onPopInvoked: (isPop) {
          Constant.itemFilter = null;
        },
        child: Scaffold(
          backgroundColor: Theme.of(context).colorScheme.primaryColor,
          appBar: UiUtils.buildAppBar(context,
              showBackButton: true,
              title: selectedcategoryName == ""
                  ? widget.categoryName
                  : selectedcategoryName),
          body: RefreshIndicator(
            onRefresh: () async {
              searchbody = {};
              Constant.itemFilter = null;

              context.read<FetchItemFromCategoryCubit>().fetchItemFromCategory(
                    categoryId: int.parse(widget.categoryId),
                    search: "",
                  );
            },
            color: context.color.territoryColor,
            child: Column(
              children: [
                SizedBox(height: 20),
                // HomeSearchField(),
                Flexible(child: buildTabContent()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget buildTabContent() {
    return CustomScrollView(
      controller: controller,
      slivers: [
        SliverToBoxAdapter(child: SizedBox(height: 2)),
        SliverToBoxAdapter(child: SliderWidget(interfaceType: "e_store")),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'ابحث عن المتجر أو الإعلان',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
        BlocBuilder<FetchSellersCubit, FetchSellersState>(
          builder: (context, state) {
            if (state is FetchSellersProgress) {
              final shimmerItemCount = (lastSellersCount / 2).ceil();
              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Container(
                            margin: EdgeInsets.all(8.0),
                            child: CustomShimmer(
                                height: 150,
                                width: double.infinity,
                                borderRadius: 12),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            margin: EdgeInsets.all(8.0),
                            child: CustomShimmer(
                                height: 150,
                                width: double.infinity,
                                borderRadius: 12),
                          ),
                        ),
                      ],
                    );
                  },
                  childCount: shimmerItemCount,
                ),
              );
            } else if (state is FetchSellersSuccess) {
              lastSellersCount = state.sellers.length;
              if (state.sellers.isEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: NoDataFound(
                    onTap: () {
                      context
                          .read<FetchSellersCubit>()
                          .fetchSellers(accountType: 3);
                    },
                    category: EmptyStateCategory.profile,
                  ),
                );
              }
              final List<UserModel> sellersToShow =
                  _filterSellers(state.sellers, _searchQuery);
              return buildCardList(sellersToShow);
            } else if (state is FetchSellersFailure) {
              return SliverFillRemaining(
                hasScrollBody: false,
                child: SomethingWentWrong(),
              );
            } else {
              return SliverToBoxAdapter(child: SizedBox.shrink());
            }
          },
        ),
      ],
    );
  }

  List<UserModel> _filterSellers(List<UserModel> sellers, String query) {
    final String normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return sellers;

    return sellers.where((seller) {
      return _sellerMatchesQuery(seller, normalized);
    }).toList(growable: false);
  }

  Widget buildCardList(List<UserModel> sellers) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          return SellerCard(seller: sellers[index]);
        },
        childCount: sellers.length,
      ),
    );
  }

  User userModelToUser(UserModel userModel) {
    return User(
      id: userModel.id,
      name: userModel.name,
      mobile: userModel.mobile,
      email: userModel.email,
      type: userModel.type,
      profile: userModel.profile,
      fcmId: userModel.fcmId,
      firebaseId: userModel.firebaseId,
      status: userModel.isActive,
      apiToken: userModel.token,
      address: userModel.address,
      createdAt: userModel.createdAt,
      updatedAt: userModel.updatedAt,
      isVerified: userModel.isVerified,
      showPersonalDetails: userModel.isPersonalDetailShow,
      accountType: userModel.userType,
      additionalInfo: _coerceAdditionalInfo(userModel.additionalInfo),
    );
  }

  Widget buildSellerCard(UserModel seller) {
    final Map<String, dynamic>? additionalInfo =
        _coerceAdditionalInfo(seller.additionalInfo);
    final Map<String, dynamic>? contactInfo =
        _contactInfoFromAdditional(additionalInfo ?? seller.additionalInfo);
    final Map<String, dynamic>? storeData = _cloneMap(seller.store);
    final String? storeIdentifier = _extractStoreIdentifier(storeData);
    String? businessLogo;
    String? businessName = seller.name;
    final seller_category_utils.SellerCategoryIdentifiers sellerCategories =
        seller_category_utils.extractSellerCategoryIdentifiers(contactInfo);
    final dynamic sellerCategoryPayload = sellerCategories.toRoutePayload();

    if (contactInfo != null) {
      if (seller.userType == Constant.accountTypeSeller) {
        final dynamic logo = contactInfo['business_logo'];
        if (logo is String && logo.trim().isNotEmpty) {
          businessLogo = logo.trim();
        }
        final dynamic name = contactInfo['business_name'];
        if (name is String && name.trim().isNotEmpty) {
          businessName = name.trim();
        }
      } else if (seller.userType == Constant.accountTypeRealEstate) {
        final dynamic logo = contactInfo['office_logo'];
        if (logo is String && logo.trim().isNotEmpty) {
          businessLogo = logo.trim();
        }
        final dynamic name = contactInfo['office_name'];
        if (name is String && name.trim().isNotEmpty) {
          businessName = name.trim();
        }
      }
    }

    if ((businessName?.trim().isNotEmpty ?? false) == false) {
      businessName = _stringValue(storeData?['name']) ?? businessName;
    }

    final String? storeImageUrl = _normalizeImageUrl(_resolveStoreImagePath(
      contactInfo,
      additionalInfo,
      businessLogo,
      seller.profile,
      storeData,
    ));
    final _StoreAvailabilityStatus availability =
        _resolveStoreAvailabilityStatus(
      contactInfo: contactInfo,
      additionalInfo: additionalInfo,
    );

    return GestureDetector(
      onTap: () {
        if (seller.userType == Constant.accountTypeSeller &&
            seller.id != null) {
          final String displayName = (businessName?.trim().isNotEmpty ?? false)
              ? businessName!.trim()
              : (seller.name ?? '');
          final String storeCategoryId =
              Constant.storeRootCategoryIdAsString;


          Navigator.pushNamed(context, Routes.section_screen, arguments: {
            'catID': storeCategoryId,
            'catName': displayName,
            'categoryIds': [storeCategoryId],
            'interfaceType': 'e_store',
            'sellerId': seller.id,
            if (storeIdentifier != null) 'storeId': storeIdentifier,
            if (storeData != null && storeData.isNotEmpty)
              'storeSnapshot': storeData,
            if (sellerCategoryPayload != null)
              'sellerCategoryIds': sellerCategoryPayload,
          });
          return;
        }

        Navigator.pushNamed(context, Routes.sellerProfileScreen, arguments: {
          "model": userModelToUser(seller),
        });
      },
      child: Container(
        margin: const EdgeInsets.all(8.0),
        height: 170,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8.0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12.0),
          child: Stack(
            children: [
              Positioned.fill(
                child: Container(color: context.color.territoryColor),
              ),
              Positioned.fill(
                child: _buildStoreImage(storeImageUrl),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.center,
                      colors: [
                        Colors.black.withOpacity(0.75),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              if (availability.primaryLabel != null)
                Positioned(
                  top: 10,
                  left: 10,
                  child: _buildStatusChip(availability),
                ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      (businessName ?? '').isNotEmpty
                          ? businessName!
                          : seller.name ?? '',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (availability.secondaryLabel != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          availability.secondaryLabel!,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 11,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Map<String, dynamic>? _coerceAdditionalInfo(dynamic raw) {
    return seller_category_utils.coerceAdditionalInfo(raw);
  }

  Map<String, dynamic>? _contactInfoFromAdditional(dynamic raw) {
    return seller_category_utils.extractContactInfo(raw);
  }

  Widget _buildStoreImage(String? imageUrl) {
    if (imageUrl == null) {
      return Image.asset(
        'assets/svg/Logo/Logo-13.png',
        fit: BoxFit.cover,
      );
    }

    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Image.asset(
        'assets/svg/Logo/Logo-13.png',
        fit: BoxFit.cover,
      ),
    );
  }

  Widget _buildStatusChip(_StoreAvailabilityStatus status) {
    final Color background =
        status.statusColor ?? Colors.black.withOpacity(0.7);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(
        status.primaryLabel ?? '',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String? _resolveStoreImagePath(
    Map<String, dynamic>? contactInfo,
    Map<String, dynamic>? additionalInfo,
    String? businessLogo,
    String? fallbackProfile,
    Map<String, dynamic>? storeData,
  ) {
    final List<String?> candidates = <String?>[
      _stringValue(contactInfo?['store_cover']),
      _stringValue(contactInfo?['store_image']),
      _stringValue(contactInfo?['store_photo']),
      _stringValue(contactInfo?['business_cover']),
      _stringValue(contactInfo?['storefront']),
      _stringValue(contactInfo?['business_logo']),
      _stringValue(additionalInfo?['store_cover']),
      _stringValue(additionalInfo?['business_logo']),
      _stringValue(storeData?['banner_url']),
      _stringValue(storeData?['bannerUrl']),
      _stringValue(storeData?['banner_path']),
      _stringValue(storeData?['logo_path']),
      _stringValue(storeData?['logo_url']),
      _stringValue(storeData?['logoUrl']),
      _stringValue(businessLogo),
      _stringValue(fallbackProfile),
    ];

    for (final String? candidate in candidates) {
      if (candidate != null && candidate.trim().isNotEmpty) {
        return candidate.trim();
      }
    }

    return null;
  }

  String? _normalizeImageUrl(String? path) {
    if (path == null || path.isEmpty) {
      return null;
    }
    final String trimmed = path.trim();
    if (trimmed.startsWith('http')) {
      return trimmed;
    }
    final String normalized =
        trimmed.startsWith('/') ? trimmed.substring(1) : trimmed;
    return 'https://marib.app/$normalized';
  }

  String? _stringValue(dynamic value) {
    if (value == null) {
      return null;
    }
    final String normalized = value.toString().trim();
    return normalized.isEmpty ? null : normalized;
  }

  String? _extractStoreIdentifier(Map<String, dynamic>? storeData) {
    if (storeData == null || storeData.isEmpty) {
      return null;
    }
    final String? numericId =
        _normalizeNumericIdentifier(storeData['id'] ?? storeData['store_id']);
    if (numericId != null) {
      return numericId;
    }
    return _normalizeSlugIdentifier(storeData['slug']);
  }

  bool _sellerMatchesQuery(UserModel seller, String query) {
    final Map<String, dynamic>? additionalInfo =
        _coerceAdditionalInfo(seller.additionalInfo);
    final Map<String, dynamic>? contactInfo =
        _contactInfoFromAdditional(additionalInfo ?? seller.additionalInfo);
    final Map<String, dynamic>? storeData = _cloneMap(seller.store);

    String? businessName = _stringValue(contactInfo?['business_name']) ??
        _stringValue(contactInfo?['office_name']) ??
        _stringValue(contactInfo?['store_name']);
    businessName ??= _stringValue(storeData?['name']);

    final List<String?> candidates = <String?>[
      businessName,
      _stringValue(seller.name),
      _stringValue(seller.email),
      _stringValue(seller.mobile),
      _stringValue(storeData?['slug']),
      _stringValue(contactInfo?['business_category']),
      _stringValue(contactInfo?['office_category']),
      _stringValue(additionalInfo?['category']),
    ];

    for (final String? value in candidates) {
      if (value != null && value.toLowerCase().contains(query)) {
        return true;
      }
    }

    return false;
  }

  String? _normalizeNumericIdentifier(dynamic raw) {
    if (raw == null) {
      return null;
    }
    if (raw is num) {
      final int value = raw.toInt();
      return value > 0 ? value.toString() : null;
    }
    if (raw is String) {
      final String trimmed = raw.trim();
      if (trimmed.isEmpty) {
        return null;
      }
      final int? parsed = int.tryParse(trimmed);
      return parsed != null && parsed > 0 ? parsed.toString() : null;
    }
    return null;
  }

  String? _normalizeSlugIdentifier(dynamic raw) {
    if (raw == null) {
      return null;
    }
    if (raw is String) {
      final String trimmed = raw.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    return null;
  }

  _StoreAvailabilityStatus _resolveStoreAvailabilityStatus({
    required Map<String, dynamic>? contactInfo,
    required Map<String, dynamic>? additionalInfo,
  }) {
    final String? openingRaw = _stringValue(
      contactInfo?['opening_time'] ?? additionalInfo?['opening_time'],
    );
    final String? closingRaw = _stringValue(
      contactInfo?['closing_time'] ?? additionalInfo?['closing_time'],
    );

    if (openingRaw == null || closingRaw == null) {
      return _StoreAvailabilityStatus(
        hasSchedule: false,
        isOpenNow: false,
        primaryLabel: 'ساعات العمل غير متاحة',
        secondaryLabel: null,
        statusColor: Colors.black54,
      );
    }

    final List<String> openingParts = openingRaw.split(':');
    final List<String> closingParts = closingRaw.split(':');
    if (openingParts.isEmpty || closingParts.isEmpty) {
      return _StoreAvailabilityStatus(
        hasSchedule: false,
        isOpenNow: false,
        primaryLabel: 'ساعات العمل غير متاحة',
        statusColor: Colors.black54,
      );
    }

    final int? openingHour = int.tryParse(openingParts[0]);
    final int openingMinute =
        openingParts.length > 1 ? int.tryParse(openingParts[1]) ?? 0 : 0;
    final int? closingHour = int.tryParse(closingParts[0]);
    final int closingMinute =
        closingParts.length > 1 ? int.tryParse(closingParts[1]) ?? 0 : 0;

    if (openingHour == null || closingHour == null) {
      return _StoreAvailabilityStatus(
        hasSchedule: false,
        isOpenNow: false,
        primaryLabel: 'ساعات العمل غير متاحة',
        statusColor: Colors.black54,
      );
    }

    final bool open24Hours =
        openingHour == closingHour && openingMinute == closingMinute;
    if (open24Hours) {
      return _StoreAvailabilityStatus(
        hasSchedule: true,
        isOpenNow: true,
        primaryLabel: 'متاح 24 ساعة',
        secondaryLabel: null,
        statusColor: Colors.green.shade600,
      );
    }

    final DateTime now = DateTime.now();
    DateTime openingTime =
        DateTime(now.year, now.month, now.day, openingHour, openingMinute);
    DateTime closingTime =
        DateTime(now.year, now.month, now.day, closingHour, closingMinute);

    if (!closingTime.isAfter(openingTime)) {
      closingTime = closingTime.add(const Duration(days: 1));
    }

    final bool isOpenNow =
        !now.isBefore(openingTime) && now.isBefore(closingTime);
    DateTime nextReference;
    String secondaryLabel;
    final DateFormat formatter = DateFormat('h:mm a', 'ar');

    if (isOpenNow) {
      nextReference = closingTime;
      secondaryLabel = 'يغلق عند ${formatter.format(nextReference)}';
    } else {
      if (now.isBefore(openingTime)) {
        nextReference = openingTime;
      } else {
        openingTime = openingTime.add(const Duration(days: 1));
        nextReference = openingTime;
      }
      secondaryLabel = 'يفتح عند ${formatter.format(nextReference)}';
    }

    return _StoreAvailabilityStatus(
      hasSchedule: true,
      isOpenNow: isOpenNow,
      primaryLabel: isOpenNow ? 'مفتوح الآن' : 'مغلق حالياً',
      secondaryLabel: secondaryLabel,
      statusColor:
          isOpenNow ? Colors.green.shade600 : Colors.redAccent.shade200,
    );
  }

  Map<String, dynamic>? _cloneMap(Map<String, dynamic>? source) {
    if (source == null) {
      return null;
    }
    return Map<String, dynamic>.from(source);
  }
}

class _StoreAvailabilityStatus {
  const _StoreAvailabilityStatus({
    required this.hasSchedule,
    required this.isOpenNow,
    this.primaryLabel,
    this.secondaryLabel,
    this.statusColor,
  });

  final bool hasSchedule;
  final bool isOpenNow;
  final String? primaryLabel;
  final String? secondaryLabel;
  final Color? statusColor;
}
