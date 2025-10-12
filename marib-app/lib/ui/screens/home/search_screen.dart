import 'dart:async';
import 'dart:convert';

import 'package:marib/app/app_theme.dart';
import 'package:marib/app/routes.dart';
import 'package:marib/data/cubits/item/search_item_cubit.dart';
import 'package:marib/data/cubits/system/app_theme_cubit.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/constant.dart';
import 'package:marib/utils/hive_keys.dart';
import 'package:marib/data/cubits/item/fetch_popular_items_cubit.dart';

import 'package:marib/data/model/category_model.dart';
import 'package:marib/data/model/item_filter_model.dart';

import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/adapters.dart';


import 'package:marib/data/model/item/item_model.dart';

import 'package:marib/ui/screens/widgets/errors/no_data_found.dart';
import 'package:marib/ui/screens/widgets/errors/no_internet.dart';
import 'package:marib/ui/screens/widgets/shimmerLoadingContainer.dart';
import 'package:marib/ui/screens/item/cards/horizontal_card.dart';
import 'package:marib/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:marib/ui/screens/widgets/errors/something_went_wrong.dart';
import 'package:marib/utils/app_icon.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/responsiveSize.dart';
import 'package:flutter/material.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:marib/ui/widgets/slivers/catalog_scroll_view.dart';
import 'package:marib/ui/widgets/slivers/catalog_section.dart';

import 'package:flutter/foundation.dart';





class SearchScreen extends StatefulWidget {
  final bool autoFocus;

  const SearchScreen({
    super.key,
    required this.autoFocus,
  });

  static Route route(RouteSettings settings) {
    Map? arguments = settings.arguments as Map?;

    return BlurredRouter(
      builder: (context) => MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (context) => SearchItemCubit(),
            ),
            BlocProvider(
              create: (context) => FetchPopularItemsCubit(),
            ),
          ],
          child: SearchScreen(
            autoFocus: arguments?['autoFocus'],
          )),
    );
  }

  @override
  SearchScreenState createState() => SearchScreenState();
}

class SearchScreenState extends State<SearchScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin<SearchScreen> {
  static const double _listItemExtent = 160;
  static const double sidePadding = Constant.defaultPadding;

  @override
  bool get wantKeepAlive => true;
  bool isFocused = false;
  String previousSearchQuery = "";
  static TextEditingController searchController = TextEditingController();
  late final ScrollController _scrollController;
  late final _SearchDebounceCoordinator _debounce;
  ItemFilterModel? filter;

  //to store selected filter categories
  List<CategoryModel> categoryList = [];

  @override
  void initState() {
    super.initState();
    Constant.itemFilter = null;
    context.read<FetchPopularItemsCubit>().fetchPopularItems();
    // context.read<ItemCubit>().fetchItem(context, {});
    //context.read<SearchItemCubit>().searchItem("", page: 1);

    _debounce = _SearchDebounceCoordinator(
      Duration(milliseconds: 500),
    );

    searchController = TextEditingController();

    searchController.addListener(searchItemListener);
    _scrollController = ScrollController()..addListener(_handleScroll);
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) {
      return;
    }

    final position = _scrollController.position;
    if (!position.hasPixels || position.maxScrollExtent <= 0) {
      return;
    }

    final double triggerOffset = position.maxScrollExtent * 0.75;
    if (position.pixels < triggerOffset) {
      return;
    }

    final searchCubit = context.read<SearchItemCubit>();
    final searchState = searchCubit.state;
    if (_shouldShowSearchSections(searchState)) {
      if (!searchCubit.hasMoreData()) {
        return;
      }

      _debounce.run(_DebounceScope.scroll, () {
        searchCubit.fetchMoreSearchData(searchController.text, filter);
      });
      return;
    }

    final popularCubit = context.read<FetchPopularItemsCubit>();
    if (!popularCubit.hasMoreData()) {
      return;
    }

    if (popularCubit.state is FetchPopularItemsSuccess &&
        (popularCubit.state as FetchPopularItemsSuccess).isLoadingMore) {
      return;
    }

    _debounce.run(_DebounceScope.scroll, () {
      popularCubit.fetchMyMoreItems();
    });
  }

  bool _shouldShowSearchSections(SearchItemState state) {
    if (searchController.text.isNotEmpty || filter != null) {
      return true;
    }

    return state is SearchItemFetchProgress ||
        state is SearchItemSuccess ||
        state is SearchItemFailure;
  }

  List<CatalogSection> _buildSections({
    required SearchItemState searchState,
    required FetchPopularItemsState popularState,
  }) {
    final sections = <CatalogSection>[
      _buildHistorySection(),
    ];

    if (_shouldShowSearchSections(searchState)) {
      sections.addAll(_buildSearchSections(searchState));
    } else {
      sections.addAll(_buildPopularSections(popularState));
    }

    return sections;
  }

  CatalogSection _buildHistorySection() {
    return CatalogSliverSection(
      key: const ValueKey('search-history'),
      sliver: ValueListenableBuilder(
        valueListenable: Hive.box(HiveKeys.historyBox).listenable(),
        builder: (context, Box box, _) {
          final List<ItemModel> items = box.values.map((jsonString) {
            return ItemModel.fromJson(jsonDecode(jsonString));
          }).toList();

          if (items.isEmpty) {
            return const SliverToBoxAdapter(child: SizedBox.shrink());
          }

          final children = <Widget>[
            _buildHistoryHeader(items.length),
            const SizedBox(height: 10),
          ];

          for (var i = 0; i < items.length; i++) {
            children.add(_buildHistoryRow(items[i]));
            if (i != items.length - 1) {
              children.add(_buildHistoryDivider());
            }
          }

          children.add(_buildHistoryDivider());

          return SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            sliver: SliverList(
              delegate: SliverChildListDelegate(children),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHistoryHeader(int itemCount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text("recentSearches".translate(context))
            .color(context.color.textDefaultColor.withOpacity(0.5)),
        InkWell(
          child: Text("clear".translate(context))
              .color(context.color.territoryColor),
          onTap: () {
            if (itemCount > 0) {
              clearBoxData();
            }
          },
        ),
      ],
    );
  }

  Widget _buildHistoryRow(ItemModel item) {
    return Row(
      children: [
        Icon(
          Icons.refresh,
          size: 22,
          color: context.color.textDefaultColor,
        ),
        const SizedBox(width: 20),
        Expanded(
          child: RichText(
            text: TextSpan(
              text: "${item.name!}\tin\t",
              style: TextStyle(
                color: context.color.textDefaultColor.withOpacity(0.5),
                overflow: TextOverflow.ellipsis,
              ),
              children: <TextSpan>[
                TextSpan(
                  text: item.category?.name ?? '',
                  style: TextStyle(
                    color: context.color.textDefaultColor,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryDivider() {
    return Divider(
      color: context.color.borderColor.darken(30),
      thickness: 1.2,
    );
  }

  List<CatalogSection> _buildSearchSections(SearchItemState state) {
    if (state is SearchItemFetchProgress || state is SearchItemInitial) {
      return [_buildShimmerSection(const ValueKey('search-loading'))];
    }

    if (state is SearchItemFailure) {
      return [_buildSearchErrorSection(state)];
    }

    if (state is SearchItemSuccess) {
      if (state.searchedItems.isEmpty) {
        return [
          _buildSearchHeaderSection(),
          _buildEmptyResultsSection(),
        ];
      }

      final sections = <CatalogSection>[
        _buildSearchHeaderSection(),
        CatalogListSection(
          key: const ValueKey('search-results'),
          padding: EdgeInsets.symmetric(
            horizontal: sidePadding,
            vertical: 8,
          ),
          itemCount: state.searchedItems.length,
          itemExtent: _listItemExtent,
          addAutomaticKeepAlives: true,
          addRepaintBoundaries: true,
          itemBuilder: (context, index) {
            final item = state.searchedItems[index];
            return Padding(
              padding: EdgeInsetsDirectional.only(
                top: index == 0 ? 4 : 0,
                bottom: index == state.searchedItems.length - 1 ? 0 : 8,
              ),
              child: InkWell(
                onTap: () {
                  insertNewItem(item);
                  Navigator.pushNamed(
                    context,
                    Routes.adDetailsScreen,
                    arguments: {
                      'model': item,
                    },
                  );
                },
                child: ItemHorizontalCard(
                  key: ValueKey(item.id),
                  item: item,
                  showLikeButton: true,
                  additionalImageWidth: 8,
                ),
              ),
            );
          },
        ),
      ];

      if (state.isLoadingMore) {
        sections.add(_buildLoadingMoreSection());
      }

      return sections;
    }
    return const [];

  }

  List<CatalogSection> _buildPopularSections(
      FetchPopularItemsState popularState) {
    if (popularState is FetchPopularItemsInProgress ||
        popularState is FetchPopularItemsInitial) {
      return [_buildShimmerSection(const ValueKey('popular-loading'))];
    }

    if (popularState is FetchPopularItemsFailed) {
      return [_buildPopularErrorSection(popularState)];
    }

    if (popularState is FetchPopularItemsSuccess) {
      if (popularState.items.isEmpty) {
        return const [
          CatalogBoxSection(child: SizedBox.shrink()),
        ];
      }

      final sections = <CatalogSection>[
        _buildPopularHeaderSection(),
        CatalogListSection(
          key: const ValueKey('popular-results'),
          padding: EdgeInsets.symmetric(
            horizontal: sidePadding,
            vertical: 8,
          ),
          itemCount: popularState.items.length,
          itemExtent: _listItemExtent,
          addAutomaticKeepAlives: true,
          addRepaintBoundaries: true,
          itemBuilder: (context, index) {
            final item = popularState.items[index];
            return Padding(
              padding: EdgeInsetsDirectional.only(
                top: index == 0 ? 4 : 0,
                bottom: index == popularState.items.length - 1 ? 0 : 8,
              ),
              child: InkWell(
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    Routes.adDetailsScreen,
                    arguments: {
                      'model': item,
                    },
                  );
                },
                child: ItemHorizontalCard(
                  key: ValueKey(item.id),
                  item: item,
                  showLikeButton: true,
                  additionalImageWidth: 8,
                ),
              ),
            );
          },
        ),
      ];

      if (popularState.isLoadingMore) {
        sections.add(_buildLoadingMoreSection());
      }

      return sections;
    }

    return const [];
  }

  CatalogSection _buildSearchHeaderSection() {
    return CatalogBoxSection(
      key: const ValueKey('search-header'),
      padding: EdgeInsets.symmetric(
        horizontal: sidePadding,
        vertical: 8,
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: 5.0),
        child: Text("searchedItems".translate(context))
            .color(context.color.textDefaultColor.withOpacity(0.5))
            .size(context.font.normal),
      ),
    );
  }

  CatalogSection _buildPopularHeaderSection() {
    return CatalogBoxSection(
      key: const ValueKey('popular-header'),
      padding: EdgeInsets.symmetric(
        horizontal: sidePadding,
        vertical: 8,
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: 5.0),
        child: Text("popularAds".translate(context))
            .color(context.color.textDefaultColor.withOpacity(0.5))
            .size(context.font.normal),
      ),
    );
  }

  CatalogSection _buildShimmerSection(Key key) {
    return CatalogListSection(
      key: key,
      padding: EdgeInsets.symmetric(
        horizontal: sidePadding,
        vertical: 8,
      ),
      itemCount: 5,
      itemExtent: _listItemExtent,
      addAutomaticKeepAlives: false,
      addRepaintBoundaries: false,
      itemBuilder: (context, index) {
        return _buildShimmerTile(context);
      },
    );
  }

  Widget _buildShimmerTile(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxWidth = constraints.maxWidth;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            color: context.color.secondaryColor,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: const CustomShimmer(height: 90, width: 90),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    CustomShimmer(height: 10, width: maxWidth - 50),
                    const SizedBox(height: 10),
                    const CustomShimmer(height: 10),
                    const SizedBox(height: 10),
                    CustomShimmer(height: 10, width: maxWidth / 1.2),
                    const SizedBox(height: 10),
                    Align(
                      alignment: AlignmentDirectional.bottomStart,
                      child: CustomShimmer(width: maxWidth / 4, height: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  CatalogSection _buildLoadingMoreSection() {
    return CatalogBoxSection(
      key: const ValueKey('loading-more'),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: UiUtils.progress(
          normalProgressColor: context.color.territoryColor,
        ),
      ),
    );
  }

  CatalogSection _buildEmptyResultsSection() {
    return CatalogBoxSection(
      key: const ValueKey('search-empty'),
      padding: EdgeInsets.symmetric(horizontal: sidePadding, vertical: 8),
      child: NoDataFound(
        onTap: () {
          context.read<SearchItemCubit>().searchItem(
            searchController.text,
            page: 1,
            filter: filter,
          );
        },
      ),
    );
  }

  CatalogSection _buildSearchErrorSection(SearchItemFailure state) {
    final message = state.errorMessage.toLowerCase();
    final bool isOffline = message.contains('internet');

    if (isOffline) {
      return CatalogBoxSection(
        key: const ValueKey('search-offline'),
        padding:
        EdgeInsets.symmetric(horizontal: sidePadding, vertical: 16),
        child: NoInternet(
          onRetry: () {
            context.read<SearchItemCubit>().searchItem(
              searchController.text,
              page: 1,
              filter: filter,
            );
          },
        ),
      );
    }

    return CatalogBoxSection(
      key: const ValueKey('search-error'),
      padding: EdgeInsets.symmetric(horizontal: sidePadding, vertical: 16),
      child: const SomethingWentWrong(),
    );
  }

  CatalogSection _buildPopularErrorSection(FetchPopularItemsFailed state) {
    final message = state.error.toString().toLowerCase();
    final bool isOffline = message.contains('internet');

    if (isOffline) {
      return CatalogBoxSection(
        key: const ValueKey('popular-offline'),
        padding:
         EdgeInsets.symmetric(horizontal: sidePadding, vertical: 16),
        child: NoInternet(
          onRetry: () {
            context.read<FetchPopularItemsCubit>().fetchPopularItems();
          },
        ),
      );
    }
    return CatalogBoxSection(
      key: const ValueKey('popular-error'),
      padding:  EdgeInsets.symmetric(horizontal: sidePadding, vertical: 16),
      child: const SomethingWentWrong(),
    );
  }

//this will listen and manage search
  void searchItemListener() {
    _debounce.run(_DebounceScope.search, itemSearch);

    setState(() {});
  }



  ///This will call api after some delay
  void itemSearch() {
    // if (searchController.text.isNotEmpty) {
    if (previousSearchQuery != searchController.text) {
      context.read<SearchItemCubit>().searchItem(
            searchController.text,
            page: 1,
            filter: filter,
          );
      previousSearchQuery = searchController.text;
      setState(() {});
    }
    // } else {
    // context.read<SearchItemCubit>().clearSearch();
    // }
  }

  PreferredSizeWidget appBarWidget() {
    return AppBar(
      systemOverlayStyle:
          SystemUiOverlayStyle(statusBarColor: context.color.backgroundColor),
      bottom: PreferredSize(
          preferredSize: Size.fromHeight(64.rh(context)),
          child: LayoutBuilder(builder: (context, c) {
            return SizedBox(
                width: c.maxWidth,
                child: FittedBox(
                  fit: BoxFit.none,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 14, horizontal: 18.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                            width: 270.rw(context),
                            height: 50.rh(context),
                            alignment: AlignmentDirectional.center,
                            decoration: BoxDecoration(
                                border: Border.all(
                                    width: context
                                                .watch<AppThemeCubit>()
                                                .state
                                                .appTheme ==
                                            AppTheme.dark
                                        ? 0
                                        : 1,
                                    color:
                                        context.color.borderColor.darken(30)),
                                borderRadius:
                                    const BorderRadius.all(Radius.circular(10)),
                                color: context.color.secondaryColor),
                            child: TextFormField(
                                autofocus: widget.autoFocus,
                                controller: searchController,
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  //OutlineInputBorder()
                                  fillColor: Theme.of(context)
                                      .colorScheme
                                      .secondaryColor,
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
                                    },
                                  );
                                  FocusScope.of(context).unfocus();
                                },
                                onTap: () {
                                  //change prefix icon color to primary
                                  setState(() {
                                    isFocused = true;
                                  });
                                })),
                        const SizedBox(
                          width: 14,
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.pushNamed(context, Routes.filterScreen,
                                arguments: {
                                  "update": getFilterValue,
                                  "from": "search",
                                  "categoryList": categoryList,
                                }).then((value) {
                              if (value == true) {
                                context.read<SearchItemCubit>().searchItem(
                                    searchController.text,
                                    page: 1,
                                    filter: filter);
                              }
                            });
                          },
                          child: Container(
                            width: 50.rw(context),
                            height: 50.rh(context),
                            decoration: BoxDecoration(
                              border: Border.all(
                                  width: 1,
                                  color: context.color.borderColor.darken(30)),
                              color: context.color.secondaryColor,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: UiUtils.getSvg(
                                  filter != null
                                      ? AppIcons.filterByIcon
                                      : AppIcons.filter,
                                  color: context.color.territoryColor),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ));
          })),
      automaticallyImplyLeading: false,
      leading: Material(
        clipBehavior: Clip.antiAlias,
        color: Colors.transparent,
        type: MaterialType.circle,
        child: InkWell(
          onTap: () {
            Navigator.pop(context);
          },
          child: Padding(
              padding: EdgeInsetsDirectional.only(start: 18.0, top: 12),
              child: Directionality(
                  textDirection: Directionality.of(context),
                  child: RotatedBox(
                    quarterTurns:
                        Directionality.of(context) == TextDirection.rtl
                            ? 2
                            : -4,
                    child: UiUtils.getSvg(AppIcons.arrowLeft,
                        fit: BoxFit.none,
                        color: context.color.textDefaultColor),
                  ))),
        ),
      ),
      /*BackButton(
        color: context.color.textDefaultColor,
      ),*/
      elevation: context.watch<AppThemeCubit>().state.appTheme == AppTheme.dark
          ? 0
          : 6,
      shadowColor:
          context.watch<AppThemeCubit>().state.appTheme == AppTheme.dark
              ? null
              : context.color.textDefaultColor.withOpacity(0.2),
      backgroundColor: context.color.backgroundColor,
    );
  }

  getFilterValue(ItemFilterModel model) {
    filter = model;
    setState(() {});
  }


  @override
  Widget build(BuildContext context) {
    super.build(context);
    return PopScope(
      canPop: true,
      onPopInvoked: (isPop) {
        Constant.itemFilter = null;
      },
      child: Scaffold(
        appBar: appBarWidget(),
        body: bodyData(),
        backgroundColor: context.color.backgroundColor,
      ),
    );
  }

/*  Widget bodyData() {
    return SingleChildScrollView(
      controller:
          searchController.text.isNotEmpty ? controller : popularController,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        buildHistoryItemList(),
        searchController.text.isNotEmpty
            ? searchItemsWidget()
            : popularItemsWidget(),
      ]),
    );
  }*/

  Widget bodyData() {
    return BlocBuilder<SearchItemCubit, SearchItemState>(

      builder: (context, searchState) {
        return BlocBuilder<FetchPopularItemsCubit, FetchPopularItemsState>(
          builder: (context, popularState) {
            final sections = _buildSections(
              searchState: searchState,
              popularState: popularState,
            );

            return CatalogScrollView(
              controller: _scrollController,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              sections: sections,
            );
          },
        );
      },
    );
  }

  void clearBoxData() async {
    var box = Hive.box(HiveKeys.historyBox);
    await box.clear();
    setState(() {});
  }



  void insertNewItem(ItemModel model) {
    var box = Hive.box(HiveKeys.historyBox);

    // Check if the model.id is already present in the box
    bool exists = false;
    for (int i = 0; i < box.length; i++) {
      var item = jsonDecode(box.getAt(i));
      if (item['id'] == model.id) {
        exists = true;
        break;
      }
    }

    // If the id does not exist, add the new item
    if (!exists) {
      // Ensure the box length does not exceed 5
      if (box.length >= 5) {
        box.deleteAt(0);
      }

      box.add(jsonEncode(model.toJson()));
    }

    setState(() {});
  }


  Widget setSearchIcon() {
    return Padding(
        padding: const EdgeInsets.all(8.0),
        child: UiUtils.getSvg(AppIcons.search,
            color: context.color.territoryColor));
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
  void dispose() {
    searchController.removeListener(searchItemListener);
    searchController.dispose();
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    _debounce.dispose();
    super.dispose();
  }


  @visibleForTesting
  ScrollController get scrollController => _scrollController;
}

enum _DebounceScope { search, scroll }

class _SearchDebounceCoordinator {
   _SearchDebounceCoordinator(this.duration);

  final Duration duration;
  final Map<_DebounceScope, Timer> _timers = {};

  void run(_DebounceScope scope, VoidCallback action) {
    _timers[scope]?.cancel();
    _timers[scope] = Timer(duration, action);
  }

  void dispose() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
  }
}
