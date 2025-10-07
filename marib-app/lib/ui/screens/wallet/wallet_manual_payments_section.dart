import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import 'package:marib/data/cubits/wallet/manual_payment_requests_cubit.dart';
import 'package:marib/ui/screens/wallet/manual_payment_requests_sheet.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:marib/utils/payment/manual_payment.dart';

class WalletManualPaymentsSection extends StatelessWidget {
  WalletManualPaymentsSection({super.key}) : _dateFormat = DateFormat('dd MMM yyyy');

  final DateFormat _dateFormat;

  Future<void> _openSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const ManualPaymentRequestsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ManualPaymentRequestsCubit, ManualPaymentRequestsState>(
      builder: (context, state) {
        if (state is ManualPaymentRequestsLoading) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (state is ManualPaymentRequestsFailure) {
          return _ErrorCard(
            message: state.error.toString(),
            onRetry: () => context.read<ManualPaymentRequestsCubit>().loadInitial(),
          );
        }

        if (state is ManualPaymentRequestsSuccess) {
          final requests = state.requests;
          return _ManualPaymentsCard(
            requests: requests,
            dateFormat: _dateFormat,
            onViewAll: () => _openSheet(context),
            isRefreshing: state.isRefreshing,
            onRefresh: () => context.read<ManualPaymentRequestsCubit>().refresh(),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }
}

class _ManualPaymentsCard extends StatelessWidget {
  const _ManualPaymentsCard({
    required this.requests,
    required this.dateFormat,
    required this.onViewAll,
    required this.isRefreshing,
    required this.onRefresh,
  });

  final List<ManualPayment> requests;
  final DateFormat dateFormat;
  final VoidCallback onViewAll;
  final bool isRefreshing;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
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
                    'طلبات الدفع اليدوي',
                    style: Theme.of(context).textTheme.titleMedium,
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
                const SizedBox(width: 4),
                OutlinedButton(
                  onPressed: onViewAll,
                  child: const Text('عرض الكل'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (requests.isEmpty)
              Text(
                'لا توجد طلبات مسجلة حتى الآن.',
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else
              Column(
                children: requests.take(3).map<Widget>((entry) {
                  final ManualPayment payment = entry;
                  final status = payment.paymentStatus.toString().capitalize();
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(payment.manualReference ?? payment.transactionIdentifier ?? '#${payment.manualPaymentId ?? ''}'),
                    subtitle: Text(
                      '${payment.amount.toStringAsFixed(2)} ${payment.currency.toUpperCase()} · ${dateFormat.format(payment.createdAt.toLocal())}',
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: context.color.territoryColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        status,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

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
              'تعذر تحميل الطلبات اليدوية',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(message, style: Theme.of(context).textTheme.bodySmall),
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