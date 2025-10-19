// lib/ui/screens/home/section/Items_List/widgets/filter_sort_bar/sort_by_action.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:marib/utils/app_icon.dart';
import 'filter_sort_action_button.dart';



/// زر "فرز بحسب" + نافذة الفرز (خفيف/متوافق مع الهوية)
class SortByAction extends StatelessWidget {
  final TextEditingController searchController;
  final String categoryId;
  final ValueChanged<String> onSortChanged;
  final String? currentSort;

  const SortByAction({
    super.key,
    required this.searchController,
    required this.categoryId,
    required this.onSortChanged,
    this.currentSort,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.color;
    final textColor = palette.textDefaultColor;


    return FilterSortActionButton(
      onTap: () => _openSheet(context),
      icon: UiUtils.getSvg(
        AppIcons.sortByIcon,
        color: textColor,
        height: 22,
        width: 22,
      ),
      label: "sortBy".translate(context),
    );
  }


  void _openSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, // حتى نضبط الحواف والظل يدويًا
      builder: (_) => _SortSheet(
        initialSort: currentSort ?? '',
        onPicked: (v) {
          HapticFeedback.selectionClick();
          FocusManager.instance.primaryFocus?.unfocus();
          onSortChanged(v);
        },
      ),
    );
  }
}



// ⬇️ بدل هذا الكلاس: كان Stateless —> صار Stateful لإدارة الاختيار + الأزرار
class _SortSheet extends StatefulWidget {
  final String initialSort;
  final ValueChanged<String> onPicked;

  const _SortSheet({
    required this.initialSort,
    required this.onPicked,
  });

  @override
  State<_SortSheet> createState() => _SortSheetState();
}

class _SortSheetState extends State<_SortSheet> {
  late String _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialSort;
  }

  @override
  Widget build(BuildContext context) {
    final t   = Theme.of(context);
    final bg  = context.color.secondaryColor;
    final br  = context.color.borderColor;
    final on  = context.color.textDefaultColor;
    final acc = context.color.territoryColor;

    final h = MediaQuery.of(context).size.height * 0.9;

    // فاصل بصري بسيط قابل لإعادة الاستخدام
    Widget separator(String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(child: Divider(color: t.dividerColor)),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: t.colorScheme.surface.withOpacity(.6),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: t.dividerColor),
            ),
            child: Text(
              text,
              style: t.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: t.colorScheme.onSurface.withOpacity(.8),
              ),
            ),
          ),
          Expanded(child: Divider(color: t.dividerColor)),
        ],
      ),
    );

    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: h),
          child: Material(
            color: bg,
            elevation: 8,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  height: 5, width: 48,
                  decoration: BoxDecoration(
                    color: br,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(height: 6),

                // رأس متناسق
                Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: br, width: 1)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.sort_rounded, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'sortBy'.translate(context),
                          style: t.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                            color: on,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.close_rounded, color: on),
                      ),
                    ],
                  ),
                ),

                // جسم الورقة
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        separator('خيارات الفرز'),
                        _OptionsList(
                          selected: _selected,
                          onSelect: (v) => setState(() => _selected = v),
                        ),
                      ],
                    ),
                  ),
                ),

                // شريط الأزرار (إلغاء + تطبيق) — نفس ستايل الفلتر
                Container(
                  decoration: BoxDecoration(
                    color: bg,
                    border: Border(top: BorderSide(color: t.dividerColor)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 8,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                  child: SafeArea(
                    top: false,
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded),
                            label: const Text('إلغاء'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              side: BorderSide(color: t.colorScheme.outline.withOpacity(.5)),
                              foregroundColor: t.colorScheme.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              widget.onPicked(_selected);
                              Navigator.pop(context);
                            },
                            label: const Text('تطبيق'),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                              elevation: 2,
                              backgroundColor: acc,
                              foregroundColor: t.colorScheme.onPrimary,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}





// ⬇️ حدّثنا القائمة لتعرض ✔ خضراء وتغيّر الاختيار بدون إغلاق فوري
class _OptionsList extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;

  const _OptionsList({
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final t     = Theme.of(context);
    final fg    = context.color.textDefaultColor;
    final ripple   = t.colorScheme.primary.withOpacity(0.14);
    final highlight= t.colorScheme.primary.withOpacity(0.06);

    final items = <_Opt>[
      _Opt('default', '', 'default'.translate(context), Icons.star_border_rounded),
      _Opt('newToOld', 'new-to-old', 'newToOld'.translate(context), Icons.fiber_new_rounded),
      _Opt('oldToNew', 'old-to-new', 'oldToNew'.translate(context), Icons.history_rounded),
      _Opt('priceHighToLow', 'price-high-to-low', 'priceHighToLow'.translate(context), Icons.trending_down_rounded),
      _Opt('priceLowToHigh', 'price-low-to-high', 'priceLowToHigh'.translate(context), Icons.trending_up_rounded),
    ];

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: items.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        thickness: 0.6,
        color: t.dividerColor.withOpacity(0.3),
      ),
      itemBuilder: (_, i) {
        final o = items[i];
        final isSel = selected == o.value;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            splashColor: ripple,
            highlightColor: highlight,
            onTap: () => onSelect(o.value),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Icon(o.icon, size: 22, color: fg),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        o.title,
                        overflow: TextOverflow.ellipsis,
                        style: t.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: fg,
                        ),
                      ),
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 140),
                      transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                      child: isSel
                          ? const Icon(Icons.check_circle_rounded,
                          key: ValueKey('on'), color: Colors.green) // ✔ أخضر
                          : const SizedBox(key: ValueKey('off'), width: 0, height: 0),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}




class _Opt {
  final String keyStr;
  final String value;
  final String title;
  final IconData icon;
  _Opt(this.keyStr, this.value, this.title, this.icon);
}
