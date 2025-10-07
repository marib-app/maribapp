import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:marib/utils/ui_utils.dart';

// إضافات fwfh

import 'package:url_launcher/url_launcher.dart';

class AppHtml extends StatelessWidget {
  final String data;
  final String? baseUrl;

  /// يحاكي max-width في CSS لتوسيط المحتوى وعرض مريح
  final double maxWidth;
  final bool centerContent;

  /// نحافظ على inline styles (ولا نفرض ستايل بديل إلا للحالات الخاصة)
  final bool preserveInlineStyles;

  /// يسمح بتحديد النص
  final bool selectable;

  /// هوامش خارجية بسيطة حول المحتوى
  final EdgeInsetsGeometry outerPadding;

  /// تمكين فتح الصور في عارض كامل الشاشة
  final bool enableImageViewer;

  const AppHtml({
    super.key,
    required this.data,
    this.baseUrl,
    this.maxWidth = 720, // 680–760 مريح
    this.centerContent = true,
    this.preserveInlineStyles = true,
    this.selectable = false,
    this.outerPadding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    this.enableImageViewer = true,
  });

  // --- أدوات صغيرة لقراءة قيم من style ---
  double? _readPx(Map<String, String> style, String key) {
    final v = style[key];
    if (v == null) return null;
    final m = RegExp(r'(-?\d+(\.\d+)?)px').firstMatch(v);
    if (m == null) return null;
    return double.tryParse(m.group(1)!);
  }

  Map<String, String> _parseInlineStyle(String? styleAttr) {
    final map = <String, String>{};
    if (styleAttr == null) return map;
    for (final p in styleAttr.split(';')) {
      final kv = p.split(':');
      if (kv.length == 2) {
        map[kv[0].trim().toLowerCase()] = kv[1].trim().toLowerCase();
      }
    }
    return map;
  }

  EdgeInsets _marginFromStyle(Map<String, String> st,
      {double fallbackBottom = 10}) {
    // نقرأ margin أو margin-bottom إن وجدت
    if (st.containsKey('margin')) {
      final m = st['margin']!;
      // أشكال مختصرة: 10px | 10px 5px | 10px 5px 8px | 10px 5px 8px 2px
      final parts = m.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
      double px(String s) =>
          double.tryParse(
              RegExp(r'(-?\d+(\.\d+)?)').firstMatch(s)?.group(1) ?? '') ??
          0;
      if (parts.length == 1) {
        final v = px(parts[0]);
        return EdgeInsets.all(v);
      } else if (parts.length == 2) {
        final vtb = px(parts[0]);
        final vlr = px(parts[1]);
        return EdgeInsets.fromLTRB(vlr, vtb, vlr, vtb);
      } else if (parts.length == 3) {
        final vt = px(parts[0]);
        final vlr = px(parts[1]);
        final vb = px(parts[2]);
        return EdgeInsets.fromLTRB(vlr, vt, vlr, vb);
      } else if (parts.length >= 4) {
        final vt = px(parts[0]);
        final vr = px(parts[1]);
        final vb = px(parts[2]);
        final vl = px(parts[3]);
        return EdgeInsets.fromLTRB(vl, vt, vr, vb);
      }
    }
    final mb = _readPx(st, 'margin-bottom') ?? fallbackBottom;
    final mt = _readPx(st, 'margin-top') ?? 0;
    final ml = _readPx(st, 'margin-left') ?? 0;
    final mr = _readPx(st, 'margin-right') ?? 0;
    return EdgeInsets.fromLTRB(ml, mt, mr, mb);
  }

  void _openImageViewer(BuildContext context, String src) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(.9),
      pageBuilder: (_, __, ___) {
        return GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4,
                  child: UiUtils.getImage(src, fit: BoxFit.contain),
                ),
              ),
              Positioned(
                top: 16,
                right: 16,
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final baseText =
        (Theme.of(context).textTheme.bodyMedium ?? const TextStyle())
            .copyWith(height: 1.65);

    final htmlView = HtmlWidget(
      data,
      renderMode: RenderMode.column,
      baseUrl: baseUrl != null ? Uri.tryParse(baseUrl!) : null,
      textStyle: baseText,

      // ✅ تنسيقات افتراضية "لطيفة" فقط عند غياب inline styles
      // + دعم أصناف (class) خاصة للـ badge/chips لتحسين التناسق
      customStylesBuilder: (element) {
        final tag = element.localName?.toLowerCase();
        final classes =
            (element.attributes['class'] ?? '').split(RegExp(r'\s+')).toSet();
        final hasInline = element.attributes.containsKey('style');

        // نبدأ بخريطة فارغة ونضيف عليها حسب الحاجة
        final s = <String, String>{};

        // ---- تحسين الشارة والـchips لو استُخدمت هذه الأصناف ----
        if (classes.contains('badge')) {
          // نجبرها على inline-flex + محاذاة وسط + فجوة ثابتة
          s.addAll({
            'display': 'inline-flex',
            'align-items': 'center',
            'gap': '8px',
            'vertical-align': 'middle',
            // padding/border/background سيحترم inline إن وُجد
          });
        }
        if (classes.contains('chip')) {
          s.addAll({
            'display': 'inline-flex',
            'align-items': 'center',
            'gap': '6px',
            'vertical-align': 'middle',
          });
        }
        if (classes.contains('chipset')) {
          s.addAll({
            'display': 'flex',
            'flex-wrap': 'wrap',
            'gap': '8px',
            'justify-content': 'center',
          });
        }

        // إن أردت الحفاظ التام على inline، ارجع الآن لو ما أضفنا شيء
        if (preserveInlineStyles && hasInline && s.isEmpty) return null;

        // افتراضيات لطيفة فقط عند غياب inline
        if (!hasInline) {
          switch (tag) {
            case 'h1':
              s.addAll({
                'margin': '0 0 14px',
                'font-size': '24px',
                'font-weight': '800',
                'text-align': 'center'
              });
              break;
            case 'h2':
              s.addAll({
                'margin': '0 0 12px',
                'font-size': '20px',
                'font-weight': '700'
              });
              break;
            case 'h3':
              s.addAll({
                'margin': '0 0 10px',
                'font-size': '18px',
                'font-weight': '700'
              });
              break;
            case 'p':
              s.addAll({'margin': '0 0 10px', 'line-height': '1.65'});
              break;
            case 'ul':
            case 'ol':
              s.addAll({
                'margin': '0 0 12px',
                'padding': '0 18px',
                'list-style-position': 'inside'
              });
              break;
            case 'li':
              s.addAll({'margin': '0 0 6px'});
              break;
            case 'img':
              s.addAll({
                'display': 'block',
                'max-width': '100%',
                'height': 'auto',
                'margin': '0 0 10px'
              });
              break;
            case 'table':
              s.addAll({
                'width': '100%',
                'border-collapse': 'separate',
                'border-spacing': '0'
              });
              break;
            case 'th':
            case 'td':
              s.addAll({'padding': '10px', 'border-bottom': '1px solid #eee'});
              break;
          }
        }
        return s.isEmpty ? null : s;
      },

      // ✅ فتح الصور في عارض كامل الشاشة مع الحفاظ على هوامش الـHTML
      customWidgetBuilder: (element) {
        if (!enableImageViewer) return null;
        if (element.localName?.toLowerCase() != 'img') return null;

        final src =
            element.attributes['src'] ?? element.attributes['data-src'] ?? '';
        if (src.isEmpty) return const SizedBox.shrink();

        final st = _parseInlineStyle(element.attributes['style']);
        final margin = _marginFromStyle(st, fallbackBottom: 10);
        final borderRadius = _readPx(st, 'border-radius') ?? 12;
        final w = _readPx(st, 'width');
        final h = _readPx(st, 'height');

        Widget img = UiUtils.getImage(
          src,
          fit: BoxFit.cover,
          width: w, // لو null تتمدّد طبيعي حسب الحاوية
          height: h,
        );

        img = ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: img,
        );

        return Padding(
          padding: margin,
          child: GestureDetector(
            onTap: () => _openImageViewer(context, src),
            child: img,
          ),
        );
      },

      // ✅ فتح الروابط بشكل صحيح
      onTapUrl: (url) async {
        final uri = Uri.tryParse(url);
        if (uri == null) return false;

        if (url.startsWith('tel:') ||
            url.startsWith('mailto:') ||
            url.contains('wa.me') ||
            uri.scheme == 'whatsapp') {
          return await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
        try {
          return await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
        } catch (_) {
          return await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },

      enableCaching: true,
    );

    // نحاكي max-width + margin:auto
    Widget content = htmlView;
    if (centerContent) {
      content = Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: htmlView,
        ),
      );
    }

    // RTL + حواف خارجية بسيطة
    content = Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: outerPadding,
        child: content,
      ),
    );

    return selectable ? SelectionArea(child: content) : content;
  }
}
