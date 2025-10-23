import 'package:flutter/material.dart';
import 'package:marib/utils/extensions/extensions.dart';

import 'package:marib/ui/theme/theme.dart';

class TopInfoBar extends StatelessWidget {
  final int totalValidAds;
  final int currentShownCount;
  final String? activeCategory;
  final bool radiusOn;
  final double radiusKm;

  const TopInfoBar({
    super.key,
    required this.totalValidAds,
    required this.currentShownCount,
    required this.activeCategory,
    required this.radiusOn,
    required this.radiusKm,
  });

  @override
  Widget build(BuildContext context) {
    final text = 'المعروض: $currentShownCount / $totalValidAds';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withOpacity(.96),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(.25),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 4,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.apartment_rounded,
                size: 16,
                color: context.color.textDefaultColor,
              ),
              const SizedBox(width: 6),
              Text(
                text,
                style: TextStyle(
                  color: context.color.textDefaultColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          if (activeCategory != null && activeCategory != 'الكل')
            _chip(context, activeCategory!),
          if (radiusOn)
            _chip(context, 'نطاق ${radiusKm.toStringAsFixed(0)} كم'),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).chipTheme.backgroundColor ??
              Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Theme.of(context).dividerColor.withOpacity(.25),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 11.5,
            color: context.color.textDefaultColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
}
