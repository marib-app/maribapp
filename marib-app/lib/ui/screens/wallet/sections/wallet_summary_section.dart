import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marib/data/cubits/wallet/wallet_summary_cubit.dart';
import 'package:marib/ui/screens/wallet/components/wallet_summary_card.dart';
import 'package:marib/utils/extensions/extensions.dart';

class WalletSummarySection extends StatelessWidget {
  const WalletSummarySection({
    super.key,
    required this.formatAmount,
  });

  final String Function(double amount, String? currency) formatAmount;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WalletSummaryCubit, WalletSummaryState>(
      builder: (context, state) {
        if (state is WalletSummaryLoading && state.previous != null) {
          final previous = state.previous!.summary;
          return WalletSummaryCard(
            balanceText: formatAmount(
              previous.balance,
              previous.currency,
            ),
            lastUpdated: previous.lastUpdatedAt,
            isLoading: true,
          );
        }
        if (state is WalletSummaryLoadSuccess) {
          final summary = state.summary;
          return WalletSummaryCard(
            balanceText: formatAmount(summary.balance, summary.currency),
            lastUpdated: summary.lastUpdatedAt,
          );
        }
        if (state is WalletSummaryFailure) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'walletSummaryError'.translate(context),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(state.error.toString()),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => context
                      .read<WalletSummaryCubit>()
                      .fetchSummary(forceReload: true),
                  child: Text('retry'.translate(context)),
                ),
              ],
            ),
          );
        }
        return const WalletSummaryCard(isLoading: true);
      },
    );
  }
}
