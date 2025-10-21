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
    Widget priceColumn(String label, String value, Color color) {
      final TextTheme textTheme = Theme.of(context).textTheme;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: textTheme.labelSmall?.copyWith(
              color: onBackground.withOpacity(0.6),
              fontWeight: FontWeight.w700,
            ) ??
                TextStyle(
                  color: onBackground.withOpacity(0.6),
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: textTheme.titleSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ) ??
                TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 15.5,
                ),
          ),
        ],
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: brand.withOpacity(0.06),
        highlightColor: brand.withOpacity(0.03),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              MetalRateIcon(
                section: section,
                rate: rate,
                size: 46,
                onBackground: onBackground,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      rate.displayName,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: onBackground,
                        fontWeight: FontWeight.w800,
                      ) ??
                          TextStyle(
                            color: onBackground,
                            fontWeight: FontWeight.w800,
                            fontSize: 15.5,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textDirection: TextDirection.rtl,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      rate.karatLabel,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: onBackground.withOpacity(0.6),
                        fontWeight: FontWeight.w600,
                      ) ??
                          TextStyle(
                            color: onBackground.withOpacity(0.6),
                            fontWeight: FontWeight.w600,
                          ),
                      textDirection: TextDirection.rtl,
                    ),
                    const SizedBox(height: 8),
                    Directionality(
                      textDirection: TextDirection.rtl,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          priceColumn('سعر البيع', sellValue, brand),
                          const SizedBox(width: 16),
                          priceColumn(
                            'سعر الشراء',
                            buyValue,
                            onBackground.withOpacity(0.85),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              changeIndicator,
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_left_rounded,
                color: onBackground.withOpacity(0.4),
              ),
            ],
          ),
        ),
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
    final Color outline = onBackground.withOpacity(0.25);
    final bool showFallback = rate.quoteUsedFallback || rate.quoteIsDefault;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: outline),
          ),
          child: Icon(section.icon, color: section.iconColor, size: size * 0.5),
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
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
      ],
    );
  }
}