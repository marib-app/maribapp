import 'package:marib/data/model/user_model.dart';
import 'dart:async';

import 'package:marib/data/cubits/item/fetch_item_from_category_cubit.dart';
import 'package:marib/ui/screens/sliders/slider_widget.dart';
import 'package:marib/ui/theme/theme.dart';
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
import 'dart:convert';

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
                  child: NoDataFound(onTap: () {
                    context
                        .read<FetchSellersCubit>()
                        .fetchSellers(accountType: 3);
                  }),
                );
              }
              return buildCardList(state.sellers);
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

  Widget buildCardList(List<UserModel> sellers) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          int firstItemIndex = index * 2;
          int? secondItemIndex =
              (firstItemIndex + 1 < sellers.length) ? firstItemIndex + 1 : null;

          return Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Expanded(
                child: buildSellerCard(sellers[firstItemIndex]),
              ),
              if (secondItemIndex != null)
                Expanded(
                  child: buildSellerCard(sellers[secondItemIndex]),
                )
              else
                Expanded(child: Container()),
            ],
          );
        },
        childCount: (sellers.length / 2).ceil(),
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
    final Map<String, dynamic>? contactInfo =
        _contactInfoFromAdditional(seller.additionalInfo);
    String? businessLogo;
    String? businessName = seller.name;

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

    return GestureDetector(
      onTap: () {
        if (seller.userType == Constant.accountTypeSeller &&
            seller.id != null) {
          final String displayName = (businessName?.trim().isNotEmpty ?? false)
              ? businessName!.trim()
              : (seller.name ?? '');

          Navigator.pushNamed(context, Routes.section_screen, arguments: {
            'catID': Constant.storeRootCategoryId.toString(),
            'catName': displayName,
            'categoryIds': [Constant.storeRootCategoryId.toString()],
            'interfaceType': 'e_store',
            'sellerId': seller.id,
          });
          return;
        }

        Navigator.pushNamed(context, Routes.sellerProfileScreen, arguments: {
          "model": userModelToUser(seller),
        });
      },
      child: Container(
        margin: EdgeInsets.all(8.0),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                color: context.color.territoryColor,
                borderRadius: BorderRadius.circular(12.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8.0,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              height: 150,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // عرض اسم المتجر في الأسفل
                  Container(
                    width: double.infinity,
                    padding:
                        EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(12.0),
                        bottomRight: Radius.circular(12.0),
                      ),
                    ),
                    child: Text(
                      businessName ?? '',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 8,
              left: 8,
              right: 8,
              bottom: 35,
              // اترك مساحة لاسم المتجر
              child: (businessLogo != null && businessLogo.isNotEmpty)
                  ? Image.network(
                      "https://marib.app/${businessLogo}",
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Image.asset(
                        'assets/svg/Logo/Logo-13.png',
                        height: 100,
                        width: 300,
                        fit: BoxFit.contain,
                      ),
                    )
                  : Image.asset(
                      'assets/svg/Logo/Logo-13.png',
                      height: 100,
                      width: 300,
                      fit: BoxFit.contain,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic>? _coerceAdditionalInfo(dynamic raw) {
    if (raw == null) {
      return null;
    }

    if (raw is Map<String, dynamic>) {
      return Map<String, dynamic>.from(raw);
    }

    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
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
          return decoded.map((key, value) => MapEntry(key.toString(), value));
        }
      } catch (_) {
        return null;
      }
    }

    return null;
  }

  Map<String, dynamic>? _contactInfoFromAdditional(dynamic raw) {
    final Map<String, dynamic>? info = _coerceAdditionalInfo(raw);
    if (info == null) {
      return null;
    }
    final dynamic contact = info['contact_info'];
    if (contact is Map<String, dynamic>) {
      return Map<String, dynamic>.from(contact);
    }
    if (contact is Map) {
      return contact.map((key, value) => MapEntry(key.toString(), value));
    }
    return null;
  }
}
