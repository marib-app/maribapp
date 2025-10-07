// lib/ui/screens/auth/sign_up/widgets/business_section.dart
 //
// واجهة "التجاري" — مقسّمة إلى بطاقات/كلاسات صغيرة قابلة لإعادة الاستخدام.
// - BusinessSection: الغلاف الذي يرتّب البطاقات
// - _LogoCard: بطاقة الشعار مع أنيميشن تحميل/نجاح وتلميح بعد الرفع (اختياري)
// - _CommercialRegisterCard: بطاقة رفع/عرض السجل التجاري
// - _BusinessNameCard: بطاقة اسم النشاط التجاري
// - _LocationCard: بطاقة الموقع الجغرافي (زر كامل العرض + تلميح كامل)
// - _ContactCard: بطاقة أرقام التواصل (الهاتف + الواتساب كلٌ في سطر)
// - _CategoriesCard: بطاقة اختيار الأقسام (FilterChips)
// - _WorkingHoursCard: بطاقة أوقات العمل (من/إلى)
// - _PaymentMethodsCard: بطاقة وسائل تحصيل الدفع + حقول تفاصيل الحساب
// - _SubmitBar: شريط إرسال/تقديم (زر رئيسي بحالة تحميل) — اختياري
//
// ملاحظة: جميع هذه الكلاسات UI فقط. المنطق (مثل الرفع/الحفظ) يبقى في الشاشة الأم.
import 'package:flutter/cupertino.dart' show CupertinoScrollbar; // لعناصر Cupertino
import 'package:flutter/services.dart';                          // للـ HapticFeedback
import 'dart:ui' show ImageFilter;                               // لـ BackdropFilter.blur

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:marib/ui/screens/widgets/custom_text_form_field.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/data/model/category_model.dart';
import 'dart:ui' as ui;    // Path, PathMetric
import 'dart:math' as math; // min
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart'; // SchedulerBinding
import 'working_hours.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:marib/utils/helper_utils.dart';


class BusinessSection extends StatelessWidget {
  // === الشعار ===
  final File? logo;
  final VoidCallback onPickLogo;

  // === السجل التجاري ===
  final File? commercialFile;
  final VoidCallback onPickFile;

  // === الحقول النصية ===
  final TextEditingController name;
  final TextEditingController phone;
  final TextEditingController whatsapp;
  final TextEditingController location;

  // === البلد و بادئة الهاتف ===
  final String prefixText; // مثال: "🇾🇪 +967"
  final VoidCallback onPickCountry;

  // === الموقع ===
  final bool isLocationLoading;
  final VoidCallback onGetLocation;

  // === الأقسام ===
  final List<CategoryModel> categories;    // الأقسام المعروضة (أطفال القسم 6)
  final List<int> selectedCategoryIds;     // المعرفات المحددة
  final void Function(int id) onToggleCategory;

  // === أوقات العمل (قديم) ===
  final TimeOfDay? openingTime;
  final TimeOfDay? closingTime;
  final VoidCallback onPickOpening;
  final VoidCallback onPickClosing;

  // === أوقات العمل (جديد - ربط موحّد للباك إند) ===
  // شكل الخريطة المتوقّع: {"sat":{"enabled":true,"from":"08:00","to":"17:00"}, ...}
  final Map<String, dynamic>? workingHours;
  final ValueChanged<Map<String, dynamic>> onChangedWorkingHours;

  // === وسائل الدفع ===
  final Map<String, String> paymentMethods; // مفتاح => النص المترجم (i18n key داخل القيمة)
  final List<String> selectedPaymentMethods;
  final Map<String, TextEditingController> paymentControllers;
  final void Function(String key, bool isSelected) onTogglePayment;
  final String Function(String key) getAccountHint;

  // === أنيميشن الشعار (اختياري) ===
  final bool isLogoUploading;       // يُظهر لودر أثناء الرفع
  final double? logoUploadProgress; // 0..1
  final bool showLogoPreviewHint;   // يُظهر تلميح "هكذا سيظهر شعارك للمستخدمين"

  // === إبراز الحقول الإلزامية بصريًا ===
  final bool highlightRequired;

  // === شريط الإرسال (اختياري) ===
  final VoidCallback? onSubmit;
  final bool isSubmitting;




  final bool isUploading;






  const BusinessSection({
    super.key,
    // الشعار
    required this.logo,
    required this.onPickLogo,
    // السجل التجاري
    required this.commercialFile,
    required this.onPickFile,
    // الحقول
    required this.name,
    required this.phone,
    required this.whatsapp,
    required this.location,
    // بادئة الدولة
    required this.prefixText,
    required this.onPickCountry,
    // الموقع
    required this.isLocationLoading,
    required this.onGetLocation,
    // الأقسام
    required this.categories,
    required this.selectedCategoryIds,
    required this.onToggleCategory,
    // أوقات العمل (قديم)
    required this.openingTime,
    required this.closingTime,
    required this.onPickOpening,
    required this.onPickClosing,
    // أوقات العمل (جديد)
    required this.workingHours,
    required this.onChangedWorkingHours,
    // وسائل الدفع
    required this.paymentMethods,
    required this.selectedPaymentMethods,
    required this.paymentControllers,
    required this.onTogglePayment,
    required this.getAccountHint,
    // أنيميشن الشعار
    this.isLogoUploading = false,
    this.logoUploadProgress,
    this.showLogoPreviewHint = false,
    // إبراز الإلزامي
    this.highlightRequired = false,
    // إرسال
    this.onSubmit,
    this.isSubmitting = false,


    required this.isUploading,

  });

  // خريطة افتراضية في حال كانت workingHours = null
  Map<String, dynamic> get _fallbackWorkingHours => const {
    "sat": {"enabled": false, "from": null, "to": null},
    "sun": {"enabled": false, "from": null, "to": null},
    "mon": {"enabled": false, "from": null, "to": null},
    "tue": {"enabled": false, "from": null, "to": null},
    "wed": {"enabled": false, "from": null, "to": null},
    "thu": {"enabled": false, "from": null, "to": null},
    "fri": {"enabled": false, "from": null, "to": null},
  };



  @override
  Widget build(BuildContext context) {
    final c = context.color;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
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
              title: "businessLogo".translate(context),
              hint: "chooseLogoCarefully".translate(context),
            ),
            const SizedBox(height: 14),

            // 2) بطاقة السجل التجاري
            _CommercialRegisterCard(
              file: commercialFile,
              onPick: onPickFile,
              title: "commercialRegister".translate(context),
              hint: "uploadCommercialRegisterHint".translate(context),
              isLoading: isUploading,
            ),

            const SizedBox(height: 14),





            // 3) اسم النشاط التجاري
            _BusinessNameCard(
              controller: name,
              highlightRequired: highlightRequired,
            ),
            const SizedBox(height: 14),

            // 4) بطاقة الموقع الجغرافي
            _LocationCard(
              controller: location,
              isLoading: isLocationLoading,
              onGetLocation: onGetLocation,
              highlightRequired: highlightRequired,
              label: "businessLocationDetailed".translate(context),
            ),
            const SizedBox(height: 14),

            // 5) بطاقة أرقام التواصل
            _ContactCard(
              phone: phone,
              whatsapp: whatsapp,
              prefixText: prefixText,
              onPickCountry: onPickCountry,
              highlightRequired: highlightRequired,
            ),
            const SizedBox(height: 14),

            // 6) بطاقة الأقسام
            _CategoriesCard(
              categories: categories,
              selectedIds: selectedCategoryIds,
              onToggle: onToggleCategory,
            ),
            const SizedBox(height: 14),


            // 7) بطاقة أوقات العمل
            const WorkingHoursCard(),
            const SizedBox(height: 14),



            // 8) بطاقة وسائل الدفع + حقول الحسابات
            _PaymentMethodsCard(
              paymentMethods: paymentMethods,
              selectedMethods: selectedPaymentMethods,
              controllers: paymentControllers,
              onToggleMethod: onTogglePayment,
              getAccountHint: getAccountHint,
            ),

            // 9) شريط إرسال (اختياري)
            if (onSubmit != null) ...[
              const SizedBox(height: 18),
              _SubmitBar(
                onSubmit: onSubmit!,
                isSubmitting: isSubmitting,
                label: "completeRegistration".translate(context),
                color: c.territoryColor,

              ),
            ],
            // 👇 أضف السطرين التاليين قبل إغلاق الـ Column
            const SizedBox(height: 8),
            _FootNote(text: "يمكنك تعديل هذه البيانات لاحقًا من الإعدادات ."),
          ],
        ),
      ),
    );
  }
}




/* =========================================
   بطاقة الشعار (أنيميشن + تلميح بعد الرفع)
   ========================================= */


class _LogoCard extends StatefulWidget {
  final File? image;
  final VoidCallback onPick;
  final bool isUploading;
  final double? progress; // 0..1
  final bool showPreviewHint;
  final bool highlightRequired;
  final String title;
  final String? hint;

  const _LogoCard({
    required this.image,
    required this.onPick,
    required this.isUploading,
    required this.progress,
    required this.showPreviewHint,
    required this.highlightRequired,
    required this.title,
    this.hint,
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
        final messenger = ScaffoldMessenger.maybeOf(context);
        messenger?.showSnackBar(
          SnackBar(content: Text(msg), duration: Duration(seconds: seconds)),
        );
      }
    });
  }

  @override
  void didUpdateWidget(covariant _LogoCard old) {
    super.didUpdateWidget(old);

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

  String _note(BuildContext context) {
    if (widget.isUploading) {
      final pct = widget.progress != null
          ? " ${(widget.progress!.clamp(0, 1) * 100).toStringAsFixed(0)}%"
          : "";
      return "جاري رفع الشعار$pct…";
    }
    if (widget.image != null) return "تم اختيار شعار. اضغط لتغييره.";
    return "اضغط لإضافة شعار المتجر";
  }

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context);
    final showHint = widget.showPreviewHint || _localHint;

    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _LabelWithAsterisk(
            text: widget.title,
            icon: Icons.image_rounded,
            showAsterisk: widget.highlightRequired,
          ),
          const SizedBox(height: 12),

          LayoutBuilder(
            builder: (context, constraints) {
              final maxW = constraints.hasBoundedWidth
                  ? constraints.maxWidth
                  : MediaQuery.of(context).size.width;
              final double size = (maxW * 0.28).clamp(180.0, 220.0);

              final outline = th.colorScheme.outline
                  .withOpacity(th.brightness == Brightness.dark ? .45 : .75);
              final dash = outline;
              final bg = th.colorScheme.surfaceVariant
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
                              border: Border.all(color: outline, width: 1.2),
                            ),
                            child: _AnimatedLogoBox(
                              image: widget.image,
                              onTap: () {
                                if (widget.isUploading) {
                                  _softToast("الرفع قيد التنفيذ…", seconds: 2);
                                  return;
                                }
                                widget.onPick();
                              },
                              // نستعيض عن اللودر الداخلي بمؤشر الزاوية
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
                                _softToast("الرفع قيد التنفيذ…", seconds: 2);
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

                      // مؤشر تحميل صغير في زاوية أعلى اليمين
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

          // سطر ملاحظة واحد (مطابق لبطاقة الشعار السابقة)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.info_outline_rounded,
                  size: 14,
                  color: th.colorScheme.onSurface.withOpacity(0.72)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  _note(context),
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

          // تلميح النجاح أسفل الكرت
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
                  text: "هكذا سيظهر شعارك للمستخدمين ",
                ),
              )
                  : const SizedBox.shrink(),
            ),
          ),

          // ملاحظة ثابتة إضافية إن أحببت (اختيارية)
          if (widget.hint != null && widget.hint!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            _TinyNote(text: widget.hint!),
          ],
        ],
      ),
    );
  }
}


// ===================== Dashed Placeholder (مربع منقّط + أيقونة إضافة) =====================
class _DashedSquarePlaceholder extends StatelessWidget {
  final Color background;
  final Color dashColor;
  final VoidCallback onTap;
  final double radius;
  final double dashWidth;
  final double dashGap;
  final double strokeWidth;

  const _DashedSquarePlaceholder({
    required this.background,
    required this.dashColor,
    required this.onTap,
    this.radius = 14,
    this.dashWidth = 8,
    this.dashGap = 6,
    this.strokeWidth = 1.2,
  });

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: CustomPaint(
          painter: _DashedBorderPainterRect(
            color: dashColor,
            radius: radius,
            dashWidth: dashWidth,
            dashGap: dashGap,
            strokeWidth: strokeWidth,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(radius),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.add_photo_alternate_rounded,
              size: 34,
              color: th.colorScheme.onSurfaceVariant.withOpacity(
                th.brightness == Brightness.dark ? .85 : .75,
              ),
            ),
          ),
        ),
      ),
    );
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
    required this.dashWidth,
    required this.dashGap,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius));
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = color;

    final ui.Path source = ui.Path()..addRRect(rrect);
    final ui.Path dashed = _dashPath(source, dashWidth, dashGap);
    canvas.drawPath(dashed, paint);
  }

  ui.Path _dashPath(ui.Path source, double dashWidth, double dashGap) {
    final ui.Path dest = ui.Path();
    for (final ui.PathMetric metric in source.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        final len = math.min(dashWidth, metric.length - distance);
        dest.addPath(metric.extractPath(distance, distance + len), Offset.zero);
        distance += dashWidth + dashGap;
      }
    }
    return dest;
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainterRect oldDelegate) {
    return color != oldDelegate.color ||
        radius != oldDelegate.radius ||
        dashWidth != oldDelegate.dashWidth ||
        dashGap != oldDelegate.dashGap ||
        strokeWidth != oldDelegate.strokeWidth;
  }
}

// ===================== Loader صغير في زاوية أعلى اليمين =====================
class _SmallCornerLoader extends StatelessWidget {
  final double? progress; // null = غير محدد

  const _SmallCornerLoader({this.progress});

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context);
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: th.colorScheme.surface.withOpacity(th.brightness == Brightness.dark ? 0.75 : 0.9),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: th.colorScheme.outline.withOpacity(.35), width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(4),
      child: Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2.2,
            value: progress != null ? progress!.clamp(0.0, 1.0) : null,
          ),
        ),
      ),
    );
  }
}







/* =========================================
   بطاقة السجل التجاري (رفع/عرض)
   ========================================= */

class _CommercialRegisterCard extends StatelessWidget {
  final File? file;
  final VoidCallback onPick;
  final String title;
  final String? hint;
  final bool isLoading; // ✅ جديد

  const _CommercialRegisterCard({
    required this.file,
    required this.onPick,
    required this.title,
    this.hint,
    this.isLoading = false, // ✅ افتراضي
  });

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final borderGray = c.outlineVariant.withOpacity(0.6); // يناسب الفاتح/الداكن

    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LabelWithAsterisk(
            text: "$title (${ 'optional'.translate(context) })",
            icon: Icons.picture_as_pdf_rounded,
            showAsterisk: false,
          ),
          const SizedBox(height: 10),

          // منطقة الرفع
          InkWell(
            onTap: isLoading ? null : onPick,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 90,
              decoration: BoxDecoration(
                color: c.surface, // خلفية تتبع الثيم
                borderRadius: BorderRadius.circular(12),
              ),
              child: CustomPaint(
                painter: _DottedBorderPainter(
                  color: borderGray,
                  strokeWidth: 1.4,
                  radius: 12,
                  dash: 6,
                  gap: 4,
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  child: isLoading
                      ? _LoadingState(textTheme: textTheme, c: c)
                      : (file != null
                      ? _FileState(file: file!, textTheme: textTheme, c: c)
                      : _EmptyState(textTheme: textTheme, c: c)),
                ),
              ),
            ),
          ),

          if (hint != null) ...[
            const SizedBox(height: 8),
            _TinyNote(text: hint!),
          ],
        ],
      ),
    );
  }
}

// ---------- حالات العرض ----------

class _EmptyState extends StatelessWidget {
  final TextTheme textTheme;
  final ColorScheme c;
  const _EmptyState({required this.textTheme, required this.c});

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const ValueKey('empty'),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // أيقونة داخل دائرة منقّطة رمادية خفيفة
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: c.surfaceVariant.withOpacity(0.25),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.upload_file_rounded, size: 22, color: c.primary),
          ),
          const SizedBox(width: 10),
          Text(
            "uploadCommercialRegister".translate(context),
            style: textTheme.bodyMedium?.copyWith(
              color: c.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _FileState extends StatelessWidget {
  final File file;
  final TextTheme textTheme;
  final ColorScheme c;
  const _FileState({required this.file, required this.textTheme, required this.c});

  @override
  Widget build(BuildContext context) {
    final name = file.path.split('/').last;
    return Padding(
      key: const ValueKey('file'),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Icon(Icons.insert_drive_file_rounded, size: 32, color: c.secondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodyMedium?.copyWith(color: c.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  final TextTheme textTheme;
  final ColorScheme c;
  const _LoadingState({required this.textTheme, required this.c});

  @override
  Widget build(BuildContext context) {
    // لو مشروعك فيه حزمة shimmer، يمديك تبدّل المحتوى هنا بـ Shimmer
    return Center(
      key: const ValueKey('loading'),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator.adaptive(strokeWidth: 2),
          ),
          const SizedBox(width: 10),
          Text(
            "جاري الرفع...",
            style: textTheme.bodyMedium?.copyWith(color: c.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

// ---------- رسّام الإطار المنقّط ----------

class _DottedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double radius;
  final double dash;
  final double gap;

  _DottedBorderPainter({
    required this.color,
    this.strokeWidth = 1,
    this.radius = 12,
    this.dash = 6,
    this.gap = 4,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      double dist = 0;
      while (dist < metric.length) {
        final next = dist + dash;
        final extract = metric.extractPath(dist, next.clamp(0, metric.length));
        canvas.drawPath(extract, paint);
        dist = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DottedBorderPainter old) {
    return color != old.color ||
        strokeWidth != old.strokeWidth ||
        radius != old.radius ||
        dash != old.dash ||
        gap != old.gap;
  }
}




/* =========================================
   بطاقة اسم النشاط التجاري
   ========================================= */

class _BusinessNameCard extends StatelessWidget {
  final TextEditingController controller;
  final bool highlightRequired;

  const _BusinessNameCard({
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
            text: "businessName".translate(context),
            icon: Icons.storefront_rounded,
            showAsterisk: highlightRequired,
          ),
          const SizedBox(height: 10),
          CustomTextFormField(
            controller: controller,
            isRequired: false,
            fillColor: c.backgroundColor,
            borderColor: c.borderColor.darken(10),
            hintText: "مثال: مؤسسة البيان للتجارة",
          ),
          const SizedBox(height: 6),
          _TinyNote(text: "اختر اسمًا واضحًا لسهولة العثور عليك."),
        ],
      ),
    );
  }
}

/* =========================================
   بطاقة الموقع الجغرافي
   ========================================= */

class _LocationCard extends StatelessWidget {
  final TextEditingController controller;   // سيتم تعبئته تلقائيًا بعد اختيار الخريطة
  final bool isLoading;                     // لودر زر تحديد الموقع
  final VoidCallback onGetLocation;         // فتح الخريطة
  final bool highlightRequired;
  final String label;

  const _LocationCard({
    required this.controller,
    required this.isLoading,
    required this.onGetLocation,
    required this.highlightRequired,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context);
    final c  = context.color;

    final bool showErrorOutline =
        highlightRequired && controller.text.trim().isEmpty;

    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LabelWithAsterisk(
            text: label, // مثال: "موقع المتجر (إلزامي)"
            icon: Icons.location_on_rounded,
            showAsterisk: highlightRequired,
          ),
          const SizedBox(height: 10),

          // حقل «عرض فقط» — يمنع الكتابة ويُفتح الخريطة عند الضغط
          Stack(
            children: [
              // نجعل الحقل للعرض فقط مع تلوين الإطار حسب الحالة
              AbsorbPointer(
                absorbing: true, // يمنع التفاعل/الكيبورد
                child: Directionality(
                  textDirection: TextDirection.rtl, // عربي افتراضي
                  child: CustomTextFormField(
                    controller: controller,
                    isRequired: false,
                    maxLine: 2,
                    fillColor: c.backgroundColor,
                    borderColor: showErrorOutline
                        ? th.colorScheme.error
                        : c.borderColor.darken(10),
                    hintText: "اضغط هنا لتحديد موقع متجرك",
                  ),
                ),
              ),

              // طبقة شفافة تلتقط النقر وتفتح الخريطة
              Positioned.fill(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: onGetLocation,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // زر تحديد الموقع على الخريطة (عرض كامل)
          _FullWidthActionButton(
            isLoading: isLoading,
            label: isLoading
                ? "gettingLocation".translate(context)
                : "selectLocationOnMap".translate(context), // "حدد الموقع على الخريطة"
            icon: Icons.my_location_rounded,
            onPressed: onGetLocation,
          ),

          const SizedBox(height: 10),

          // ملاحظة مختصرة + تنويه دقة المعلومات
          _InfoLine(
            icon: Icons.info_outline_rounded,
            text: "يتم احتساب تكلفة التوصيل حسب المسافة، لذا دقّة تحديد موقع المتجر مهمة.",
          ),

          const SizedBox(height: 6),

        ],
      ),
    );
  }
}


/* =========================================
   بطاقة أرقام التواصل
   ========================================= */

class _ContactCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final c = context.color;

    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LabelWithAsterisk(
            text: "contactInfo".translate(context),
            icon: Icons.call_rounded,
            showAsterisk: highlightRequired,
          ),
          const SizedBox(height: 10),

          // الهاتف — سطر كامل
          _FieldLabel(text: "contactNumber".translate(context)),
          const SizedBox(height: 8),
          CustomTextFormField(
            controller: phone,
            fillColor: c.secondaryColor,
            borderColor: c.borderColor.darken(30),
            keyboard: TextInputType.phone, // ملاحظة: استخدم 'keyboard' وليس 'keyboardType'
            fixedPrefix: _CountryPrefix(prefixText: prefixText, onPickCountry: onPickCountry),
            hintText: "phoneNumber".translate(context),
          ),

          const SizedBox(height: 16),

          // الواتساب — سطر كامل
          _FieldLabel(text: "whatsappNumber".translate(context)),
          const SizedBox(height: 8),
          CustomTextFormField(
            controller: whatsapp,
            fillColor: c.secondaryColor,
            borderColor: c.borderColor.darken(30),
            keyboard: TextInputType.phone,
            fixedPrefix: _CountryPrefix(prefixText: prefixText, onPickCountry: onPickCountry),
            hintText: "whatsappNumber".translate(context),
          ),

          const SizedBox(height: 10),
          _TinyNote(text: "يمكنك وضع رقم واتساب مختلف عن رقم الهاتف."),
        ],
      ),
    );
  }
}


/* =========================================
   بطاقة اختيار الأقسام (FilterChips)
   ========================================= */

class _CategoriesCard extends StatelessWidget {
  final List<CategoryModel> categories;
  final List<int> selectedIds;
  final void Function(int id) onToggle;

  const _CategoriesCard({
    required this.categories,
    required this.selectedIds,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.color;

    final valid = categories
        .where((e) => e.id != null && (e.name?.trim().isNotEmpty ?? false))
        .toList();

    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LabelWithAsterisk(
            text: "selectBusinessCategories".translate(context),
            icon: Icons.category_rounded,
            showAsterisk: true,
          ),
          const SizedBox(height: 10),

          // الملاحظة الموجّهة للتجّار
          _NoticeBanner(
            icon: Icons.info_rounded,
            text:
            "ملاحظة: اختر الأقسام التي تخص نشاطك التجاري لإتاحة واجهات النشر المخصصة لتلك الأقسام.",
          ),
          const SizedBox(height: 12),

          if (valid.isEmpty)
            Text("noCategoriesAvailable".translate(context))
                .size(context.font.normal)
                .color(c.textDefaultColor.withOpacity(0.7))
          else
            Column(
              children: [
                // زر فتح القائمة
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _openCategoriesMenu(
                      context: context,
                      categories: valid,
                      selectedIds: selectedIds.toSet(),
                      onToggle: onToggle,
                    ),
                    icon: const Icon(Icons.tune_rounded),
                    label: Text(
                      "اختيار الأقسام • ${selectedIds.length}",
                      style: TextStyle(fontSize: context.font.normal),
                    ),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      backgroundColor: c.territoryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // ملخص سريع للمختارات الحالية (قابلة للإزالة بالضغط)
                if (selectedIds.isNotEmpty)
                  _SelectedSummaryLine(
                    categories: valid,
                    selectedIds: selectedIds,
                    onToggle: onToggle,
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/* --------------------------- Notice Banner --------------------------- */

class _NoticeBanner extends StatelessWidget {
  final IconData icon;
  final String text;
  const _NoticeBanner({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final c = context.color;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: c.territoryColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.territoryColor.withOpacity(0.35), width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: c.territoryColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: context.font.small,
                color: c.textDefaultColor,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/*=========================== Open Sheet Function ===========================*/

Future<void> _openCategoriesMenu({
  required BuildContext context,
  required List<CategoryModel> categories,
  required Set<int> selectedIds,
  required void Function(int id) onToggle,
}) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withOpacity(0.35),
    enableDrag: true,
    builder: (_) => _CategoriesPaletteSheet(
      categories: categories,
      initialSelected: selectedIds,
      onToggle: onToggle,
    ),
  );
}

/*======================== Palette Sheet (Full Code) ========================*/

class _CategoriesPaletteSheet extends StatefulWidget {
  final List<CategoryModel> categories;
  final Set<int> initialSelected;
  final void Function(int id) onToggle;

  const _CategoriesPaletteSheet({
    required this.categories,
    required this.initialSelected,
    required this.onToggle,
  });

  @override
  State<_CategoriesPaletteSheet> createState() => _CategoriesPaletteSheetState();
}

class _CategoriesPaletteSheetState extends State<_CategoriesPaletteSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac =
  AnimationController(vsync: this, duration: const Duration(milliseconds: 220))
    ..forward();
  late final Animation<Offset> _slide =
  Tween(begin: const Offset(0, 0.06), end: Offset.zero)
      .animate(CurvedAnimation(parent: _ac, curve: Curves.easeOutCubic));
  late final Animation<double> _fade =
  CurvedAnimation(parent: _ac, curve: Curves.easeOut);

  final ValueNotifier<bool> _scrolled = ValueNotifier(false);
  late Set<int> _localSelected = {...widget.initialSelected};

  @override
  void dispose() {
    _ac.dispose();
    _scrolled.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.color;

    final list = widget.categories
        .where((e) => e.id != null && (e.name?.trim().isNotEmpty ?? false))
        .toList()
      ..sort((a, b) => (a.name ?? '').compareTo(b.name ?? ''));

    final faintDivider = c.borderColor.withOpacity(0.55);

    return SlideTransition(
      position: _slide,
      child: FadeTransition(
        opacity: _fade,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            child: Material(
              color: c.backgroundColor,
              child: SafeArea(
                top: false,
                child: DraggableScrollableSheet(
                  expand: false,
                  // يفتح شبه ممتلئ للأعلى افتراضيًا
                  initialChildSize: 0.95,
                  minChildSize: 0.5,
                  maxChildSize: 0.95,
                  builder: (_, scrollController) {
                    return Stack(
                      children: [
                        // المحتوى الأساسي
                        Column(
                          children: [
                            const SizedBox(height: 8),
                            Container(
                              width: 40, height: 4,
                              decoration: BoxDecoration(
                                color: c.borderColor,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(height: 8),

                            // الهيدر: عنوان فقط في المنتصف
                            ValueListenableBuilder<bool>(
                              valueListenable: _scrolled,
                              builder: (_, sc, __) => AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                                decoration: BoxDecoration(
                                  color: c.backgroundColor,
                                  boxShadow: sc
                                      ? [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.06),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ]
                                      : const [],
                                ),
                                child: Center(
                                  child: Text(
                                    "حدد نوع نشاطك التجاري",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: context.font.large,
                                      fontWeight: FontWeight.w800,
                                      color: c.textDefaultColor,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // خط فاصل باهت تحت العنوان
                            Divider(height: 1, thickness: 1, color: faintDivider),

                            // الملاحظة بعرض كامل
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: c.territoryColor.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: c.territoryColor.withOpacity(0.35), width: 1),
                                ),
                                child: Text(
                                  "قد لا ترى بعض الأقسام بشكل صريح لأنها أقسام جامعة. "
                                      "مثلاً: \"الإكسسوارات\" قد تشمل أكثر من 10 أنشطة تجارية فرعية، "
                                      "وهكذا بقية الأقسام.",
                                  textAlign: TextAlign.start,
                                  style: TextStyle(
                                    fontSize: context.font.small,
                                    color: c.textDefaultColor.withOpacity(0.9),
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ),

                            // القائمة مع فواصل باهتة
                            Expanded(
                              child: ScrollConfiguration(
                                behavior: const _NoGlowScrollBehavior(),
                                child: NotificationListener<ScrollNotification>(
                                  onNotification: (n) {
                                    if (n.metrics.pixels <= 2 && _scrolled.value) {
                                      _scrolled.value = false;
                                    } else if (n.metrics.pixels > 2 && !_scrolled.value) {
                                      _scrolled.value = true;
                                    }
                                    return false;
                                  },
                                  child: Scrollbar(
                                    controller: scrollController,
                                    interactive: true,
                                    child: ListView.separated(
                                      controller: scrollController,
                                      physics: const BouncingScrollPhysics(
                                        parent: AlwaysScrollableScrollPhysics(),
                                      ),
                                      itemCount: list.length,
                                      separatorBuilder: (_, __) =>
                                          Divider(height: 1, color: faintDivider),
                                      itemBuilder: (ctx, i) {
                                        final cat = list[i];
                                        final id  = cat.id!;
                                        final sel = _localSelected.contains(id);
                                        return _PaletteRow(
                                          label: cat.name!.trim(),
                                          selected: sel,
                                          onTap: () {
                                            HapticFeedback.selectionClick();
                                            setState(() {
                                              sel ? _localSelected.remove(id) : _localSelected.add(id);
                                            });
                                            widget.onToggle(id);
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // الشريط السفلي: زر "تم" فقط مع Blur
                            ClipRect(
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: c.backgroundColor.withOpacity(0.85),
                                    border: Border(top: BorderSide(color: c.borderColor)),
                                  ),
                                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: () => Navigator.pop(context),
                                      icon: const Icon(Icons.check_rounded),
                                      label: Text("تم • ${_localSelected.length}"),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: c.territoryColor,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 14),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        // زر الإغلاق معلّق في زاوية النافذة (منفصل عن العنوان)
                        PositionedDirectional(
                          top: 6,
                          end: 8, // لو تريدها دائمًا أعلى اليمين: Positioned(top: 6, right: 8, child: ...)
                          child: IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded),
                            color: c.textDefaultColor.withOpacity(0.85),
                            splashRadius: 22,
                            padding: const EdgeInsets.all(8),
                            constraints: const BoxConstraints(),
                            tooltip: "إغلاق",
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

/*========================= Row & ScrollBehavior =========================*/

class _PaletteRow extends StatefulWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _PaletteRow({required this.label, required this.selected, required this.onTap});

  @override
  State<_PaletteRow> createState() => _PaletteRowState();
}

class _PaletteRowState extends State<_PaletteRow> {
  bool _pressed = false;

  static const double _iconSlot = 26;

  @override
  Widget build(BuildContext context) {
    final c = context.color;

    return InkWell(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      splashColor: c.territoryColor.withOpacity(0.08),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        color: widget.selected
            ? c.territoryColor.withOpacity(0.06)
            : (_pressed ? c.backgroundColor.withOpacity(0.60) : c.backgroundColor),
        child: Row(
          children: [
            SizedBox(
              width: _iconSlot,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                switchInCurve: Curves.easeOutBack,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, a) => FadeTransition(
                  opacity: a,
                  child: ScaleTransition(
                    scale: Tween(begin: 0.6, end: 1.0).animate(
                      CurvedAnimation(parent: a, curve: Curves.easeOutBack),
                    ),
                    child: child,
                  ),
                ),
                child: widget.selected
                    ? Container(
                  key: const ValueKey('on'),
                  width: 20, height: 20,
                  decoration: BoxDecoration(
                    color: c.territoryColor.withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: c.territoryColor, width: 1.5),
                  ),
                  child: Icon(Icons.check_rounded, size: 14, color: c.territoryColor),
                )
                    : const SizedBox(key: ValueKey('off'), width: 20, height: 20),
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
                  color: widget.selected ? c.territoryColor : c.textDefaultColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoGlowScrollBehavior extends ScrollBehavior {
  const _NoGlowScrollBehavior();

  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) {
    return child; // بدون توهج
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
  }
}

/* -------------------------- Menu Row Widget -------------------------- */

class _SelectableRow extends StatefulWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SelectableRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_SelectableRow> createState() => _SelectableRowState();
}

class _SelectableRowState extends State<_SelectableRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = context.color;

    return InkWell(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      splashColor: c.territoryColor.withOpacity(0.08),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        color: widget.selected
            ? c.territoryColor.withOpacity(0.06)
            : (_pressed ? c.backgroundColor.withOpacity(0.6) : c.backgroundColor),
        child: Row(
          children: [
            // علامة الصح المتحركة (AnimatedSwitcher)
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              switchInCurve: Curves.easeOutBack,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, a) => FadeTransition(
                opacity: a,
                child: ScaleTransition(
                  scale: Tween(begin: 0.6, end: 1.0)
                      .animate(CurvedAnimation(parent: a, curve: Curves.easeOutBack)),
                  child: child,
                ),
              ),
              child: widget.selected
                  ? Container(
                key: const ValueKey('on'),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: c.territoryColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: c.territoryColor, width: 1.5),
                ),
                child: Icon(Icons.check_rounded, size: 16, color: c.territoryColor),
              )
                  : const SizedBox(key: ValueKey('off'), width: 22, height: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: context.font.normal,
                  fontWeight: FontWeight.w600,
                  color: widget.selected ? c.territoryColor : c.textDefaultColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ------------------------ Selected Summary Line ---------------------- */

class _SelectedSummaryLine extends StatelessWidget {
  final List<CategoryModel> categories;
  final List<int> selectedIds;
  final void Function(int id) onToggle;

  const _SelectedSummaryLine({
    required this.categories,
    required this.selectedIds,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.color;
    final selected = categories.where((e) => selectedIds.contains(e.id)).toList();

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsetsDirectional.only(start: 6, end: 6),
        itemCount: selected.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final name = selected[i].name!;
          final id = selected[i].id!;
          return InkWell(
            onTap: () => onToggle(id),
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: c.territoryColor.withOpacity(0.10),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: c.territoryColor, width: 1),
              ),
              alignment: Alignment.center,
              child: Row(
                children: [
                  Icon(Icons.check_rounded, size: 16, color: c.territoryColor),
                  const SizedBox(width: 6),
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: context.font.small,
                      color: c.territoryColor,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}



/* =========================================
   بطاقة أوقات العمل
   ========================================= */










/* =========================================
   بطاقة وسائل الدفع + حقول الحسابات
   ========================================= */

class _PaymentMethodsCard extends StatelessWidget {
  final Map<String, String> paymentMethods;                  // key -> i18n key
  final List<String> selectedMethods;
  final Map<String, TextEditingController> controllers;
  final void Function(String key, bool isSelected) onToggleMethod;
  final String Function(String key) getAccountHint;

  const _PaymentMethodsCard({
    required this.paymentMethods,
    required this.selectedMethods,
    required this.controllers,
    required this.onToggleMethod,
    required this.getAccountHint,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.color;

    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LabelWithAsterisk(
            text: "paymentReceivingMethods".translate(context),
            icon: Icons.account_balance_wallet_rounded,
            showAsterisk: false,
          ),
          const SizedBox(height: 10),

          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.borderColor.darken(20)),
            ),
            child: Column(
              children: paymentMethods.entries.map((entry) {
                final key = entry.key;
                final title = entry.value.translate(context);
                final isSelected = selectedMethods.contains(key);
                final controller = controllers[key];

                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    children: [
                      CheckboxListTile(
                        value: isSelected,
                        title: Text(
                          title,
                          style: TextStyle(
                            fontSize: context.font.normal,
                            fontWeight: FontWeight.w500,
                            color: c.textDefaultColor,
                          ),
                        ),
                        activeColor: const Color(0xFFF35A00),
                        onChanged: (checked) => onToggleMethod(key, checked ?? false),
                        controlAffinity: ListTileControlAffinity.leading,
                      ),

                      if (isSelected)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          child: CustomTextFormField(
                            controller: controller,
                            fillColor: c.backgroundColor,
                            borderColor: c.borderColor.darken(30),
                            hintText: getAccountHint(key),
                            // ملاحظة: إن كان الحقل مطلوب لاحقًا، أضف validator هنا
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

/* =========================================
   شريط تقديم الطلب (زر رئيسي)
   ========================================= */


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
        onPressed: isSubmitting ? null : onSubmit,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: isSubmitting
            ? const SizedBox(
          width: 20, height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        )
            : Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    );
  }
}





/* =========================================
   عناصر مساعدة داخلية (UI فقط)
   ========================================= */

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

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    final c = context.color;
    final f = context.font;
    return Text(
      text,
      style: TextStyle(fontSize: f.normal, color: c.textDefaultColor, fontWeight: FontWeight.w600),
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
      style: TextStyle(fontSize: f.small, color: c.textColorDark.withOpacity(0.75)),
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
            style: TextStyle(fontSize: f.small, color: c.textColorDark.withOpacity(0.8)),
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

/// صندوق الشعار مع أنيميشن تحميل/نجاح (نفس فكرة العقاري للتناسق)
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
            if (image != null)
              Image.file(image!, fit: BoxFit.cover)
            else
              Icon(Icons.add_photo_alternate_rounded, size: 56, color: c.territoryColor),

            if (isUploading) ...[
              Container(color: Colors.black.withOpacity(0.3)),
              Center(
                child: SizedBox(
                  height: 36,
                  width: 36,
                  child: progress != null
                      ? CircularProgressIndicator(value: progress!.clamp(0.0, 1.0), strokeWidth: 3, color: Colors.white)
                      : const CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                ),
              ),
            ],

            if (success && !isUploading)
              AnimatedOpacity(
                duration: const Duration(milliseconds: 280),
                opacity: 1,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.black.withOpacity(0.0), Colors.black.withOpacity(0.25)],
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

class _SuccessCheckBadgeState extends State<_SuccessCheckBadge> with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
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
          boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.35), blurRadius: 10)],
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        icon: isLoading
            ? const SizedBox(
          width: 18, height: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        )
            : Icon(icon, size: 20, color: Colors.white),
        label: Text(
          label,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
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
        Icon(Icons.info_outline_rounded, size: 16, color: c.textColorDark.withOpacity(0.7)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: f.small, color: c.textColorDark.withOpacity(0.7)),
          ),
        ),
      ],
    );
  }
}
