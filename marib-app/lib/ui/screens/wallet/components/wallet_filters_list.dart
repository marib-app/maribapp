import 'package:flutter/material.dart';
import 'package:marib/data/model/wallet/wallet_filter.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';

class WalletFiltersList extends StatelessWidget {
  const WalletFiltersList({
    super.key,
    required this.filters,
    required this.activeFilter,
    required this.onClear,
    required this.onFilterSelected,
  });

  final List<WalletFilter> filters;
  final String? activeFilter;
  final VoidCallback onClear;
  final ValueChanged<String> onFilterSelected;

  @override
  Widget build(BuildContext context) {
    if (filters.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 64,
      child: ListView(
        padding: const EdgeInsetsDirectional.only(
          start: 16,
          end: 16,
          top: 12,
          bottom: 12,
        ),
        scrollDirection: Axis.horizontal,
        children: [
          _WalletFilterChip(
            label: 'walletFilterAll'.translate(context),
            selected: activeFilter == null || activeFilter == 'all',
            onSelected: (_) => onClear(),
          ),
          const SizedBox(width: 8),
          ...filters.map(
                (filter) => Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: _WalletFilterChip(
                label: _localizedFilterLabel(context, filter.value, filter.label),
                selected: activeFilter == filter.value,
                onSelected: (_) => onFilterSelected(filter.value),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _localizedFilterLabel(
      BuildContext context,
      String value,
      String fallback,
      ) {
    final normalized = value.toLowerCase().trim();
    switch (normalized) {
      case 'top-ups':
      case 'top_up':
      case 'deposit':
      case 'deposits':
        return 'walletFilterDeposits'.translate(context);
      case 'payments':
      case 'payment':
      case 'purchase':
      case 'purchases':
        return 'walletFilterPurchases'.translate(context);
      case 'transfers':
      case 'transfer':
        return 'walletFilterTransfers'.translate(context);
      case 'refunds':
      case 'refund':
        return 'walletFilterRefunds'.translate(context);
    }
    if (fallback.isNotEmpty) {
      return fallback;
    }
    return value.isNotEmpty ? value : 'walletFilterAll'.translate(context);
  }
}

class _WalletFilterChip extends StatelessWidget {
  const _WalletFilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedColor = context.color.territoryColor.withOpacity(.16);
    final borderColor = selected
        ? context.color.territoryColor
        : context.color.borderColor.withOpacity(0.6);
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      side: BorderSide(color: borderColor),
      backgroundColor: context.color.secondaryColor,
      selectedColor: selectedColor,
      elevation: 0,
      labelStyle: theme.textTheme.bodyMedium?.copyWith(
        color: selected
            ? context.color.territoryColor
            : theme.colorScheme.onSurface,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
      ),
    );
  }
}