import 'package:marib/data/cubits/category/fetch_sub_categories_cubit.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shimmer/shimmer.dart';

import 'package:marib/app/routes.dart';
import 'package:marib/data/model/category_model.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/ui_utils.dart';


import 'package:marib/ui/screens/item/add_item_screen/widgets/category.dart';
import 'package:marib/utils/sliver_grid_delegate_with_fixed_cross_axis_count_and_fixed_height.dart';
import 'package:marib/ui/screens/widgets/errors/no_data_found.dart';
import 'package:marib/ui/screens/widgets/errors/no_internet.dart';
import 'package:marib/ui/screens/widgets/errors/something_went_wrong.dart';
import 'package:marib/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:marib/utils/api.dart';

class CategoryListPublic extends StatefulWidget {

  final String categoryName;
  final int categoryId;
  final String? interfaceType;

  const CategoryListPublic({
    super.key,
    required this.categoryName,
    required this.categoryId,
    this.interfaceType,
  });

  @override
  State<CategoryListPublic> createState() => CategoryListPublicScreenState();

  static Route route(RouteSettings routeSettings) {
    Map? args = routeSettings.arguments as Map?;
    return BlurredRouter(
      builder: (_) => CategoryListPublic(
        categoryName: args?['catName'],
        categoryId: args?['catId'],
        interfaceType: args?['interfaceType'],
      ),
    );
  }
}

class CategoryListPublicScreenState extends State<CategoryListPublic> {
  @override
  void initState() {
    super.initState();
   
    context
        .read<FetchSubCategoriesCubit>()
        .fetchSubCategories(categoryId: widget.categoryId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.color.backgroundColor,
      appBar: UiUtils.buildAppBar(
        context,
        showBackButton: true,
        title: widget.categoryName,
      ),
    
      body: BlocBuilder<FetchSubCategoriesCubit, FetchSubCategoriesState>(
        builder: (context, state) {

          if (state is FetchSubCategoriesInProgress) {
            return _buildGridShimmer();
          }


          if (state is FetchSubCategoriesFailure) {
          if (state.errorMessage is ApiException) {
            if (state.errorMessage == "no-internet") {
              return NoInternet(
                onRetry: () {
                  context
                      .read<FetchSubCategoriesCubit>()
                      .fetchSubCategories(categoryId: widget.categoryId);
                },
              );
            }
          }

          return const SomethingWentWrong();
        }

    
          if (state is FetchSubCategoriesSuccess) {

            if (state.categories.isEmpty) {
              return NoDataFound(onTap: () {
                 context
                    .read<FetchSubCategoriesCubit>()
                    .fetchSubCategories(categoryId: widget.categoryId);
              });
            }
 
            return GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 20),
              gridDelegate:
                  SliverGridDelegateWithFixedCrossAxisCountAndFixedHeight(
                crossAxisCount: 3,
                height: MediaQuery.of(context).size.height * 0.18,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
              ),
              itemCount: state.categories.length,
              itemBuilder: (context, index) {
                CategoryModel subCategory = state.categories[index];
                
                return CategoryCard(
                  title: subCategory.name!,
                  url: subCategory.url!,
                  onTap: () {
                
                   if (state.categories[index].children!.isEmpty &&
                          state.categories[index].subcategoriesCount == 0) {
                        Navigator.pushNamed(context, Routes.itemsList,
                            arguments: {
                              'catID': state.categories[index].id.toString(),
                              'catName': state.categories[index].name,
                              "categoryIds": [ state.categories[index].id.toString()],
                              "interfaceType": widget.interfaceType,
                            });
                      } else {
                        print("hi");
                        Navigator.pushNamed(context, Routes.subCategoryScreen,
                            arguments: {
                              "categoryList": state.categories[index].children!,
                              "catName": state.categories[index].name,
                              "catId": state.categories[index].id,
                                    "categoryIds": [
                                      state.categories[index].id.toString()
                                    ],
                              "interfaceType": widget.interfaceType,
                            });
                      }
                  },
                );
              },
            );
          }


          return Container();
        },
      ),
    );
  }


  Widget _buildGridShimmer() {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 20),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCountAndFixedHeight(
        crossAxisCount: 3,
        height: MediaQuery.of(context).size.height * 0.18,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemCount: 9, 
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Theme.of(context).colorScheme.shimmerBaseColor,
          highlightColor: Theme.of(context).colorScheme.shimmerHighlightColor,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      },
    );
  }
}