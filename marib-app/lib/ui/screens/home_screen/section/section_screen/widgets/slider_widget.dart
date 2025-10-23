import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shimmer/shimmer.dart';

import 'package:marib/data/cubits/category/fetch_category_cubit.dart';
import 'package:marib/utils/slider_interface_mapper.dart';
import 'package:flutter/foundation.dart';

const _shimmerBaseColor = Color(0xFFB8BEC9);
const _shimmerHighlightColor = Color(0xFFE4E8F0);

class PcSliderWidget extends StatefulWidget {
  final int parentId;
  final int? selectedCategoryId;
  final ValueChanged<int?>? onCategorySelected;
  final bool fancySelection;
  final String? interfaceType;
  final List<int>? sellerCategoryIds;

  const PcSliderWidget({
    super.key,
    required this.parentId,
    this.selectedCategoryId,
    this.onCategorySelected,
    this.interfaceType,
    this.sellerCategoryIds,
    this.fancySelection = true,
  });

  @override
  State<PcSliderWidget> createState() => _PcSliderWidgetState();
}

class _PcSliderWidgetState extends State<PcSliderWidget> {
  // 0 = "الكل"
  late int _selectedId = widget.selectedCategoryId ?? 0;

  // القائمة المعروضة
  List<Map<String, dynamic>> _display = [];

  // مفاتيح العناصر للـ ensureVisible
  final Map<int, GlobalKey> _itemKeys = {};
  int? _lastCenteredId;
  Set<int>? _sellerCategoryIdSet;

  // ثوابت تنسيق
  static const double _kBarTop = 10.0;
  static const double _kBarBottom = 12.0;
  static const double _kChipHeight = 34.0;
  static const double _kListHPad = 12.0;
  static const double _kChipSpacing = 8.0;
  static const double _kEdgeFadeW = 0.0; // تلاشي الأطراف

  @override
  void initState() {
    super.initState();

    _sellerCategoryIdSet =
        _normalizeSellerCategoryIds(widget.sellerCategoryIds);

    _kickoffCategoriesFetchIfNeeded();
    WidgetsBinding.instance.addPostFrameCallback((_) => _centerCurrent());
  }

  @override
  void didUpdateWidget(covariant PcSliderWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.parentId != widget.parentId) {
      _kickoffCategoriesFetchIfNeeded(force: true);
      _lastCenteredId = null;
    }

    if (!listEquals(oldWidget.sellerCategoryIds, widget.sellerCategoryIds)) {
      _sellerCategoryIdSet =
          _normalizeSellerCategoryIds(widget.sellerCategoryIds);
      _kickoffCategoriesFetchIfNeeded(force: true);
    }

    if (widget.selectedCategoryId != null &&
        widget.selectedCategoryId != _selectedId) {
      setState(() {
        _selectedId = widget.selectedCategoryId!;
        _lastCenteredId = null;
      });
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _centerCurrent(force: true));
    }
  }

  void _kickoffCategoriesFetchIfNeeded({bool force = false}) {
    final catCubit = context.read<FetchCategoryCubit>();
    final FetchCategoryState state = catCubit.state;
    final FetchCategorySuccess? success =
        state is FetchCategorySuccess ? state : null;
    final Set<int>? sellerSet = _sellerCategoryIdSet;
    final bool restrictBySeller = sellerSet != null && sellerSet.isNotEmpty;
    final String? normalizedInterface =
        SliderInterfaceMapper.normalize(widget.interfaceType) ??
            widget.interfaceType?.trim();
    final String? interfaceType =
        (normalizedInterface != null && normalizedInterface.isNotEmpty)
            ? normalizedInterface
            : success?.interfaceType;

    final int parentId = widget.parentId;
    final bool shouldFetch = force ||
        success == null ||
        success.categoryId != parentId ||
        success.categories.every((category) => category.id != parentId);

    if (!shouldFetch) {
      return;
    }
    catCubit.fetchCategories(
      forceRefresh: force ? true : null,
      categoryId: parentId,
      interfaceType: interfaceType,
      onlyAllowed: restrictBySeller,
      ensureCategoryIds:
          restrictBySeller ? sellerSet!.toList(growable: false) : const <int>[],
      allowedCategoryIds:
          restrictBySeller ? sellerSet!.toList(growable: false) : const <int>[],
    );
  }

  void _onTapCategory(int id) {
    if (_selectedId == id) return;

    HapticFeedback.selectionClick();

    setState(() {
      _selectedId = id;
      _lastCenteredId = null;
    });

    _centerCurrent(force: true);
    widget.onCategorySelected?.call(id);
  }

  void _centerCurrent({bool force = false}) {
    final id = _selectedId;
    if (!force && _lastCenteredId == id) return;

    final key = _itemKeys[id];
    if (key == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = key.currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.5,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
      _lastCenteredId = id;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // لون الخلفية خلف الشريط (نخليه قريب من لون الـ Material الأب)
    final barBg = theme.colorScheme.surface;

    return BlocBuilder<FetchCategoryCubit, FetchCategoryState>(
      builder: (context, catState) {
        // شيمر أثناء التحميل/الفشل
        if (catState is! FetchCategorySuccess) {
          return _buildShimmer(barBg);
        }

        _display = _buildDisplayList(catState, widget.parentId);

        for (final m in _display) {
          final id = m['id'] as int;
          _itemKeys.putIfAbsent(id, () => GlobalKey());
        }

        WidgetsBinding.instance.addPostFrameCallback((_) => _centerCurrent());

        return Padding(
          padding: const EdgeInsets.fromLTRB(0, _kBarTop, 0, _kBarBottom),
          // نستخدم Stack لإضافة تلاشي الأطراف بدون “خط سفلي”
          child: SizedBox(
            height: _kChipHeight, // يوحّد الارتفاع مع الشيمر
            child: Stack(
              children: [
                // القائمة
                RepaintBoundary(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: _kListHPad),
                    scrollDirection: Axis.horizontal,
                    itemCount: _display.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(width: _kChipSpacing),
                    itemBuilder: (context, index) {
                      final m = _display[index];
                      final id = m['id'] as int;
                      final name = m['name'] as String;
                      final isSelected = id == _selectedId;
                      final key = _itemKeys[id]!;

                      return KeyedSubtree(
                        key: key,
                        child: _chip(
                          context: context,
                          name: name,
                          isSelected: isSelected,
                          fancySelection: widget.fancySelection,
                          onTap: () => _onTapCategory(id),
                        ),
                      );
                    },
                  ),
                ),

                // تلاشي الطرف الأيسر
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    child: Container(
                      width: _kEdgeFadeW,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [barBg, barBg.withOpacity(0.0)],
                        ),
                      ),
                    ),
                  ),
                ),
                // تلاشي الطرف الأيمن
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    child: Container(
                      width: _kEdgeFadeW,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerRight,
                          end: Alignment.centerLeft,
                          colors: [barBg, barBg.withOpacity(0.0)],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // شيمر بنفس الارتفاع تمامًا وبدون أي خط سفلي

  Widget _buildShimmer(Color barBg) {
    // ألوان موحّدة للشيمر
    const base = _shimmerBaseColor;
    const highlight = _shimmerHighlightColor;

    const widths = [72.0, 88.0, 64.0, 96.0, 70.0, 90.0, 68.0];

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, _kBarTop, 0, _kBarBottom),
      child: SizedBox(
        height: _kChipHeight,
        child: Stack(
          children: [
            RepaintBoundary(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: _kListHPad),
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                itemBuilder: (_, i) => Shimmer.fromColors(
                  baseColor: base,
                  highlightColor: highlight,
                  period: const Duration(milliseconds: 1150),
                  child: Container(
                    width: widths[i % widths.length],
                    height: _kChipHeight,
                    decoration: BoxDecoration(
                      color: base,
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
                separatorBuilder: (_, __) =>
                    const SizedBox(width: _kChipSpacing),
                itemCount: 10,
              ),
            ),
            // نفس تلاشي الأطراف عشان الشكل يظل متّسق
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: IgnorePointer(
                child: Container(
                  width: _kEdgeFadeW,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [barBg, barBg.withOpacity(0.0)],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: IgnorePointer(
                child: Container(
                  width: _kEdgeFadeW,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerRight,
                      end: Alignment.centerLeft,
                      colors: [barBg, barBg.withOpacity(0.0)],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _buildDisplayList(
    FetchCategorySuccess state,
    int parentId,
  ) {
    try {
      final parent = state.categories.firstWhere((c) => c.id == parentId);
      final children = parent.children ?? const [];
      final List<Map<String, dynamic>> base = [
        {'id': 0, 'name': 'الكل'},
        ...children.map((c) => {'id': c.id, 'name': c.name}),
      ];
      return _reorderForSellerCategories(base);
    } catch (e) {
      debugPrint("PcSliderWidget: error loading children of $parentId → $e");
      return [
        {'id': 0, 'name': 'الكل'},
      ];
    }
  }

  Set<int>? _normalizeSellerCategoryIds(List<int>? ids) {
    if (ids == null) {
      return null;
    }
    final Set<int> normalized = <int>{};
    for (final int id in ids) {
      if (id > 0) {
        normalized.add(id);
      }
    }
    return normalized.isEmpty ? null : normalized;
  }

  List<Map<String, dynamic>> _reorderForSellerCategories(
      List<Map<String, dynamic>> categories) {
    final Set<int>? sellerSet = _sellerCategoryIdSet;
    if (sellerSet == null || sellerSet.isEmpty || categories.length <= 2) {
      return categories;
    }

    final List<Map<String, dynamic>> sellerFirst = <Map<String, dynamic>>[];
    final List<Map<String, dynamic>> others = <Map<String, dynamic>>[];

    for (final Map<String, dynamic> entry in categories.skip(1)) {
      final dynamic rawId = entry['id'];
      final int? id = rawId is int ? rawId : int.tryParse('$rawId');
      if (id != null && sellerSet.contains(id)) {
        sellerFirst.add(entry);
      } else {
        others.add(entry);
      }
    }

    if (sellerFirst.isEmpty) {
      return categories;
    }

    final List<Map<String, dynamic>> ordered = <Map<String, dynamic>>[
      categories.first
    ];
    final Set<int> seen = <int>{0};

    void addEntry(Map<String, dynamic> entry) {
      final dynamic rawId = entry['id'];
      final int? id = rawId is int ? rawId : int.tryParse('$rawId');
      if (id == null || seen.contains(id)) {
        return;
      }
      seen.add(id);
      ordered.add(entry);
    }

    for (final Map<String, dynamic> entry in sellerFirst) {
      addEntry(entry);
    }
    for (final Map<String, dynamic> entry in others) {
      addEntry(entry);
    }

    return ordered;
  }
}

// عنصر التصنيف (chip)
Widget _chip({
  required BuildContext context,
  required String name,
  required bool isSelected,
  required VoidCallback onTap,
  required bool fancySelection,
}) {
  final theme = Theme.of(context);
  final primary = theme.colorScheme.primary;
  final onSurface = theme.colorScheme.onSurface;
  final bg = theme.cardColor;

  final decoration = fancySelection && isSelected
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

  return Semantics(
    button: true,
    selected: isSelected,
    label: 'تصنيف $name',
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      splashColor: primary.withOpacity(.08),
      highlightColor: Colors.transparent,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        height: _PcSliderWidgetState._kChipHeight,
        constraints: const BoxConstraints(minWidth: 64),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: decoration,
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? primary : onSurface,
            ),
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    ),
  );
}
