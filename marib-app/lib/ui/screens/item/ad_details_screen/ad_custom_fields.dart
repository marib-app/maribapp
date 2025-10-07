import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart' as svg;
import 'package:marib/data/model/custom_field/custom_field_model.dart';

import 'package:marib/ui/screens/widgets/shimmerLoadingContainer.dart';

class AdCustomFieldsShimmer extends StatelessWidget {
  final int columns;
  final EdgeInsetsGeometry padding;

  const AdCustomFieldsShimmer({
    super.key,
    this.columns = 2,
    this.padding = const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
  });

  @override
  Widget build(BuildContext context) {
    final int count = columns.clamp(1, 4);

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CustomShimmer(height: 18, width: 160, borderRadius: 8),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: count,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 3.5,
            ),
            itemCount: count * 2,
            itemBuilder: (context, index) {
              return const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomShimmer(height: 12, width: 100, borderRadius: 6),
                  SizedBox(height: 6),
                  CustomShimmer(height: 14, borderRadius: 8),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: List.generate(2, (index) {
              return Expanded(
                child: Padding(
                  padding: EdgeInsetsDirectional.only(
                    end: index == 1 ? 0 : 12,
                  ),
                  child: const CustomShimmer(
                    height: 42,
                    borderRadius: 12,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

/// ===============================
/// إعدادات قابلة للتخصيص لكل جزئية
/// ===============================
class AdFieldsStyle {
  // أحجام الأيقونات
  final double leadingBoxSize; // صندوق الأيقونة في الصفوف/الأزرار
  final double leadingIconSize; // الأيقونة داخل الصندوق
  final double actionIconSize; // حجم أيقونة الأزرار السفلية (إن وجدت)

  // line-heights والتباعدات
  final double titleLineHeight; // سطر عنوان الحقل
  final double valueLineHeight; // سطر القيمة/الرابط
  final double titleToValueGap; // المسافة بين العنوان والقيمة
  final double rowToDividerGap; // المسافة قبل الـDivider
  final double wrapSpacing; // تباعد أفقي بين عناصر الشبكة
  final double wrapRunSpacing; // تباعد عمودي بين الصفوف بالشبكة

  // عرض أيقونات السيرفر
  final bool showServerIconOnTextRows; // في صفوف الشبكة العلوية
  final bool showServerIconOnActionButtons; // في منطقة الأزرار السفلية

  // تخصيص خطوط وأزرار
  final TextStyle? labelTextStyle;
  final TextStyle? valueTextStyle;
  final TextStyle? actionButtonTextStyle;
  final ButtonStyle? actionButtonStyle;

  // قوالب نصوص (بدون {label} لإلغاء التكرار) – تدعم {count}
  final String emptyPlaceholder;
  final String imagesButtonLabel; // مثال: 'عرض الصور ({count})'
  final String filesButtonLabel; // مثال: 'عرض الملفات ({count})'
  final String checkboxButtonLabel; // مثال: 'عرض القيم ({count})'

  // نصوص واجهة Dialog للـCheckbox
  final String dialogCloseText;
  final String dialogSearchHint;
  final String dialogCopyAll;

  // نص زر التحكّم الواحد
  final String collapsedText; // يُعرض عند الطي (مثلاً: "عرض المزيد (N)")
  final String expandedText; // يُعرض عند التوسيع (مثلاً: "إخفاء الكل")

  const AdFieldsStyle({
    this.leadingBoxSize = 24,
    this.leadingIconSize = 20,
    this.actionIconSize = 18,
    this.titleLineHeight = 1.15,
    this.valueLineHeight = 1.00,
    this.titleToValueGap = 2,
    this.rowToDividerGap = 6,
    this.wrapSpacing = 20,
    this.wrapRunSpacing = 20,
    this.showServerIconOnTextRows = true,
    this.showServerIconOnActionButtons = true,
    this.labelTextStyle,
    this.valueTextStyle,
    this.actionButtonTextStyle,
    this.actionButtonStyle,
    this.emptyPlaceholder = 'غير محدد',
    this.imagesButtonLabel = 'عرض الصور ({count})',
    this.filesButtonLabel = 'عرض الملفات ({count})',
    this.checkboxButtonLabel = 'عرض القيم ({count})',
    this.dialogCloseText = 'إغلاق',
    this.dialogSearchHint = 'ابحث داخل القيم…',
    this.dialogCopyAll = 'نسخ الكل',
    this.collapsedText = 'عرض المزيد',
    this.expandedText = 'إخفاء الكل',
  });

  ButtonStyle effectiveActionButtonStyle(BuildContext context) {
    if (actionButtonStyle != null) return actionButtonStyle!;
    final cs = Theme.of(context).colorScheme;
    return OutlinedButton.styleFrom(
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      side: BorderSide(color: cs.outline.withOpacity(.35)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  /// استبدال {count} فقط (بدون {label} لتفادي التكرار)
  String formatCount(String tpl, int count) =>
      tpl.replaceAll('{count}', '$count');
}

/// ===============================
/// القسم الرئيسي: تفاصيل الإعلان
/// ===============================
class AdCustomFieldsSection extends StatefulWidget {
  final List<CustomFieldModel> fields;
  final EdgeInsetsGeometry padding;
  final int columns; // افتراضي عمودين
  final String title;
  final bool showTitle;

  /// تخصيص بناء أيقونة من بيانات السيرفر
  final Widget Function(Map<String, dynamic> map, String label)? iconBuilder;

  /// إعدادات العرض
  final AdFieldsStyle style;

  const AdCustomFieldsSection({
    super.key,
    required this.fields,
    this.padding = const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
    this.columns = 2,
    this.title = 'تفاصيل الاعلان',
    this.showTitle = true,
    this.iconBuilder,
    this.style = const AdFieldsStyle(),
  });

  @override
  State<AdCustomFieldsSection> createState() => _AdCustomFieldsSectionState();
}

/// سجل موحّد لكل عنصر
typedef _FieldRec = ({
  Map<String, dynamic> map,
  String label,
  String value, // قيمة نصية مختصرة للعرض العادي
  String? iconUrl, // أيقونة الحقل من السيرفر إن وُجدت
  bool wide, // طلب عرض صف كامل (للصور/الملفات)
  bool checkbox, // هل هو حقل Checkbox؟
  List<String> labels, // ملصقات القيم المختارة (للـ Checkbox)
  String kind, // 'text' | 'image' | 'file' | 'checkbox'
  List<String> mediaUrls, // روابط الصور/الملفات إن وجدت
});

class _AdCustomFieldsSectionState extends State<AdCustomFieldsSection>
    with SingleTickerProviderStateMixin {
  static const int _defaultCount = 8;

  /// زر واحد يتحكم بإظهار بقية الشبكة + الأزرار السفلية
  bool _expanded = false;

  AdFieldsStyle get style => widget.style;

  @override
  Widget build(BuildContext context) {
    // 1) بناء العناصر + كشف النوع
    final List<_FieldRec> items = widget.fields
        .map<_FieldRec?>((f) {
          final map = _safeMap(f);
          final label = _labelOf(map);
          if (label.isEmpty) return null;

          final raw =
              map['value'] ?? map['display_value'] ?? map['displayValue'];
          final (textValue, _) = _valueOf(map);

          final urls = _collectUrls(raw);
          final isChk = _isCheckbox(map);
          final kind = isChk
              ? 'checkbox'
              : (urls.any(_isImageUrl)
                  ? 'image'
                  : urls.isNotEmpty
                      ? 'file'
                      : 'text');

          final labels = isChk ? _extractCheckboxLabels(map) : const <String>[];
          final isWide = (kind == 'image' || kind == 'file');

          // تجاهل النص الفارغ
          if (!isChk && kind == 'text' && textValue.isEmpty) return null;

          final iconUrl = _iconUrlOf(map);

          return (
            map: map,
            label: label,
            value: textValue,
            iconUrl: iconUrl,
            wide: isWide,
            checkbox: isChk,
            labels: labels,
            kind: kind,
            mediaUrls: urls
          );
        })
        .whereType<_FieldRec>()
        .toList();

    if (items.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // 2) نقسم: Grid للنصوص + Actions سفلية
    final gridItems = items.where((e) => e.kind == 'text').toList();
    final cbxActions = items.where((e) => e.kind == 'checkbox').toList();
    final imgActions = items.where((e) => e.kind == 'image').toList();
    final fileActions = items.where((e) => e.kind == 'file').toList();

    final bool hasActions = cbxActions.isNotEmpty ||
        imgActions.isNotEmpty ||
        fileActions.isNotEmpty;
    final bool hasMore = gridItems.length > _defaultCount;

    final List<_FieldRec> base = gridItems.take(_defaultCount).toList();
    final List<_FieldRec> extra = gridItems.skip(_defaultCount).toList();

    final List<_FieldRec> visibleGrid = _expanded ? [...base, ...extra] : base;

    return Padding(
      padding: widget.padding,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final fullWidth = constraints.maxWidth;
          final spacing = style.wrapSpacing;

          int colCount =
              widget.columns <= 1 ? 1 : widget.columns; // 2 افتراضيًا
          if (fullWidth < 340) colCount = 1;
          final itemW = (fullWidth - spacing * (colCount - 1)) / colCount;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.showTitle) ...[
                Text(
                  widget.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // --- شبكة الحقول العادية (نص) ---
              Wrap(
                spacing: style.wrapSpacing,
                runSpacing: style.wrapRunSpacing,
                children: visibleGrid.map((it) {
                  final width = it.wide ? fullWidth : itemW;
                  final leading = style.showServerIconOnTextRows
                      ? _buildServerIcon(context, it.map, it.iconUrl)
                      : null;

                  return SizedBox(
                    width: width,
                    child: _FieldRow(
                      label: it.label,
                      value: it.value,
                      leadingIcon: leading,
                      style: style,
                    ),
                  );
                }).toList(),
              ),

              // زر "عرض المزيد" يظهر فقط قبل التوسيع.
              if (!_expanded && (hasMore || hasActions)) ...[
                const SizedBox(height: 10),
                Center(
                  child: TextButton.icon(
                    onPressed: () =>
                        setState(() => _expanded = true), // فقط تفعيل التوسيع
                    icon: const Icon(Icons.expand_more),
                    label: Text(
                      hasMore
                          ? '${style.collapsedText} (${gridItems.length - _defaultCount})'
                          : style.collapsedText,
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: cs.primary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      textStyle: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
              // --- منطقة الأزرار السفلية (تظهر فقط عند التوسيع) ---
              if (hasActions && _expanded) ...[
                SizedBox(height: style.rowToDividerGap.toDouble()),
                _standardDivider(context),
                const SizedBox(height: 10),

                // صفوف كاملة: أيقونة السيرفر + عنوان الحقل (ثابتين) + زر "عرض"
                // Checkbox rows
                ...cbxActions.map((it) {
                  final buttonText = style.formatCount(
                      style.checkboxButtonLabel, it.labels.length);
                  final leading = style.showServerIconOnActionButtons
                      ? _buildServerActionIcon(context, it.map, it.iconUrl)
                      : null;

                  return _ActionLine(
                    width: fullWidth,
                    leading: leading,
                    label: it.label,
                    style: style,
                    trailing: _CheckboxActionButton(
                      title: it.label,
                      buttonText: buttonText, // بدون تكرار العنوان
                      labels: it.labels,
                      style: style,
                    ),
                  );
                }),

                // Images rows (يفتح أول صورة مباشرة)
                ...imgActions.map((it) {
                  final buttonText = style.formatCount(
                      style.imagesButtonLabel, it.mediaUrls.length);
                  final leading = style.showServerIconOnActionButtons
                      ? _buildServerActionIcon(context, it.map, it.iconUrl)
                      : null;

                  return _ActionLine(
                    width: fullWidth,
                    leading: leading,
                    label: it.label,
                    style: style,
                    trailing: _ImagesOpenButton(
                      title: it.label,
                      buttonText: buttonText, // بدون تكرار العنوان
                      imageUrls: it.mediaUrls,
                      style: style,
                    ),
                  );
                }),

                // Files rows (يفتح أول ملف مباشرة)
                ...fileActions.map((it) {
                  final buttonText = style.formatCount(
                      style.filesButtonLabel, it.mediaUrls.length);
                  final leading = style.showServerIconOnActionButtons
                      ? _buildServerActionIcon(context, it.map, it.iconUrl)
                      : null;

                  return _ActionLine(
                    width: fullWidth,
                    leading: leading,
                    label: it.label,
                    style: style,
                    trailing: _FilesOpenButton(
                      title: it.label,
                      buttonText: buttonText, // بدون تكرار العنوان
                      fileUrls: it.mediaUrls,
                      style: style,
                    ),
                  );
                }),

                const SizedBox(height: 10),
                _standardDivider(context),
              ],
            ],
          );
        },
      ),
    );
  }

  // ===== Helpers: تحويلات وقراءات آمنة =====

  Map<String, dynamic> _safeMap(CustomFieldModel f) {
    try {
      final m = f.toMap();
      return Map<String, dynamic>.from(m);
    } catch (_) {
      return const {};
    }
  }

  String _labelOf(Map<String, dynamic> m) {
    for (final k in ['title', 'label', 'name', 'field', 'slug']) {
      final v = m[k];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    return '';
  }

  (String, bool) _valueOf(Map<String, dynamic> m) {
    final dynamic direct =
        m['value'] ?? m['display_value'] ?? m['displayValue'];
    String text = _stringify(direct);
    bool wide = _looksLikeFileOrImage(direct);

    if (text.isEmpty) {
      for (final k in [
        'value_string',
        'valueString',
        'text',
        'val',
        'selected',
        'option'
      ]) {
        final v = m[k];
        text = _stringify(v);
        wide = wide || _looksLikeFileOrImage(v);
        if (text.isNotEmpty) break;
      }
    }
    if (text.isEmpty) {
      for (final k in ['values', 'options', 'list', 'choices']) {
        final v = m[k];
        text = _stringify(v);
        wide = wide || _looksLikeFileOrImage(v);
        if (text.isNotEmpty) break;
      }
    }
    return (text, wide);
  }

  String _stringify(dynamic v) {
    if (v == null) return '';
    if (v is String) return v.trim();
    if (v is num || v is bool) return v.toString();
    if (v is List) {
      final parts = v.map(_stringify).where((s) => s.isNotEmpty).toList();
      return parts.join(' , ');
    }
    if (v is Map) {
      final label = v['label'] ?? v['name'] ?? v['title'] ?? v['text'];
      final s = _stringify(label);
      if (s.isNotEmpty) return s;
    }
    return v.toString();
  }

  bool _looksLikeFileOrImage(dynamic node) => _collectUrls(node).isNotEmpty;

  List<String> _collectUrls(dynamic node) {
    final out = <String>[];
    void walk(n) {
      if (n == null) return;
      if (n is String) {
        final s = n.trim();
        if (s.startsWith('http') || s.startsWith('data:image')) out.add(s);
        return;
      }
      if (n is List) {
        for (final e in n) walk(e);
        return;
      }
      if (n is Map) {
        for (final v in n.values) walk(v);
        return;
      }
    }

    walk(node);
    return LinkedHashSet<String>.from(out).toList(growable: false);
  }

  bool _isImageUrl(String u) {
    final x = u.split('?').first.toLowerCase();
    return x.endsWith('.png') ||
        x.endsWith('.jpg') ||
        x.endsWith('.jpeg') ||
        x.endsWith('.webp') ||
        x.endsWith('.svg') ||
        u.startsWith('data:image');
  }

  String? _iconUrlOf(Map<String, dynamic> m) {
    for (final k in [
      'icon',
      'icon_url',
      'iconUrl',
      'iconPath',
      'icon_image',
      'image',
      'media'
    ]) {
      if (m.containsKey(k)) {
        final u = _findFirstUrl(m[k]);
        if (u != null) return u;
      }
    }
    return _findFirstUrl(m);
  }

  String? _findFirstUrl(dynamic node) {
    if (node == null) return null;
    if (node is String) {
      final s = node.trim();
      if (s.startsWith('http') || s.startsWith('data:image')) return s;
      return null;
    }
    if (node is List) {
      for (final e in node) {
        final u = _findFirstUrl(e);
        if (u != null) return u;
      }
    }
    if (node is Map) {
      for (final v in node.values) {
        final u = _findFirstUrl(v);
        if (u != null) return u;
      }
    }
    return null;
  }

  /// أيقونة شبكة الحقول (صندوق ثابت + شيمر)
  Widget? _buildServerIcon(
      BuildContext context, Map<String, dynamic> map, String? url) {
    if (widget.iconBuilder != null) {
      final w = widget.iconBuilder!(map, _labelOf(map));
      return _iconBox(child: w, size: style.leadingBoxSize);
    }
    url ??= _iconUrlOf(map);
    if (url == null || url.isEmpty) return null;
    return _iconBox(
      child: _ServerIcon(url: url, size: style.leadingIconSize),
      size: style.leadingBoxSize,
    );
  }

  /// أيقونة الأزرار السفلية — من السيرفر فقط (بدون fallback)
  Widget? _buildServerActionIcon(
      BuildContext context, Map<String, dynamic> map, String? url) {
    url ??= _iconUrlOf(map);
    if (url == null || url.isEmpty) return null;
    return SizedBox.square(
      dimension: style.actionIconSize + 6,
      child: Center(child: _ServerIcon(url: url, size: style.actionIconSize)),
    );
  }

  // ===== Helpers خاصة بالـ Checkbox =====
  bool _isCheckbox(Map<String, dynamic> m) {
    final t = _typeOf(m);
    return t == 'checkbox' ||
        t == 'multi_checkbox' ||
        t == 'multi-check' ||
        t == 'checks';
  }

  String _typeOf(Map<String, dynamic> m) {
    for (final k in ['type', 'field_type', 'input_type', 'kind']) {
      final v = m[k];
      if (v is String && v.trim().isNotEmpty) return v.trim().toLowerCase();
    }
    return '';
  }

  Map<String, String> _buildLabelIndex(List<dynamic> all) {
    final map = <String, String>{};
    for (final e in all) {
      if (e is Map) {
        final v = e['value']?.toString();
        final l = e['label']?.toString();
        if (v != null && v.isNotEmpty)
          map[v] = (l == null || l.isEmpty) ? v : l;
      } else if (e != null) {
        final s = e.toString();
        if (s.isNotEmpty) map[s] = s;
      }
    }
    return map;
  }

  List<dynamic> _toList(dynamic node) {
    if (node == null) return const [];
    if (node is List) return node;
    if (node is String && node.contains(',')) {
      return node
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    return [node];
  }

  List<String> _extractCheckboxLabels(Map<String, dynamic> m) {
    final selectedNode =
        m['selected'] ?? m['value'] ?? m['values'] ?? m['options'];
    final allNode =
        m['all_values'] ?? m['values'] ?? m['options'] ?? m['choices'];

    final selected = _toList(selectedNode);
    final all = _toList(allNode);

    final index = _buildLabelIndex(all);
    final seen = LinkedHashSet<String>();

    for (final e in selected) {
      if (e is Map) {
        final lbl = (e['label']?.toString() ?? '').trim();
        final val = (e['value']?.toString() ?? '').trim();
        final resolved =
            lbl.isNotEmpty ? lbl : (val.isNotEmpty ? (index[val] ?? val) : '');
        if (resolved.isNotEmpty) seen.add(resolved);
      } else if (e != null) {
        final s = e.toString().trim();
        if (s.isNotEmpty) seen.add(index[s] ?? s);
      }
    }
    return seen.toList(growable: false);
  }
}

/// ===============================
/// صف حقل نصّي عادي + Divider
/// ===============================
class _FieldRow extends StatelessWidget {
  const _FieldRow({
    required this.label,
    required this.value,
    required this.style,
    this.leadingIcon,
  });

  final String label;
  final String value;
  final Widget? leadingIcon;
  final AdFieldsStyle style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final labelStyle =
        (style.labelTextStyle ?? theme.textTheme.bodyMedium)?.copyWith(
      color: cs.onSurface.withOpacity(.70),
      fontWeight: FontWeight.w700,
      height: style.titleLineHeight,
    );

    final valueStyle =
        (style.valueTextStyle ?? theme.textTheme.bodySmall)?.copyWith(
      color: cs.onSurface,
      height: style.valueLineHeight,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            (leadingIcon ??
                SizedBox(
                    width: style.leadingBoxSize, height: style.leadingBoxSize)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Tooltip(
                    message: label,
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: labelStyle,
                    ),
                  ),
                  SizedBox(height: style.titleToValueGap),
                  Text(
                    value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: valueStyle,
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: style.rowToDividerGap),
        _standardDivider(context),
      ],
    );
  }
}

/// ===============================
/// صف أكشن كامل العرض: أيقونة سيرفر + عنوان + زر تشغيل/عرض
/// ===============================
class _ActionLine extends StatelessWidget {
  const _ActionLine({
    required this.width,
    required this.label,
    required this.style,
    required this.trailing,
    this.leading,
  });

  final double width;
  final String label;
  final Widget? leading;
  final Widget trailing;
  final AdFieldsStyle style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final labelStyle =
        (style.labelTextStyle ?? theme.textTheme.bodyMedium)?.copyWith(
      color: cs.onSurface.withOpacity(.70),
      fontWeight: FontWeight.w700,
      height: style.titleLineHeight,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SizedBox(
        width: width,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // أيقونة السيرفر (إن وُجدت) أو فراغ محجوز للمحاذاة
            (leading ??
                SizedBox(
                    width: style.leadingBoxSize, height: style.leadingBoxSize)),
            const SizedBox(width: 8),

            // عنوان الحقل
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: labelStyle,
              ),
            ),

            const SizedBox(width: 8),

            // زر الأكشن (عرض القيم/الصور/الملفات)
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 120),
              child: trailing,
            ),
          ],
        ),
      ),
    );
  }
}

// ===============================
// أزرار الأكشن
// ===============================

// Checkbox: يفتح Dialog بحث/نسخ (القيم النصية)

class _CheckboxActionButton extends StatelessWidget {
  const _CheckboxActionButton({
    required this.title,
    required this.buttonText,
    required this.labels,
    required this.style,
  });

  final String title;
  final String buttonText;
  final List<String> labels;
  final AdFieldsStyle style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return OutlinedButton(
      onPressed: () => _showDialog(context, title, labels, style),
      child: Text(buttonText,
          style: style.actionButtonTextStyle ?? theme.textTheme.bodySmall),
      style: style.effectiveActionButtonStyle(context),
    );
  }

  static Future<void> _showDialog(
    BuildContext context,
    String title,
    List<String> labels,
    AdFieldsStyle style,
  ) async {
    final theme = Theme.of(context);
    await showDialog(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        final ValueNotifier<List<String>> filtered =
            ValueNotifier<List<String>>(labels);

        void applyFilter(String s) {
          if (s.trim().isEmpty) {
            filtered.value = labels;
          } else {
            final t = s.toLowerCase();
            filtered.value =
                labels.where((e) => e.toLowerCase().contains(t)).toList();
          }
        }

        return Dialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560, maxHeight: 520),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Column(
                children: [
                  // رأس الحوار
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      IconButton(
                        tooltip: style.dialogCloseText,
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),

                  // قائمة القيم
                  const SizedBox(height: 6),
                  Divider(
                      height: 1,
                      color: theme.colorScheme.outline.withOpacity(.25)),
                  const SizedBox(height: 6),

                  Expanded(
                    child: ValueListenableBuilder<List<String>>(
                      valueListenable: filtered,
                      builder: (_, list, __) {
                        if (labels.isEmpty) {
                          return Center(
                            child: Text(
                              style.emptyPlaceholder,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color:
                                    theme.colorScheme.onSurface.withOpacity(.6),
                              ),
                            ),
                          );
                        }
                        return Scrollbar(
                          thumbVisibility: true,
                          child: ListView.separated(
                            physics: const BouncingScrollPhysics(
                                parent: AlwaysScrollableScrollPhysics()),
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            itemCount: list.length,
                            separatorBuilder: (_, __) => Divider(
                              height: 1,
                              color: theme.colorScheme.outline.withOpacity(.15),
                            ),
                            itemBuilder: (_, i) => ListTile(
                              dense: true,
                              leading: const Icon(Icons.check, size: 18),
                              title: Text(list[i],
                                  style: theme.textTheme.bodyMedium),
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 6),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: Text(style.dialogCloseText),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// Images: يفتح أول صورة مباشرة (view) — بدون أي Dialog

class _ImagesOpenButton extends StatelessWidget {
  const _ImagesOpenButton({
    required this.title,
    required this.buttonText,
    required this.imageUrls,
    required this.style,
  });

  final String title;
  final String buttonText;
  final List<String> imageUrls;
  final AdFieldsStyle style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return OutlinedButton(
      onPressed: () {
        if (imageUrls.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('لا توجد صور للعرض')),
          );
          return;
        }
        // فتح أول صورة مباشرة
        launchUrlString(imageUrls.first);
        if (imageUrls.length > 1) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تم فتح أول صورة من ${imageUrls.length}')),
          );
        }
      },
      child: Text(buttonText,
          style: style.actionButtonTextStyle ?? theme.textTheme.bodySmall),
      style: style.effectiveActionButtonStyle(context),
    );
  }
}

// Files: يفتح أول ملف مباشرة (view) — بدون أي Dialog
class _FilesOpenButton extends StatelessWidget {
  const _FilesOpenButton({
    required this.title,
    required this.buttonText,
    required this.fileUrls,
    required this.style,
  });

  final String title;
  final String buttonText;
  final List<String> fileUrls;
  final AdFieldsStyle style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return OutlinedButton(
      onPressed: () {
        if (fileUrls.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('لا توجد ملفات للعرض')),
          );
          return;
        }
        // فتح أول ملف مباشرة
        launchUrlString(fileUrls.first);
        if (fileUrls.length > 1) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تم فتح أول ملف من ${fileUrls.length}')),
          );
        }
      },
      child: Text(buttonText,
          style: style.actionButtonTextStyle ?? theme.textTheme.bodySmall),
      style: style.effectiveActionButtonStyle(context),
    );
  }
}

/// ===============================
/// أدوات مشتركة: Divider, Icon Box, ServerIcon, Shimmer
/// ===============================
Widget _standardDivider(BuildContext context) => Divider(
      height: 1,
      thickness: .6,
      color: Theme.of(context).brightness == Brightness.dark
          ? Colors.grey.shade800
          : const Color(0xFFE0E0E0),
    );

Widget _iconBox({required Widget child, double size = 24}) =>
    SizedBox(width: size, height: size, child: Center(child: child));

class _ServerIcon extends StatelessWidget {
  final String url;
  final double size;
  const _ServerIcon({required this.url, this.size = 20});

  @override
  Widget build(BuildContext context) {
    final clean = url.split('?').first.toLowerCase();
    final isSvg =
        clean.endsWith('.svg') || url.startsWith('data:image/svg+xml');

    if (isSvg) {
      return svg.SvgPicture.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.contain,
        placeholderBuilder: (_) =>
            _ShimmerBox(width: size, height: size, radius: 4),
      );
    }

    return Image.network(
      url,
      width: size,
      height: size,
      fit: BoxFit.contain,
      frameBuilder: (ctx, child, frame, wasSyncLoaded) {
        if (wasSyncLoaded || frame != null) return child;
        return _ShimmerBox(width: size, height: size, radius: 4);
      },
      errorBuilder: (_, __, ___) => SizedBox(width: size, height: size),
    );
  }
}

class _ShimmerBox extends StatefulWidget {
  const _ShimmerBox({
    required this.width,
    required this.height,
    this.radius = 8,
  });

  final double width;
  final double height;
  final double radius;

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100))
    ..repeat();

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final base = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE9E9E9);
    final highlight =
        isDark ? const Color(0xFF3A3A3A) : const Color(0xFFF5F5F5);

    return AnimatedBuilder(
      animation: _ac,
      builder: (_, __) {
        final v = _ac.value; // 0..1
        return ClipRRect(
          borderRadius: BorderRadius.circular(widget.radius),
          child: ShaderMask(
            shaderCallback: (rect) {
              return LinearGradient(
                begin: Alignment(-1.0 - 1.5 + 3 * v, 0),
                end: const Alignment(1.0, 0),
                colors: [base, highlight, base],
                stops: const [0.25, 0.5, 0.75],
              ).createShader(rect);
            },
            blendMode: BlendMode.srcATop,
            child: Container(
              width: widget.width,
              height: widget.height,
              color: base,
            ),
          ),
        );
      },
    );
  }
}

// استبدلها بمنطق مشروعك لفتح الروابط خارجيًا

void launchUrlString(String url) {
  debugPrint('Open: $url');
}
