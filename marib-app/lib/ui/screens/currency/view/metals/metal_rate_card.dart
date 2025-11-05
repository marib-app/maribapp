import 'package:flutter/material.dart';
import 'package:marib/data/model/metal_rate.dart';
import 'metal_section.dart';

class MetalRateCard extends StatelessWidget {
  const MetalRateCard({
    super.key,
    required this.section,
    required this.rate,
    required this.sellValue,
    required this.buyValue,
    required this.brand,
    required this.onBackground,
    required this.changeIndicator,
    required this.onTap,
  });

  final MetalSection section;
  final MetalRate rate;
  final String sellValue;
  final String buyValue;
  final Color brand;
  final Color onBackground;
  final Widget changeIndicator;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color cardBg = Theme.of(context).cardColor;
    final Color borderColor = onBackground.withOpacity(0.08);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Material(
        color: cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: borderColor),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          splashColor: brand.withOpacity(0.06),
          highlightColor: brand.withOpacity(0.03),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // الأيقونة مثبتة أقصى اليمين
                MetalRateIcon(
                  section: section,
                  rate: rate,
                  size: 44,
                  onBackground: onBackground,
                ),
                const SizedBox(width: 10),

                // النصوص + الشرائح (تتمدّد يسار الأيقونة)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, // start = يمين مع RTL
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // عنوان المعدن والعيار بمحاذاة اليمين
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start, // يمين
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          rate.displayName,
                          textAlign: TextAlign.start, // يمين مع RTL
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: onBackground,
                            fontWeight: FontWeight.w800,
                          ) ??
                              TextStyle(
                                color: onBackground,
                                fontWeight: FontWeight.w800,
                                fontSize: 15.5,
                              ),
                        ),

                      ],
                    ),

                    const SizedBox(height: 10),

                    // شرائح الأسعار
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start, // start = يمين مع RTL
                      children: [
                        _priceChip(
                          context: context,
                          label: 'سعر البيع',
                          value: sellValue,
                          bg: brand.withOpacity(0.01),
                          fg: brand,
                          onBackground: onBackground,
                        ),
                        const SizedBox(width: 8),
                        _priceChip(
                          context: context,
                          label: 'سعر الشراء',
                          value: buyValue,
                          bg: onBackground.withOpacity(0.06),
                          fg: onBackground.withOpacity(0.85),
                          onBackground: onBackground,
                        ),
                      ],
                    ),
                  ],
                ),
              ),


                const SizedBox(width: 12),

              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _priceChip({
    required BuildContext context,
    required String label,
    required String value,
    required Color bg,
    required Color fg,
    required Color onBackground,
  }) {
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: onBackground.withOpacity(0.70),
              fontWeight: FontWeight.w700,
            ) ??
                TextStyle(
                  color: onBackground.withOpacity(0.70),
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w900,
            ) ??
                TextStyle(
                  color: fg,
                  fontWeight: FontWeight.w900,
                  fontSize: 15.5,
                ),
          ),
        ],
      ),
    );
  }
}

class MetalRateIcon extends StatelessWidget {
  const MetalRateIcon({
    super.key,
    required this.section,
    required this.rate,
    required this.onBackground,
    this.size = 48,
  });

  final MetalSection section;
  final MetalRate rate;
  final Color onBackground;
  final double size;

  @override
  Widget build(BuildContext context) {
    final Color ring = onBackground.withOpacity(0.12);
    final bool showFallback = rate.quoteUsedFallback || rate.quoteIsDefault;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Align(
        alignment: Alignment.centerRight, // كل الودجت يلتصق بأقصى اليمين
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        section.iconColor.withOpacity(0.10),
                        section.iconColor.withOpacity(0.04),
                      ],
                    ),
                    border: Border.all(color: ring),
                  ),
                  child: Icon(
                    section.icon,
                    color: section.iconColor,
                    size: size * 0.52,
                  ),
                ),
              ),
              if (showFallback)
                Positioned(
                  bottom: -2,
                  right: -2,
                  child: Container(
                    width: size * 0.38,
                    height: size * 0.38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: section.accent,
                      border: Border.all(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        width: size * 0.08,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: section.accent.withOpacity(0.25),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

}
