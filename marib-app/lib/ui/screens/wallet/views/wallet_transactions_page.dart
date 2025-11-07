import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:marib/app/app_scroll_behavior.dart';
import 'package:marib/data/cubits/wallet/wallet_transactions_cubit.dart';
import 'package:marib/ui/screens/wallet/components/wallet_transactions_sliver.dart';
import 'package:marib/ui/screens/wallet/sections/wallet_filters_section.dart';
import 'package:marib/ui/screens/wallet/sections/wallet_summary_section.dart';
import 'package:marib/ui/screens/wallet/sections/wallet_withdrawals_section.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';

class WalletTransactionsPage extends StatefulWidget {
  const WalletTransactionsPage({
    super.key,
    required this.onRefresh,
    required this.formatAmount,
    required this.dateFormat,
  });

  final Future<void> Function() onRefresh;
  final String Function(double amount, String? currency) formatAmount;
  final DateFormat dateFormat;

  @override
  State<WalletTransactionsPage> createState() => _WalletTransactionsPageState();
}

class _WalletTransactionsPageState extends State<WalletTransactionsPage> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 180) {
      context.read<WalletTransactionsCubit>().loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: context.color.territoryColor,
      onRefresh: widget.onRefresh,
      child: CustomScrollView(
        controller: _scrollController,
        physics: AppScrollBehavior.defaultPhysics,
        slivers: [
          SliverToBoxAdapter(
            child: WalletSummarySection(
              formatAmount: widget.formatAmount,
            ),
          ),
          SliverToBoxAdapter(
            child: WalletWithdrawalsSection(
              formatAmount: widget.formatAmount,
              dateFormat: widget.dateFormat,
            ),
          ),
          const SliverToBoxAdapter(
            child: WalletFiltersSection(),
          ),
          BlocBuilder<WalletTransactionsCubit, WalletTransactionsState>(
            builder: (context, state) {
              return WalletTransactionsSliver(
                state: state,
                formatAmount: widget.formatAmount,
                dateFormat: widget.dateFormat,
                onRetry: () =>
                    context.read<WalletTransactionsCubit>().loadInitial(),
                onRefresh: () =>
                    context.read<WalletTransactionsCubit>().refresh(),
              );
            },
          ),
        ],
      ),
    );
  }
}
