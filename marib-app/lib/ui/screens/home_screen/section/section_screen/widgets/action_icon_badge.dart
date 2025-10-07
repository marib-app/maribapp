import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:marib/ui/theme/theme.dart'; // يوفر context.color
import 'package:marib/utils/extensions/extensions.dart'; // يوفر translate, .size, .color...

/// زر أيقونة (SVG أو IconData) مع بادج عددي اختياري.
/// متوافق RTL عبر PositionedDirectional.
/// يستخدم ألوان الثيم: territoryColor للأيقونة والبادج افتراضيًا.

class ActionIconBadge extends StatelessWidget {
  const ActionIconBadge({
    super.key,
    required this.onTap,
    this.svgAsset,
    this.iconData,
    this.count = 0,
    this.tapSize = 44,
    this.iconSize = 24,
    this.iconColor,
    this.badgeColor,
    this.semanticLabel,
    this.tooltip,
    this.padding = EdgeInsets.zero,
    this.splashRadius,
  }) : assert(
            svgAsset != null || iconData != null, 'مرّر svgAsset أو iconData');

  /// استدعاء عند الضغط
  final VoidCallback onTap;

  /// أحدهما فقط: SVG أو IconData
  final String? svgAsset;
  final IconData? iconData;

  /// رقم البادج (0 لإخفائه)
  final int count;

  /// أبعاد منطقة الضغط (المربع الخارجي)
  final double tapSize;

  /// حجم الأيقونة
  final double iconSize;

  /// لون الأيقونة (افتراضي: context.color.territoryColor)
  final Color? iconColor;

  /// لون البادج (افتراضي: context.color.territoryColor)
  final Color? badgeColor;

  /// إمكانية الوصول
  final String? semanticLabel;

  /// تلميح
  final String? tooltip;

  /// حشوة إضافية حول الأيقونة داخل مساحة الضغط
  final EdgeInsetsGeometry padding;

  /// نصف قطر الـ splash (إن أردت تخصيصه)
  final double? splashRadius;

  @override
  Widget build(BuildContext context) {
    final colors = context.color;
    final showBadge = count > 0;

    return Semantics(
      button: true,
      label: semanticLabel ?? tooltip,
      child: SizedBox(
        width: tapSize,
        height: tapSize,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // الزر الأساسي
            Positioned.fill(
              child: IconButton(
                splashRadius: splashRadius ?? (tapSize * 0.5),
                padding: padding,
                tooltip: tooltip,
                onPressed: onTap,
                icon: _buildIcon(
                  context,
                  color: iconColor ?? colors.territoryColor,
                  size: iconSize,
                ),
              ),
            ),

            // البادج
            if (showBadge)
              PositionedDirectional(
                top: -2,
                end: -2,
                child: _BadgeDot(
                  value: count,
                  color: badgeColor ?? colors.territoryColor,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon(BuildContext context,
      {required Color color, required double size}) {
    if (svgAsset != null) {
      return SvgPicture.asset(svgAsset!,
          height: size, width: size, color: color);
    }
    return Icon(iconData!, size: size, color: color);
  }
}

/// شارة عدديّة صغيرة
class _BadgeDot extends StatelessWidget {
  const _BadgeDot({required this.value, required this.color});
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final String text = value > 99 ? '99+' : value.toString();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: Colors.white, width: 1),
      ),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(
              fontSize: 10, color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
