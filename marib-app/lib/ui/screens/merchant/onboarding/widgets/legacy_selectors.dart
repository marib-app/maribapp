import 'package:flutter/material.dart';
import 'package:marib/data/model/category_model.dart';
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
  final valid = categories
      .where((e) => e.id != null && (e.name?.trim().isNotEmpty ?? false))
      .toList()
    ..sort((a, b) => (a.name ?? '').compareTo(b.name ?? ''));

  return showModalBottomSheet<Set<int>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) {
      final Set<int> localSelection = {...initialSelection};
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.9,
        builder: (_, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 48,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).dividerColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'حدد الأقسام المناسبة لنشاطك التجاري',
                          style: TextStyle(
                            fontSize: context.font.large,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'قد تشمل بعض الأقسام فئات فرعية متعددة، اختر ما ينطبق على منتجاتك.',
                          style: TextStyle(
                            fontSize: context.font.small,
                            color: Theme.of(context).textTheme.bodySmall?.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: valid.length,
                      itemBuilder: (_, index) {
                        final category = valid[index];
                        final id = category.id!;
                        final bool selected = localSelection.contains(id);
                        return ListTile(
                          title: Text(category.name ?? ''),
                          trailing: Icon(
                            selected
                                ? Icons.check_circle
                                : Icons.circle_outlined,
                            color: selected
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).disabledColor,
                          ),
                          onTap: () {
                            if (selected) {
                              localSelection.remove(id);
                            } else {
                              localSelection.add(id);
                            }
                          },
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.pop(context, localSelection),
                        icon: const Icon(Icons.check),
                        label: Text('تم • ${localSelection.length}'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

Future<Map<int, LegacyDayHours>?> showLegacyWorkingHoursSheet({
  required BuildContext context,
  required Map<int, LegacyDayHours> initialDays,
}) {
  final data = {
    for (final entry in initialDays.entries) entry.key: entry.value.copy(),
  };

  TimeOfDay? _defaultFrom;
  TimeOfDay? _defaultTo;

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
              Future<void> pickDayTime(int index, bool isFrom) async {
                final current = isFrom ? data[index]!.from : data[index]!.to;
                final TimeOfDay? picked = await _pickTime(
                  context,
                  current ?? (isFrom ? _defaultFrom : _defaultTo),
                  isOpening: isFrom,
                );
                if (picked != null) {
                  setState(() {
                    if (isFrom) {
                      data[index]!.from = picked;
                      _defaultFrom ??= picked;
                    } else {
                      data[index]!.to = picked;
                      _defaultTo ??= picked;
                    }
                  });
                }
              }

              return Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).dividerColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'إعداد ساعات العمل',
                    style: TextStyle(
                      fontSize: context.font.large,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.all(20),
                      separatorBuilder: (_, __) => const Divider(),
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
                                      color: Theme.of(context)
                                          .textTheme
                                          .bodyLarge
                                          ?.color,
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
                                  child: OutlinedButton(
                                    onPressed: entry.enabled
                                        ? () => pickDayTime(index, true)
                                        : null,
                                    child: Text(
                                        entry.from?.format(context) ?? '--:--'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: entry.enabled
                                        ? () => pickDayTime(index, false)
                                        : null,
                                    child: Text(
                                        entry.to?.format(context) ?? '--:--'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          for (final entry in data.entries) {
                            if (entry.value.enabled &&
                                (entry.value.from == null ||
                                    entry.value.to == null)) {
                              HelperUtils.showSnackBarMessage(
                                context,
                                'يرجى تحديد ساعات يوم ${_weekdays[entry.key]}',
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
              );
            },
          ),
        ),
      );
    },
  );
}

final List<String> _weekdays = const [
  'السبت',
  'الأحد',
  'الاثنين',
  'الثلاثاء',
  'الأربعاء',
  'الخميس',
  'الجمعة',
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
    helpText: isOpening ? 'وقت البداية' : 'وقت النهاية',
    cancelText: 'إلغاء',
    confirmText: 'تأكيد',
    builder: (context, child) => Directionality(
      textDirection: TextDirection.rtl,
      child: child ?? const SizedBox.shrink(),
    ),
  );
}
