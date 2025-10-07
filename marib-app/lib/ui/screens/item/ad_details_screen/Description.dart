import 'package:flutter/material.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';

/// ويدجت عرض "تفاصيل إضافية" كوصف للإعلان.
/// - إن مرّرت [description] نعرضها مباشرة.
/// - إن مرّرت [loadDescription] نحمّل الوصف من السيرفر مع حالة تحميل/خطأ.
/// - يدعم "عرض المزيد" لو النص طويل.
/// - ⚙️ تحكّم بالتباعد والمسافات عبر: lineHeight / titleBottomSpacing / letterSpacing.
class AdDescriptionSection extends StatefulWidget {
  final String? description; // وصف جاهز (اختياري)
  final Future<String?> Function()? loadDescription; // جلب من السيرفر (اختياري)
  final String title;
  final EdgeInsetsGeometry? margin;

  // ⚙️ إعدادات تجربة الاستخدام (اختيارية)
  final bool selectable; // جعل النص قابل للتحديد
  final int collapsedLines; // عدد الأسطر في الوضع المطوي
  final double fadeHeight; // ارتفاع طبقة التدرّج عند الطي
  final String expandLabel; // نص زر التوسيع
  final String collapseLabel; // نص زر الإخفاء

  // ⚙️ إعدادات التنسيق
  final double lineHeight; // تباعد الأسطر
  final double titleBottomSpacing; // المسافة بين العنوان والنص
  final double letterSpacing; // مسافة طفيفة بين الحروف

  const AdDescriptionSection({
    super.key,
    this.description,
    this.loadDescription,
    this.title = 'تفاصيل إضافية',
    this.margin,

    // تجربة الاستخدام الافتراضية
    this.selectable = true,
    this.collapsedLines = 6,
    this.fadeHeight = 28,
    this.expandLabel = 'عرض المزيد',
    this.collapseLabel = 'إخفاء',

    // تنسيق افتراضي مريح للقراءة
    this.lineHeight = 1.6,
    this.titleBottomSpacing = 10,
    this.letterSpacing = .1,
  });

  @override
  State<AdDescriptionSection> createState() => _AdDescriptionSectionState();
}

class _AdDescriptionSectionState extends State<AdDescriptionSection>
    with TickerProviderStateMixin {
  bool _loading = false;
  String? _error;
  String? _text;
  bool _expanded = false;
  bool _isOverflowing = false; // يُحدَّث ديناميكيًا حسب العرض وعدد الأسطر

  @override
  void initState() {
    super.initState();
    // أولوية: description الجاهزة، وإلا لو فيه loader نحمل
    if ((widget.description ?? '').trim().isNotEmpty) {
      _text = widget.description!.trim();
    } else if (widget.loadDescription != null) {
      _fetch();
    }
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final t = await widget.loadDescription!.call();
      _text = (t ?? '').trim();
    } catch (e) {
      _error = 'تعذر جلب الوصف. حاول مرة أخرى.';
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.color;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;

    return Padding(
      padding:
          widget.margin ?? const EdgeInsetsDirectional.fromSTEB(10, 8, 10, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ===== سطر عنوان ضمن خط علوي =====
          _headingLine(context), // ← ----- عنوان القسم -----
          SizedBox(height: widget.titleBottomSpacing),

          // حالة تحميل
          if (_loading) _buildShimmer(context),

          // حالة خطأ
          if (!_loading && _error != null) ...[
            Row(
              children: [
                const Icon(Icons.error_outline, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _error!,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: OutlinedButton.icon(
                onPressed: _fetch,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('إعادة المحاولة'),
              ),
            ),
          ],

          // النص
          if (!_loading && _error == null) _buildTextSection(context, bgColor),

          // ===== مسافة + فاصل سفلي باهت =====
          const SizedBox(height: 10),
          _softDivider(context),
        ],
      ),
    );
  }

  /// ----- عنوان القسم ----- (Divider يمين ويسار والعنوان بالوسط)

  /// ----- عنوان القسم -------------------------
  /// نجعل العنوان مائلًا لليمين عبر جعل الخط الأيسر أطول (leftFlex > rightFlex)

  Widget _headingLine(BuildContext context) {
    final lineColor = Theme.of(context).dividerColor.withOpacity(0.16);
    final titleStyle = Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: .2,
        );

    // 👇 عدّل النسب حسب رغبتك:
    // كلما زدت leftFlex، اندفع العنوان أكثر لليمين.
    const int leftFlex = 1; // جرّب 3..6
    const int rightFlex = 7; // يظل قصير لترك العنوان قريبًا من اليمين

    return Row(
      children: [
        Expanded(flex: leftFlex, child: Container(height: 1, color: lineColor)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: Text(widget.title, style: titleStyle),
        ),
        Expanded(
            flex: rightFlex, child: Container(height: 1, color: lineColor)),
      ],
    );
  }

  /// Divider ناعم (رمادي باهت) متوافق مع الوضعين

  Widget _softDivider(BuildContext context) {
    final base = Theme.of(context).dividerColor;
    return Divider(
      height: 12,
      thickness: 1,
      color: base.withOpacity(0.1),
    );
  }

  Widget _buildShimmer(BuildContext context) {
    final cs = context.color;
    // شيمر بسيط (بدون حزمة خارجية)
    Widget bar(double h, [double w = double.infinity]) => Container(
          height: h,
          width: w,
          decoration: BoxDecoration(
            color: cs.territoryColor.withOpacity(.10),
            borderRadius: BorderRadius.circular(8),
          ),
        );
    return Column(
      children: [
        bar(12),
        const SizedBox(height: 8),
        bar(12, MediaQuery.of(context).size.width * .85),
        const SizedBox(height: 8),
        bar(12, MediaQuery.of(context).size.width * .70),
      ],
    );
  }

  /// قسم النص مع تجربة "عرض المزيد" المحسّنة:
  /// - كشف تجاوز الأسطر فعليًا باستخدام TextPainter
  /// - انتقال سلس عبر AnimatedSize
  /// - طبقة Fade تُظهر وجود محتوى إضافي عند الطي
  Widget _buildTextSection(BuildContext context, Color bgColor) {
    final base = Theme.of(context).textTheme.bodyMedium;

    // 👇 ننسخ نمط النص ونعلي التباعد بين الأسطر والحروف
    final textStyle = base?.copyWith(
      height: widget.lineHeight,
      letterSpacing: widget.letterSpacing,
    );

    final txt = (_text ?? '').trim();
    if (txt.isEmpty) {
      return Text('لا يوجد وصف', style: textStyle ?? base);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // تحقق تجاوز الأسطر عند الحالة المطوية
        _isOverflowing = _exceedsMaxLines(
          text: txt,
          style: textStyle ?? base,
          maxWidth: constraints.maxWidth,
          maxLines: widget.collapsedLines,
          textDirection: Directionality.of(context),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stack لطبقة التدرّج أثناء الطي
            Stack(
              children: [
                // انتقال سلس في الارتفاع عند الطي/التوسيع
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: _expanded
                        ? const BoxConstraints() // ارتفاع حر عند التوسيع
                        : BoxConstraints(
                            // قصّ إلى عدد أسطر محدد عند الطي
                            maxHeight: _estimatedHeightForLines(
                              context,
                              lines: widget.collapsedLines,
                              style: textStyle ?? base,
                            ),
                          ),
                    child: widget.selectable
                        ? SelectableText(
                            txt,
                            style: textStyle ?? base,
                            textAlign: TextAlign.start,
                          )
                        : Text(
                            txt,
                            style: textStyle ?? base,
                            textAlign: TextAlign.start,
                          ),
                  ),
                ),

                // طبقة Fade فقط عندما: غير موسّع && فعلياً فيه تجاوز
                if (!_expanded && _isOverflowing)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: IgnorePointer(
                      ignoring: true,
                      child: Container(
                        height: widget.fadeHeight,
                        decoration: BoxDecoration(
                          // تدرّج من شفاف إلى لون الخلفية (بدون بطاقة)
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              bgColor.withOpacity(0.0),
                              bgColor,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            // زر عرض المزيد/إخفاء — يظهر فقط إذا كان هناك تجاوز فعلي
            if (_isOverflowing) ...[
              const SizedBox(height: 6),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: () => setState(() => _expanded = !_expanded),
                  icon: AnimatedRotation(
                    duration: const Duration(milliseconds: 200),
                    turns: _expanded ? 0.5 : 0.0, // تدوير السهم 180°
                    child: const Icon(Icons.expand_more_rounded, size: 20),
                  ),
                  label: Text(
                      _expanded ? widget.collapseLabel : widget.expandLabel),
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.onSurface,
                    padding: const EdgeInsetsDirectional.fromSTEB(8, 6, 8, 6),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  // يفحص هل النص سيتجاوز عدد الأسطر المحدد فعليًا ضمن عرض معيّن

  bool _exceedsMaxLines({
    required String text,
    required TextStyle? style,
    required double maxWidth,
    required int maxLines,
    required TextDirection textDirection,
  }) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: textDirection,
      maxLines: maxLines,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);

    // إذا النص لم يُرسم بالكامل ضمن maxLines → فهو متجاوز
    return tp.didExceedMaxLines;
  }

  /// تقدير ارتفاع عدد أسطر محدد لنمط معيّن (للاقتطاع الناعم عند الطي)
  double _estimatedHeightForLines(
    BuildContext context, {
    required int lines,
    required TextStyle? style,
  }) {
    final s = style ?? Theme.of(context).textTheme.bodyMedium;
    final fontSize = s?.fontSize ?? 14;
    final heightFactor = s?.height ?? 1.2;
    final lineHeight = fontSize * heightFactor;
    // نضيف هامشًا بسيطًا لتجنب قص البازلاين الأخير
    return lineHeight * lines + 2;
  }
}
