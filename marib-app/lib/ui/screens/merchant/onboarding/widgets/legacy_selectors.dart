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
      'لا توجد أقسام متاحة حالياً.',
    );
    return Future.value(null);
  }

  return showModalBottomSheet<Set<int>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withOpacity(0.35),
    enableDrag: true,
    builder: (_) => Directionality(
      textDirection: TextDirection.rtl,
      child: _LegacyCategoriesPaletteSheet(
        categories: valid,
        initialSelected: initialSelection,
      ),
    ),
  );
}

class _LegacyCategoriesPaletteSheet extends StatefulWidget {
  final List<CategoryModel> categories;
  final Set<int> initialSelected;

  const _LegacyCategoriesPaletteSheet({
    required this.categories,
    required this.initialSelected,
  });

  @override
  State<_LegacyCategoriesPaletteSheet> createState() =>
      _LegacyCategoriesPaletteSheetState();
}

class _LegacyCategoriesPaletteSheetState
    extends State<_LegacyCategoriesPaletteSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  )..forward();
  late final Animation<Offset> _slideAnimation =
      Tween(begin: const Offset(0, 0.06), end: Offset.zero).animate(
    CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
  );
  late final Animation<double> _fadeAnimation =
      CurvedAnimation(parent: _controller, curve: Curves.easeOut);

  final ValueNotifier<bool> _scrolled = ValueNotifier<bool>(false);
  late Set<int> _localSelected = {...widget.initialSelected};

  @override
  void dispose() {
    _controller.dispose();
    _scrolled.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.color;
    final List<CategoryModel> ordered =
        List<CategoryModel>.from(widget.categories)
          ..sort((a, b) => (a.name ?? '').compareTo(b.name ?? ''));
    final Color faintDivider = colors.borderColor.withOpacity(0.55);

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(18),
            ),
            child: Material(
              color: colors.backgroundColor,
              child: SafeArea(
                top: false,
                child: DraggableScrollableSheet(
                  expand: false,
                  initialChildSize: 0.95,
                  minChildSize: 0.5,
                  maxChildSize: 0.95,
                  builder: (_, scrollController) {
                    return Stack(
                      children: [
                        Column(
                          children: [
                            const SizedBox(height: 8),
                            Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: colors.borderColor,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(height: 8),
                            ValueListenableBuilder<bool>(
                              valueListenable: _scrolled,
                              builder: (_, hasShadow, __) {
                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 160),
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    10,
                                    16,
                                    12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colors.backgroundColor,
                                    boxShadow: hasShadow
                                        ? [
                                            BoxShadow(
                                              color: Colors.black
                                                  .withOpacity(0.06),
                                              blurRadius: 10,
                                              offset: const Offset(0, 4),
                                            ),
                                          ]
                                        : const [],
                                  ),
                                  child: Center(
                                    child: Text(
                                      'حدد نوع نشاطك التجاري',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: context.font.large,
                                        fontWeight: FontWeight.w800,
                                        color: colors.textDefaultColor,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                            Divider(
                                height: 1, thickness: 1, color: faintDivider),
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 10, 16, 12),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      colors.territoryColor.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color:
                                        colors.territoryColor.withOpacity(0.35),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  'ملاحظة: اختر الأقسام التي تمثل نشاط متجرك ليتم تفعيل واجهات النشر المناسبة لها.',
                                  style: TextStyle(
                                    fontSize: context.font.small,
                                    color: colors.textDefaultColor,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: ScrollConfiguration(
                                behavior: const _LegacyNoGlowScrollBehavior(),
                                child: NotificationListener<ScrollNotification>(
                                  onNotification: (notification) {
                                    final bool shouldHighlight =
                                        notification.metrics.pixels > 2;
                                    if (shouldHighlight != _scrolled.value) {
                                      _scrolled.value = shouldHighlight;
                                    }
                                    return false;
                                  },
                                  child: Scrollbar(
                                    controller: scrollController,
                                    interactive: true,
                                    child: ListView.separated(
                                      controller: scrollController,
                                      itemCount: ordered.length,
                                      separatorBuilder: (_, __) => Divider(
                                        height: 1,
                                        color: faintDivider,
                                      ),
                                      itemBuilder: (_, index) {
                                        final category = ordered[index];
                                        final int id = category.id!;
                                        final String label =
                                            category.name!.trim();
                                        final bool selected =
                                            _localSelected.contains(id);
                                        return _LegacyPaletteRow(
                                          label: label,
                                          selected: selected,
                                          onTap: () {
                                            HapticFeedback.selectionClick();
                                            setState(() {
                                              if (selected) {
                                                _localSelected.remove(id);
                                              } else {
                                                _localSelected.add(id);
                                              }
                                            });
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            ClipRect(
                              child: BackdropFilter(
                                filter:
                                    ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: colors.backgroundColor
                                        .withOpacity(0.85),
                                    border: Border(
                                      top:
                                          BorderSide(color: colors.borderColor),
                                    ),
                                  ),
                                  padding: const EdgeInsets.fromLTRB(
                                    12,
                                    8,
                                    12,
                                    12,
                                  ),
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: () => Navigator.of(context)
                                          .pop(_localSelected),
                                      icon: const Icon(Icons.check_rounded),
                                      label: Text(
                                        'تم • ${_localSelected.length}',
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: colors.territoryColor,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 14,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        PositionedDirectional(
                          top: 6,
                          end: 8,
                          child: IconButton(
                            onPressed: () => Navigator.of(context).pop(null),
                            icon: const Icon(Icons.close_rounded),
                            color: colors.textDefaultColor.withOpacity(0.85),
                            splashRadius: 22,
                            tooltip: 'إغلاق',
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

class _LegacyPaletteRow extends StatefulWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _LegacyPaletteRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_LegacyPaletteRow> createState() => _LegacyPaletteRowState();
}

class _LegacyPaletteRowState extends State<_LegacyPaletteRow> {
  bool _pressed = false;
  static const double _iconSlot = 26;

  @override
  Widget build(BuildContext context) {
    final colors = context.color;

    return InkWell(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      splashColor: colors.territoryColor.withOpacity(0.08),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        color: widget.selected
            ? colors.territoryColor.withOpacity(0.06)
            : (_pressed
                ? colors.backgroundColor.withOpacity(0.6)
                : colors.backgroundColor),
        child: Row(
          children: [
            SizedBox(
              width: _iconSlot,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                switchInCurve: Curves.easeOutBack,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween(begin: 0.6, end: 1.0).animate(
                      CurvedAnimation(
                          parent: animation, curve: Curves.easeOutBack),
                    ),
                    child: child,
                  ),
                ),
                child: widget.selected
                    ? Container(
                        key: const ValueKey('on'),
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: colors.territoryColor.withOpacity(0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: colors.territoryColor,
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          Icons.check_rounded,
                          size: 14,
                          color: colors.territoryColor,
                        ),
                      )
                    : const SizedBox(
                        key: ValueKey('off'), width: 20, height: 20),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: context.font.normal,
                  fontWeight: FontWeight.w600,
                  color: widget.selected
                      ? colors.territoryColor
                      : colors.textDefaultColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegacyNoGlowScrollBehavior extends AppScrollBehavior {
  const _LegacyNoGlowScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
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
                    'ضبط ساعات العمل',
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
                                      entry.from?.format(context) ?? '--:--',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: entry.enabled
                                        ? () => pickDayTime(index, false)
                                        : null,
                                    child: Text(
                                      entry.to?.format(context) ?? '--:--',
                                    ),
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
