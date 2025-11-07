import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marib/data/cubits/wallet/wallet_transactions_cubit.dart';
import 'package:marib/data/model/wallet/wallet_filter.dart';
import 'package:marib/ui/screens/wallet/components/wallet_filters_list.dart';

class WalletFiltersSection extends StatelessWidget {
  const WalletFiltersSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WalletTransactionsCubit, WalletTransactionsState>(
      builder: (context, state) {
        List<WalletFilter> filters = const [];
        String? activeFilter;

        if (state is WalletTransactionsSuccess) {
          filters = state.availableFilters;
          activeFilter = state.appliedFilter;
        }

        return WalletFiltersList(
          filters: filters,
          activeFilter: activeFilter,
          onClear: () => context.read<WalletTransactionsCubit>().clearFilters(),
          onFilterSelected: (value) =>
              context.read<WalletTransactionsCubit>().applyFilter(value),
        );
      },
    );
  }
}
