import 'package:flutter/material.dart';

import 'metal_section.dart';

class MetalsFilterBar extends StatelessWidget {
  const MetalsFilterBar({
    super.key,
    required this.selectedFilter,
    required this.onFilterSelected,
    required this.showOther,
    required this.borderColor,
    required this.onBackground,
    required this.brand,
  });

  final MetalsFilter selectedFilter;
  final ValueChanged<MetalsFilter> onFilterSelected;
  final bool showOther;
  final Color borderColor;
  final Color onBackground;
  final Color brand;

  @override
  Widget build(BuildContext context) {
    final List<_FilterOption> options = <_FilterOption>[
      const _FilterOption(filter: MetalsFilter.all, label: 'الكل'),
      const _FilterOption(filter: MetalsFilter.gold, label: 'الذهب'),
      const _FilterOption(filter: MetalsFilter.silver, label: 'الفضة'),
    ];

    if (showOther) {
      options.add(const _FilterOption(filter: MetalsFilter.other, label: 'أخرى'));
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: options
            .map(
              (option) => ChoiceChip(
            label: Text(option.label),
            selected: selectedFilter == option.filter,
            onSelected: (_) => onFilterSelected(option.filter),
            selectedColor: brand.withOpacity(0.12),
            labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: selectedFilter == option.filter
                  ? brand
                  : onBackground.withOpacity(0.75),
              fontWeight: FontWeight.w700,
            ),
            backgroundColor: Colors.transparent,
            side: BorderSide(color: borderColor),
          ),
        )
            .toList(growable: false),
      ),
    );
  }
}

class _FilterOption {
  const _FilterOption({required this.filter, required this.label});

  final MetalsFilter filter;
  final String label;
}