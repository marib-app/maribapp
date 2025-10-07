// الهدف: واجهة تسجيل "العقاري" فقط.
// يعتمد على shared widgets (مثل RealEstateLogoPicker و PhoneFieldsRow).
// لا يحتوي أي منطق أعمال، مجرد واجهة صافية.
import 'dart:ui' as ui; // Path, PathMetric
import 'dart:math' as math; // min
import 'dart:async';

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:marib/ui/screens/widgets/custom_text_form_field.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';

import 'package:flutter/scheduler.dart';

import 'package:marib/utils/ui_utils.dart';

// lib/ui/screens/auth/sign_up/widgets/real_estate_section.dart

// واجهة "العقاري" — مقسّمة إلى بطاقات/كلاسات صغيرة قابلة لإعادة الاستخدام.
// - RealEstateSection: الغلاف الذي يرتّب البطاقات
// - _LogoCard: بطاقة الشعار مع أنيميشن تحميل/نجاح وتلميح بعد الرفع
// - _OfficeNameCard: بطاقة اسم المكتب
// - _LocationCard: بطاقة الموقع الجغرافي مع زر كامل العرض + تلميح كامل
// - _ContactCard: بطاقة أرقام التواصل (الهاتف + الواتساب كلٌ في سطر)
// - _SubmitBar: شريط تقديم الطلب (زر رئيسي بحالة تحميل/تعطيل)
//
// ملاحظة: جميع هذه الكلاسات UI فقط. المنطق (مثل الرفع/الحفظ) يبقى في الشاشة الأم.
// يجمع البطاقات ويربطها بخصائص الشاشة الأم (بدون منطق).

class RealEstateSection extends StatelessWidget {
  // === شعار المكتب ===
  final File? logo;
  final VoidCallback onPickLogo;

  // === حقول النص ===
  final TextEditingController officeName;
  final TextEditingController officePhone;
  final TextEditingController officeWhatsapp;
  final TextEditingController officeLocation;

  // === البلد و بادئة الهاتف ===
  final String prefixText; // مثال: "🇾🇪 +967"
  final VoidCallback onPickCountry;

  // === الموقع ===
  final bool isLocationLoading;
  final VoidCallback onGetLocation;

  // === أنيميشن اختيارية للشعار ===
  final bool isLogoUploading; // يُظهر لودر أثناء الرفع
  final double? logoUploadProgress; // 0..1
  final bool showLogoPreviewHint; // يُظهر تلميح "هكذا سيظهر شعارك للمستخدمين"

  // === إبراز الحقول الإلزامية بصريًا ===
  final bool highlightRequired;

  // === شريط الإرسال (اختياري) ===
  final VoidCallback? onSubmit; // عند الضغط على "إكمال التسجيل"
  final bool isSubmitting; // لعرض حالة تحميل على الزر

  // === تحكم الحاوية (جديد) ===
  /// أقصى عرض للقسم. اتركه null ليكون فل-ويدث (يمتد حتى الحواف مع الـ gutter).
  final double? sectionMaxWidth;

  /// الفراغ الصغير عن أطراف الشاشة (dp). افتراضي 6.
  final double horizontalGutter;

  /// إزالة أي padding يضيفه ScrollView/MediaQuery يمين/يسار.
  final bool removeViewportPadding;

  const RealEstateSection({
    super.key,
    // شعار
    required this.logo,
    required this.onPickLogo,
    // حقول
    required this.officeName,
    required this.officePhone,
    required this.officeWhatsapp,
    required this.officeLocation,
    // بلد/بادئة
    required this.prefixText,
    required this.onPickCountry,
    // موقع
    required this.isLocationLoading,
    required this.onGetLocation,
    // أنيميشن الشعار (اختياري)
    this.isLogoUploading = false,
    this.logoUploadProgress,
    this.showLogoPreviewHint = false,
    // إبراز الإلزامي (اختياري)
    this.highlightRequired = false,
    // إرسال (اختياري)
    this.onSubmit,
    this.isSubmitting = false,
    // تحكم الحاوية (اختياري)
    this.sectionMaxWidth, // null => Full-bleed
    this.horizontalGutter = -12, // فراغ بسيط عن الأطراف
    this.removeViewportPadding = true,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.color;

    final media = MediaQuery.of(context);
    final screenW = media.size.width;
    final safeLeft = media.padding.left;
    final safeRight = media.padding.right;

    // أقصى عرض: إن تركته null => نفس عرض الشاشة (فل-ويدث).
    final maxW = sectionMaxWidth ?? screenW;

    // نفرض حدود منطقية للـ gutter
    final double side = horizontalGutter.clamp(0, 32);

    // الحشو الجانبي (يشمل الـ SafeArea)
    final pad = EdgeInsetsDirectional.only(
      start: side + safeLeft,
      end: side + safeRight,
    );

    final content = Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1) بطاقة الشعار
            _LogoCard(
              image: logo,
              onPick: onPickLogo,
              isUploading: isLogoUploading,
              progress: logoUploadProgress,
              showPreviewHint: showLogoPreviewHint,
              highlightRequired: highlightRequired,
            ),
            const SizedBox(height: 14),

            // 2) بطاقة اسم المكتب
            _OfficeNameCard(
              controller: officeName,
              highlightRequired: highlightRequired,
            ),
            const SizedBox(height: 14),

            // 3) بطاقة الموقع الجغرافي
            _LocationCard(
              controller: officeLocation,
              isLoading: isLocationLoading,
              onGetLocation: onGetLocation,
              highlightRequired: highlightRequired,
            ),
            const SizedBox(height: 14),

            // 4) بطاقة أرقام التواصل
            _ContactCard(
              phone: officePhone,
              whatsapp: officeWhatsapp,
              prefixText: prefixText,
              onPickCountry: onPickCountry,
              highlightRequired: highlightRequired,
            ),

            // 5) شريط إرسال (اختياري)
            if (onSubmit != null) ...[
              const SizedBox(height: 18),
              _SubmitBar(
                onSubmit: onSubmit!,
                isSubmitting: isSubmitting,
                label: "completeRegistration".translate(context),
                color: context.color.territoryColor,
              )
            ],

            const SizedBox(height: 8),
            _FootNote(text: "يمكنك تعديل هذه البيانات لاحقًا من الإعدادات."),
          ],
        ),
      ),
    );

    // إزالة أي padding تلقائي من الـ ScrollView/MediaQuery (إن رغبت)
    return removeViewportPadding
        ? MediaQuery.removePadding(
            context: context,
            removeLeft: true,
            removeRight: true,
            child: Padding(padding: pad, child: content),
          )
        : Padding(padding: pad, child: content);
  }
}

/* ==============================
   بطاقة الشعار (مع أنيميشن)
   ============================== */

class _LogoCard extends StatefulWidget {
  final File? image;
  final VoidCallback onPick;
  final bool isUploading;
  final double? progress; // 0..1
  final bool showPreviewHint;
  final bool highlightRequired;

  const _LogoCard({
    required this.image,
    required this.onPick,
    required this.isUploading,
    required this.progress,
    required this.showPreviewHint,
    required this.highlightRequired,
  });

  @override
  State<_LogoCard> createState() => _LogoCardState();
}

class _LogoCardState extends State<_LogoCard> {
  static const _r = 14.0;
  bool _localHint = false;
  Timer? _hintTimer;

  void _softToast(String msg, {int seconds = 3}) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        UiUtils.showSoftSnackBar(
          context,
          message: msg,
        );
      } catch (_) {
        // Fallback آمن
        final messenger = ScaffoldMessenger.maybeOf(context);
        if (messenger != null) {
          messenger.showSnackBar(
            SnackBar(content: Text(msg), duration: Duration(seconds: seconds)),
          );
        }
      }
    });
  }

  @override
  void didUpdateWidget(covariant _LogoCard old) {
    super.didUpdateWidget(old);

    // ↓↓↓ هذه الاستدعاءات تبقى كما هي — الآن تُجَدول بعد الإطار
    if (!old.isUploading && widget.isUploading) {
      _softToast("جاري رفع الشعار…", seconds: 2);
    }

    if (old.isUploading && !widget.isUploading) {
      if (widget.image != null) {
        _softToast("تم تحميل الصورة بنجاح", seconds: 3);

        if (!widget.showPreviewHint) {
          _hintTimer?.cancel();
          setState(() => _localHint = true);
          _hintTimer = Timer(const Duration(seconds: 3), () {
            if (mounted) setState(() => _localHint = false);
          });
        }
      } else if ((widget.progress ?? 0) < 1.0) {
        _softToast("تعذّر رفع الشعار. حاول مجددًا.", seconds: 3);
      }
    }
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context);

    String note() {
      if (widget.isUploading) {
        final pct = widget.progress != null
            ? " ${(widget.progress!.clamp(0, 1) * 100).toStringAsFixed(0)}%"
            : "";
        return "جاري رفع الشعار$pct…";
      }
      if (widget.image != null) return "تم اختيار شعار. اضغط لتغييره.";
      return "اضغط لاضافة شعار المكتب ";
    }

    final showHint = widget.showPreviewHint || _localHint;

    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _LabelWithAsterisk(
            text: "officeLogo".translate(context),
            icon: Icons.image_rounded,
            showAsterisk: widget.highlightRequired,
          ),
          const SizedBox(height: 12),

          // مربع بحواف منحنية: صورة أو Placeholder منقّط
          LayoutBuilder(
            builder: (context, constraints) {
              final maxW = constraints.hasBoundedWidth
                  ? constraints.maxWidth
                  : MediaQuery.of(context).size.width;
              final double size = (maxW * 0.28).clamp(180.0, 220.0);

              final outline = th.colorScheme.outline
                  .withOpacity(th.brightness == Brightness.dark ? .45 : .75);
              final dash = outline;
              final bg = th.colorScheme.surfaceContainerHighest
                  .withOpacity(th.brightness == Brightness.dark ? .18 : .45);

              return Center(
                child: SizedBox(
                  width: size,
                  child: Stack(
                    children: [
                      AspectRatio(
                        aspectRatio: 1,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(_r),
                          child: widget.image != null
                              ? Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(_r),
                                    border:
                                        Border.all(color: outline, width: 1.2),
                                  ),
                                  child: _AnimatedLogoBox(
                                    image: widget.image,
                                    // نمنع انيميشن التحميل الداخلي ونستبدله بمؤشر صغير بالزاوية
                                    onTap: () {
                                      if (widget.isUploading) {
                                        _softToast("الرفع قيد التنفيذ…",
                                            seconds: 2);
                                        return;
                                      }
                                      widget.onPick();
                                    },
                                    isUploading: false,
                                    progress: null,
                                    success: showHint,
                                  ),
                                )
                              : _DashedSquarePlaceholder(
                                  background: bg,
                                  dashColor: dash,
                                  onTap: () {
                                    if (widget.isUploading) {
                                      _softToast("الرفع قيد التنفيذ…",
                                          seconds: 2);
                                      return;
                                    }
                                    widget.onPick();
                                  },
                                ),
                        ),
                      ),

                      // إبراز مطلوب (إطار أحمر) عندما لا توجد صورة
                      if (widget.highlightRequired &&
                          widget.image == null &&
                          !widget.isUploading)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(_r),
                                border: Border.all(
                                  color: th.colorScheme.error.withOpacity(0.9),
                                  width: 1.6,
                                ),
                              ),
                            ),
                          ),
                        ),

                      // ✅ مؤشر تحميل صغير وأنيق في زاوية أعلى اليمين
                      if (widget.isUploading)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: _SmallCornerLoader(progress: widget.progress),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 25),
          // سطر ملاحظة واحد
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.info_outline_rounded,
                  size: 14, color: th.colorScheme.onSurface.withOpacity(0.72)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  note(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: th.textTheme.labelMedium?.copyWith(
                    color: th.colorScheme.onSurface.withOpacity(0.72),
                    fontWeight: FontWeight.w500,
                    letterSpacing: .2,
                  ),
                ),
              ),
            ],
          ),

          // تلميح النجاح الخارجي
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 250),
              opacity: showHint ? 1 : 0,
              child: showHint
                  ? Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: _HintBanner(
                        icon: Icons.visibility_rounded,
                        text: "هكذا سيظهر شعارك للمستخدمين",
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}

// مؤشر تحميل صغير/احترافي يوضع في زاوية الصورة
class _SmallCornerLoader extends StatelessWidget {
  final double? progress;
  const _SmallCornerLoader({this.progress});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.45),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2.4,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      ),
    );
  }
}

// Placeholder منقّط (مربّع بحواف منحنية) وأيقونة إضافة أكبر
class _DashedSquarePlaceholder extends StatelessWidget {
  final Color background;
  final Color dashColor;
  final VoidCallback onTap;

  const _DashedSquarePlaceholder({
    required this.background,
    required this.dashColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = Theme.of(context).colorScheme.onSurface.withOpacity(0.70);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: CustomPaint(
          painter: _DashedBorderPainterRect(
              color: dashColor,
              radius: 14,
              dashWidth: 7,
              dashGap: 5,
              strokeWidth: 1.4),
          child: Container(
            decoration: BoxDecoration(
                color: background, borderRadius: BorderRadius.circular(14)),
            child: const Center(
              child: Icon(Icons.add_photo_alternate_rounded,
                  size: 64), // أكبر قليلًا
            ),
          ),
        ),
      ),
    ).withIconColor(iconColor);
  }
}

class _DashedBorderPainterRect extends CustomPainter {
  final Color color;
  final double radius;
  final double dashWidth;
  final double dashGap;
  final double strokeWidth;

  _DashedBorderPainterRect({
    required this.color,
    required this.radius,
    this.dashWidth = 6,
    this.dashGap = 4,
    this.strokeWidth = 1.5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (color == Colors.transparent) return;

    final rrect =
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius));
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final ui.Path path = ui.Path()..addRRect(rrect);
    final ui.Path dashed = _dashPath(path, dashWidth, dashGap);
    canvas.drawPath(dashed, paint);
  }

  ui.Path _dashPath(ui.Path source, double dashWidth, double dashGap) {
    final ui.Path dest = ui.Path();
    for (final ui.PathMetric metric in source.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        final double len = math.min(dashWidth, metric.length - distance);
        dest.addPath(metric.extractPath(distance, distance + len), Offset.zero);
        distance += dashWidth + dashGap;
      }
    }
    return dest;
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainterRect old) {
    return old.color != color ||
        old.radius != radius ||
        old.dashWidth != dashWidth ||
        old.dashGap != dashGap ||
        old.strokeWidth != strokeWidth;
  }
}

// لتلوين الأيقونة داخل Placeholder
extension on Widget {
  Widget withIconColor(Color color) =>
      IconTheme(data: IconThemeData(color: color), child: this);
}

/* ==============================
   بطاقة اسم المكتب
   ============================== */

class _OfficeNameCard extends StatelessWidget {
  final TextEditingController controller;
  final bool highlightRequired;

  const _OfficeNameCard({
    required this.controller,
    required this.highlightRequired,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.color;
    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LabelWithAsterisk(
            text: "officeName".translate(context),
            icon: Icons.business_rounded,
            showAsterisk: highlightRequired,
          ),
          const SizedBox(height: 10),
          CustomTextFormField(
            controller: controller,
            isRequired: false,
            fillColor: c.backgroundColor,
            borderColor: c.borderColor.darken(10),
            hintText: "مثال : روابي المجد للعقارات ",
          ),
          const SizedBox(height: 6),
          _TinyNote(text: "يرجى إدخال اسم المكتب العقاري الصحيح"),
        ],
      ),
    );
  }
}

class _TinyNote extends StatelessWidget {
  final String text;
  const _TinyNote({required this.text});

  @override
  Widget build(BuildContext context) {
    final c = context.color;
    final f = context.font;
    return Text(
      text,
      style: TextStyle(
          fontSize: f.small, color: c.textColorDark.withOpacity(0.75)),
    );
  }
}

/* ==============================
   بطاقة الموقع الجغرافي
   ============================== */

class _LocationCard extends StatelessWidget {
  final TextEditingController controller;
  final bool isLoading;
  final VoidCallback onGetLocation;
  final bool highlightRequired;

  const _LocationCard({
    required this.controller,
    required this.isLoading,
    required this.onGetLocation,
    required this.highlightRequired,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.color;

    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LabelWithAsterisk(
            text: "officeLocationDetailed".translate(context),
            icon: Icons.location_on_rounded,
            showAsterisk: highlightRequired,
          ),
          const SizedBox(height: 10),
          CustomTextFormField(
            controller: controller,
            isRequired: false,
            fillColor: c.backgroundColor,
            borderColor: c.borderColor.darken(10),
            maxLine: 3,
            hintText: "اكتب عنوان مكتبك هنا ... ",
          ),
          const SizedBox(height: 12),

          // زر تحديد الموقع — عرض كامل
          _FullWidthActionButton(
            isLoading: isLoading,
            label: isLoading
                ? "gettingLocation".translate(context)
                : "selectLocationOnMap".translate(context),
            icon: Icons.my_location_rounded,
            onPressed: onGetLocation,
          ),

          const SizedBox(height: 10),
          _InfoLine(
            icon: Icons.map_rounded,
            text: "اضغط على الزر للتعبئة التلقائية أو أدخل العنوان يدويًا.",
          ),
        ],
      ),
    );
  }
}

/* ==============================
   بطاقة أرقام التواصل
   ============================== */

class _ContactCard extends StatefulWidget {
  final TextEditingController phone;
  final TextEditingController whatsapp;
  final String prefixText;
  final VoidCallback onPickCountry;
  final bool highlightRequired;

  const _ContactCard({
    required this.phone,
    required this.whatsapp,
    required this.prefixText,
    required this.onPickCountry,
    required this.highlightRequired,
  });

  @override
  State<_ContactCard> createState() => _ContactCardState();
}

class _ContactCardState extends State<_ContactCard> {
  late final FocusNode _focusPhone;
  late final FocusNode _focusWhats;
  Timer? _debouncePhone;
  Timer? _debounceWhats;

  String? _notePhone;
  String? _noteWhats;
  bool _sameAsPhone = false;

  DateTime? _lastToastAt;

  @override
  void initState() {
    super.initState();
    _focusPhone = FocusNode()..addListener(() => setState(() {}));
    _focusWhats = FocusNode()..addListener(() => setState(() {}));

    widget.phone.addListener(_onPhoneChanged);
    widget.whatsapp.addListener(_onWhatsChanged);

    _validatePhone(widget.phone.text, silent: true);
    _validateWhats(widget.whatsapp.text, silent: true);
  }

  @override
  void dispose() {
    _debouncePhone?.cancel();
    _debounceWhats?.cancel();
    _focusPhone.dispose();
    _focusWhats.dispose();
    widget.phone.removeListener(_onPhoneChanged);
    widget.whatsapp.removeListener(_onWhatsChanged);
    super.dispose();
  }

  void _softToast(String msg) {
    final now = DateTime.now();
    if (_lastToastAt != null &&
        now.difference(_lastToastAt!) < const Duration(milliseconds: 900)) {
      return;
    }
    _lastToastAt = now;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        UiUtils.showSoftSnackBar(context, message: msg);
      } catch (_) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
      }
    });
  }

  String _digitsOnly(String s) => s.replaceAll(RegExp(r'\D+'), '');

  void _onPhoneChanged() {
    _debouncePhone?.cancel();
    final before = widget.phone.text;

    _debouncePhone = Timer(const Duration(milliseconds: 220), () {
      if (!mounted) return;
      final sanitized = _digitsOnly(before);
      if (sanitized != before) {
        widget.phone.value = TextEditingValue(
          text: sanitized,
          selection: TextSelection.collapsed(offset: sanitized.length),
          composing: TextRange.empty,
        );
        _softToast("تم تنسيق الرقم تلقائيًا");
      }

      // لو مفعّل “مطابقة رقم الهاتف”
      if (_sameAsPhone) {
        widget.whatsapp.value = TextEditingValue(
          text: sanitized,
          selection: TextSelection.collapsed(offset: sanitized.length),
          composing: TextRange.empty,
        );
      }

      _validatePhone(sanitized);
      if (_sameAsPhone) _validateWhats(sanitized);
    });
  }

  void _onWhatsChanged() {
    _debounceWhats?.cancel();
    final before = widget.whatsapp.text;

    _debounceWhats = Timer(const Duration(milliseconds: 220), () {
      if (!mounted) return;
      final sanitized = _digitsOnly(before);
      if (sanitized != before) {
        widget.whatsapp.value = TextEditingValue(
          text: sanitized,
          selection: TextSelection.collapsed(offset: sanitized.length),
          composing: TextRange.empty,
        );
        _softToast("تم تنسيق الرقم تلقائيًا");
      }
      _validateWhats(sanitized);
    });
  }

  bool _isValidLen(String digits) => digits.length >= 6 && digits.length <= 15;

  void _validatePhone(String text, {bool silent = false}) {
    String? note;
    final t = text.trim();
    if (widget.highlightRequired && !_focusPhone.hasFocus && t.isEmpty) {
      note = "الرقم مطلوب.";
    } else if (t.isNotEmpty && !_isValidLen(t)) {
      note = "رقم غير مكتمل.";
    } else {
      note = null;
    }
    if (!silent || _notePhone != note) setState(() => _notePhone = note);
  }

  void _validateWhats(String text, {bool silent = false}) {
    String? note;
    final t = text.trim();
    if (widget.highlightRequired && !_focusWhats.hasFocus && t.isEmpty) {
      note = "رقم واتساب مطلوب.";
    } else if (t.isNotEmpty && !_isValidLen(t)) {
      note = "رقم غير مكتمل.";
    } else {
      note = null;
    }
    if (!silent || _noteWhats != note) setState(() => _noteWhats = note);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.color;
    final th = Theme.of(context);

    TextStyle noteStyle = th.textTheme.labelMedium!.copyWith(
      color: th.colorScheme.onSurface.withOpacity(0.72),
      fontWeight: FontWeight.w500,
      letterSpacing: .2,
    );

    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LabelWithAsterisk(
            text: "contactInfo".translate(context),
            icon: Icons.call_rounded,
            showAsterisk: widget.highlightRequired,
          ),

          const SizedBox(height: 12),

          // الهاتف
          _FieldLabel(text: "contactNumber".translate(context)),
          const SizedBox(height: 8),
          Directionality(
            textDirection: TextDirection.rtl,
            child: CustomTextFormField(
              controller: widget.phone,
              fillColor: c.backgroundColor,
              borderColor: c.borderColor.darken(30),
              keyboard: TextInputType.phone, // لاحظ: الخصائص حسب ودجتك
              fixedPrefix: _CountryPrefix(
                prefixText: widget.prefixText,
                onPickCountry: widget.onPickCountry,
              ),
              hintText: "phoneNumber".translate(context),
            ),
          ),
          if (_notePhone != null && _notePhone!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(_notePhone!,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: noteStyle),
          ],

          const SizedBox(height: 16),

          // واتساب
          _FieldLabel(text: "whatsappNumber".translate(context)),
          const SizedBox(height: 8),
          Directionality(
            textDirection: TextDirection.rtl,
            child: CustomTextFormField(
              controller: widget.whatsapp,
              fillColor: c.backgroundColor,
              borderColor: c.borderColor.darken(30),
              keyboard: TextInputType.phone,
              fixedPrefix: _CountryPrefix(
                prefixText: widget.prefixText,
                onPickCountry: widget.onPickCountry,
              ),
              hintText: "whatsappNumber".translate(context),
            ),
          ),
          if (_noteWhats != null && _noteWhats!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(_noteWhats!,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: noteStyle),
          ],

          const SizedBox(height: 12),
          Text(
            "يفضل رقم واتساب مختلف عن رقم الهاتف لسهولة التواصل .",
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: noteStyle,
          ),
        ],
      ),
    );
  }
}

/* ==============================
   شريط تقديم الطلب (زر رئيسي)
   ============================== */

class _SubmitBar extends StatelessWidget {
  final VoidCallback onSubmit;
  final bool isSubmitting;
  final String label;
  final Color color;

  const _SubmitBar({
    required this.onSubmit,
    required this.isSubmitting,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: isSubmitting ? null : onSubmit, // ← مباشرة
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: isSubmitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : Text(label,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

/* ==============================
   عناصر مساعدة داخلية (UI فقط)
   ============================== */

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
              style: TextStyle(
                  fontSize: f.normal,
                  color: c.textDefaultColor,
                  fontWeight: FontWeight.w600),
              children: [
                TextSpan(text: text),
                if (showAsterisk)
                  TextSpan(
                    text: "  *",
                    style: TextStyle(
                        color: Colors.redAccent, fontSize: f.normal + 1),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    final c = context.color;
    final f = context.font;
    return Text(
      text,
      style: TextStyle(
          fontSize: f.normal,
          color: c.textDefaultColor,
          fontWeight: FontWeight.w600),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final c = context.color;
    final f = context.font;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: c.textColorDark.withOpacity(0.8)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
                fontSize: f.small, color: c.textColorDark.withOpacity(0.8)),
          ),
        ),
      ],
    );
  }
}

class _CountryPrefix extends StatelessWidget {
  final String prefixText;
  final VoidCallback onPickCountry;
  const _CountryPrefix({required this.prefixText, required this.onPickCountry});

  @override
  Widget build(BuildContext context) {
    final c = context.color;
    final f = context.font;
    return InkWell(
      onTap: onPickCountry,
      child: Container(
        width: 86,
        height: 48,
        decoration: BoxDecoration(
          border: Border(right: BorderSide(color: c.borderColor, width: 1.5)),
        ),
        child: Center(
          child: Text(
            prefixText,
            style: TextStyle(fontSize: f.normal, color: c.textDefaultColor),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

/// صندوق الشعار مع أنيميشن تحميل/نجاح
class _AnimatedLogoBox extends StatelessWidget {
  final File? image;
  final VoidCallback onTap;
  final bool isUploading;
  final double? progress; // 0..1
  final bool success;

  const _AnimatedLogoBox({
    required this.image,
    required this.onTap,
    required this.isUploading,
    required this.progress,
    required this.success,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.color;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        height: 140,
        width: 140,
        decoration: BoxDecoration(
          color: c.backgroundColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: success ? Colors.green : c.borderColor.darken(10),
            width: success ? 2 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // الصورة أو أيقونة الإضافة
            if (image != null)
              Image.file(image!, fit: BoxFit.cover)
            else
              Icon(Icons.add_photo_alternate_rounded,
                  size: 56, color: c.territoryColor),

            // طبقة تحميل
            if (isUploading) ...[
              Container(color: Colors.black.withOpacity(0.3)),
              Center(
                child: SizedBox(
                  height: 36,
                  width: 36,
                  child: progress != null
                      ? CircularProgressIndicator(
                          value: progress!.clamp(0.0, 1.0),
                          strokeWidth: 3,
                          color: Colors.white)
                      : const CircularProgressIndicator(
                          strokeWidth: 3, color: Colors.white),
                ),
              ),
            ],

            // طبقة نجاح
            if (success && !isUploading)
              AnimatedOpacity(
                duration: const Duration(milliseconds: 280),
                opacity: 1,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withOpacity(0.0),
                        Colors.black.withOpacity(0.25)
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _SuccessCheckBadge(),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SuccessCheckBadge extends StatefulWidget {
  @override
  State<_SuccessCheckBadge> createState() => _SuccessCheckBadgeState();
}

class _SuccessCheckBadgeState extends State<_SuccessCheckBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 380));
    _scale = CurvedAnimation(parent: _ctl, curve: Curves.easeOutBack);
    _ctl.forward();
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.color;
    return ScaleTransition(
      scale: _scale,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.green,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: Colors.green.withOpacity(0.35), blurRadius: 10)
          ],
        ),
        child: Icon(Icons.check_rounded, size: 20, color: c.secondaryColor),
      ),
    );
  }
}

class _HintBanner extends StatelessWidget {
  final IconData icon;
  final String text;

  const _HintBanner({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final c = context.color;
    final f = context.font;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: c.territoryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: c.territoryColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: f.small,
                color: c.territoryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FullWidthActionButton extends StatelessWidget {
  final bool isLoading;
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const _FullWidthActionButton({
    required this.isLoading,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.color;
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: c.territoryColor,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        icon: isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : Icon(icon, size: 20, color: Colors.white),
        label: Text(
          label,
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _FootNote extends StatelessWidget {
  final String text;
  const _FootNote({required this.text});
  @override
  Widget build(BuildContext context) {
    final c = context.color;
    final f = context.font;
    return Row(
      children: [
        Icon(Icons.info_outline_rounded,
            size: 16, color: c.textColorDark.withOpacity(0.7)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
                fontSize: f.small, color: c.textColorDark.withOpacity(0.7)),
          ),
        ),
      ],
    );
  }
}
