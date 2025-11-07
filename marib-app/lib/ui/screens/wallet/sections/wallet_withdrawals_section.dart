import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:marib/data/cubits/wallet/wallet_withdrawals_cubit.dart';
import 'package:marib/ui/screens/wallet/components/wallet_withdrawals_cards.dart';

class WalletWithdrawalsSection extends StatelessWidget {
  const WalletWithdrawalsSection({
    super.key,
    required this.formatAmount,
    required this.dateFormat,
  });

  final String Function(double amount, String? currency) formatAmount;
  final DateFormat dateFormat;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WalletWithdrawalsCubit, WalletWithdrawalsState>(
      builder: (context, state) {
        if (state is WalletWithdrawalsLoading) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (state is WalletWithdrawalsFailure) {
          return WalletWithdrawalsErrorCard(
            message: state.error.toString(),
            onRetry: () => context
                .read<WalletWithdrawalsCubit>()
                .loadInitial(includeOptions: true),
          );
        }

        if (state is WalletWithdrawalsSuccess) {
          return WalletWithdrawalsCard(
            withdrawals: state.withdrawals,
            formatAmount: formatAmount,
            dateFormat: dateFormat,
            isRefreshing: state.isRefreshing,
            isLoadingMore: state.isLoadingMore,
            hasMore: state.hasMore,
            lastError: state.lastError,
            onRefresh: () => context.read<WalletWithdrawalsCubit>().refresh(),
            onLoadMore: state.hasMore
                ? () => context.read<WalletWithdrawalsCubit>().loadMore()
                : null,
          );
        }

        return const SizedBox.shrink();
      },
    );
  }
}
