// categories_bar.dart
// شريط تبويبات الفئات الأفقية مع عنصر "الكل"
// يعتمد على FetchCategoryCubit لجلب الفئات

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// Cubit + Model (عدّل المسارات حسب مشروعك)
import 'package:marib/data/cubits/category/fetch_category_cubit.dart';
import 'package:marib/data/model/category_model.dart';

/// شريط تبويبات الفئات:
/// - [parentId]: رقم التصنيف الأب الذي سنعرض أبناءه.
/// - [selectedCategoryId]: المعرّف المحدد افتراضياً (0 = الكل).
/// - [onCategorySelected]: يستدعى عند اختيار تبويب جديد.
/// - [fancySelection]: هل نعرض تأثيرات تحديد محسّنة؟
class CategoriesBar extends StatefulWidget {
  final int parentId;
  final int? selectedCategoryId;
  final ValueChanged<int?>? onCategorySelected;
  final bool fancySelection;

  const CategoriesBar({
    Key? key,
    required this.parentId,
    this.selectedCategoryId,
    this.onCategorySelected,
    this.fancySelection = true,
  }) : super(key: key);

  @override
  State<CategoriesBar> createState() => _CategoriesBarState();
}

class _CategoriesBarState extends State<CategoriesBar> {
  // أبعاد ثابتة لتوحيد القياسات
  static const double _barHeight = 42;
  static const double _chipHeight = 34;
  static const double _chipMinW = 64;

  // المعرّف الحالي المحدد محلياً
  late int _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    _selectedCategoryId = widget.selectedCategoryId ?? 0;

    // تأكد أن لدينا بيانات الفئات؛ إن لم تكن محمّلة، اطلبها.
    final fetchCategoryCubit = context.read<FetchCategoryCubit>();
    if (fetchCategoryCubit.state is! FetchCategorySuccess) {
      fetchCategoryCubit.fetchCategories();
    }
  }

  // تحديث الاختيار وتمريره للمستمع الخارجي (إن وُجد)
  void _onCategorySelected(int id) {
    setState(() => _selectedCategoryId = id);
    widget.onCategorySelected?.call(id);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FetchCategoryCubit, FetchCategoryState>(
      builder: (context, catState) {
        // حالة التحميل/غير الجاهز: شريط بارتفاع ثابت مع مؤشر
        if (catState is! FetchCategorySuccess) {
          return const SizedBox(
            height: _barHeight,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }

        // إيجاد تصنيف الأب؛ إن لم يوجد (نادر) ننشئ كائن مؤقت
        final CategoryModel parentCategory = catState.categories.firstWhere(
          (c) => c.id == widget.parentId,
          orElse: () => CategoryModel(
            id: widget.parentId,
            name: "?",
            url: "",
            children: const [],
          ),
        );

        // بناء قائمة الفئات: "الكل" + أبناء التصنيف الأب
        final List<CategoryModel> categories = <CategoryModel>[
          CategoryModel(id: 0, name: "الكل", url: ""),
          ...((parentCategory.children ?? const <CategoryModel>[])),
        ];

        // الـ ListView الأفقي للشيبس
        return SizedBox(
          height: _barHeight,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (context, index) {
              final cat = categories[index];
              final bool isSelected = (cat.id ?? 0) == _selectedCategoryId;

              return _CategoryChip(
                label: cat.name ?? "",
                isSelected: isSelected,
                fancy: widget.fancySelection,
                onTap: () {
                  HapticFeedback.selectionClick();
                  _onCategorySelected(cat.id ?? 0);
                },
              );
            },
          ),
        );
      },
    );
  }
}

/// ويدجت شيب (زر) الفئة مع حالتي التحديد/الافتراضي
class _CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final bool fancy;
  final VoidCallback onTap;

  const _CategoryChip({
    Key? key,
    required this.label,
    required this.isSelected,
    required this.fancy,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final onSurface = theme.colorScheme.onSurface;
    final bg = theme.cardColor;

    // ديكور الشيب: تأثير محسّن عند التحديد إن كانت fancy=true
    final BoxDecoration decoration = fancy && isSelected
        ? BoxDecoration(
            color: primary.withOpacity(.08),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: primary.withOpacity(.65), width: 1),
            boxShadow: [
              BoxShadow(
                color: primary.withOpacity(.12),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          )
        : BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected
                  ? primary.withOpacity(.40)
                  : theme.dividerColor.withOpacity(.15),
              width: 1,
            ),
          );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      splashColor: primary.withOpacity(.1),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        height: _CategoriesBarState._chipHeight,
        constraints: const BoxConstraints(
          minWidth: _CategoriesBarState._chipMinW,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: decoration,
        child: Center(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? primary : onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
