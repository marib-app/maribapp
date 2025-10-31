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

class CategoryWidgetShein extends StatefulWidget {
  final int?
      parentCategoryId; // The selected parent category ID (null or 0 = all)
  const CategoryWidgetShein({super.key, this.parentCategoryId});

  @override
  State<CategoryWidgetShein> createState() => _CategoryWidgetSheinState();
}

class _CategoryWidgetSheinState extends State<CategoryWidgetShein> {
  late final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void didUpdateWidget(covariant CategoryWidgetShein oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.parentCategoryId != widget.parentCategoryId) {
      _currentPage = 0;
      _jumpToPageSafely(0);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _jumpToPageSafely(int page) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pageController.hasClients) {
        return;
      }
      final int target = page < 0 ? 0 : page;
      _pageController.jumpToPage(target);
    });
  }

  void _ensurePageWithinBounds(int pageCount) {
    if (pageCount <= 0) {
      return;
    }
    final int maxPage = pageCount - 1;
    if (_currentPage > maxPage) {
      _currentPage = maxPage;
      _jumpToPageSafely(_currentPage);
    }
  }

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
            if (widget.parentCategoryId == null ||
                widget.parentCategoryId == 0) {
              categoriesToShow = parentCategory.children ?? [];
            } else {
              // Find the selected category among children
              final selected = parentCategory.children?.firstWhere(
                (cat) => cat.id == widget.parentCategoryId,
                orElse: () => CategoryModel(
                    id: -1, name: '', children: []), // Dummy fallback
              );
              categoriesToShow = (selected != null && selected.id != -1)
                  ? (selected.children ?? [])
                  : [];
            }
            // Split categories into pages of 12 (4 columns x 3 rows)
            final int itemsPerPage = 12;
            final bool showSpecialTile =
                (widget.parentCategoryId == null ||
                    widget.parentCategoryId == 0);
            final bool hasCategories = categoriesToShow.isNotEmpty;

            // إذا لم يكن لدينا أي عناصر لنظهرها (ولا حتى الزر الخاص)
            // فلن ننشئ PageView فارغًا كي لا يتسبب في أخطاء لمس.
            if (!hasCategories && !showSpecialTile) {
              return const SizedBox.shrink();
            }

            final int basePageCount =
                (categoriesToShow.length / itemsPerPage).ceil();
            final int pageCount = basePageCount == 0 ? 1 : basePageCount;

            List<List<Object>> pages = List.generate(
              pageCount,
              (page) {
                final List<Object> pageList = [];
                if (page == 0 && showSpecialTile) {

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
            if (pages.isEmpty) {
              return const SizedBox.shrink();
            }

            _ensurePageWithinBounds(pages.length);

            return Padding(
              padding: const EdgeInsets.only(top: 10),
              child: SizedBox(
                width: context.screenWidth,
                height: 300,
                child: PageView.builder(
                  itemCount: pages.length,
                  controller: _pageController,
                  onPageChanged: (page) => _currentPage = page,
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
