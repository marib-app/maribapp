import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:marib/data/model/wallet/wallet_withdrawal.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/ui_utils.dart';

class WalletWithdrawalsCard extends StatelessWidget {
  const WalletWithdrawalsCard({
    super.key,
    required this.withdrawals,
    required this.formatAmount,
    required this.dateFormat,
    required this.isRefreshing,
    required this.isLoadingMore,
    required this.hasMore,
    required this.onRefresh,
    this.onLoadMore,
    this.lastError,
  });

  final List<WalletWithdrawal> withdrawals;
  final String Function(double amount, String? currency) formatAmount;
  final DateFormat dateFormat;
  final bool isRefreshing;
  final bool isLoadingMore;
  final bool hasMore;
  final VoidCallback onRefresh;
  final VoidCallback? onLoadMore;
  final dynamic lastError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final List<WalletWithdrawal> visible = withdrawals.take(3).toList();

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'طلبات السحب',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                TextButton(
                  onPressed: isRefreshing ? null : onRefresh,
                  child: isRefreshing
                      ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Text('تحديث'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (lastError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                  'تعذر تحديث القائمة: $lastError',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            if (withdrawals.isEmpty)
              Text(
                'لا توجد طلبات سحب حتى الآن.',
                style: theme.textTheme.bodyMedium,
              )
            else
              Column(
                children: [
                  for (var i = 0; i < visible.length; i++) ...[
                    if (i > 0) const Divider(height: 20),
                    WalletWithdrawalTile(
                      withdrawal: visible[i],
                      formatAmount: formatAmount,
                      dateFormat: dateFormat,
                    ),
                  ],
                  if (hasMore || isLoadingMore)
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton(
                        onPressed: isLoadingMore || onLoadMore == null
                            ? null
                            : onLoadMore,
                        child: isLoadingMore
                            ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                            : const Text('تحميل المزيد'),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class WalletWithdrawalTile extends StatelessWidget {
  const WalletWithdrawalTile({
    super.key,
    required this.withdrawal,
    required this.formatAmount,
    required this.dateFormat,
  });

  final WalletWithdrawal withdrawal;
  final String Function(double amount, String? currency) formatAmount;
  final DateFormat dateFormat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reference = withdrawal.reference?.isNotEmpty == true
        ? withdrawal.reference!
        : '#${withdrawal.id}';
    final amountValue = withdrawal.amount;
    final amountText = amountValue != null
        ? formatAmount(
        amountValue > 0 ? -amountValue : amountValue, withdrawal.currency)
        : '--';
    final status = withdrawal.status?.capitalize() ?? 'غير معروف';
    final timestamp = withdrawal.updatedAt ?? withdrawal.createdAt;
    final subtitleText =
    timestamp != null ? dateFormat.format(timestamp.toLocal()) : null;
    final statusColor = _statusColor(context, withdrawal.status);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(reference, style: theme.textTheme.titleMedium),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (subtitleText != null)
            Text(
              subtitleText,
              style: theme.textTheme.bodySmall,
            ),
          if (withdrawal.statusMessage?.isNotEmpty == true)
            Text(
              withdrawal.statusMessage!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            amountText,
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              status,
              style: theme.textTheme.bodySmall?.copyWith(color: statusColor),
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(BuildContext context, String? status) {
    final normalized = status?.toLowerCase() ?? '';
    if (normalized.contains('fail') ||
        normalized.contains('reject') ||
        normalized.contains('cancel')) {
      return Colors.redAccent;
    }
    if (normalized.contains('complete') ||
        normalized.contains('success') ||
        normalized.contains('paid')) {
      return Colors.green;
    }
    if (normalized.contains('pending') || normalized.contains('process')) {
      return context.color.territoryColor;
    }
    return Theme.of(context).colorScheme.primary;
  }
}

class WalletWithdrawalsErrorCard extends StatelessWidget {
  const WalletWithdrawalsErrorCard({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'تعذر تحميل طلبات السحب',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            UiUtils.buildButton(
              context,
              onPressed: onRetry,
              buttonTitle: 'إعادة المحاولة',
              height: 44,
              radius: 8,
            ),
          ],
        ),
      ),
    );
  }
}