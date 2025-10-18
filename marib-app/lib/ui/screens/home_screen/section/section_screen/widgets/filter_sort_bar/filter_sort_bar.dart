import 'dart:math' as math;

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/data/model/item_filter_model.dart';
import 'package:marib/data/model/category_model.dart';
import 'filter_sort_action_button.dart';

// الأزرار المنفصلة
import 'filter_button.dart';
import 'sort_by_action.dart';

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
  final Future<List<CategoryModel>> Function(String parentId)? loadSubcategories;

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
    final borderColor = (isDark ? Colors.white : Colors.black).withOpacity(0.12);

    final size = MediaQuery.of(context).size;

    return SafeArea(
      top: false,
      minimum: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: size.width * 0.02),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          builder: (context, t, child) {
            final lift = lerpDouble(12, 0, t)!; // رفع بسيط للشريط
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
                  vertical: 8,
                  horizontal: size.width * 0.02,
                ),
                  child: LayoutBuilder(
                      builder: (context, constraints) {
                        const buttonCount = 3;
                        final double horizontalGapCandidate = constraints.maxWidth * 0.03;
                        final double horizontalGap = horizontalGapCandidate < 8
                            ? 8
                            : (horizontalGapCandidate > 16 ? 16 : horizontalGapCandidate);
                        final double availableWidth = math.max(
                          0,
                          constraints.maxWidth - horizontalGap * (buttonCount - 1),
                        );
                        final double buttonWidth = availableWidth > 0
                            ? availableWidth / buttonCount
                            : constraints.maxWidth / buttonCount;
                        final double desiredHeight =
                        (size.height * 0.08).clamp(44.0, 52.0).toDouble();
                        return Row(
                          children: [
                            SizedBox(
                              width: buttonWidth,
                              height: desiredHeight,
                              child: FilterButton(
                                categoryIds: categoryIds,
                                onFilterChanged: onFilterChanged,             // ✅ مهم: نمرر الكولباك الحقيقي
                                currentFilter: currentFilter,                 // إبراز القيم الحالية
                                categoryListInitial: currentCategoryList,     // عرض أسماء/أيقونات الفئات
                                parentCategoryId: parentCategoryId,           // تحميل الفرعيات
                                loadSubcategories: loadSubcategories,         // لودر الفرعيات
                              ),
                            ),
                            SizedBox(width: horizontalGap),
                            SizedBox(
                              width: buttonWidth,
                              height: desiredHeight,
                              child: FilterSortActionButton(
                                onTap: onMapSearchTap,
                                icon: const Icon(Icons.map, size: 22),
                                label: "searchOnMap".translate(context),
                              ),
                            ),
                            SizedBox(width: horizontalGap),
                            SizedBox(
                              width: buttonWidth,
                              height: desiredHeight,
                              child: SortByAction(
                                searchController: searchController,
                                categoryId: categoryId,
                                onSortChanged: onSortChanged,
                                currentSort: currentSort, // إبراز الخيار الحالي
                              ),
                            ),
                          ],
                        );
                      },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
