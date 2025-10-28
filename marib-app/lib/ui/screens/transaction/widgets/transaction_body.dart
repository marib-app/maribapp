import 'package:flutter/material.dart';

import 'package:marib/ui/screens/widgets/errors/no_data_found.dart';
import 'package:marib/utils/payment/manual_payment.dart';
import 'package:marib/utils/ui_utils.dart';

import 'transaction_error_banner.dart';

class TransactionBody extends StatelessWidget {
  const TransactionBody({
    super.key,
    required this.loading,
    required this.error,
    required this.transactions,
    required this.onRetry,
    required this.manualPaymentBuilder,
  });

  final bool loading;
  final Object? error;
  final List<ManualPayment> transactions;
  final VoidCallback onRetry;
  final Widget Function(BuildContext, ManualPayment) manualPaymentBuilder;

  bool get _hasError => error != null;

  @override
  Widget build(BuildContext context) {
    if (loading && transactions.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: <Widget>[
          const SizedBox(height: 160),
          Center(child: UiUtils.progress()),
        ],
      );
    }

    if (_hasError && transactions.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          TransactionErrorBanner(onRetry: onRetry, includeRetry: true),
        ],
      );
    }

    if (transactions.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(8),
        children: <Widget>[
          NoDataFound(
            onTap: onRetry,
            category: EmptyStateCategory.transactions,
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
      itemCount: transactions.length + (_hasError ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (BuildContext context, int index) {
        if (_hasError) {
          if (index == 0) {
            return TransactionErrorBanner(onRetry: onRetry);
          }
          final ManualPayment mp = transactions[index - 1];
          return manualPaymentBuilder(context, mp);
        }

        final ManualPayment mp = transactions[index];
        return manualPaymentBuilder(context, mp);
      },
    );
  }
}
