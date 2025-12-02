import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:marib/app/app_scroll_behavior.dart';
import 'package:marib/data/model/category_model.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/helper_utils.dart';

class LegacyDayHours {
  bool enabled;
  TimeOfDay? from;
  TimeOfDay? to;

  LegacyDayHours({this.enabled = false, this.from, this.to});

  LegacyDayHours copy() => LegacyDayHours(enabled: enabled, from: from, to: to);
}

Future<Set<int>?> showLegacyCategoriesPalette({
  required BuildContext context,
  required List<CategoryModel> categories,
  required Set<int> initialSelection,
}) {
  final List<CategoryModel> valid = categories
      .where((category) => category.id != null && category.name != null)
      .toList()
    ..sort((a, b) => (a.name ?? '').compareTo(b.name ?? ''));

  if (valid.isEmpty) {
    HelperUtils.showSnackBarMessage(
      context,
      'لا توجد فئات متاحة للاختيار.',
    );
    return Future.value(null);
  }

  return showModalBottomSheet<Set<int>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (_) => Directionality(
      textDirection: TextDirection.rtl,
      child: _CategoriesSelectorSheet(
        categories: valid,
        initialSelected: initialSelection,
      ),
    ),
  );
}

class _CategoriesSelectorSheet extends StatefulWidget {
  final List<CategoryModel> categories;
  final Set<int> initialSelected;

  const _CategoriesSelectorSheet({
    required this.categories,
    required this.initialSelected,
  });

  @override
  State<_CategoriesSelectorSheet> createState() => _CategoriesSelectorSheetState();
}

class _CategoriesSelectorSheetState extends State<_CategoriesSelectorSheet> {
  late Set<int> _selected = {...widget.initialSelected};

  @override
  Widget build(BuildContext context) {
    final colors = context.color;
    return FractionallySizedBox(
      heightFactor: 0.9,
      child: SafeArea(
        top: false,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          child: Material(
            color: colors.backgroundColor,
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.borderColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'اختيار الأقسام',
                          style: TextStyle(
                            fontSize: context.font.large,
                            fontWeight: FontWeight.w700,
                            color: colors.textColorDark,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                        color: colors.textDefaultColor,
                        splashRadius: 20,
                        tooltip: 'إغلاق',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'يمكنك اختيار الأقسام التي ينتمي إليها متجرك. يظهر الحد الأقصى في الزر.',
                    style: TextStyle(
                      fontSize: context.font.small,
                      color: colors.textDefaultColor.withValues(alpha: 0.75),
                      height: 1.35,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ScrollConfiguration(
                    behavior: AppScrollBehavior(),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: widget.categories.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        color: colors.borderColor,
                      ),
                      itemBuilder: (_, index) {
                        final c = widget.categories[index];
                        final id = c.id!;
                        final selected = _selected.contains(id);
                        return CheckboxListTile(
                          value: selected,
                          activeColor: colors.territoryColor,
                          checkColor: colors.textDefaultColor,
                          title: Text(
                            c.name ?? '',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: colors.textColorDark,
                            ),
                          ),
                          controlAffinity: ListTileControlAffinity.trailing,
                          contentPadding: EdgeInsets.zero,
                          onChanged: (_) {
                            setState(() {
                              if (selected) {
                                _selected.remove(id);
                              } else {
                                _selected.add(id);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.check_rounded),
                      onPressed: () => Navigator.of(context).pop(_selected),
                      label: Text('حفظ (${_selected.length})'),
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.territoryColor,
                        foregroundColor: colors.textDefaultColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
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

final List<String> _weekdays = const [
  'الأحد',
  'الاثنين',
  'الثلاثاء',
  'الأربعاء',
  'الخميس',
  'الجمعة',
  'السبت',
];

Future<TimeOfDay?> _pickTime(
  BuildContext context,
  TimeOfDay? initial, {
  required bool isOpening,
}) async {
  final now = TimeOfDay.now();
  return showTimePicker(
    context: context,
    initialTime: initial ?? now,
    helpText: isOpening ? 'يبدأ الدوام من' : 'ينتهي الدوام عند',
    cancelText: 'إلغاء',
    confirmText: 'تأكيد',
    builder: (context, child) => Directionality(
      textDirection: TextDirection.rtl,
      child: child ?? const SizedBox.shrink(),
    ),
  );
}

Future<Map<int, LegacyDayHours>?> showLegacyWorkingHoursSheet({
  required BuildContext context,
  required Map<int, LegacyDayHours> initialDays,
}) {
  final Map<int, LegacyDayHours> data = {
    for (final entry in initialDays.entries) entry.key: entry.value.copy(),
  };

  TimeOfDay? defaultFrom;
  TimeOfDay? defaultTo;

  return showModalBottomSheet<Map<int, LegacyDayHours>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) {
      return FractionallySizedBox(
        heightFactor: 0.85,
        child: SafeArea(
          top: false,
          child: StatefulBuilder(
            builder: (context, setState) {
              final colors = context.color;

              Future<void> pickDayTime(int index, bool isFrom) async {
                final TimeOfDay? current =
                    isFrom ? data[index]!.from : data[index]!.to;
                final TimeOfDay? picked = await _pickTime(
                  context,
                  current ?? (isFrom ? defaultFrom : defaultTo),
                  isOpening: isFrom,
                );
                if (picked != null) {
                  setState(() {
                    if (isFrom) {
                      data[index]!.from = picked;
                      defaultFrom ??= picked;
                    } else {
                      data[index]!.to = picked;
                      defaultTo ??= picked;
                    }
                  });
                }
              }

              return Theme(
                data: Theme.of(context).copyWith(
                  outlinedButtonTheme: OutlinedButtonThemeData(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: colors.secondaryColor,
                      foregroundColor: colors.textColorDark,
                      side: BorderSide(color: colors.territoryColor),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  filledButtonTheme: FilledButtonThemeData(
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.territoryColor,
                      foregroundColor: colors.textDefaultColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colors.borderColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'أوقات العمل',
                      style: TextStyle(
                        fontSize: context.font.large,
                        fontWeight: FontWeight.w700,
                        color: colors.textColorDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'حدد وقت بداية ونهاية الدوام لكل يوم.',
                      style: TextStyle(
                        color: colors.textColorDark.withValues(alpha: 0.7),
                        fontSize: context.font.normal,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ScrollConfiguration(
                        behavior: AppScrollBehavior(),
                        child: ListView.separated(
                          padding: const EdgeInsets.all(20),
                          separatorBuilder: (_, __) => Divider(
                            color: colors.borderColor,
                            height: 20,
                          ),
                          itemCount: 7,
                          itemBuilder: (_, index) {
                            final entry = data[index]!;
                            final label = _weekdays[index];
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        label,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: colors.textColorDark,
                                        ),
                                      ),
                                    ),
                                    Switch.adaptive(
                                      value: entry.enabled,
                                      onChanged: (value) {
                                        setState(() => entry.enabled = value);
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'يبدأ من',
                                            style: TextStyle(
                                              fontSize: context.font.small,
                                              color: colors.textLightColor,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          OutlinedButton(
                                            onPressed: entry.enabled
                                                ? () => pickDayTime(index, true)
                                                : null,
                                            child: Text(
                                              entry.from?.format(context) ??
                                                  '--:--',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'ينتهي عند',
                                            style: TextStyle(
                                              fontSize: context.font.small,
                                              color: colors.textLightColor,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          OutlinedButton(
                                            onPressed: entry.enabled
                                                ? () => pickDayTime(index, false)
                                                : null,
                                            child: Text(
                                              entry.to?.format(context) ??
                                                  '--:--',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () {
                            for (final entry in data.entries) {
                              if (entry.value.enabled &&
                                  (entry.value.from == null ||
                                      entry.value.to == null)) {
                                HelperUtils.showSnackBarMessage(
                                  context,
                                  'يرجى إدخال وقت البداية والنهاية ليوم ${_weekdays[entry.key]}',
                                  messageDuration: 3,
                                );
                                return;
                              }
                            }
                            Navigator.pop(context, data);
                          },
                          child: const Text('حفظ'),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
    },
  );
}
