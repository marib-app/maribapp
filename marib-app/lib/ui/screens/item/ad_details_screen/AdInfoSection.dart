import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/app_icon.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'dart:ui';
import 'package:flutter/widgets.dart';
import 'dart:ui' as ui;
import 'package:marib/ui/screens/widgets/shimmerLoadingContainer.dart';

class AdInfoSectionShimmer extends StatelessWidget {
  final bool isOwner;

  const AdInfoSectionShimmer({super.key, this.isOwner = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: CustomShimmer(
                height: 26,
                borderRadius: 12,
              ),
            ),
            if (isOwner) ...[
              const SizedBox(width: 12),
              const CustomShimmer(
                height: 26,
                width: 110,
                borderRadius: 20,
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            CustomShimmer(height: 20, width: 20, borderRadius: 6),
            SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomShimmer(height: 14, borderRadius: 8),
                  SizedBox(height: 6),
                  CustomShimmer(height: 14, width: 160, borderRadius: 8),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Row(
          children: [
            CustomShimmer(height: 12, width: 100, borderRadius: 6),
            SizedBox(width: 12),
            CustomShimmer(height: 12, width: 70, borderRadius: 6),
          ],
        ),
      ],
    );
  }
}

class AdInfoSection {
  final BuildContext context;
  final dynamic model;
  final bool isAddedByMe;

  AdInfoSection({
    required this.context,
    required this.model,
    required this.isAddedByMe,
  });

  Widget _buildStatusChip(
    BuildContext context,
    String? rawStatus, {
    bool fullWidth = false, // اجعلها true لو تبغاه يتمدد
    bool showTooltip = true, // Tooltip بالوصف
    bool dense = false, // حجم أصغر
  }) {
    final cs = Theme.of(context).colorScheme;
    final norm = _normalizeStatus(rawStatus);
    final st = _statusStyles(context, cs)[norm] ??
        _statusStyles(context, cs)['review']!;
    final t = Theme.of(context).textTheme;
    final textScale = MediaQuery.of(context).textScaleFactor.clamp(1.0, 1.3);

    Widget buildChip({required bool compact, required bool iconOnly}) {
      final label =
          iconOnly ? '' : (compact ? _shortLabel(norm, st.label) : st.label);
      final padH = iconOnly ? 10.0 : (dense ? 10.0 : 12.0);
      final padV = dense ? 6.0 : 8.0;

      final content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(st.icon, size: compact ? 16 : 18, color: st.fg),
          if (!iconOnly) ...[
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: (t.bodyMedium ?? const TextStyle()).copyWith(
                  color: st.fg,
                  fontWeight: FontWeight.w600,
                  fontSize: (dense ? 12.0 : 13.0) * (compact ? 0.95 : 1.0),
                ),
              ),
            ),
          ],
        ],
      );

      final box = AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
        constraints: const BoxConstraints(minHeight: 32),
        decoration: BoxDecoration(
          color: st.bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: st.border, width: 1),
        ),
        child: content,
      );

      return Semantics(
        label: 'حالة الإعلان: ${st.label}',
        child: showTooltip ? Tooltip(message: st.description, child: box) : box,
      );
    }

    // التكيّف مع العرض المتاح
    Widget responsive(BuildContext ctx) {
      return LayoutBuilder(builder: (ctx, c) {
        final w =
            c.maxWidth.isFinite ? c.maxWidth : MediaQuery.of(ctx).size.width;

        // قواعد بسيطة:
        // < 120px  -> أيقونة فقط
        // < 200px  -> نص قصير
        // >= 200px -> نص كامل
        final iconOnly = w < 120;
        final compact = !iconOnly && (w < 200 || textScale > 1.15);

        Widget chip = buildChip(compact: compact, iconOnly: iconOnly);
        if (fullWidth) chip = Row(children: [Expanded(child: chip)]);
        return chip;
      });
    }

    return responsive(context);
  }

// نص مختصر للحالات عند ضيق المساحة
  String _shortLabel(String norm, String fallback) {
    switch (norm) {
      case 'approved':
        return 'مفعل';
      case 'review':
        return 'قيد المراجعة';
      case 'inactive':
        return 'موقّت';
      case 'rejected':
        return 'مرفوض';
      case 'sold out':
        return 'تم البيع';
      default:
        return fallback;
    }
  }

  // ✅ ويدجت السعر والحالة
  Widget priceAndStatus() {
    final double? basePrice = model.price;
    final double? discountedPrice = model.finalPrice ?? basePrice;
    final bool hasDiscount = basePrice != null &&
        discountedPrice != null &&
        discountedPrice < basePrice;

    final double? discountPercent = hasDiscount
        ? (((basePrice! - discountedPrice!) / basePrice) * 100).clamp(0, 100)
        : null;

    final double? priceValue = discountedPrice ?? basePrice;
    final bool showPrice = priceValue != null && priceValue > 0;

    final NumberFormat formatter = NumberFormat('#,##0.##', 'ar');
    final String? priceText = showPrice ? formatter.format(priceValue) : null;
    final String? basePriceText =
        hasDiscount && basePrice != null ? formatter.format(basePrice) : null;
    final String currencyText =
        showPrice ? _getCurrencySymbol(model.currency) : "";

    final hasStatus = model.status != null && isAddedByMe;
    final statusText = hasStatus ? _getStatusText(model.status) : null;
    final statusColor = hasStatus ? _getStatusColor(model.status) : null;
    final statusTextColor =
        hasStatus ? _getStatusTextColor(model.status) : null;

    Widget buildPriceWidget() {
      if (priceText == null) {
        return const SizedBox();
      }
      final Color accent = context.color.territoryColor;

      final TextStyle currencyStyle = TextStyle(
        fontSize: context.font.normal + 2,
        fontWeight: FontWeight.w600,
        color: accent.withOpacity(0.85),
        height: 1.1,
      );

      final TextStyle valueStyle = TextStyle(
        fontSize: context.font.larger + 2,
        fontWeight: FontWeight.w800,
        color: accent,
        height: 1.1,
      );

      final TextStyle basePriceStyle = TextStyle(
        fontSize: context.font.normal,
        color: context.color.textLightColor.withOpacity(0.7),
        decoration: TextDecoration.lineThrough,
        decorationColor: context.color.textLightColor.withOpacity(0.55),
        height: 1.2,
      );

      final Widget priceValue = Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(priceText, style: valueStyle),
          if (currencyText.isNotEmpty) ...[
            const SizedBox(width: 4),
            Text(currencyText, style: currencyStyle),
          ],
        ],
      );

      final Widget? basePriceWidget = basePriceText == null
          ? null
          : Text(
              currencyText.isEmpty
                  ? basePriceText
                  : '$basePriceText $currencyText',
              style: basePriceStyle,
            );

      final Widget? discountChip = (hasDiscount && discountPercent != null)
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: accent.withOpacity(0.35), width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.discount_rounded, size: 18, color: accent),
                  const SizedBox(width: 6),
                  Text(
                    '-${discountPercent.toStringAsFixed(discountPercent >= 10 ? 0 : 1)}%',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: context.font.normal,
                      color: accent,
                    ),
                  ),
                ],
              ),
            )
          : null;

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (discountChip != null) ...[
              discountChip,
              const SizedBox(width: 12),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  priceValue,
                  if (basePriceWidget != null) ...[
                    const SizedBox(height: 4),
                    basePriceWidget,
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        /// 💵 السعر (يختفي إن كان 0)
        Expanded(child: buildPriceWidget()),
        // 🏷️ حالة الإعلان (تظهر فقط لصاحب الإعلان)
        if (hasStatus) ...[
          const SizedBox(width: 12),
          _buildStatusChip(context, model.status),
        ],
      ],
    );
  }

  // ✅ ويدجت العنوان والتاريخ
  Widget titleAndDate({
    required bool isDate,
    double datePaddingStart = 8.0,
    double dateLeftOffset = 0.0,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fadedColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Row(
        mainAxisAlignment:
            isDate ? MainAxisAlignment.spaceBetween : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SvgPicture.asset(
            AppIcons.location,
            colorFilter: ColorFilter.mode(
              context.color.territoryColor,
              BlendMode.srcIn,
            ),
          ),
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(start: 5.0),
              child: Text(
                model.address ?? "جاري التحميل...",
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: fadedColor,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          if (isDate)
            Expanded(
              child: Padding(
                padding: EdgeInsetsDirectional.only(
                  start: datePaddingStart,
                  end: dateLeftOffset,
                ),
                child: Text(
                  model.created != null
                      ? timeago.format(
                          DateTime.tryParse(model.created!) ?? DateTime.now(),
                          locale: 'ar')
                      : "تحميل...",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: fadedColor,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// ✅ أدوات مساعدة

  String _getCurrencySymbol(String? currency) {
    if (currency == "usd") return "دولار";
    if (currency == "sar") return "ر.س";
    if (currency == "yer") return "ر.ي";
    return currency ?? "";
  }

  String? _getStatusText(String? status) {
    switch (status) {
      case "review":
        return "underReview".translate(context);
      case "active":
        return "active".translate(context);
      case "approved":
        return "approved".translate(context);
      case "inactive":
        return "deactivate".translate(context);
      case "sold out":
        return "soldOut".translate(context);
      case "rejected":
        return "rejected".translate(context);
      // 🔥 حُذف expired نهائيًا
      default:
        return status;
    }
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case "review":
        return pendingButtonColor.withOpacity(0.1);
      case "active":
      case "approved":
        return activateButtonColor.withOpacity(0.1);
      case "inactive":
      case "rejected":
        return deactivateButtonColor.withOpacity(0.1);
      case "sold out":
        return soldOutButtonColor.withOpacity(0.1);
      // 🔥 حُذف expired نهائيًا
      default:
        return context.color.territoryColor.withOpacity(0.1);
    }
  }

  Color _getStatusTextColor(String? status) {
    switch (status) {
      case "review":
        return pendingButtonColor;
      case "active":
      case "approved":
        return activateButtonColor;
      case "inactive":
      case "rejected":
        return deactivateButtonColor;
      case "sold out":
        return soldOutButtonColor;
      // 🔥 حُذف expired نهائيًا
      default:
        return context.color.territoryColor;
    }
  }
}

// =====================
// تطبيع الحالة + أنماطها
// =====================
String _normalizeStatus(String? raw) {
  final s = (raw ?? '').trim().toLowerCase();
  if (s.isEmpty) return 'review';
  if (['approved', 'active', 'published', 'enabled'].contains(s))
    return 'approved';
  if (['inactive', 'paused', 'disabled'].contains(s)) return 'inactive';
  if (['rejected', 'declined'].contains(s)) return 'rejected';
  if (['sold out', 'sold', 'completed'].contains(s)) return 'sold out';
  if (['review', 'pending', 'under_review', 'inreview'].contains(s))
    return 'review';
  return s;
}

class _StatusStyle {
  final Color bg, fg, border;
  final IconData icon;
  final String label;
  final String description;

  const _StatusStyle({
    required this.bg,
    required this.fg,
    required this.border,
    required this.icon,
    required this.label,
    required this.description,
  });
}

// خريطة الأنماط: تُراعي الثيم تلقائياً

Map<String, _StatusStyle> _statusStyles(BuildContext context, ColorScheme cs) {
  final isDark = Theme.of(context).brightness == Brightness.dark;

  return {
    'review': _StatusStyle(
      bg: Colors.blue.withOpacity(isDark ? .28 : .18),
      fg: isDark ? Colors.blue.shade100 : Colors.blue.shade900,
      border: Colors.blue.withOpacity(.35),
      icon: Icons.hourglass_top_rounded,
      label: "إعلانك قيد المراجعة",
      description:
          "نراجع إعلانك للتأكد من مطابقته للإرشادات. عادةً يتم الاعتماد خلال وقت قصير.",
    ),
    'approved': _StatusStyle(
      bg: Colors.green.withOpacity(isDark ? .28 : .18),
      fg: isDark ? Colors.green.shade100 : Colors.green.shade900,
      border: Colors.green.withOpacity(.35),
      icon: Icons.verified_rounded,
      label: "إعلانك مفعل",
      description: "إعلانك ظاهر للمستخدمين ويمكنهم التفاعل معه الآن.",
    ),
    'inactive': _StatusStyle(
      bg: Colors.grey.withOpacity(isDark ? .30 : .18),
      fg: isDark ? Colors.grey.shade100 : Colors.grey.shade900,
      border: Colors.grey.withOpacity(.35),
      icon: Icons.pause_circle_filled_rounded,
      label: "إعلانك موقّت",
      description:
          "الإعلان غير ظاهر حالياً. يمكنك تفعيله مجددًا من خيارات الإعلان.",
    ),
    'rejected': _StatusStyle(
      bg: Colors.red.withOpacity(isDark ? .28 : .18),
      fg: isDark ? Colors.red.shade100 : Colors.red.shade900,
      border: Colors.red.withOpacity(.40),
      icon: Icons.block_rounded,
      label: "إعلانك مرفوض",
      description: "راجع سبب الرفض وعدّل الإعلان ثم أعد الإرسال للمراجعة.",
    ),
    'sold out': _StatusStyle(
      bg: Colors.amber.withOpacity(isDark ? .28 : .18),
      fg: isDark ? Colors.amber.shade100 : Colors.amber.shade900,
      border: Colors.amber.withOpacity(.35),
      icon: Icons.sell_rounded,
      label: "تم البيع",
      description: "مبروك! يمكنك إيقاف الإعلان أو تركه كتجربة ناجحة.",
    ),
  };
}
