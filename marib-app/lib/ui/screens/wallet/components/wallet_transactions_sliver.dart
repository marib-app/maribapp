import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:marib/data/cubits/wallet/wallet_transactions_cubit.dart';
import 'package:marib/data/model/wallet/wallet_transaction.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/ui/screens/widgets/errors/no_data_found.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/ui_utils.dart';

class WalletTransactionsSliver extends StatelessWidget {
  const WalletTransactionsSliver({
    super.key,
    required this.state,
    required this.formatAmount,
    required this.dateFormat,
    required this.onRetry,
    required this.onRefresh,
  });

  final WalletTransactionsState state;
  final String Function(double amount, String? currency) formatAmount;
  final DateFormat dateFormat;
  final VoidCallback onRetry;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return SliverList(
      delegate: SliverChildListDelegate(
        _buildContent(context),
      ),
    );
  }

  List<Widget> _buildContent(BuildContext context) {
    if (state is WalletTransactionsLoading) {
      return [
        Padding(
          padding: const EdgeInsets.only(top: 120),
          child: Center(child: UiUtils.progress()),
        ),
      ];
    }

    if (state is WalletTransactionsFailure) {
      final error = state as WalletTransactionsFailure;
      return [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'walletTransactionsError'.translate(context),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(error.error.toString()),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: onRetry,
                child: Text('retry'.translate(context)),
              ),
            ],
          ),
        ),
      ];
    }

    if (state is WalletTransactionsSuccess) {
      final success = state as WalletTransactionsSuccess;
      if (success.transactions.isEmpty) {
        return [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 64),
            child: Column(
              children: [
                NoDataFound(
                  mainMessage: 'walletEmptyState'.translate(context),
                  subMessage: 'walletEmptyDescription'.translate(context),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: onRefresh,
                  child: Text('retry'.translate(context)),
                ),
              ],
            ),
          ),
        ];
      }

      final tiles = <Widget>[];
      for (final tx in success.transactions) {
        tiles.add(
          WalletTransactionTile(
            transaction: tx,
            formatAmount: formatAmount,
            dateFormat: dateFormat,
          ),
        );
      }

      if (success.isLoadingMore) {
        tiles.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(child: UiUtils.progress()),
          ),
        );
      }
      return tiles;
    }

    return const [];
  }
}

class WalletTransactionTile extends StatelessWidget {
  const WalletTransactionTile({
    super.key,
    required this.transaction,
    required this.formatAmount,
    required this.dateFormat,
  });

  final WalletTransaction transaction;
  final String Function(double amount, String? currency) formatAmount;
  final DateFormat dateFormat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final amountText = formatAmount(transaction.amount, transaction.currency);
    final accent = _resolveAccentColor(context);
    final timestamp = transaction.createdAt == null
        ? 'walletUnknownDate'.translate(context)
        : dateFormat.format(transaction.createdAt!.toLocal());
    final subtitle = _resolveSubtitle();
    final statusLabel = _statusLabel();
    final referenceValues = _referenceValues();

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      color: context.color.secondaryColor,
      elevation: transaction.highlighted ? 6 : 0,
      shadowColor: accent.withOpacity(transaction.highlighted ? 0.25 : 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: transaction.highlighted
              ? accent
              : context.color.borderColor.withOpacity(0.35),
          width: transaction.highlighted ? 1.4 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    _resolveIcon(),
                    size: 22,
                    color: accent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _classificationLabel(context),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      amountText,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      timestamp,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (statusLabel != null)
              Row(
                children: [
                  WalletTransactionInfoRow(
                    icon: Icons.verified_rounded,
                    label: statusLabel,
                    labelStyle: theme.textTheme.bodySmall?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            if (referenceValues.isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: referenceValues
                    .map((value) => _buildTag(context, value, accent))
                    .toList(),
              ),
            ],
            if (transaction.balanceBefore != null ||
                transaction.balanceAfter != null) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: WalletBalanceSummary(
                      label: 'walletBalanceBefore'.translate(context),
                      value: transaction.balanceBefore == null
                          ? '--'
                          : _formatBalanceValue(transaction.balanceBefore!),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: WalletBalanceSummary(
                      label: 'walletBalanceAfter'.translate(context),
                      value: transaction.balanceAfter == null
                          ? '--'
                          : _formatBalanceValue(transaction.balanceAfter!),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _classificationLabel(BuildContext context) {
    final normalized =
    (transaction.category ?? transaction.classification ?? '')
        .toLowerCase()
        .trim();
    switch (normalized) {
      case 'deposit':
      case 'top-up':
      case 'top-ups':
      case 'top_up':
        return 'walletCategoryDeposit'.translate(context);
      case 'transfer':
      case 'wallet_transfer':
        return 'walletCategoryTransfer'.translate(context);
      case 'purchase':
      case 'payment':
      case 'payments':
        return 'walletCategoryPurchase'.translate(context);
      case 'refund':
      case 'refunds':
        return 'walletCategoryRefund'.translate(context);
      default:
        final fallback = transaction.classification ?? transaction.category;
        if (fallback != null && fallback.trim().isNotEmpty) {
          return fallback;
        }
        return 'walletUnknownClassification'.translate(context);
    }
  }

  IconData _resolveIcon() {
    final normalized =
    (transaction.category ?? transaction.classification ?? '')
        .toLowerCase()
        .trim();
    switch (normalized) {
      case 'transfer':
      case 'wallet_transfer':
        return Icons.swap_horiz_rounded;
      case 'refund':
      case 'refunds':
        return Icons.reply_rounded;
      case 'purchase':
      case 'payment':
      case 'payments':
        return Icons.shopping_bag_outlined;
      default:
        return Icons.savings_outlined;
    }
  }

  Color _resolveAccentColor(BuildContext context) {
    final normalized =
    (transaction.category ?? transaction.classification ?? '')
        .toLowerCase()
        .trim();
    if (normalized.contains('transfer')) {
      return const Color(0xFF3A7AFE);
    }
    if (normalized.contains('refund')) {
      return const Color(0xFF2AB795);
    }
    if (!transaction.isCredit) {
      return Theme.of(context).colorScheme.error;
    }
    return context.color.territoryColor;
  }

  String? _resolveSubtitle() {
    final description = transaction.description;
    if (description != null && description.trim().isNotEmpty) {
      return description.trim();
    }

    final reason = transaction.metadata['reason'];
    if (reason is String && reason.trim().isNotEmpty) {
      return reason.replaceAll('_', ' ').trim();
    }

    final applied = transaction.appliedFilters;
    if (applied.isNotEmpty) {
      final label = applied.first.label.trim();
      if (label.isNotEmpty) {
        return label;
      }
    }

    return null;
  }

  String? _statusLabel() {
    final statusLabel = transaction.metadata['status_label'];
    if (statusLabel is String && statusLabel.trim().isNotEmpty) {
      return statusLabel.trim();
    }

    final status = transaction.metadata['status'];
    if (status is String && status.trim().isNotEmpty) {
      return status.trim();
    }

    return null;
  }

  List<String> _referenceValues() {
    final values = <String>{};
    for (final reference in transaction.references) {
      final trimmed = reference.trim();
      if (trimmed.isNotEmpty) {
        values.add(trimmed);
      }
    }
    final code = transaction.referenceCode;
    if (code != null && code.trim().isNotEmpty) {
      values.add(code.trim());
    }
    return values.toList();
  }

  String _formatBalanceValue(double value) {
    final formatted = formatAmount(value, transaction.currency);
    if (formatted.startsWith('+')) {
      return formatted.substring(1).trimLeft();
    }
    return formatted;
  }

  Widget _buildTag(BuildContext context, String value, Color accent) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withOpacity(0.5)),
      ),
      child: Text(
        value,
        style: theme.textTheme.bodySmall?.copyWith(
          color: accent,
          fontWeight: FontWeight.w600,
        ) ??
            TextStyle(
              color: accent,
              fontSize: theme.textTheme.bodySmall?.fontSize ?? 12,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class WalletTransactionInfoRow extends StatelessWidget {
  const WalletTransactionInfoRow({
    super.key,
    required this.icon,
    required this.label,
    this.labelStyle,
  });

  final IconData icon;
  final String label;
  final TextStyle? labelStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.outline;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: labelStyle ??
                theme.textTheme.bodySmall?.copyWith(
                  color: color,
                ),
          ),
        ),
      ],
    );
  }
}

class WalletBalanceSummary extends StatelessWidget {
  const WalletBalanceSummary({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}