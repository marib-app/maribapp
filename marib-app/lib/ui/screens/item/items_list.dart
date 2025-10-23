import 'dart:async';
import 'dart:math';

import 'package:marib/app/routes.dart';
import 'package:marib/data/cubits/item/fetch_item_from_category_cubit.dart';
import 'package:marib/ui/screens/sliders/slider_widget.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/constant.dart';
import 'package:marib/utils/hive_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'package:marib/utils/app_icon.dart';
import 'package:marib/utils/sliver_grid_delegate_with_fixed_cross_axis_count_and_fixed_height.dart';
import 'package:marib/data/model/item/item_model.dart';
import 'package:marib/data/model/item_filter_model.dart';

import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/api.dart';

import 'package:marib/utils/responsiveSize.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:marib/ui/screens/item/cards/sections_adapter.dart';
import 'package:marib/ui/screens/widgets/errors/no_data_found.dart';
import 'package:marib/ui/screens/item/cards/horizontal_card.dart';
import 'package:marib/ui/screens/settings/main_activity.dart';
import 'package:marib/ui/screens/native_ads_screen.dart';
import 'package:marib/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:marib/ui/screens/widgets/shimmerLoadingContainer.dart';
import 'package:marib/ui/widgets/slivers/catalog_scroll_view.dart';
import 'package:marib/ui/widgets/slivers/catalog_section.dart';
class ItemsList extends StatefulWidget {
  final String categoryId, categoryName;
  final List<String> categoryIds;
  final String interfaceType;

  const ItemsList(
      {super.key,
        required this.categoryId,
        required this.categoryName,
        required this.categoryIds,
        required this.interfaceType});

  @override
  ItemsListState createState() => ItemsListState();

  static Route route(RouteSettings routeSettings) {
    Map? arguments = routeSettings.arguments as Map?;
    return BlurredRouter(
      builder: (_) => ItemsList(
        categoryId: arguments?['catID'] as String,
        categoryName: arguments?['catName'],
        categoryIds: arguments?['categoryIds'],
        interfaceType: arguments?['interfaceType'],
      ),
    );
  }
}

class ItemsListState extends State<ItemsList> {

  static const double _listItemExtent = 152;
  static const double _gridMainAxisSpacing = 12;
  static const double _gridCrossAxisSpacing = 12;





  late ScrollController controller;
  static TextEditingController searchController = TextEditingController();
  bool isFocused = false;
  bool isList = false;
  String previousSearchQuery = "";
  Timer? _searchDelay;
  String? sortBy;
  ItemFilterModel? filter;

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
          // Remove location filtering to show all items regardless of location
          // country: HiveUtils.getCountryName() ?? "",
          // areaId: HiveUtils.getAreaId() != null
          //     ? int.parse(HiveUtils.getAreaId().toString())
          //     : null,
          // city: HiveUtils.getCityName() ?? "",
          // state: HiveUtils.getStateName() ?? "",
          categoryId: widget.categoryId,
          // radius: HiveUtils.getNearbyRadius() ?? null,
          // latitude: HiveUtils.getLatitude() ?? null,
          // longitude: HiveUtils.getLongitude() ?? null
        ));

    Future.delayed(Duration.zero, () {
      selectedcategoryId = widget.categoryId;
      selectedcategoryName = widget.categoryName;
      searchbody[Api.categoryId] = widget.categoryId;
      setState(() {});
    });
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
    // if (searchController.text.isNotEmpty) {
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
              // Remove location filtering for loading more items
              // country: HiveUtils.getCountryName() ?? "",
              // areaId: HiveUtils.getAreaId() != null
              //     ? int.parse(HiveUtils.getAreaId().toString())
              //     : null,
              // city: HiveUtils.getCityName() ?? "",
              // state: HiveUtils.getStateName() ?? "",
              categoryId: widget.categoryId,
            ));
      }
    }
  }

  Widget searchBarWidget() {
    return Container(
      height: 56.rh(context),
      color: context.color.secondaryColor,
      child: LayoutBuilder(builder: (context, c) {
        return SizedBox(
            width: c.maxWidth,
            child: FittedBox(
              fit: BoxFit.none,
              child: Padding(
                padding:
                const EdgeInsets.symmetric(vertical: 14, horizontal: 18.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                        width: 243.rw(context),
                        height: 40.rh(context),
                        alignment: AlignmentDirectional.center,
                        decoration: BoxDecoration(
                            border: Border.all(
                                width: 1,
                                color: context.color.borderColor.darken(30)),
                            borderRadius:
                            const BorderRadius.all(Radius.circular(10)),
                            color: context.color.primaryColor),
                        child: TextFormField(
                            controller: searchController,
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                  vertical: 10, horizontal: 8),
                              //OutlineInputBorder()
                              fillColor:
                              Theme.of(context).colorScheme.primaryColor,
                              hintText: "searchHintLbl".translate(context),
                              prefixIcon: setSearchIcon(),
                              prefixIconConstraints: const BoxConstraints(
                                  minHeight: 5, minWidth: 5),
                            ),
                            enableSuggestions: true,
                            onEditingComplete: () {
                              setState(
                                    () {
                                  isFocused = false;
                                  FocusScope.of(context).unfocus();
                                },
                              );
                              print("onediting");
                            },
                            onTap: () {
                              //change prefix icon color to primary
                              setState(() {
                                isFocused = true;
                              });
                            })),
                    const SizedBox(
                      width: 8,
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          isList = false;
                        });
                      },
                      child: Container(
                        width: 40.rw(context),
                        height: 40.rh(context),
                        decoration: BoxDecoration(
                          border: Border.all(
                              width: 1,
                              color: context.color.borderColor.darken(30)),
                          color: context.color.secondaryColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: UiUtils.getSvg(AppIcons.gridViewIcon,
                              color: !isList
                                  ? context.color.textDefaultColor
                                  : context.color.textDefaultColor
                                  .withOpacity(0.2)),
                        ),
                      ),
                    ),
                    const SizedBox(
                      width: 8,
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          isList = true;
                        });
                      },
                      child: Container(
                        width: 40.rw(context),
                        height: 40.rh(context),
                        decoration: BoxDecoration(
                          border: Border.all(
                              width: 1,
                              color: context.color.borderColor.darken(30)),
                          color: context.color.secondaryColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: UiUtils.getSvg(AppIcons.listViewIcon,
                              color: isList
                                  ? context.color.textDefaultColor
                                  : context.color.textDefaultColor
                                  .withOpacity(0.2)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ));
      }),
    );
  }

  Widget setSearchIcon() {
    return Padding(
        padding: const EdgeInsets.all(8.0),
        child: UiUtils.getSvg(AppIcons.search,
            color: context.color.textDefaultColor));
  }

  Widget setSuffixIcon() {
    return GestureDetector(
      onTap: () {
        searchController.clear();
        isFocused = false; //set icon color to black back
        FocusScope.of(context).unfocus(); //dismiss keyboard
        setState(() {});
      },
      child: Icon(
        Icons.close_rounded,
        color: Theme.of(context).colorScheme.blackColor,
        size: 30,
      ),
    );
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
          bottomNavigationBar: bottomWidget(),
          body: BlocBuilder<FetchItemFromCategoryCubit,
              FetchItemFromCategoryState>(
            builder: (context, state) {
              final sections = _buildSectionsForState(context, state);

              return RefreshIndicator(
                onRefresh: () async {
                  searchbody = {};
                  Constant.itemFilter = null;

                  context
                      .read<FetchItemFromCategoryCubit>()
                      .fetchItemFromCategory(
                    categoryId: int.parse(widget.categoryId),
                    search: "",
                  );
                },
                color: context.color.territoryColor,
                child: CatalogScrollView(
                  controller: controller,

                  sections: sections,
                ),
              );
            },

          ),
        ),
      ),
    );
  }

  Container bottomWidget() {
    return Container(
      color: context.color.secondaryColor,
      padding: EdgeInsets.only(top: 3, bottom: 3),
      height: 45,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          filterByWidget(),
          VerticalDivider(
            color: context.color.borderColor.darken(50),
          ),
          // Add a vertical divider here
          sortByWidget(),
        ],
      ),
    );
  }

  Widget filterByWidget() {
    return InkWell(
      child: Row(
        children: [
          UiUtils.getSvg(AppIcons.filterByIcon,
              color: context.color.textDefaultColor),
          SizedBox(
            width: 7,
          ),
          Text("filterTitle".translate(context))
        ],
      ),
      onTap: () {
        Navigator.pushNamed(context, Routes.filterScreen, arguments: {
          "update": getFilterValue,
          "from": "itemsList",
          "categoryIds": widget.categoryIds
        }).then((value) {
          if (value == true) {
            ItemFilterModel updatedFilter =
            filter!.copyWith(categoryId: widget.categoryId);
            context.read<FetchItemFromCategoryCubit>().fetchItemFromCategory(
                categoryId: int.parse(
                  widget.categoryId,
                ),
                search: searchController.text.toString(),
                filter: updatedFilter);
          }
          setState(() {});
        });
      },
    );
  }

  getFilterValue(ItemFilterModel model) {
    filter = model;
    setState(() {});
  }

  Widget sortByWidget() {
    return InkWell(
      child: Row(
        children: [
          UiUtils.getSvg(AppIcons.sortByIcon,
              color: context.color.textDefaultColor),
          SizedBox(
            width: 7,
          ),
          Text("sortBy".translate(context))
        ],
      ),
      onTap: () {
        showSortByBottomSheet();
      },
    );
  }

  showSortByBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(8.0),
          topRight: Radius.circular(8.0),
        ),
      ),
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: context.color.secondaryColor,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
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
                  'sortBy'.translate(context),
                  textAlign: TextAlign.start,
                ).bold(weight: FontWeight.bold).size(context.font.large),
              ),

              Divider(height: 1), // Add some space between title and options
              ListTile(
                contentPadding: EdgeInsets.symmetric(horizontal: 20),
                title: Text('default'.translate(context)),
                onTap: () {
                  Navigator.pop(context);
                  context
                      .read<FetchItemFromCategoryCubit>()
                      .fetchItemFromCategory(
                      categoryId: int.parse(
                        widget.categoryId,
                      ),
                      search: searchController.text.toString(),
                      sortBy: null);

                  setState(() {
                    sortBy = null;
                    print("isfocus$isFocused");

                    FocusManager.instance.primaryFocus?.unfocus();
                  });

                  // Handle option 1 selection
                },
              ),
              Divider(height: 1), // Divider between option 1 and option 2
              ListTile(
                contentPadding: EdgeInsets.symmetric(horizontal: 20),
                title: Text('newToOld'.translate(context)),
                onTap: () {
                  Navigator.pop(context);
                  context
                      .read<FetchItemFromCategoryCubit>()
                      .fetchItemFromCategory(
                      categoryId: int.parse(
                        widget.categoryId,
                      ),
                      search: searchController.text.toString(),
                      sortBy: "new-to-old");
                  setState(() {
                    sortBy = "new-to-old";
                    FocusManager.instance.primaryFocus?.unfocus();
                  });
                },
              ),
              Divider(height: 1), // Divider between option 2 and option 3
              ListTile(
                contentPadding: EdgeInsets.symmetric(horizontal: 20),
                title: Text('oldToNew'.translate(context)),
                onTap: () {
                  Navigator.pop(context);
                  context
                      .read<FetchItemFromCategoryCubit>()
                      .fetchItemFromCategory(
                      categoryId: int.parse(
                        widget.categoryId,
                      ),
                      search: searchController.text.toString(),
                      sortBy: "old-to-new");
                  setState(() {
                    sortBy = "old-to-new";
                    FocusManager.instance.primaryFocus?.unfocus();
                  });
                },
              ),
              Divider(height: 1), // Divider between option 3 and option 4
              ListTile(
                contentPadding: EdgeInsets.symmetric(horizontal: 20),
                title: Text('priceHighToLow'.translate(context)),
                onTap: () {
                  Navigator.pop(context);
                  context
                      .read<FetchItemFromCategoryCubit>()
                      .fetchItemFromCategory(
                      categoryId: int.parse(
                        widget.categoryId,
                      ),
                      search: searchController.text.toString(),
                      sortBy: "price-high-to-low");
                  setState(() {
                    sortBy = "price-high-to-low";
                    FocusManager.instance.primaryFocus?.unfocus();
                  });
                },
              ),
              Divider(height: 1), // Divider between option 4 and option 5
              ListTile(
                contentPadding: EdgeInsets.symmetric(horizontal: 20),
                title: Text('priceLowToHigh'.translate(context)),
                onTap: () {
                  Navigator.pop(context);
                  context
                      .read<FetchItemFromCategoryCubit>()
                      .fetchItemFromCategory(
                      categoryId: int.parse(
                        widget.categoryId,
                      ),
                      search: searchController.text.toString(),
                      sortBy: "price-low-to-high");
                  setState(() {
                    sortBy = "price-low-to-high";
                    FocusManager.instance.primaryFocus?.unfocus();
                  });
                },
              ),
            ],
          ),
        );
      },
    );
  }

  List<CatalogSection> _buildSectionsForState(
      BuildContext context, FetchItemFromCategoryState state) {
    final sections = <CatalogSection>[
      CatalogBoxSection(
        key: const ValueKey('items_slider_section'),
        child: SliderWidget(
          interfaceType: widget.interfaceType,
        ),
      ),
      _buildSearchHeaderSection(context),
    ];

    if (state is FetchItemFromCategoryInProgress ||
        state is FetchItemFromCategoryInitial) {
      sections.addAll(_buildLoadingSections(context));
      return sections;
    }

    if (state is FetchItemFromCategoryFailure) {
      sections.add(_buildFailureSection(context, state.errorMessage));
      return sections;
    }

    if (state is FetchItemFromCategorySuccess) {
      final List<ItemModel> skeletons = state.itemSkeletons;

      if (skeletons.isEmpty) {

        sections.add(_buildEmptySection(context));
      } else {
        sections.addAll(_buildSuccessSections(context, skeletons));
      }

      if (state.isLoadingMore) {
        sections.add(_buildLoadingMoreSection(context));
      } else if (state.loadingMoreError) {
        sections.add(_buildLoadMoreErrorSection(context));
      }

      return sections;
    }

    return sections;
  }

  CatalogSection _buildSearchHeaderSection(BuildContext context) {
    final double headerHeight = 56.rh(context) + 24;

    return CatalogPersistentHeaderSection(
      key: const ValueKey('items_search_header'),
      pinned: true,
      delegate: _PinnedHeaderDelegate(
        height: headerHeight,
        child: ColoredBox(
          color: context.color.secondaryColor,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: searchBarWidget(),
          ),
        ),
      ),
    );
  }

  List<CatalogSection> _buildLoadingSections(BuildContext context) {
    return [
      CatalogListSection(
        key: const ValueKey('items_loading_shimmer'),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        itemCount: 5,
        itemExtent: _listItemExtent,
        addAutomaticKeepAlives: false,
        addRepaintBoundaries: false,
        itemBuilder: (context, index) => _buildShimmerTile(context),
      ),
    ];
  }

  List<CatalogSection> _buildSuccessSections(
      BuildContext context, List<ItemModel> items) {
    final sections = <CatalogSection>[];
    final int step = max(1, Constant.nativeAdsAfterItemNumber);

    for (int start = 0; start < items.length; start += step) {
      final int count = min(step, items.length - start);

      if (isList) {
        sections.add(_buildListSection(context, items, start, count));

      } else {
        sections.add(_buildGridSection(context, items, start, count));

      }

      final int nextIndex = start + count;
      if (nextIndex < items.length) {
        sections.add(_buildAdSection(nextIndex));
      }
    }

    return sections;

  }

  CatalogSection _buildListSection(
      BuildContext context,
      List<ItemModel> items,
      int start,
      int count,
      ) {
    return CatalogListSection(
      key: ValueKey('items_list_${isList}_$start'),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 3),
      itemCount: count,
      itemExtent: _listItemExtent,
      itemBuilder: (context, localIndex) {
        final int globalIndex = start + localIndex;
        final ItemModel item = items[globalIndex];
        final Key cardKey = ValueKey(item.id ?? 'list_$globalIndex');
        return GestureDetector(
          onTap: () => _navigateToDetails(context, item),
          child: ItemHorizontalCard(
            key: cardKey,
            item: item,
          ),
        );
      },
    );
  }

  CatalogSection _buildGridSection(
      BuildContext context,
      List<ItemModel> items,
      int start,
      int count,
      ) {
    return CatalogGridSection(
      key: ValueKey('items_grid_${isList}_$start'),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
      itemCount: count,


      gridDelegate: SliverGridDelegateWithFixedCrossAxisCountAndFixedHeight(
        crossAxisCount: 2,
        height: _gridItemHeight(context),
        mainAxisSpacing: _gridMainAxisSpacing,
        crossAxisSpacing: _gridCrossAxisSpacing,
      ),
      itemBuilder: (context, localIndex) {
        final int globalIndex = start + localIndex;
        final ItemModel item = items[globalIndex];
        final Key cardKey = ValueKey(item.id ?? 'grid_$globalIndex');

        return ICard(
          key: cardKey,
          item: item,
        );
      },
    );
  }

  CatalogSection _buildAdSection(int index) {
    return CatalogBoxSection(
      key: ValueKey('items_native_ad_$index'),
      child: NativeAdWidget(
        key: ValueKey('native_ad_widget_$index'),
        type: TemplateType.medium,
      ),
    );
  }

  CatalogSection _buildEmptySection(BuildContext context) {
    return CatalogSliverSection(
      key: const ValueKey('items_empty_state'),
      sliver: SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: NoDataFound(
            onTap: _retryInitialFetch,
            category: EmptyStateCategory.items,
          ),
        ),
      ),
    );
  }

  CatalogSection _buildFailureSection(BuildContext context, String message) {
    final String effectiveMessage = message.isEmpty
        ? 'somethingWentWrong'.translate(context)
        : message;

    return CatalogSliverSection(
      key: const ValueKey('items_failure_state'),
      sliver: SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              effectiveMessage,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }

  CatalogSection _buildLoadingMoreSection(BuildContext context) {
    return CatalogBoxSection(
      key: const ValueKey('items_loading_more'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: UiUtils.progress(
            normalProgressColor: context.color.territoryColor,
          ),
        ),
      ),
    );
  }

  CatalogSection _buildLoadMoreErrorSection(BuildContext context) {
    return CatalogBoxSection(
      key: const ValueKey('items_loading_more_error'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        child: Text(
          'somethingWentWrong'.translate(context),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildShimmerTile(BuildContext context) {

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Container(
        height: 120.rh(context),
        decoration: BoxDecoration(
          border: Border.all(width: 1.5, color: context.color.borderColor),
          color: context.color.secondaryColor,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            CustomShimmer(
              height: 120.rh(context),
              width: 100.rw(context),
            ),
            SizedBox(
              width: 10.rw(context),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                CustomShimmer(
                  width: 100.rw(context),
                  height: 10,
                  borderRadius: 7,
                ),
                CustomShimmer(
                  width: 150.rw(context),
                  height: 10,
                  borderRadius: 7,
                ),
                CustomShimmer(
                  width: 120.rw(context),
                  height: 10,
                  borderRadius: 7,
                ),
                CustomShimmer(
                  width: 80.rw(context),
                  height: 10,
                  borderRadius: 7,
                ),
              ],
            )
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

  void _retryInitialFetch() {
    context.read<FetchItemFromCategoryCubit>().fetchItemFromCategory(
      categoryId: int.parse(widget.categoryId),
      search: searchController.text.toString(),
    );
  }

  double _gridItemHeight(BuildContext context) => 220.rh(context);
}

class _PinnedHeaderDelegate extends SliverPersistentHeaderDelegate {
  _PinnedHeaderDelegate({required this.child, required this.height});

  final Widget child;
  final double height;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(_PinnedHeaderDelegate oldDelegate) {
    return oldDelegate.child != child || oldDelegate.height != height;
  }


}
