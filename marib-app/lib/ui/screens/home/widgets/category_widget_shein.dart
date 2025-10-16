import 'package:marib/app/routes.dart';
import 'package:marib/data/cubits/category/fetch_category_cubit.dart';
import 'package:marib/ui/screens/home/widgets/category_shein_card.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/app_icon.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marib/data/model/category_model.dart';
import 'package:url_launcher/url_launcher.dart';

class CategoryWidgetShein extends StatelessWidget {
  final int?
      parentCategoryId; // The selected parent category ID (null or 0 = all)
  const CategoryWidgetShein({super.key, this.parentCategoryId});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FetchCategoryCubit, FetchCategoryState>(
      builder: (context, state) {
        if (state is FetchCategorySuccess) {
          if (state.categories.isNotEmpty) {
            // Find the main parent category (id == 6)
            final parentCategory = state.categories.firstWhere(
              (cat) => cat.id == 6,
              orElse: () => CategoryModel(
                  id: -1, name: '', children: []), // Dummy fallback
            );
            if (parentCategory.id == -1) return const SizedBox();
            // If no category is selected or 'All' is selected, show all subcategories of id 6
            List categoriesToShow;
            if (parentCategoryId == null || parentCategoryId == 0) {
              categoriesToShow = parentCategory.children ?? [];
            } else {
              // Find the selected category among children
              final selected = parentCategory.children?.firstWhere(
                (cat) => cat.id == parentCategoryId,
                orElse: () => CategoryModel(
                    id: -1, name: '', children: []), // Dummy fallback
              );
              categoriesToShow = (selected != null && selected.id != -1)
                  ? (selected.children ?? [])
                  : [];
            }
            // Split categories into pages of 12 (4 columns x 3 rows)
            final int itemsPerPage = 12;
            final int pageCount =
                (categoriesToShow.length / itemsPerPage).ceil();
            List<List<Object>> pages = List.generate(
              pageCount,
              (page) {
                final List<Object> pageList = [];
                if (page == 0 &&
                    (parentCategoryId == null || parentCategoryId == 0)) {
                  pageList.add({'special': true});
                }
                pageList.addAll(
                  categoriesToShow
                      .skip(page * itemsPerPage)
                      .take(itemsPerPage)
                      .cast<Object>(),
                );
                return pageList;
              },
            );
            return Padding(
              padding: const EdgeInsets.only(top: 10),
              child: SizedBox(
                width: context.screenWidth,
                height: 300,
                child: PageView.builder(
                  itemCount: pages.length,
                  controller: PageController(),
                  itemBuilder: (context, pageIndex) {
                    final page = pages[pageIndex];
                    return GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4, // 4 columns
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 1,
                        childAspectRatio: 0.8,
                      ),
                      itemCount: page.length,
                      itemBuilder: (context, index) {
                        final item = page[index];
                        if (item is Map && item['special'] == true) {
                        
                          return GestureDetector(
                     onTap: () async {
    final Uri whatsappUrl = Uri.parse("https://wa.me/maribsrvices?text=مرحبا, أريد طلب خاص");

    if (await canLaunchUrl(whatsappUrl)) {
      await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
    }
  },
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.grey.withOpacity(0.15),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Icon(Icons.star,
                                        color: context.color.territoryColor,
                                        size: 32),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'طلب خاص',
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                    color: context.color.textDefaultColor,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        if (item is CategoryModel) {
                          final category = item;
                          return CategorySheinCard(
                            title: category.name!,
                            url: category.url!,
                            onTap: () {
                              if (category.children != null &&
                                  category.children!.isNotEmpty) {
                                Navigator.pushNamed(
                                  context,
                                  Routes.subCategoryScreen,
                                  arguments: {
                                    "categoryList": category.children,
                                    "catName": category.name,
                                    "catId": category.id,
                                    "categoryIds": [category.id.toString()],
                                    "interfaceType": "shein_products",

                                    
                                  },
                                );
                              } else {
                                Navigator.pushNamed(
                                  context,
                                  Routes.itemsList,
                                  arguments: {
                                    'catID': category.id.toString(),
                                    'catName': category.name,
                                    "categoryIds": [category.id.toString()],
                                    "interfaceType": "shein_products",
                                  },
                                );
                              }
                            },
                          );
                        } else {
                          return const SizedBox();
                        }
                      },
                    );
                  },
                ),
              ),
            );
          }
        }
        return const SizedBox();
      },
    );
  }

  Widget moreCategory(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(context, Routes.categories,
            arguments: {"from": Routes.home}).then((dynamic value) {
          if (value != null) {
            // selectedCategory = value;
          }
        });
      },
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey.shade100,
              border: Border.all(
                color: context.color.borderColor.darken(60),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade300,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: RotatedBox(
                quarterTurns: 1,
                child: UiUtils.getSvg(
                  AppIcons.more,
                  color: context.color.territoryColor,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "المزيد",
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: context.color.textDefaultColor,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          )
        ],
      ),
    );
  }
}
