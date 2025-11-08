import 'package:flutter/material.dart';
import 'package:marib/data/cubits/currency/currency_filters.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';

import '../../state/state.dart';

class RatesFilterBar extends StatelessWidget {
  const RatesFilterBar({
    super.key,
    required this.state,
    required this.onDirectionFilterChanged,
  });

  final CurrencyViewState state;
  final ValueChanged<RateChangeFilter> onDirectionFilterChanged;

  bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isDark = _isDark(context);
    final Color borderColor = isDark ? Colors.white24 : Colors.black12;
    final Color onBackground = isDark ? Colors.white : Colors.black;
    final Color brand = context.color.territoryColor;
    final Color selectedBg = brand.withOpacity(isDark ? 0.25 : 0.12);

    Widget label(String text) {
      return Padding(
        padding: const EdgeInsetsDirectional.only(end: 4),
        child: Text(
          text,
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: onBackground.withOpacity(0.7),
          ),
        ),
      );
    }

    ChoiceChip buildChoiceChip({
      required String text,
      required bool selected,
      required VoidCallback onTap,
      IconData? icon,
    }) {
      final Color textColor = selected ? onBackground : onBackground.withOpacity(0.8);
      return ChoiceChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: textColor),
              const SizedBox(width: 4),
            ],
            Text(
              text,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
        selected: selected,
        onSelected: (_) {
          if (!selected) {
            onTap();
          }
        },
        backgroundColor: Colors.transparent,
        selectedColor: selectedBg,
        pressElevation: 0,
        shape: StadiumBorder(
          side: BorderSide(color: selected ? brand : borderColor),
        ),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            label('الاتجاه'),
            buildChoiceChip(
              text: 'الكل',
              selected: state.changeFilter == RateChangeFilter.all,
              onTap: () => onDirectionFilterChanged(RateChangeFilter.all),
              icon: Icons.filter_list,
            ),
            buildChoiceChip(
              text: 'ارتفاع',
              selected: state.changeFilter == RateChangeFilter.rising,
              onTap: () => onDirectionFilterChanged(RateChangeFilter.rising),
              icon: Icons.trending_up,
            ),
            buildChoiceChip(
              text: 'انخفاض',
              selected: state.changeFilter == RateChangeFilter.falling,
              onTap: () => onDirectionFilterChanged(RateChangeFilter.falling),
              icon: Icons.trending_down,
            ),
          ],
        ),
      ),
    );
  }
}
