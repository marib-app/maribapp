import 'package:flutter/material.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:flutter/scheduler.dart'; // SchedulerBinding
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'dart:ui' as ui;


/* =========================================
   بطاقة أوقات العمل
   ========================================= */



class WorkingHoursCard extends StatefulWidget {
  const WorkingHoursCard({super.key});

  @override
  State<WorkingHoursCard> createState() => _WorkingHoursCardState();
}

class _WorkingHoursCardState extends State<WorkingHoursCard> {

  bool globalEnabled = true;



  void _openWorkingHoursSheet() async {
    await showModalBottomSheet<WeeklyHours>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return FractionallySizedBox(
          heightFactor: 0.7, // 70% من ارتفاع الشاشة
          child: Directionality(
            textDirection: ui.TextDirection.rtl, // 👈 هنا العكس
            child: const WorkingHoursSheet(),
          ),
        );
      },
    );
  }



  @override
  Widget build(BuildContext context) {
    final c = context.color;

    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LabelWithAsterisk(
            text: "workingHours".translate(context),
            icon: Icons.access_time_rounded,
            showAsterisk: false,
          ),
          const SizedBox(height: 8),
          Text(
            "أخبر عملاءك بالمواعيد المحددة لنشاطك التجاري .",
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: c.textColor.withOpacity(0.75),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity, // الزر ياخذ كامل عرض الكارت
            height: 50,             // ارتفاع مخصص
            child: UiUtils.buildButton(
              context,
              onPressed: _openWorkingHoursSheet, // يفتح نافذة الساعات
              buttonTitle: "اعداد ساعات العمل ".translate(context),
              radius: 8,
            ),
          ),

        ],
      ),
    );
  }
}


/* =========================================
   عناصر مساعدة داخلية (UI فقط)
   ========================================= */




// 2) النماذج المساعدة:
class DayHours {
  bool enabled;
  TimeOfDay? from;
  TimeOfDay? to;

  DayHours({this.enabled = false, this.from, this.to});

  Map<String, dynamic> toJson() => {
    "enabled": enabled,
    "from": from == null ? null : "${from!.hour}:${from!.minute}",
    "to":   to   == null ? null : "${to!.hour}:${to!.minute}",
  };
}

class WeeklyHours {
  final Map<int, DayHours> days; // 0=الأحد .. 6=السبت
  WeeklyHours(this.days);

  Map<String, dynamic> toMap() =>
      days.map((k, v) => MapEntry(k.toString(), v.toJson()));
}

const _arabicWeekdays = [
  "السبت",
  "الأحد",
  "الاثنين",
  "الثلاثاء",
  "الأربعاء",
  "الخميس",
  "الجمعة",
];


String _fmt(BuildContext ctx, TimeOfDay? t) =>
    t == null ? "—" : t.format(ctx);




Future<TimeOfDay?> _pickTime(
    BuildContext context,
    TimeOfDay? initial, {
      required bool isOpening,
    }) async {
  TimeOfDay? selected = initial ?? TimeOfDay.now();

  return showTimePicker(
    context: context,
    initialTime: selected,
    helpText: isOpening ? "اختر وقت بدء الدوام" : "اختر وقت نهاية الدوام",
    cancelText: "إلغاء",
    confirmText: "تأكيد",
    builder: (context, child) {
      return Localizations.override(
        context: context,
        locale: const Locale("ar"),
        child: StatefulBuilder(
          builder: (context, setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Expanded(child: child!),
                      Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 12, left: 12, right: 12),
                        child: Text(
                          isOpening
                              ? "المتجر يبدأ من الساعة ${selected?.format(context) ?? "--:--"}"
                              : "المتجر ينتهي عند الساعة ${selected?.format(context) ?? "--:--"}",
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface, // 👈 تلقائي مع الوضعين
                          ),
                        ),
                      ),

                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );
    },
  ).then((value) {
    if (value != null) {
      selected = value;
    }
    return selected;
  });
}





// 3) ورقة "تحديد الساعات":

class WorkingHoursSheet extends StatefulWidget {
  const WorkingHoursSheet({super.key});

  @override
  State<WorkingHoursSheet> createState() => _WorkingHoursSheetState();
}

class _WorkingHoursSheetState extends State<WorkingHoursSheet> {
  TimeOfDay? globalFrom = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay? globalTo = const TimeOfDay(hour: 18, minute: 0);

  bool globalEnabled = true;

  late final Map<int, DayHours> dayData = {
    for (int i = 0; i < 7; i++) i: DayHours(),
  };



  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final padding = media.viewInsets +
        const EdgeInsets.fromLTRB(16, 12, 16, 16);

    return Directionality( // 👈 عكس الاتجاه بالكامل
      textDirection: ui.TextDirection.rtl,
      child: Padding(
        padding: padding,
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // العنوان
              Text(
                "إعداد ساعات العمل",
                textAlign: TextAlign.center,
                style: Theme
                    .of(context)
                    .textTheme
                    .titleMedium,
              ),
              const SizedBox(height: 16),

              // الوقت العام + تطبيق على الكل
              _GlobalRow(
                from: globalFrom,
                to: globalTo,
                enabled: globalEnabled,                 // ✅
                onToggle: (v) => setState(() => globalEnabled = v), // ✅
                onPickFrom: () async {
                  final t = await _pickTime(context, globalFrom, isOpening: true);
                  if (t != null) setState(() => globalFrom = t);
                },
                onPickTo: () async {
                  final t = await _pickTime(context, globalTo, isOpening: false);
                  if (t != null) setState(() => globalTo = t);
                },
                onApplyAll: () {
                  setState(() {
                    for (final e in dayData.values) {
                      e.enabled = true;
                      e.from = globalFrom;
                      e.to = globalTo;
                    }
                  });
                },
              ),


              const SizedBox(height: 12),
              const Divider(height: 1),

              // قائمة الأيام
              Flexible(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  itemCount: 7,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (ctx, i) {
                    final d = dayData[i]!;
                    return _DayRow(
                      label: _arabicWeekdays[i],
                      enabled: d.enabled,
                      from: d.from,
                      to: d.to,
                      onToggle: (val) => setState(() => d.enabled = val),
                      onPickFrom: () async {
                        final t = await _pickTime(
                          context,
                          d.from ?? globalFrom,
                          isOpening: true,
                        );
                        if (t != null) setState(() => d.from = t);
                      },
                      onPickTo: () async {
                        final t = await _pickTime(
                          context,
                          d.to ?? globalTo,
                          isOpening: false,
                        );
                        if (t != null) setState(() => d.to = t);
                      },
                    );
                  },
                ),
              ),

              const SizedBox(height: 16),

              // زر الحفظ باستخدام UiUtils
              SizedBox(
                width: double.infinity,
                height: 50,
                child: UiUtils.buildButton(
                  context,
                  onPressed: _save,
                  buttonTitle: "حفظ",
                  radius: 8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _save() {
    for (final entry in dayData.entries) {
      final d = entry.value;
      if (d.enabled && (d.from == null || d.to == null)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(
              "يرجى تحديد ساعات يوم ${_arabicWeekdays[entry.key]}")),
        );
        return;
      }
    }
    Navigator.of(context).pop(WeeklyHours(dayData));
  }
}


// 4) عناصر واجهة داخلية (سطر الوقت العام + سطر اليوم)

class _GlobalRow extends StatelessWidget {
  final TimeOfDay? from, to;
  final bool enabled;                 // ✅ جديد
  final ValueChanged<bool> onToggle;  // ✅ جديد
  final VoidCallback onApplyAll;
  final VoidCallback onPickFrom, onPickTo;

  const _GlobalRow({
    required this.from,
    required this.to,
    required this.enabled,     // ✅
    required this.onToggle,    // ✅
    required this.onApplyAll,
    required this.onPickFrom,
    required this.onPickTo,
  });

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // العنوان + السويتش
        Row(
          children: [
            Expanded(
              child: Text(
                "وقت عام ينطبق على الجميع",
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.start,
              ),
            ),
            const SizedBox(width: 8),
            Switch.adaptive(value: enabled, onChanged: onToggle),
          ],
        ),
        const SizedBox(height: 8),

        // أزرار فتح/إغلاق (تتعطّل عند الإيقاف)
        Row(
          children: [
            Expanded(
              child: _TimeButton(
                label: "فتح",
                value: _fmt(context, from),
                onTap: enabled ? onPickFrom : null,
                disabled: !enabled,
              ),
            ),
            const SizedBox(width: 10),
            Text("-", style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(width: 10),
            Expanded(
              child: _TimeButton(
                label: "إغلاق",
                value: _fmt(context, to),
                onTap: enabled ? onPickTo : null,
                disabled: !enabled,
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        // تطبيق على الكل (يتعطّل عند الإيقاف)
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: enabled ? onApplyAll : null,
            icon: const Icon(Icons.done_all_rounded),
            label: const Text("تطبيق على الكل"),
            style: TextButton.styleFrom(foregroundColor: c.primary),
          ),
        ),
      ],
    );
  }
}




class _DayRow extends StatelessWidget {
  final String label;
  final bool enabled;
  final TimeOfDay? from, to;
  final ValueChanged<bool> onToggle;
  final VoidCallback onPickFrom, onPickTo;

  const _DayRow({
    required this.label,
    required this.enabled,
    required this.from,
    required this.to,
    required this.onToggle,
    required this.onPickFrom,
    required this.onPickTo,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // اسم اليوم أولًا (يمين في RTL)
            Expanded(
              child: Text(
                label,
                textAlign: TextAlign.start, // يتبع Directionality
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            const SizedBox(width: 8),
            // السويتش يجي يسار في RTL
            Switch.adaptive(value: enabled, onChanged: onToggle),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _TimeButton(
                label: "فتح",
                value: _fmt(context, from),
                onTap: enabled ? onPickFrom : null,
                disabled: !enabled,
              ),
            ),
            const SizedBox(width: 10),
            Text("-", style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(width: 10),
            Expanded(
              child: _TimeButton(
                label: "إغلاق",
                value: _fmt(context, to),
                onTap: enabled ? onPickTo : null,
                disabled: !enabled,
              ),
            ),
          ],
        ),
      ],
    );
  }
}




class _TimeButton extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onTap;
  final bool disabled;

  const _TimeButton({
    required this.label,
    required this.value,
    required this.onTap,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final border = Theme.of(context).dividerColor;
    final c = Theme.of(context).colorScheme;

    return OutlinedButton(
      onPressed: disabled ? null : onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        side: BorderSide(color: disabled ? border.withOpacity(0.3) : border),
        backgroundColor: disabled ? c.surfaceVariant.withOpacity(0.15) : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // أيقونة الساعة + القيمة
          Row(
            children: [
              Icon(Icons.schedule_rounded,
                  size: 18,
                  color: disabled
                      ? Theme.of(context).disabledColor
                      : c.primary),
              const SizedBox(width: 6),
              Text(
                value,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: disabled
                      ? Theme.of(context).disabledColor
                      : c.onSurface,
                ),
              ),
            ],
          ),

          // التسمية (فتح / إغلاق)
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: disabled
                  ? Theme.of(context).disabledColor
                  : c.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}




















class _CardShell extends StatelessWidget {
  final Widget child;
  const _CardShell({required this.child});

  @override
  Widget build(BuildContext context) {
    final c = context.color;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.secondaryColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.borderColor.darken(8), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}



class _LabelWithAsterisk extends StatelessWidget {
  final String text;
  final IconData icon;
  final bool showAsterisk;

  const _LabelWithAsterisk({
    required this.text,
    required this.icon,
    required this.showAsterisk,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.color;
    final f = context.font;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: c.territoryColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: c.territoryColor, size: 18),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: RichText(
            text: TextSpan(
              style: TextStyle(fontSize: f.normal, color: c.textDefaultColor, fontWeight: FontWeight.w600),
              children: [
                TextSpan(text: text),
                if (showAsterisk)
                  TextSpan(
                    text: "  *",
                    style: TextStyle(color: Colors.redAccent, fontSize: f.normal + 1),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
