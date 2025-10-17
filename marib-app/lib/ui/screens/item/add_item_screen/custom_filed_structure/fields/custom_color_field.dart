import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:marib/ui/screens/item/add_item_screen/custom_filed_structure/custom_field.dart';
import 'package:marib/data/constants/color_catalog.dart';

//import 'package:marib/utils/helper_utils.dart';


/// ===============================================================
/// CustomColorField
/// - واجهة الحقل (العنوان + الأيقونة + الوصف + زر فتح الورقة)
/// - إدارة القيمة المختارة وكتابتها في CustomField.fieldsData[key]
/// ===============================================================
class CustomColorField extends CustomField {
  @override
  String type = 'color';

  // لوحة أساسية كبيرة — أسماء فقط للمستخدم (لا نعرض الأكواد)
  static final List<Map<String, String>> basePalette =
      ColorCatalog.basePalette;

  // المختارات (HEX6 بدون #). نحتفظ أيضًا بالمخصّص الذي يضيفه المستخدم
  final Set<String> _selected = <String>{};
  final Set<String> _custom   = <String>{};

  // مفاتيح وخصائص من السكيما
  String get _key {
    final k = parameters['key']?.toString().trim();
    return (k != null && k.isNotEmpty) ? k : 'colors';
  }

  String get _title => parameters['name']?.toString() ?? 'الألوان المتاحة';

  // الوصف/الملاحظة: يدعم عدة مفاتيح معروفة
  String? get _description {
    for (final k in ['description', 'note', 'notes', 'hint']) {
      final v = parameters[k];
      if (v != null && v.toString().trim().isNotEmpty) return v.toString().trim();
    }
    return null;
  }

  // مسار/اسم الأيقونة/الصورة القادمة من السيرفر (SVG/PNG/JPG/URL/Asset)
  String? get _iconPath {
    for (final k in ['icon', 'image', 'iconPath', 'img']) {
      final v = parameters[k];
      if (v != null && v.toString().trim().isNotEmpty) return v.toString().trim();
    }
    return null;
  }

  bool get _isRequired =>
      parameters['required'] == true || parameters['required'] == 1;

  int? get _maxCount {
    final m = parameters['max'];
    return (m is int && m > 0) ? m : null;
  }

  @override
  void init() {
    // تجاهل values من السيرفر (حسب طلبك)
    // وضع التعديل: قراءة value (List / JSON String / قيمة مفردة)
    if (parameters['isEdit'] == true && parameters['value'] != null) {
      final v = parameters['value'];
      if (v is List) {
        _selected.addAll(v
            .map((e) => ColorCatalog.sanitizeHex(e.toString()))
            .where(_isHex6));

      } else if (v is String) {
        final raw = v.trim();
        try {
          final d = jsonDecode(raw);
          if (d is List) {
            _selected.addAll(d
                .map((e) => ColorCatalog.sanitizeHex(e.toString()))
                .where(_isHex6));

          } else if (raw.isNotEmpty) {
            final hex = ColorCatalog.sanitizeHex(raw);
            if (_isHex6(hex)) _selected.add(hex);

          }
        } catch (_) {
          if (raw.isNotEmpty) {
            final hex = ColorCatalog.sanitizeHex(raw);
            if (_isHex6(hex)) _selected.add(hex);
          }
        }
      }
    }
    _sync(); // كتابة القيمة الأولى
    super.init();
  }

  // ===== أدوات مساعدة عامة =====
  bool _isHex6(String h) => RegExp(r'^[0-9A-F]{6}$').hasMatch(h);
  Color _c(String hex6) => Color(int.parse('0xFF$hex6'));


  void _sync() {
    CustomField.fieldsData[_key] = _selected
        .map(ColorCatalog.sanitizeHex)
        .where(_isHex6)
        .toSet()
        .toList();
  }

  void _toggle(String hex) {
    final h = ColorCatalog.sanitizeHex(hex);
    if (!_isHex6(h)) return;
    if (!_selected.contains(h) && _maxCount != null && _selected.length >= _maxCount!) return;
    if (_selected.contains(h)) _selected.remove(h); else _selected.add(h);
    _sync(); update(() {});
  }

  void _addCustom(String hex) {
    final h = ColorCatalog.sanitizeHex(hex);
    if (!_isHex6(h)) return;
    _custom.add(h);
    if (!_selected.contains(h)) {
      if (_maxCount == null || _selected.length < _maxCount!) _selected.add(h);
    }
    _sync(); update(() {});
  }

  void _openSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ColorSheet(
        title: 'اختر الألوان المتوفّرة لمنتجك',
        initiallySelected: _selected,
        initiallyCustom: _custom,
        onPickFromBase: _toggle,                 // يبدّل من قائمة الأساس
        onAddCustomHex: _addCustom,              // عند إضافة لون مخصّص
        basePalette: basePalette,
        onSave: (sel, cus) {
          _selected
            ..clear()
            ..addAll(sel
                .map(ColorCatalog.sanitizeHex)
                .where(_isHex6));
          _custom
            ..clear()
            ..addAll(cus
                .map(ColorCatalog.sanitizeHex)
                .where(_isHex6));
          _sync();
          update(() {});
        },
      ),
    );
  }

  // ===== واجهة الحقل =====
  @override
  Widget render() {
    final fg = context.color.textDefaultColor;
    final br = context.color.borderColor;
    final bg = context.color.secondaryColor;

    final chosen = _selected.length;


    final t   = Theme.of(context);
    final on  = t.colorScheme.onSurface;
    final ico = on.withOpacity(.7);           // أيقونة رمادية أدكن


    // بطاقة الأيقونة من السيرفر — على اليمين دائمًا
    Widget iconBadge() => Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: br, width: 1),
      ),
      alignment: Alignment.center,
      child: _iconPath != null
          ? (_iconPath!.toLowerCase().endsWith('.svg')
          ? UiUtils.getSvg(_iconPath!, height: 24, width: 24)
          : UiUtils.getImage(_iconPath!, height: 24, width: 24))
          : Icon(Icons.palette_outlined, size: 22, color: fg),
    );

    return FormField<List<String>>(
      validator: (_) =>
      (_isRequired && _selected.isEmpty) ? 'يرجى اختيار لون واحد على الأقل' : null,
      builder: (state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // نجبر السطر على RTL لضمان الأيقونة يمينًا ثم العنوان
            Directionality(
              textDirection: TextDirection.rtl,
              child: Row(
                children: [
                  iconBadge(),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: fg,
                      ),
                    ),
                  ),
                  if (_isRequired)
                    Text(' *',
                        style: TextStyle(
                            color: context.color.territoryColor,
                            fontWeight: FontWeight.bold)),
                ],
              ),
            ),

            if (_description != null) ...[
              const SizedBox(height: 6),
              Text(
                _description!,
                style: TextStyle(fontSize: 12.5, color: fg.withOpacity(.75)),
              ),
            ],

            const SizedBox(height: 10),

            // زر فتح الورقة — يتغيّر نصه بعد الحفظ
            SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _openSheet,
                  icon: Icon(Icons.color_lens_rounded, color: ico),
                  label: Text(chosen > 0 ? 'الألوان المختارة :  $chosen' : 'اختيار الألوان'),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: bg,                               // خلفية رمادية
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: BorderSide(color: br),                       // حدّ رمادي
                    foregroundColor: fg,                               // نص رمادي
                  ).copyWith(
                    overlayColor: MaterialStatePropertyAll(on.withOpacity(.06)), // ضغط خفيف رمادي
                  ),
                ),
            ),

            if (state.hasError) ...[
              const SizedBox(height: 6),
              Text(state.errorText!,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.error, fontSize: 12)),
            ],
          ],
        );
      },
    );
  }
}



// ===============================================================
// ColorSheet
// - يظهر قائمة الألوان الأساسية + زر لاختيار لون مخصّص
// - عند حفظ بدون اختيار: يعرض SnackBar يطلب اختيار لون أو إلغاء
// - عند حفظ مع اختيار: يحفظ ثم يغلق الشيت ثم يظهر SnackBar "تم الحفظ"
// ===============================================================



class ColorSheet extends StatefulWidget {
  final String title;
  final List<Map<String, String>> basePalette;
  final Set<String> initiallySelected;
  final Set<String> initiallyCustom;

  // تبقى موجودة للتوافق، لكن لن نستعملها أثناء التحديد داخل الشيت
  final void Function(String hex) onPickFromBase;
  final void Function(String hex) onAddCustomHex;

  // تُستدعى فقط عند الضغط على "حفظ"
  final void Function(Set<String> selected, Set<String> custom) onSave;

  /// لو true يعرض فقط الألوان الشائعة (مختصرة)
  final bool commonOnly;

  const ColorSheet({
    super.key,
    required this.title,
    required this.basePalette,
    required this.initiallySelected,
    required this.initiallyCustom,
    required this.onPickFromBase,
    required this.onAddCustomHex,
    required this.onSave,
    this.commonOnly = true,
  });

  static Future<void> show(
      BuildContext context, {
        required String title,
        required List<Map<String, String>> basePalette,
        required Set<String> initiallySelected,
        required Set<String> initiallyCustom,
        required void Function(String hex) onPickFromBase,
        required void Function(String hex) onAddCustomHex,
        required void Function(Set<String> selected, Set<String> custom) onSave,
        bool commonOnly = true,
      }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: false,
      builder: (_) => ColorSheet(
        title: title,
        basePalette: basePalette,
        initiallySelected: initiallySelected,
        initiallyCustom: initiallyCustom,
        onPickFromBase: onPickFromBase,
        onAddCustomHex: onAddCustomHex,
        onSave: onSave,
        commonOnly: commonOnly,
      ),
    );
  }

  @override
  State<ColorSheet> createState() => _ColorSheetState();
}

class _ColorSheetState extends State<ColorSheet> {
  late Set<String> _selected; // حالة مؤقتة داخل الشيت
  late Set<String> _custom;   // حالة مؤقتة داخل الشيت

  /// الأكثر شيوعًا
  static const Set<String> _commonHex = {
    'FFFFFF','000000','808080','C0C0C0','D4AF37',
    'FF0000','0000FF','00A651','FFFF00','FFA500',
    '8B4513','F5F5DC','000080','FFC0CB','40E0D0',
  };

  @override
  void initState() {
    _selected = {...widget.initiallySelected};
    _custom   = {...widget.initiallyCustom};
    super.initState();
  }

  Color _c(String hex6) => Color(int.parse('0xFF$hex6'));

  void _toggleLocal(String hex) {
    setState(() {
      if (_selected.contains(hex)) {
        _selected.remove(hex);
      } else {
        _selected.add(hex);
      }
    });
    // لا نستدعي onPickFromBase هنا حتى لا نطبّق التغيير قبل الحفظ
  }

  void _removeCustomLocal(String hex) {
    setState(() {
      _custom.remove(hex);
      _selected.remove(hex);
    });
  }

  Future<void> _openCustomPicker() async {
    final hex = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: false,
      builder: (_) => const ColorWheelPickerSheet(),
    );
    if (hex != null && hex.isNotEmpty) {
      setState(() {
        _custom.add(hex);
        _selected.add(hex);
      });
      // لا نستدعي onAddCustomHex هنا.. سنمرر كل شيء عند الحفظ
    }
  }

  @override
  Widget build(BuildContext context) {
    final t   = Theme.of(context);
    final bg  = context.color.secondaryColor;
    final br  = context.color.borderColor;
    final on  = context.color.textDefaultColor;
    final acc = context.color.territoryColor;

    // فلترة الشائعة إن لزم
    final List<Map<String,String>> palette = widget.commonOnly
        ? widget.basePalette
        .where((e) => _commonHex.contains((e['hex'] ?? '').toUpperCase()))
        .toList()
        : widget.basePalette;

    Widget sectionLabel(String text) => Padding(
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
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * .92),
          child: Material(
            color: bg,
            elevation: 8,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(height: 5, width: 48,
                    decoration: BoxDecoration(color: br, borderRadius: BorderRadius.circular(3))),
                // رأس
                Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: br, width: 1)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.color_lens_rounded, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.title,
                          style: t.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800, letterSpacing: .2, color: on),
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

                // الجسم
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Align(
                          alignment: Alignment.center,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              'اختر الألوان المتوفّرة لمنتجك',
                              style: t.textTheme.bodySmall?.copyWith(
                                color: t.textTheme.bodySmall?.color?.withOpacity(.7),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),

                        sectionLabel('الألوان الأساسية'),

                        // قائمة الأساس (لا نكتب للخارج هنا)
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: palette.length,
                          separatorBuilder: (_, __) =>
                              Divider(height: 1, thickness: .6, color: t.dividerColor.withOpacity(.3)),
                          itemBuilder: (_, i) {
                            final e = palette[i];
                            final name = e['name'] ?? '';
                            final hex  = e['hex'] ?? '';
                            final selected = _selected.contains(hex);
                            return Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(8),
                                splashColor: t.colorScheme.primary.withOpacity(.14),
                                highlightColor: t.colorScheme.primary.withOpacity(.06),
                                onTap: () => _toggleLocal(hex),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 22, height: 22,
                                          decoration: BoxDecoration(
                                            color: _c(hex),
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.black.withOpacity(.15)),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            name,
                                            overflow: TextOverflow.ellipsis,
                                            style: t.textTheme.bodyLarge?.copyWith(
                                                fontWeight: FontWeight.w600, color: on),
                                          ),
                                        ),
                                        AnimatedSwitcher(
                                          duration: const Duration(milliseconds: 140),
                                          transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                                          child: selected
                                              ? const Icon(Icons.check_circle_rounded,
                                              key: ValueKey('on'), color: Colors.green)
                                              : const SizedBox(key: ValueKey('off'), width: 0, height: 0),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 10),
                        sectionLabel('ألوان مخصّصة'),

                        Align(
                          alignment: Alignment.center,
                          child: OutlinedButton.icon(
                            onPressed: _openCustomPicker,
                            icon: const Icon(Icons.add),
                            label: const Text('اختيار لون مخصّص'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(220, 44),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),

                        if (_custom.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: _custom.map((h) {
                              return _DeletableColorDot(
                                color: _c(h),
                                onDelete: () => _removeCustomLocal(h),
                                tooltip: 'حذف اللون',
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // شريط الأزرار
                Container(
                  decoration: BoxDecoration(
                    color: bg,
                    border: Border(top: BorderSide(color: t.dividerColor)),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(.06), blurRadius: 8, offset: const Offset(0, -2))],
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
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              side: BorderSide(color: t.colorScheme.outline.withOpacity(.5)),
                              foregroundColor: t.colorScheme.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              // ✅ نطبّق التغييرات (حتى لو فارغة) ثم نغلق
                              final rootCtx =
                                  Navigator.of(context, rootNavigator: true).overlay?.context ?? context;

                              widget.onSave(_selected, _custom);
                              Navigator.pop(context);

                              // أظهر التنبيه بعد الإغلاق ليكون فوق الشيت
                              Future.delayed(const Duration(milliseconds: 120), () {
                                final msg = _selected.isEmpty
                                    ? 'تم حفظ التعديلات (لا ألوان محددة)'
                                    : 'تم حفظ الألوان';
                         //       HelperUtils.showSnackBarMessage(rootCtx, msg);
                              });
                            },
                            icon: const Icon(Icons.check_rounded),
                            label: const Text('حفظ'),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                              elevation: 2,
                              backgroundColor: acc,
                              foregroundColor: t.colorScheme.onPrimary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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








class _DeletableColorDot extends StatelessWidget {
  final Color color;
  final VoidCallback onDelete;
  final String? tooltip;

  const _DeletableColorDot({
    required this.color,
    required this.onDelete,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final border = Border.all(color: Colors.black.withOpacity(.15));
    final closeBg = Colors.black.withOpacity(.72);

    Widget closeBtn = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onDelete,
        customBorder: const CircleBorder(),
        child: Container(
          width: 20, height: 20,
          decoration: BoxDecoration(
            color: closeBg,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1),
          ),
          child: const Icon(Icons.close_rounded, size: 12, color: Colors.white),
        ),
      ),
    );

    if (tooltip != null) {
      closeBtn = Tooltip(message: tooltip!, child: closeBtn);
    }

    return SizedBox(
      width: 36, height: 36,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // دائرة اللون
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(shape: BoxShape.circle, color: color, border: border),
            ),
          ),
          // زر الحذف (يحترم RTL/LTR)
          const PositionedDirectional(
            top: -4,
            start: -4,
            child: SizedBox.shrink(), // placeholder يُستبدل بالزر أدناه
          ),
          PositionedDirectional(
            top: -4,
            start: -4,
            child: closeBtn,
          ),
        ],
      ),
    );
  }
}


/// ===============================================================
/// BaseColorList
/// - قائمة الألوان الأساسية (اسم + دائرة اللون + مؤشر ✔ عند الاختيار)
/// ===============================================================

class BaseColorList extends StatelessWidget {
  final List<Map<String, String>> palette;
  final bool Function(String hex) isSelected;
  final Color Function(String hex) colorOf;
  final void Function(String hex) onTap;

  const BaseColorList({
    super.key,
    required this.palette,
    required this.isSelected,
    required this.colorOf,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final on = context.color.textDefaultColor;

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: palette.length,
      separatorBuilder: (_, __) => Divider(
          height: 1, thickness: .6, color: t.dividerColor.withOpacity(.3)),
      itemBuilder: (_, i) {
        final e = palette[i];
        final name = e['name'] ?? '';
        final hex  = e['hex'] ?? '';
        final selected = isSelected(hex);

        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            splashColor: t.colorScheme.primary.withOpacity(.14),
            highlightColor: t.colorScheme.primary.withOpacity(.06),
            onTap: () => onTap(hex),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Container(
                      width: 22, height: 22,
                      decoration: BoxDecoration(
                        color: colorOf(hex),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black.withOpacity(.15)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        name,
                        overflow: TextOverflow.ellipsis,
                        style: t.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600, color: on),
                      ),
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 140),
                      transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                      child: selected
                          ? const Icon(Icons.check_circle_rounded,
                          key: ValueKey('on'), color: Colors.green)
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


/// ===============================================================
/// ColorWheelPickerSheet
/// - ورقة فرعية تعرض منتقي ألوان دائري + منزلق السطوع
/// - تعيد HEX6 عند الضغط "إضافة اللون"
/// ===============================================================



class ColorWheelPickerSheet extends StatefulWidget {
  const ColorWheelPickerSheet({super.key});

  @override
  State<ColorWheelPickerSheet> createState() => _ColorWheelPickerSheetState();
}

class _ColorWheelPickerSheetState extends State<ColorWheelPickerSheet> {
  double _hue = 210;   // 0..360
  double _sat = .8;    // 0..1  (من المركز للحافة)
  double _val = .9;    // 0..1  (السطوع)

  Color get _color => HSVColor.fromAHSV(1, _hue, _sat, _val).toColor();

  String get _hex =>
      '${_color.red.toRadixString(16).padLeft(2, "0")}'
          '${_color.green.toRadixString(16).padLeft(2, "0")}'
          '${_color.blue.toRadixString(16).padLeft(2, "0")}'
          .toUpperCase();

  void _reset() => setState(() { _hue = 210; _sat = .8; _val = .9; });

  @override
  Widget build(BuildContext context) {
    final t   = Theme.of(context);
    final bg  = context.color.secondaryColor;
    final br  = context.color.borderColor;
    final on  = context.color.textDefaultColor;
    final acc = context.color.territoryColor;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * .9),
          child: Material(
            color: bg,
            elevation: 10,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(height: 5, width: 48,
                    decoration: BoxDecoration(color: br, borderRadius: BorderRadius.circular(3))),
                // رأس
                Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: br, width: 1))),
                  child: Row(
                    children: [
                      const Icon(Icons.colorize_rounded, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'اختر لونًا مخصّصًا',
                          style: t.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800, letterSpacing: .2, color: on),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.close_rounded, color: on),
                      ),
                    ],
                  ),
                ),

                // جسم منظم: تعليمات ثم العجلة “منزّلة” قليلًا
                Expanded(
                  child: LayoutBuilder(
                    builder: (ctx, cons) {
                      // حجم متجاوب: لا يغطي العنوان/التعليمات
                      final maxWheel = 200.0;
                      final wheelSize = math.max(140.0, math.min(maxWheel, cons.maxWidth - 96));

                      return SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // تعليمات مختصرة
                            Padding(
                              padding: const EdgeInsets.only(top: 10, bottom: 8),
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline, size: 16, color: on.withOpacity(.7)),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'انقر/اسحب داخل الدائرة لاختيار اللون. استخدم شريط السطوع لتفتيح أو تغميق.',
                                      style: t.textTheme.bodySmall?.copyWith(color: on.withOpacity(.75)),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 6), // ↓ تنزيل العجلة قليلًا
                            Center(
                              child: _HSVWheel(
                                size: wheelSize,
                                hue: _hue,
                                sat: _sat,
                                onChanged: (h, s) => setState(() { _hue = h; _sat = s; }),
                              ),
                            ),

                            const SizedBox(height: 12),

                            // معاينة + مسح
                            Row(
                              children: [
                                Container(
                                  width: 36, height: 36,
                                  decoration: BoxDecoration(
                                    color: _color,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.black.withOpacity(.15)),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text('المعاينة',
                                      style: t.textTheme.labelLarge?.copyWith(color: on)),
                                ),
                                IconButton(
                                  tooltip: 'مسح اللون',
                                  onPressed: _reset,
                                  icon: const Icon(Icons.close_rounded),
                                  color: on.withOpacity(.9),
                                  splashRadius: 18,
                                ),
                              ],
                            ),

                            // سطوع
                            Row(
                              children: [
                                const SizedBox(width: 4),
                                const Icon(Icons.brightness_6, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Slider(
                                    value: _val, min: .05, max: 1,
                                    onChanged: (v) => setState(() => _val = v),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // أزرار
                Container(
                  decoration: BoxDecoration(
                    color: bg,
                    border: Border(top: BorderSide(color: t.dividerColor)),
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
                            label: const Text('رجوع'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => Navigator.pop(context, _hex),
                            icon: const Icon(Icons.add),
                            label: const Text('إضافة اللون'),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                              backgroundColor: acc,
                              foregroundColor: t.colorScheme.onPrimary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

/// ===============================================================
/// _HSVWheel
/// - رسم قرص HSV حقيقي: Hue=زاوية (باتجاه عقارب الساعة)، Sat=نصف القطر.
/// - بدون مناطق سوداء/مقطوعة.
/// - التفاعل يَقصّ المؤشر داخل الدائرة لتحسين الدقة.
/// ===============================================================
class _HSVWheel extends StatefulWidget {
  final double size;
  final double hue; // 0..360
  final double sat; // 0..1
  final void Function(double hue, double sat) onChanged;

  const _HSVWheel({
    required this.size,
    required this.hue,
    required this.sat,
    required this.onChanged,
  });

  @override
  State<_HSVWheel> createState() => _HSVWheelState();
}

class _HSVWheelState extends State<_HSVWheel> {
  late double _hue;
  late double _sat;

  @override
  void initState() {
    _hue = widget.hue;
    _sat = widget.sat;
    super.initState();
  }

  void _handle(Offset local, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final v = local - center;
    final r = v.distance;
    final radius = size.width / 2;

    // زاوية باتجاه عقارب الساعة (atan2(y, x) مع y أسفل)
    double angle = (math.atan2(v.dy, v.dx) * 180 / math.pi);
    if (angle < 0) angle += 360;

    // قصّ نصف القطر داخل القرص
    final sat = (r.clamp(0.0, radius) / radius).clamp(0.0, 1.0);

    setState(() { _hue = angle; _sat = sat; });
    widget.onChanged(_hue, _sat);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return GestureDetector(
      onPanStart: (d) => _handle(d.localPosition, Size(s, s)),
      onPanUpdate: (d) => _handle(d.localPosition, Size(s, s)),
      onTapDown:  (d) => _handle(d.localPosition, Size(s, s)),
      child: CustomPaint(
        size: Size.square(s),
        painter: _HSVWheelPainter(hue: _hue, sat: _sat),
      ),
    );
  }
}

class _HSVWheelPainter extends CustomPainter {
  final double hue; // 0..360
  final double sat; // 0..1

  _HSVWheelPainter({required this.hue, required this.sat});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width/2, size.height/2);
    final radius = size.width/2;

    // نرسم قرص HSV عبر حلقات كثيرة (سلسة) — لا أسود/قطع.
    const int rings = 100;                     // عدد الحلقات (الدقة)
    final ringW = radius / rings;

    for (int i = 0; i < rings; i++) {
      final s = (i + .5) / rings;             // التشبّع لهذه الحلقة
      // ألوان الهيو مع اتجاه عقارب الساعة (0→360)
      final colors = List<Color>.generate(361, (d) =>
          HSVColor.fromAHSV(1, d.toDouble(), s, 1).toColor());
      colors.add(colors.first);                // غلق التدرّج لمنع الشرخ

      final paint = Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = ringW + 1
        ..shader = SweepGradient(colors: colors).createShader(Offset.zero & size);

      canvas.drawCircle(center, ringW * (i + 1), paint);
    }

    // مؤشر الموضع الحالي (محاذاة نفس الاتجاه المستخدم أعلاه)
    final angleRad = hue * math.pi / 180.0;   // مع عقارب الساعة
    final r = sat * radius;
    final p = Offset(center.dx + r * math.cos(angleRad),
        center.dy + r * math.sin(angleRad));

    final markerWhite = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white;
    final markerBlack = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.black.withOpacity(.35);

    canvas.drawCircle(p, 8, markerWhite);
    canvas.drawCircle(p, 8, markerBlack);
  }

  @override
  bool shouldRepaint(covariant _HSVWheelPainter old) =>
      old.hue != hue || old.sat != sat;
}




/// ===============================================================
/// _ColorWheel
/// - رسم دائرة تدرّج لوني (Hue + Saturation) مع مؤشر
/// - السطوع (Value) يُضبط من خارجها عبر Slider
/// ===============================================================
class _ColorWheel extends StatefulWidget {
  final double size;
  final double hue;        // 0..360
  final double sat;        // 0..1
  final void Function(double hue, double sat) onChanged;

  const _ColorWheel({
    required this.size,
    required this.hue,
    required this.sat,
    required this.onChanged,
  });

  @override
  State<_ColorWheel> createState() => _ColorWheelState();
}

class _ColorWheelState extends State<_ColorWheel> {
  late double _hue;
  late double _sat;

  @override
  void initState() {
    _hue = widget.hue;
    _sat = widget.sat;
    super.initState();
  }

  void _handlePan(Offset local, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final v = local - center;
    final r = math.sqrt(v.dx * v.dx + v.dy * v.dy);
    final maxR = size.width / 2;

    // زاوية بالدرجات 0..360 (مع قلب Y لأن Flutter Y للأسفل)
    double angle = (math.atan2(-v.dy, v.dx) * 180 / math.pi);
    if (angle < 0) angle += 360;

    double sat = (r / maxR).clamp(0.0, 1.0);

    setState(() {
      _hue = angle;
      _sat = sat;
    });
    widget.onChanged(_hue, _sat);
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;

    return GestureDetector(
      onPanStart: (d) => _handlePan(d.localPosition, Size(size, size)),
      onPanUpdate: (d) => _handlePan(d.localPosition, Size(size, size)),
      onTapDown: (d) => _handlePan(d.localPosition, Size(size, size)),
      child: CustomPaint(
        size: Size.square(size),
        painter: _ColorWheelPainter(hue: _hue, sat: _sat),
      ),
    );
  }
}

/// رسّام العجلة: SweepGradient (Hue) + RadialGradient (لتدرّج Saturation من المركز)
class _ColorWheelPainter extends CustomPainter {
  final double hue;
  final double sat;

  _ColorWheelPainter({required this.hue, required this.sat});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = Offset(size.width/2, size.height/2);
    final radius = size.width/2;

    // تدرّج لوني دائري (Hue)
    final sweep = SweepGradient(
      colors: List.generate(361, (i) =>
          HSVColor.fromAHSV(1, i.toDouble(), 1, 1).toColor()),
    ).createShader(rect);

    // طبقة التشبّع: من الأبيض (المركز) إلى شفاف (الحافة)
    final radial = RadialGradient(
      colors: [Colors.white, Colors.transparent],
      stops: const [0.0, 1.0],
    ).createShader(rect);

    // ارسم العجلة
    final paint = Paint()..shader = sweep;
    canvas.drawCircle(center, radius, paint);

    // مزج التشبّع
    final satPaint = Paint()
      ..blendMode = BlendMode.modulate
      ..shader = radial;
    canvas.drawCircle(center, radius, satPaint);

    // مؤشر الموقع الحالي
    final angleRad = (math.pi * hue) / 180.0;
    final r = sat * radius;
    final p = Offset(center.dx + r * math.cos(angleRad),
        center.dy - r * math.sin(angleRad));

    final marker = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white;
    canvas.drawCircle(p, 8, marker);
    canvas.drawCircle(p, 8, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.black.withOpacity(.35));
  }

  @override
  bool shouldRepaint(covariant _ColorWheelPainter old) =>
      old.hue != hue || old.sat != sat;
}
