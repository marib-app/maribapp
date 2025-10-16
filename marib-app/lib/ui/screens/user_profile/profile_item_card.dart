// lib/ui/screens/profile/widgets/profile_item_card.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:marquee/marquee.dart';

import 'package:marib/ui/screens/widgets/promoted_widget.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/app_icon.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/string_extenstion.dart';
import 'package:marib/data/model/item/item_model.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:marib/utils/helper_utils.dart';

/// ---------------------------
///  شارة حالة الإعلان
/// ---------------------------
class StatusButton {
  final String lable;
  final Color color;
  final Color? textColor;

  StatusButton({
    required this.lable,
    required this.color,
    this.textColor,
  });
}

class StatusBadgeWidget extends StatelessWidget {
  final StatusButton status;
  const StatusBadgeWidget({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: status.color,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Center(
        child: Text(status.lable)
            .size(context.font.small)
            .bold()
            .color(status.textColor ?? Colors.black),
      ),
    );
  }
}







Widget statusBadge(BuildContext context, String? status) {
  final label = _statusText(context, status) ?? '-';
  return Semantics(
    label: "الحالة: $label",
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 10, vertical: 4),
      constraints: const BoxConstraints(minHeight: 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: _statusBgColor(context, status),
      ),
      child: Text(label)
          .size(context.font.small)
          .color(_statusTextColor(context, status)),
    ),
  );
}








String _statusText(BuildContext context, String? status) {
  switch (status) {
    case "review":  return "underReview".translate(context);
    case "active":  return "active".translate(context);
    case "approved":return "approved".translate(context);
    case "inactive":return "deactivate".translate(context);
    case "sold out":return "soldOut".translate(context);
    case "rejected":return "rejected".translate(context);
    case "expired": return "expired".translate(context);
    default: return status ?? "-";
  }
}



Color _statusBgColor(BuildContext context, String? status) {
  switch (status) {
    case "review":           return pendingButtonColor.withOpacity(0.1);
    case "active":
    case "approved":         return activateButtonColor.withOpacity(0.1);
    case "inactive":         return deactivateButtonColor.withOpacity(0.1);
    case "sold out":         return soldOutButtonColor.withOpacity(0.1);
    case "rejected":
    case "expired":          return deactivateButtonColor.withOpacity(0.1);
    default:                 return context.color.territoryColor.withOpacity(0.1);
  }
}


Color _statusTextColor(BuildContext context, String? status) {
  switch (status) {
    case "review":  return pendingButtonColor;
    case "active":
    case "approved":return activateButtonColor;
    case "inactive":return deactivateButtonColor;
    case "sold out":return soldOutButtonColor;
    case "rejected":
    case "expired": return deactivateButtonColor;
    default:        return context.color.territoryColor;
  }
}














/// ---------------------------
///  شارة "جديد"
/// ---------------------------
class _NewBadge extends StatelessWidget {
  const _NewBadge();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text("جديد", style: TextStyle(color: Colors.white, fontSize: 12)),
    );
  }
}

/// ---------------------------
///  صورة + promoted + جديد + (اختياري) شارة حالة تحت الصورة
/// ---------------------------
class ItemImageSection extends StatelessWidget {
  final ItemModel item;
  final double imageHeight;
  final double imageWidth;
  final StatusButton? statusButton;

  const ItemImageSection({
    super.key,
    required this.item,
    required this.imageHeight,
    required this.imageWidth,
    this.statusButton,
  });

  bool _isItemNew(String? created) {
    if (created == null) return false;
    try {
      final d = DateTime.parse(created);
      return DateTime.now().difference(d).inHours < 24;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNew = _isItemNew(item.created);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: item.image ?? '',
                height: imageHeight,
                width: imageWidth,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  height: imageHeight,
                  width: imageWidth,
                  color: Colors.grey.shade200,
                  child: Icon(Icons.broken_image, size: 40, color: Colors.grey.shade400),
                ),
              ),
            ),
            if (item.isFeature ?? false)
              const PositionedDirectional(
                start: 5, top: 5,
                child: PromotedCard(type: PromoteCardType.icon),
              ),
            if (isNew)
              PositionedDirectional(
                start: 5,
                top: (item.isFeature ?? false) ? 5 + 26 : 5,
                child: const _NewBadge(),
              ),
          ],
        ),
        if (statusButton != null) ...[
          const SizedBox(height: 4),
          StatusBadgeWidget(status: statusButton!),
        ],
      ],
    );
  }
}

/// ---------------------------
///  عرض السعر-inline (بدون شيمر)
/// ---------------------------
class _PriceInline extends StatelessWidget {
  final num? price;
  final String currency;
  final Color textColor;
  final Color priceColor;
  final TextStyle style;
  final double spacing;

  const _PriceInline({
    required this.price,
    required this.currency,
    required this.textColor,
    required this.priceColor,
    required this.style,
    this.spacing = 6.0,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(_priceLabel, style: style.copyWith(color: priceColor)).bold(),
        SizedBox(width: spacing),
        Text(
          currency,
          style: style.copyWith(
            fontSize: style.fontSize != null ? style.fontSize! * 0.75 : null,
            color: textColor.withOpacity(0.6),
          ),
        ),
      ],
    );
  }

  String get _priceLabel {
    final formatted = HelperUtils.formatPrice(price);
    if (formatted.isEmpty) {
      return 'غير متوفر';
    }
    return formatted;
  }


}





// ---------------------------
///  شريط الإحصائيات (مشاهدات/إعجابات)
// ---------------------------


class _StatsRow extends StatelessWidget {
  final ItemModel item; final double iconSize; final double fontSize; final double spacing;
  const _StatsRow({required this.item, required this.iconSize, required this.fontSize, this.spacing = 8});

  String _fmt(num n){
    if(n>=1000000) return "${(n/1000000).toStringAsFixed(n%1000000==0?0:1)}M";
    if(n>=1000)    return "${(n/1000).toStringAsFixed(n%1000==0?0:1)}K";
    return n.toStringAsFixed(0);
  }

  Widget _chip(BuildContext ctx, Widget icon, String value){
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: ctx.color.borderColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        icon,
        const SizedBox(width: 6),
        Text(value).size(fontSize).color(ctx.color.textDefaultColor),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final views = _fmt(item.views ?? 0);
    final likes = _fmt(item.totalLikes ?? 0);

    return Wrap(
      spacing: spacing, runSpacing: 4,
      children: [
        _chip(
          context,
          UiUtils.getSvg(AppIcons.eye, width: iconSize, height: iconSize, color: context.color.textDefaultColor),
          views,
        ),
        _chip(
          context,
          UiUtils.getSvg(AppIcons.like, width: iconSize, height: iconSize, color: context.color.textDefaultColor),
          likes,
        ),
      ],
    );
  }
}



/// ---------------------------
///  تفاصيل يمين (عنوان + سعر + إحصائيات) — بدون موقع وبدون مفضلة
/// ---------------------------
class ItemDetailsSection extends StatelessWidget {
  final ItemModel item;
  const ItemDetailsSection({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final title = item.name?.firstUpperCase() ?? "بدون عنوان";
    final dynamicFont = title.length > 30 ? context.font.smaller : context.font.normal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // العنوان (Marquee عند الطول)
        Builder(
          builder: (context) {
            final style = TextStyle(
              fontSize: dynamicFont,
              color: context.color.textDefaultColor,
              fontWeight: FontWeight.w500,
              shadows: [
                Shadow(
                  blurRadius: 1,
                  color: Colors.black.withOpacity(0.08),
                  offset: const Offset(0, .5),
                ),
              ],
            );
            if (title.length > 28) {
              return SizedBox(
                height: (style.fontSize ?? 14) + 2,
                child: Marquee(
                  text: title, style: style,
                  scrollAxis: Axis.horizontal,
                  blankSpace: 30.0, velocity: 25.0,
                  pauseAfterRound: const Duration(seconds: 1),
                  startPadding: 10.0,
                  accelerationDuration: const Duration(seconds: 1),
                  decelerationDuration: const Duration(milliseconds: 500),
                ),
              );
            }
            return Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: style);
          },
        ),

        const SizedBox(height: 14),

        // السعر
        _PriceInline(
          price: item.price,
          currency: item.currency ?? "",
          textColor: context.color.textDefaultColor,
          priceColor: context.color.territoryColor,
          style: TextStyle(fontSize: context.font.normal),
        ),

        const Spacer(),

        // الإحصائيات أسفل البطاقة
        _StatsRow(
          item: item,
          iconSize: 16,
          fontSize: context.font.small,
        ),
      ],
    );
  }
}

/// ---------------------------
///  بطاقة البروفايل الأفقية (جاهزة للاستخدام)
/// ---------------------------


class ProfileItemCard extends StatelessWidget {
  final ItemModel item;
  final VoidCallback? onTap;
  final double? additionalHeight;
  final double? additionalImageWidth;
  final StatusButton? statusButton;

  const ProfileItemCard({
    super.key,
    required this.item,
    this.onTap,
    this.additionalHeight,
    this.additionalImageWidth,
    this.statusButton,
  });

  @override
  Widget build(BuildContext context) {
    // مقاسات مرنة
    final width = MediaQuery.of(context).size.width;
    double clamp(double v, double min, double max) => v < min ? min : (v > max ? max : v);

    final double baseH = clamp(width * 0.27, 108, 156); // حد أدنى منطقي حتى لا تختفي الصورة
    final double cardHeight = baseH + (additionalHeight ?? 0);
    final double imageWidth = clamp(width * 0.26, 92, 160) + (additionalImageWidth ?? 0);

    final radius = 15.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(8),
          margin: const EdgeInsets.symmetric(vertical: 1.5),
          decoration: BoxDecoration(
            color: context.color.secondaryColor,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: context.color.borderColor, width: 6),
          ),
          child: SizedBox(
            height: cardHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // الصورة (بدون شارات حالة تحتها)
                ItemImageSection(
                  item: item,
                  imageHeight: cardHeight - 1,
                  imageWidth: imageWidth,
                  statusButton: null,
                ),

                const SizedBox(width: 12),

                // التفاصيل: العنوان + شارة الحالة داخل المحتوى + السعر + الإحصائيات
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // العنوان + شارة الحالة داخل نفس السطر
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.name?.firstUpperCase() ?? "بدون عنوان",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: context.font.normal,
                                fontWeight: FontWeight.w600,
                                color: context.color.textDefaultColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // الجديد:
                          StatusChipSmall(rawStatus: item.status, dense: true),
                        ],
                      ),

                      const SizedBox(height: 6),

                      // السعر + العملة
                      _PriceInline(
                        price: item.price,
                        currency: item.currency ?? "",
                        textColor: context.color.textDefaultColor,
                        priceColor: context.color.territoryColor,
                        style: TextStyle(fontSize: context.font.normal),
                      ),

                      const Spacer(),

                      // الإحصائيات (مشاهدات/إعجابات)
                      _StatsRow(
                        item: item,
                        iconSize: 16,
                        fontSize: context.font.small,
                      ),
                    ],
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









// === Status chip (مطابق لألوان/أيقونات تفاصيل الإعلان) ===
String _normalizeStatus(String? raw) {
  final s = (raw ?? '').trim().toLowerCase();
  if (s.isEmpty) return 'review';
  if (['approved','active','published','enabled'].contains(s)) return 'approved';
  if (['inactive','paused','disabled'].contains(s)) return 'inactive';
  if (['rejected','declined'].contains(s)) return 'rejected';
  if (['sold out','sold','completed'].contains(s)) return 'sold out';
  if (['review','pending','under_review','inreview'].contains(s)) return 'review';
  return s;
}

class _StatusStyle {
  final Color bg, fg, border;
  final IconData icon;
  final String label;
  const _StatusStyle({required this.bg, required this.fg, required this.border, required this.icon, required this.label});
}

Map<String, _StatusStyle> _statusStyles(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return {
    'review': _StatusStyle(
      bg: Colors.blue.withOpacity(isDark ? .28 : .18),
      fg: isDark ? Colors.blue.shade100 : Colors.blue.shade900,
      border: Colors.blue.withOpacity(.35),
      icon: Icons.hourglass_top_rounded,
      label: "قيد المراجعة",
    ),
    'approved': _StatusStyle(
      bg: Colors.green.withOpacity(isDark ? .28 : .18),
      fg: isDark ? Colors.green.shade100 : Colors.green.shade900,
      border: Colors.green.withOpacity(.35),
      icon: Icons.verified_rounded,
      label: "مفعل",
    ),
    'inactive': _StatusStyle(
      bg: Colors.grey.withOpacity(isDark ? .30 : .18),
      fg: isDark ? Colors.grey.shade100 : Colors.grey.shade900,
      border: Colors.grey.withOpacity(.35),
      icon: Icons.pause_circle_filled_rounded,
      label: "موقّت",
    ),
    'rejected': _StatusStyle(
      bg: Colors.red.withOpacity(isDark ? .28 : .18),
      fg: isDark ? Colors.red.shade100 : Colors.red.shade900,
      border: Colors.red.withOpacity(.40),
      icon: Icons.block_rounded,
      label: "مرفوض",
    ),
    'sold out': _StatusStyle(
      bg: Colors.amber.withOpacity(isDark ? .28 : .18),
      fg: isDark ? Colors.amber.shade100 : Colors.amber.shade900,
      border: Colors.amber.withOpacity(.35),
      icon: Icons.sell_rounded,
      label: "تم البيع",
    ),
  };
}

class StatusChipSmall extends StatelessWidget {
  final String? rawStatus;
  final bool dense;
  const StatusChipSmall({super.key, required this.rawStatus, this.dense = true});

  @override
  Widget build(BuildContext context) {
    final norm = _normalizeStatus(rawStatus);
    final map  = _statusStyles(context);
    final st   = map[norm] ?? map['review']!;
    final padH = dense ? 10.0 : 12.0;
    final padV = dense ? 6.0  : 8.0;

    return IgnorePointer(
      ignoring: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
        decoration: BoxDecoration(
          color: st.bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: st.border, width: 1),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(st.icon, size: dense ? 14 : 16, color: st.fg),
          const SizedBox(width: 6),
          Text(st.label, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: st.fg, fontWeight: FontWeight.w600, fontSize: dense ? 12 : 13)),
        ]),
      ),
    );
  }
}
