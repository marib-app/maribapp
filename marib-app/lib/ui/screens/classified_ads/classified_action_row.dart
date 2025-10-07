import 'package:flutter/material.dart';

class ClassifiedActionRow extends StatelessWidget {
  final VoidCallback onShare;
  final VoidCallback onTapRating;

  /// نص التقييم المعروض (مثلاً: "4.8 (120)")، لو null نكتب "التقييم"
  final String? ratingText;

  /// تحكم بالهوامش حول الصف (افتراضياً تحت الصورة)
  final EdgeInsetsGeometry padding;

  const ClassifiedActionRow({
    super.key,
    required this.onShare,
    required this.onTapRating,
    this.ratingText,
    this.padding = const EdgeInsets.only(top: 8, bottom: 4, left: 4, right: 4),
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: padding,
      child: Align(
        alignment: Alignment.centerLeft, // يسار الشاشة (حتى في RTL)
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PillButton(
              icon: const Icon(Icons.ios_share, size: 18),
              label: 'مشاركة',
              onTap: onShare,
              bg: cs.surfaceVariant,
              fg: cs.onSurface,
              border: cs.outlineVariant.withOpacity(.35),
            ),
            const SizedBox(width: 8),
            _PillButton(
              icon: const Icon(Icons.star_rounded, size: 18, color: Colors.amber),
              label: ratingText ?? 'التقييم',
              onTap: onTapRating,
              bg: cs.surfaceVariant,
              fg: cs.onSurface,
              border: cs.outlineVariant.withOpacity(.35),
            ),
          ],
        ),
      ),
    );
  }
}

class _PillButton extends StatefulWidget {
  final Widget icon;
  final String label;
  final VoidCallback onTap;
  final Color bg;
  final Color fg;
  final Color border;

  const _PillButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.bg,
    required this.fg,
    required this.border,
  });

  @override
  State<_PillButton> createState() => _PillButtonState();
}

class _PillButtonState extends State<_PillButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? .96 : 1,
      duration: const Duration(milliseconds: 110),
      child: Material(
        color: widget.bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
          side: BorderSide(color: widget.border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: widget.onTap,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) => setState(() => _pressed = false),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconTheme.merge(
                  data: IconThemeData(color: widget.fg),
                  child: widget.icon,
                ),
                const SizedBox(width: 6),
                Text(
                  widget.label,
                  style: TextStyle(
                    color: widget.fg,
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
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
