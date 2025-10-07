import 'package:marib/ui/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:marib/utils/sliver_grid_delegate_with_fixed_cross_axis_count_and_fixed_height.dart';
import 'package:marib/app/routes.dart';
import 'package:marib/data/cubits/category/fetch_category_cubit.dart';
import 'package:marib/data/model/category_model.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/constant.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:marib/utils/ui_utils.dart';

import 'package:marib/ui/screens/item/add_item_screen/widgets/category.dart';
import 'package:marib/ui/screens/widgets/animated_routes/blur_page_route.dart';

class CategoryList extends StatefulWidget {
  final String? from;

  const CategoryList({super.key, this.from});

  @override
  State<CategoryList> createState() => _CategoryListState();

  static Route route(RouteSettings routeSettings) {
    Map? args = routeSettings.arguments as Map?;
    return BlurredRouter(
      builder: (_) => CategoryList(from: args?['from']),
    );
  }
}

class _CategoryListState extends State<CategoryList>
    with TickerProviderStateMixin {
  final ScrollController _pageScrollController = ScrollController();

  @override
  void initState() {
    _pageScrollController.addListener(() {
      if (_pageScrollController.isEndReached()) {
        if (context.read<FetchCategoryCubit>().hasMoreData()) {
          context.read<FetchCategoryCubit>().fetchCategoriesMore();
        }
      }
    });
    super.initState();
  }

  @override
  void dispose() {
    _pageScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion(
      value: UiUtils.getSystemUiOverlayStyle(
          context: context, statusBarColor: context.color.secondaryColor),
      child: Scaffold(
        backgroundColor: context.color.backgroundColor,
        appBar: UiUtils.buildAppBar(
          context,
          showBackButton: true,
          title: "categoriesLbl".translate(context),
        ),
        body: BlocConsumer<FetchCategoryCubit, FetchCategoryState>(
          listener: ((context, state) {
            // if (state is FetchCategorySuccess) {}
          }),
          builder: (context, state) {
            if (state is FetchCategoryInProgress) {
              return UiUtils.progress();
            }
            if (state is FetchCategorySuccess) {
              return Column(
                children: [
                  Expanded(
                      child: GridView.builder(
                    shrinkWrap: true,
                    controller: _pageScrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 15,
                    ),
                    gridDelegate:
                        SliverGridDelegateWithFixedCrossAxisCountAndFixedHeight(
                      crossAxisCount: 3,
                      height: MediaQuery.of(context).size.height * 0.18,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                    ),
                    itemBuilder: (context, index) {
                      CategoryModel category = state.categories[index];
                      return CategoryCard(
                        onTap: () {
                          if (widget.from == Routes.filterScreen) {
                            Navigator.pop(context, category);
                          } else {
                            if (state.categories[index].children!.isEmpty) {
                                           print(
                                  "categoryList: ${state.categories[index].children}");
                              print("catName: ${state.categories[index].name}");
                              print("catId: ${state.categories[index].id}");
                              print(
                                  "categoryIds: [${state.categories[index].id.toString()}]");
                              Constant.itemFilter = null;
                              HelperUtils.goToNextPage(
                                Routes.itemsList,
                                context,
                                false,
                                args: {
                                  'catID': category.id.toString(),
                                  'catName': category.name,
                                  "categoryIds": [category.id.toString()]
                                },
                              );
                            } else {
                 
                              Navigator.pushNamed(
                                  context, Routes.subCategoryScreen,
                                  arguments: {
                                    "categoryList":
                                        state.categories[index].children,
                                    "catName": state.categories[index].name,
                                    "catId": state.categories[index].id,
                                    "categoryIds": [
                                      state.categories[index].id.toString()
                                    ]
                                  }); //pass current index category id & name here
                            }
                          }
                        },
                        title: category.name!,
                        url: category.url!,
                      );
                    },
                    itemCount: state.categories.length,
                  )),
                  if (state.isLoadingMore) UiUtils.progress()
                ],
              );
            }

            return Container();
          },
        ),
      ),
    );
    //   body:
    //       BlocBuilder<CategoryCubit, CategoryState>(builder: (context, state) {
    //     if (state is CategoryFetchProgress) {
    //       return const Center(
    //         child: CircularProgressIndicator(),
    //       );
    //     } else if (state is CategoryFetchSuccess) {
    //       initCategoryAnimations(state.categorylist);
    //       categorieslist.clear();
    //       categorieslist.addAll(state.categorylist);

    //       return gridWidget();
    //     } else if (state is ChangeSelectedCategory) {
    //       return gridWidget();
    //     } else {
    //       return const SizedBox.shrink();
    //     }
    //   }),
    // );
  }
}
