// lib/ui/screens/item/add_item_screen/select_category_ui.dart
//
// واجهة العرض فقط (UI-Only)
// - المنطق بالكامل موجود في select_category.dart
// - هذا الملف يبني الواجهات: SelectCategoryUI + SelectNestedCategoryUI
// - مُحسّن بإضافة زر "إعادة المحاولة" اختياري في الشاشة الجذرية
// - مفصول بوضوح بين كل دالة مع تعليق يوضح دورها

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter/services.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/sliver_grid_delegate_with_fixed_cross_axis_count_and_fixed_height.dart';

import 'package:marib/ui/screens/widgets/errors/no_data_found.dart';

import 'package:marib/ui/screens/widgets/errors/no_internet.dart';

import 'package:marib/ui/screens/widgets/errors/something_went_wrong.dart';

import 'package:marib/data/cubits/category/fetch_category_cubit.dart';
import 'package:marib/data/cubits/category/fetch_sub_categories_cubit.dart';
import 'package:marib/data/model/category_model.dart';

import 'package:marib/ui/screens/item/add_item_screen/widgets/category.dart';

/// ======================================================================
///  SelectCategoryUI (واجهة الفئات الجذرية/الرئيسية)
///  - تستقبل الحالة من FetchCategoryCubit (عبر المنطق)
///  - تعرض شيمر لأي حالة ≠ Success
///  - تعرض NoData/Failure مع زر إعادة المحاولة (اختياري)
/// ======================================================================

class SelectCategoryUI extends StatelessWidget {
  const SelectCategoryUI({
    super.key,
    required this.controller,
    required this.fetchCategoryState,
    required this.onBackToRoot,
    required this.onLoadMoreRequested,
    required this.onCategoryTap,
    this.onRetryFetchRoot, // ← تحسين اختياري لإعادة الجلب عند الفشل/لا بيانات
  });

  // Controllers & State
  final ScrollController controller;
  final FetchCategoryState fetchCategoryState;

  // Callbacks (منطق)
  final VoidCallback onBackToRoot;
  final VoidCallback onLoadMoreRequested;
  final void Function(CategoryModel) onCategoryTap;
  final VoidCallback? onRetryFetchRoot;

  // ----------------------------------------------------------------------
  //  build
  // ----------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion(
      value: UiUtils.getSystemUiOverlayStyle(
        context: context,
        statusBarColor: context.color.secondaryColor,
      ),
      child: SafeArea(
        child: Scaffold(
          appBar: UiUtils.buildAppBar(
            context,
            showBackButton: true,
            title: "adListing".translate(context),
            onBackPress: onBackToRoot,
          ),
          body: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            controller: controller,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: _buildBody(context),
            ),
          ),
        ),
      ),
    );
  }

  // ----------------------------------------------------------------------
  //  _buildBody: يقرر ما الذي يجب عرضه حسب حالة FetchCategoryState
  // ----------------------------------------------------------------------

  Widget _buildBody(BuildContext context) {
    final state = fetchCategoryState;

    if (state is FetchCategoryFailure) {
      // فشل عام: أظهر ودجت قياسية مع زر إعادة محاولة (اختياري)
      return const SomethingWentWrong();
    }

    if (state is! FetchCategorySuccess) {
      // أي حالة غير نجاح: شيمر شبكة
      return _gridShimmer(context);
    }

    if (state.categories.isEmpty) {
      // نجاح بدون بيانات
      return NoDataFound(onTap: onRetryFetchRoot);
    }

    // نجاح مع بيانات
    return _categoriesGrid(context, state);
  }

  // ----------------------------------------------------------------------
  //  _categoriesGrid: شبكة بطاقات الفئات الرئيسية
  // ----------------------------------------------------------------------
  Widget _categoriesGrid(BuildContext context, FetchCategorySuccess state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("selectTheCategory".translate(context))
            .size(context.font.large)
            .bold(weight: FontWeight.w600)
            .color(context.color.textColorDark),
        const SizedBox(height: 18),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCountAndFixedHeight(
            crossAxisCount: 3,
            height: MediaQuery.of(context).size.height * 0.18,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
          ),
          itemCount: state.categories.length,
          itemBuilder: (context, index) {
            final category = state.categories[index];
            return CategoryCard(
              onTap: () => onCategoryTap(category),
              title: category.name ?? '',
              url: category.url ?? '',
            );
          },
        ),
        if (state.isLoadingMore) UiUtils.progress(),
      ],
    );
  }

  // ----------------------------------------------------------------------
  //  _gridShimmer: شيمر شبكة الفئات الرئيسية قبل اكتمال الجلب
  // ----------------------------------------------------------------------

  Widget _gridShimmer(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("selectTheCategory".translate(context))
            .size(context.font.large)
            .bold(weight: FontWeight.w600)
            .color(context.color.textColorDark),
        const SizedBox(height: 18),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
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
              highlightColor:
                  Theme.of(context).colorScheme.shimmerHighlightColor,
              child: Container(
                decoration: BoxDecoration(
                  color: context.color.borderColor.darken(6),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// ======================================================================
///  SelectNestedCategoryUI (واجهة الفئات المتداخلة/الفرعية)
///  - لا تعتمد على current.children (المنطق يضمن الجلب من الكيوبِت)
///  - تعرض شيمر لأي حالة ≠ Success، ومعالجة NoData/NoInternet/Failure
/// ======================================================================

class SelectNestedCategoryUI extends StatelessWidget {
  const SelectNestedCategoryUI({
    super.key,
    required this.controller,
    required this.current,
    required this.breadCrumbData,
    required this.fetchSubCategoriesState,
    required this.onHomeTap,
    required this.onBreadCrumbItemTap,
    required this.onTapAllCurrent,
    required this.onCategoryTap,
    required this.onLoadMoreRequested,
    required this.onRetryFetchSubCategories,
    required this.onSystemBackDidPop,
  });

  // Controllers & State
  final ScrollController controller;
  final CategoryModel current;
  final List<CategoryModel> breadCrumbData;
  final FetchSubCategoriesState fetchSubCategoriesState;

  // Callbacks (منطق)
  final Future<void> Function(bool didPop) onSystemBackDidPop;
  final VoidCallback onLoadMoreRequested;
  final VoidCallback onRetryFetchSubCategories;

  final VoidCallback onHomeTap;
  final void Function(List<CategoryModel> dataList, int index)
      onBreadCrumbItemTap;

  final VoidCallback onTapAllCurrent;
  final void Function(CategoryModel) onCategoryTap;

  // داخل SelectNestedCategoryUI (كحقل نهائي)
//  final ScrollController _breadcrumbController = ScrollController();

  // ----------------------------------------------------------------------
  //  build
  // ----------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion(
      value: UiUtils.getSystemUiOverlayStyle(
        context: context,
        statusBarColor: context.color.secondaryColor,
      ),
      child: PopScope(
        canPop: true,
        onPopInvoked: onSystemBackDidPop,
        child: SafeArea(
          child: Scaffold(
            backgroundColor: context.color.backgroundColor,
            appBar: UiUtils.buildAppBar(
              context,
              showBackButton: true,
              title: "adListing".translate(context),
            ),
            body: Padding(
              padding: const EdgeInsets.only(top: 0.0),
              child: SingleChildScrollView(
                child: Container(
                  color: context.color.secondaryColor,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _headerWithBreadcrumb(context),
                      const Divider(thickness: 1.2, height: 10),
                      _subcategoriesBody(context),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ----------------------------------------------------------------------
  //  _headerWithBreadcrumb: عنوان + مسار تنقل أفقي
  // ----------------------------------------------------------------------

// بديل _headerWithBreadcrumb: عنوان + Chips + زر "الكل"

  Widget _headerWithBreadcrumb(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      decoration: BoxDecoration(
        color: context.color.secondaryColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("selectTheCategory".translate(context))
              .size(context.font.large)
              .bold(weight: FontWeight.w700)
              .color(context.color.textColorDark),
          const SizedBox(height: 10),
          _breadcrumbChips(context), // النسخة الجديدة أدناه
        ],
      ),
    );
  }

  // ----------------------------------------------------------------------
  //  _breadcrumb: شريط مسار التنقل (Home > Level1 > Level2 ...)
  // ----------------------------------------------------------------------

// مسار الفئات لازم نقله لتفاصيل الاعلان

  Widget _breadcrumbChips(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // +1 للـ Home
    final total = breadCrumbData.length + 1;
    final activeIndex = breadCrumbData.isEmpty
        ? 0
        : breadCrumbData.length; // آخر فتات = الحالية
    final keys = List.generate(total, (_) => GlobalKey());

    // تمركز الفئة النشطة في المنتصف بعد البناء
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (activeIndex >= 0 && activeIndex < keys.length) {
        final ctx = keys[activeIndex].currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(
            ctx,
            alignment: 0.5, // ← وسط المسار
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
          );
        }
      }
    });

    return SizedBox(
      height: 40,
      child: ListView.separated(
        // controller: _breadcrumbController,

        physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics()),
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: total,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Container(
              key: keys[index],
              child: _chip(
                context,
                label: "Home",
                icon: Icons.home_outlined,
                isActive: activeIndex == 0,
                isDark: isDark,
                onTap: onHomeTap,
              ),
            );
          }
          final crumb = breadCrumbData[index - 1];
          final isLast = index == breadCrumbData.length;
          return Container(
            key: keys[index],
            child: _chip(
              context,
              label: crumb.name ?? '',
              icon: isLast ? Icons.label_important : Icons.chevron_right,
              isActive: isLast,
              isDark: isDark,
              onTap: () => onBreadCrumbItemTap(breadCrumbData, index - 1),
            ),
          );
        },
      ),
    );
  }

  Widget _chip(
    BuildContext context, {
    required String label,
    required IconData icon,
    required bool isActive,
    required bool isDark, // ← جديد
    required VoidCallback onTap,
  }) {
    // ألوان متكيفة
    final Color baseText = context.color.textDefaultColor;
    final Color borderColor = isActive
        ? context.color.territoryColor.withOpacity(0.55)
        : (isDark
            ? Colors.white.withOpacity(0.10)
            : Colors.black.withOpacity(0.08));

    final Color bgColor = isActive
        ? context.color.territoryColor.withOpacity(0.18)
        : (isDark
            ? Colors.white.withOpacity(0.04)
            : context.color.borderColor.darken(4));

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor, width: 1), // ← حدود خفيفة
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: context.color.territoryColor.withOpacity(0.10),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 16, color: baseText.withOpacity(isActive ? 0.95 : 0.8)),
            const SizedBox(width: 6),
            Text(label)
                .size(context.font.small)
                .color(baseText.withOpacity(isActive ? 0.95 : 0.85)),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------------------------
  //  _subcategoriesBody: يقرر ما الذي يجب عرضه حسب حالة FetchSubCategoriesState
  // ----------------------------------------------------------------------

  Widget _subcategoriesBody(BuildContext context) {
    final state = fetchSubCategoriesState;

    if (state is FetchSubCategoriesFailure) {
      final msg = state.errorMessage;
      if (msg == "no-internet") {
        return NoInternet(onRetry: onRetryFetchSubCategories);
      }
      return const SomethingWentWrong();
    }

    if (state is! FetchSubCategoriesSuccess) {
      return _listShimmer(context); // شيمر قائمة
    }

    if (state.categories.isEmpty) {
      return NoDataFound(onTap: onRetryFetchSubCategories);
    }

    return _subcategoriesList(context, state); // ← قائمة محسّنة
  }

  // ----------------------------------------------------------------------
  //  _subcategoriesList: قائمة الفئات الفرعية (نجاح)
  // ----------------------------------------------------------------------

  Widget _subcategoriesList(
      BuildContext context, FetchSubCategoriesSuccess state) {
    final items = state.categories;

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      controller: controller,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      itemCount: items.length + (state.isLoadingMore ? 1 : 0),
      separatorBuilder: (_, __) => Divider(
        height: 1,
        thickness: 0.8,
        color: context.color.borderColor.darken(8),
      ),
      itemBuilder: (context, index) {
        if (index == items.length) {
          // مؤشّر تحميل أسفل القائمة عند "تحميل المزيد"
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(child: UiUtils.progress()),
          );
        }

        final cat = items[index];
        return _animatedListItem(
          context,
          index: index,
          title: cat.name ?? '',
          imageUrl: cat.url ?? '',
          onTap: () {
            HapticFeedback.lightImpact();
            onCategoryTap(cat);
          },
          onLongPress: () {
            HapticFeedback.selectionClick();
          },
        );
      },
    );
  }

  Widget _animatedListItem(
    BuildContext context, {
    required int index,
    required String title,
    required String imageUrl,
    required VoidCallback onTap,
    required VoidCallback onLongPress,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.95, end: 1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          alignment: Alignment.centerLeft,
          child: _pressableListTile(
            context,
            title: title,
            imageUrl: imageUrl,
            onTap: onTap,
            onLongPress: onLongPress,
          ),
        );
      },
    );
  }

  Widget _pressableListTile(
    BuildContext context, {
    required String title,
    required String imageUrl,
    required VoidCallback onTap,
    required VoidCallback onLongPress,
  }) {
    return _ScaleOnPress(
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            color: context.color.secondaryColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: context.color.textDefaultColor
                  .withOpacity(0.08), // 👈 رمادي شفاف
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                // صورة
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 44,
                    height: 44,
                    color: context.color.territoryColor.withOpacity(.12),
                    child: UiUtils.imageType(
                      imageUrl,
                      color: context.color.territoryColor,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // عنوان
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                      .size(context.font.normal)
                      .bold(weight: FontWeight.w600)
                      .color(context.color.textDefaultColor),
                ),
                // سهم
                Icon(
                  Icons.chevron_right_rounded,
                  size: 22,
                  color: context.color.textDefaultColor.withOpacity(.7),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ----------------------------------------------------------------------
  //  _listShimmer: شيمر لقائمة الفئات الفرعية قبل اكتمال الجلب
  // ----------------------------------------------------------------------

  Widget _listShimmer(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 12,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      separatorBuilder: (_, __) => Divider(
        height: 1,
        thickness: 0.8,
        color: context.color.borderColor.darken(8),
      ),
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Theme.of(context).colorScheme.shimmerBaseColor,
          highlightColor: Theme.of(context).colorScheme.shimmerHighlightColor,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: context.color.borderColor.darken(6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    height: 16,
                    decoration: BoxDecoration(
                      color: context.color.borderColor.darken(6),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: context.color.borderColor.darken(6),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ScaleOnPress extends StatefulWidget {
  const _ScaleOnPress({required this.child});
  final Widget child;

  @override
  State<_ScaleOnPress> createState() => _ScaleOnPressState();
}

class _ScaleOnPressState extends State<_ScaleOnPress> {
  double _scale = 1.0;
  void _down(_) => setState(() => _scale = 0.97);
  void _up([_]) => setState(() => _scale = 1.0);

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _down,
      onPointerUp: _up,
      onPointerCancel: _up,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
