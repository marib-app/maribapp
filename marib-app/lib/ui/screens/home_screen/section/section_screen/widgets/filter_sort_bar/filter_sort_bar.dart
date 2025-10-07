import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/data/model/item_filter_model.dart';
import 'package:marib/data/model/category_model.dart';

// الأزرار المنفصلة
import 'package:marib/ui/screens/home_screen/section/section_screen/widgets/filter_sort_bar/filter_button.dart';
import 'package:marib/ui/screens/home_screen/section/section_screen/widgets/filter_sort_bar/sort_by_action.dart';

class FilterSortBar extends StatelessWidget {
  final List<String> categoryIds;
  final String categoryId;
  final TextEditingController searchController;
  final Function(ItemFilterModel) onFilterChanged;
  final Function(String) onSortChanged;
  final VoidCallback onMapSearchTap;

  // إبراز الخيارات الحالية (اختياري)
  final String? currentSort;
  final ItemFilterModel? currentFilter;
  final List<CategoryModel>? currentCategoryList;

  // دعم الفئات الفرعية (اختياري)
  final String? parentCategoryId;
  final Future<List<CategoryModel>> Function(String parentId)?
      loadSubcategories;

  // (اختياري غير مستخدم هنا، لو ودّك تستخدمه لاحقًا)
  final List<CategoryModel>? subcategories;

  const FilterSortBar({
    super.key,
    required this.categoryIds,
    required this.categoryId,
    required this.searchController,
    required this.onFilterChanged,
    required this.onSortChanged,
    required this.onMapSearchTap,
    this.currentSort,
    this.currentFilter,
    this.currentCategoryList,
    this.parentCategoryId,
    this.loadSubcategories,
    this.subcategories,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // ألوان زجاجية خفيفة متناسقة مع الثيم
    final glassColor = (isDark ? Colors.white : Colors.black).withOpacity(0.06);
    final borderColor =
        (isDark ? Colors.white : Colors.black).withOpacity(0.12);

    final size = MediaQuery.of(context).size;

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: size.width * 0.02),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          builder: (context, t, child) {
            final lift = lerpDouble(12, 6, t)!; // رفع بسيط للشريط
            return Transform.translate(offset: Offset(0, -lift), child: child!);
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14), // خفيف
              child: Container(
                decoration: BoxDecoration(
                  color: glassColor,
                  border: Border.all(color: borderColor, width: 1),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.30 : 0.12),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                padding: EdgeInsets.symmetric(
                  vertical: size.height * 0.012,
                  horizontal: size.width * 0.02,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // زر الفلترة (نافذة من الأسفل)
                    Flexible(
                      flex: 1,
                      child: FilterButton(
                        categoryIds: categoryIds,
                        onFilterChanged:
                            onFilterChanged, // ✅ مهم: نمرر الكولباك الحقيقي
                        currentFilter: currentFilter, // إبراز القيم الحالية
                        categoryListInitial:
                            currentCategoryList, // عرض أسماء/أيقونات الفئات
                        parentCategoryId: parentCategoryId, // تحميل الفرعيات
                        loadSubcategories: loadSubcategories, // لودر الفرعيات
                      ),
                    ),
                    SizedBox(width: size.width * 0.012),

                    // زر الخريطة
                    Flexible(
                      flex: 1,
                      child: _MapButton(onTap: onMapSearchTap),
                    ),
                    SizedBox(width: size.width * 0.012),

                    // زر الفرز (نافذة من الأسفل)
                    Flexible(
                      flex: 1,
                      child: SortByAction(
                        searchController: searchController,
                        categoryId: categoryId,
                        onSortChanged: onSortChanged,
                        currentSort: currentSort, // إبراز الخيار الحالي
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// زر الخريطة
class _MapButton extends StatelessWidget {
  final VoidCallback onTap;
  const _MapButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final chipColor = (isDark ? Colors.white : Colors.black).withOpacity(0.06);
    final textColor = theme.textTheme.bodyMedium?.color;
    final borderColor =
        (isDark ? Colors.white : Colors.black).withOpacity(0.12);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      splashColor: theme.colorScheme.primary.withOpacity(0.14),
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: MediaQuery.of(context).size.height * 0.012,
          horizontal: MediaQuery.of(context).size.width * 0.02,
        ),
        decoration: BoxDecoration(
          color: chipColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.map, size: 20),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                "searchOnMap".translate(context),
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w600, color: textColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
