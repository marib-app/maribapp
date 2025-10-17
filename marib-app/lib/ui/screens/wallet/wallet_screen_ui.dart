import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'dart:typed_data';
import 'package:marib/data/cubits/wallet/wallet_transfers_cubit.dart';
import 'package:marib/data/cubits/wallet/wallet_withdrawals_cubit.dart';
import 'package:marib/data/cubits/wallet/wallet_summary_cubit.dart';
import 'package:marib/data/cubits/wallet/wallet_transactions_cubit.dart';
import 'package:marib/data/model/wallet/wallet_filter.dart';
import 'package:marib/data/model/wallet/wallet_operation_options.dart';
import 'package:marib/data/model/wallet/wallet_withdrawal.dart';
import 'package:marib/data/model/wallet/wallet_transaction.dart';
import 'package:marib/ui/screens/widgets/errors/no_data_found.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:marib/utils/hive_utils.dart';
import 'package:marib/utils/payment/bank_transfer_args.dart';
import 'package:marib/utils/payment/bank_transfer_screen.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:marib/ui/screens/wallet/wallet_transfer_sheet.dart';
import 'package:marib/ui/screens/wallet/wallet_withdrawal_sheet.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/ui/screens/wallet/wallet_manual_payments_section.dart';
import 'package:marib/utils/currency_utils.dart';
import 'package:marib/data/model/wallet/wallet_summary.dart';

class WalletScreenUI extends StatefulWidget {
  const WalletScreenUI({super.key});

  @override
  State<WalletScreenUI> createState() => _WalletScreenUIState();
}

class _WalletScreenUIState extends State<WalletScreenUI> {
  final PageController _pageController = PageController();

  final ScrollController _scrollController = ScrollController();
  final NumberFormat _numberFormat =
      NumberFormat.currency(decimalDigits: 2, symbol: '');
  final DateFormat _dateTimeFormat = DateFormat('dd MMM yyyy, HH:mm');

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _pageController.dispose();

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

  Future<void> _onRefresh() async {
    final summaryCubit = context.read<WalletSummaryCubit>();
    final transactionsCubit = context.read<WalletTransactionsCubit>();
    await Future.wait([
      summaryCubit.refresh(),
      transactionsCubit.refresh(),
    ]);
  }

  String _formatAmount(double amount, String? currency) {
    final formatted = _numberFormat.format(amount.abs());
    final withSign = amount >= 0 ? '+$formatted' : '-$formatted';
    final WalletSummary? summary = _activeSummary();
    String? display = currency?.trim();
    String? code;

    if (summary != null) {
      display =
          (display != null && display.isNotEmpty) ? display : summary.currency;
      code = summary.currencyCode ??
          CurrencyUtils.normalizeCurrencyCode(summary.currency);
    } else {
      code = CurrencyUtils.normalizeCurrencyCode(display);
    }

    final String? resolved = CurrencyUtils.displayToken(
      label: display,
      fallback: code,
      code: code,
    );

    return resolved == null || resolved.isEmpty
        ? withSign
        : '$withSign $resolved';
  }

  String? _summaryCurrency() {
    final WalletSummary? summary = _activeSummary();
    if (summary == null) {
      return null;
    }
    return CurrencyUtils.displayToken(
      label: summary.currency,
      fallback: summary.currencyCode,
      code: summary.currencyCode,
    );
  }

  String _localizedFilterLabel(
      BuildContext context, String value, String fallback) {
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

  WalletSummary? _activeSummary() {
    final state = context.read<WalletSummaryCubit>().state;
    if (state is WalletSummaryLoadSuccess) {
      return state.summary;
    }
    if (state is WalletSummaryLoading && state.previous != null) {
      return state.previous!.summary;
    }
    return null;
  }

  double? _currentBalance() {
    final state = context.read<WalletSummaryCubit>().state;
    if (state is WalletSummaryLoadSuccess) {
      return state.summary.balance;
    }
    if (state is WalletSummaryLoading && state.previous != null) {
      return state.previous!.summary.balance;
    }
    return null;
  }

  List<Map<String, dynamic>> _parseFieldList(dynamic raw) {
    if (raw is List) {
      return raw
          .whereType<dynamic>()
          .map((e) => e is Map<String, dynamic>
              ? e
              : Map<String, dynamic>.from(e as Map))
          .toList();
    }
    if (raw is Map<String, dynamic>) {
      if (raw.containsKey('fields')) {
        return _parseFieldList(raw['fields']);
      }
      return raw.values
          .whereType<dynamic>()
          .map((e) => e is Map<String, dynamic>
              ? e
              : Map<String, dynamic>.from(e as Map))
          .toList();
    }
    if (raw is Map) {
      return raw.values
          .whereType<dynamic>()
          .map((e) => e is Map<String, dynamic>
              ? e
              : Map<String, dynamic>.from(e as Map))
          .toList();
    }
    return const [];
  }

  WalletOperationOptions? _extractTransferOptions(
      WalletOperationOptions? base) {
    if (base == null) return null;

    WalletOperationOptions mergeOptions(WalletOperationOptions source) {
      final metadata = {...base.metadata};
      metadata.addAll(source.metadata);
      final raw = {...base.raw};
      raw['transfer'] = source.raw.isEmpty ? source.fields : source.raw;
      return base.copyWith(
        fields: source.fields.isNotEmpty ? source.fields : base.fields,
        amountFieldId: source.amountFieldId ?? base.amountFieldId,
        minimumAmount: source.minimumAmount ?? base.minimumAmount,
        maximumAmount: source.maximumAmount ?? base.maximumAmount,
        metadata: metadata,
        raw: raw,
      );
    }

    final candidates = [
      base.raw['transfer'],
      base.raw['transfer_fields'],
      base.raw['transfer_form'],
      base.raw['transfers'],
      base.metadata['transfer'],
      base.metadata['transfer_fields'],
      base.metadata['transfers'],
    ];

    for (final candidate in candidates) {
      if (candidate is WalletOperationOptions) {
        return mergeOptions(candidate);
      }
      if (candidate is Map<String, dynamic>) {
        final transferOptions = WalletOperationOptions.fromMap(candidate);
        return mergeOptions(transferOptions);
      }
      if (candidate is Map) {
        final map =
            candidate.map((key, value) => MapEntry(key.toString(), value));
        final transferOptions = WalletOperationOptions.fromMap(map);
        return mergeOptions(transferOptions);
      }
      final parsed = _parseFieldList(candidate);
      if (parsed.isNotEmpty) {
        return base.copyWith(fields: parsed);
      }
    }

    return base;
  }

  Future<void> _showWithdrawalSheet() async {
    final withdrawalsCubit = context.read<WalletWithdrawalsCubit>();

    WalletOperationOptions? options;
    final currentState = withdrawalsCubit.state;
    if (currentState is WalletWithdrawalsSuccess &&
        currentState.options != null) {
      options = currentState.options;
    } else {
      options = await withdrawalsCubit.loadOptions();
    }

    options ??= await withdrawalsCubit.loadOptions(force: true);

    if (!mounted) return;

    if (options == null || options.fields.isEmpty) {
      HelperUtils.showSnackBarMessage(
          context, 'تعذر تحميل نموذج السحب حالياً.');
      return;
    }
    final WalletOperationOptions sheetOptions = options;

    final result = await showModalBottomSheet<WalletWithdrawal>(
      context: context,
      isScrollControlled: true,
      builder: (_) => BlocProvider.value(
        value: withdrawalsCubit,
        child: WalletWithdrawalSheet(
          options: sheetOptions,
          balance: _currentBalance(),
          currency: _summaryCurrency(),
        ),
      ),
    );

    if (result != null && mounted) {
      await Future.wait([
        context.read<WalletSummaryCubit>().refresh(),
        context.read<WalletTransactionsCubit>().refresh(),
        withdrawalsCubit.refresh(),
      ]);
    }
  }

  Future<void> _showTransferSheet() async {
    final withdrawalsCubit = context.read<WalletWithdrawalsCubit>();

    WalletOperationOptions? baseOptions;
    final currentState = withdrawalsCubit.state;
    if (currentState is WalletWithdrawalsSuccess &&
        currentState.options != null) {
      baseOptions = currentState.options;
    } else {
      baseOptions = await withdrawalsCubit.loadOptions();
    }

    baseOptions ??= await withdrawalsCubit.loadOptions(force: true);

    if (!mounted) return;

    final transferOptions = _extractTransferOptions(baseOptions);
    if (transferOptions == null || transferOptions.fields.isEmpty) {
      HelperUtils.showSnackBarMessage(
          context, 'لا توجد حقول متاحة لعملية التحويل حالياً.');
      return;
    }

    final response = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => WalletTransferSheet(
        options: transferOptions,
        balance: _currentBalance(),
        currency: _summaryCurrency(),
      ),
    );

    if (response != null && mounted) {
      await Future.wait([
        context.read<WalletSummaryCubit>().refresh(),
        context.read<WalletTransactionsCubit>().refresh(),
        withdrawalsCubit.refresh(),
      ]);
      context.read<WalletTransfersCubit>().refresh();
    }
  }

  Future<void> _startTopUp({String gateway = 'manual_bank'}) async {
    if (!HiveUtils.isUserAuthenticated()) {
      UiUtils.checkUser(onNotGuest: () {}, context: context);
      return;
    }

    final amount = await _promptForAmount();
    if (amount == null) return;

    final token = HiveUtils.getJWT();
    if (token == null || token.isEmpty) {
      HelperUtils.showSnackBarMessage(context, 'loginFirst'.translate(context));
      return;
    }

    final args = BankTransferArgs(
      token: token,
      packageId: 0,
      amount: amount,
      currency: _summaryCurrency(),
      packageType: 'wallet_top_up',
      purpose: 'wallet',
      initialGateway: gateway,
    );

    if (!mounted) return;
    await BankTransferScreen.show(context, args);
  }

  Future<double?> _promptForAmount() async {
    final controller = TextEditingController();
    return showDialog<double>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('walletTopUpAmountTitle'.translate(context)),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'walletTopUpAmountLabel'.translate(context),
              hintText: 'walletTopUpAmountHint'.translate(context),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('cancelBtnLbl'.translate(context)),
            ),
            TextButton(
              onPressed: () {
                final value =
                    double.tryParse(controller.text.replaceAll(',', '.'));
                if (value == null || value <= 0) {
                  HelperUtils.showSnackBarMessage(
                    context,
                    'walletTopUpAmountInvalid'.translate(context),
                  );
                  return;
                }
                Navigator.of(context).pop(value);
              },
              child: Text('walletTopUpConfirm'.translate(context)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.color.backgroundColor,
      appBar: UiUtils.buildAppBar(
        context,
        title: 'walletTitle'.translate(context),
        showBackButton: true,
      ),
      body: PageView(
        controller: _pageController,
        physics: const BouncingScrollPhysics(),
        children: [
          _buildTransactionsPage(),
          _buildActionsPage(),
        ],
      ),
    );
  }

  Widget _buildTransactionsPage() {
    return RefreshIndicator(
      color: context.color.territoryColor,
      onRefresh: _onRefresh,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          SliverToBoxAdapter(child: _buildSummarySection()),
          SliverToBoxAdapter(child: _buildWithdrawalsSection()),
          SliverToBoxAdapter(child: _buildFiltersSection()),
          BlocBuilder<WalletTransactionsCubit, WalletTransactionsState>(
            builder: (context, state) {
              return SliverList(
                delegate: SliverChildListDelegate(
                  _buildTransactionsContent(state),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWithdrawalsSection() {
    return BlocBuilder<WalletWithdrawalsCubit, WalletWithdrawalsState>(
      builder: (context, state) {
        if (state is WalletWithdrawalsLoading) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (state is WalletWithdrawalsFailure) {
          return _WithdrawalsErrorCard(
            message: state.error.toString(),
            onRetry: () => context
                .read<WalletWithdrawalsCubit>()
                .loadInitial(includeOptions: true),
          );
        }

        if (state is WalletWithdrawalsSuccess) {
          return _WithdrawalsCard(
            withdrawals: state.withdrawals,
            formatAmount: _formatAmount,
            dateFormat: _dateTimeFormat,
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

  Widget _buildActionsPage() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          16,
          24,
          16,
          24 + MediaQuery.of(context).padding.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'walletTopUpHeader'.translate(context),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            _buildActionButtonsCard(),
            const SizedBox(height: 24),
            WalletManualPaymentsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildSummarySection() {
    return BlocBuilder<WalletSummaryCubit, WalletSummaryState>(
      builder: (context, state) {
        if (state is WalletSummaryLoading && state.previous != null) {
          return _SummaryCard(
            balanceText: _formatAmount(state.previous!.summary.balance,
                state.previous!.summary.currency),
            lastUpdated: state.previous!.summary.lastUpdatedAt,
            isLoading: true,
          );
        }
        if (state is WalletSummaryLoadSuccess) {
          return _SummaryCard(
            balanceText:
                _formatAmount(state.summary.balance, state.summary.currency),
            lastUpdated: state.summary.lastUpdatedAt,
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
        return const _SummaryCard(isLoading: true);
      },
    );
  }

  Widget _buildFiltersSection() {
    return BlocBuilder<WalletTransactionsCubit, WalletTransactionsState>(
      builder: (context, state) {
        List<WalletFilter> filters = const [];
        String? activeFilter;
        if (state is WalletTransactionsSuccess) {
          filters = state.availableFilters;
          activeFilter = state.appliedFilter;
        }
        if (filters.isEmpty) {
          return const SizedBox.shrink();
        }

        return SizedBox(
          height: 64,
          child: ListView(
            padding: const EdgeInsetsDirectional.only(
                start: 16, end: 16, top: 12, bottom: 12),
            scrollDirection: Axis.horizontal,
            children: [
              _FilterChip(
                label: 'walletFilterAll'.translate(context),
                selected: activeFilter == null || activeFilter == 'all',
                onSelected: (_) =>
                    context.read<WalletTransactionsCubit>().clearFilters(),
              ),
              const SizedBox(width: 8),
              ...filters.map(
                (filter) => Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: _FilterChip(
                    label: _localizedFilterLabel(
                        context, filter.value, filter.label),
                    selected: activeFilter == filter.value,
                    onSelected: (_) => context
                        .read<WalletTransactionsCubit>()
                        .applyFilter(filter.value),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionButtonsCard() {
    final borderColor = context.color.borderColor.withOpacity(0.2);
    final backgroundColor = context.color.secondaryColor;

    return Card(
      color: backgroundColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTopUpSection(),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _showTransferSheet,
              icon: const Icon(Icons.swap_horiz),
              label: Text('walletTransferAction'.translate(context)),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _showWithdrawalSheet,
              icon: const Icon(Icons.arrow_circle_down_outlined),
              label: Text('walletWithdrawalAction'.translate(context)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopUpSection() {
    return _WalletPrimaryButton(
      title: 'walletTopUpAction'.translate(context),
      icon: Icons.account_balance_wallet_outlined,
      onPressed: () {
        _startTopUp();
      },
    );
  }

  List<Widget> _buildTransactionsContent(WalletTransactionsState state) {
    if (state is WalletTransactionsLoading) {
      return [
        Padding(
          padding: const EdgeInsets.only(top: 120),
          child: Center(child: UiUtils.progress()),
        ),
      ];
    }

    if (state is WalletTransactionsFailure) {
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
              Text(state.error.toString()),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () =>
                    context.read<WalletTransactionsCubit>().loadInitial(),
                child: Text('retry'.translate(context)),
              ),
            ],
          ),
        ),
      ];
    }

    if (state is WalletTransactionsSuccess) {
      if (state.transactions.isEmpty) {
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
                  onPressed: () =>
                      context.read<WalletTransactionsCubit>().refresh(),
                  child: Text('retry'.translate(context)),
                ),
              ],
            ),
          ),
        ];
      }

      final tiles = <Widget>[];
      for (final tx in state.transactions) {
        tiles.add(_TransactionTile(
          transaction: tx,
          formatAmount: _formatAmount,
          dateFormat: _dateTimeFormat,
        ));
      }

      if (state.isLoadingMore) {
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

class _WithdrawalsCard extends StatelessWidget {
  const _WithdrawalsCard({
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
                    _WithdrawalTile(
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
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
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

class _WithdrawalTile extends StatelessWidget {
  const _WithdrawalTile({
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

class _WithdrawalsErrorCard extends StatelessWidget {
  const _WithdrawalsErrorCard({
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

class _WalletPrimaryButton extends StatelessWidget {
  const _WalletPrimaryButton({
    required this.title,
    required this.onPressed,
    this.icon,
  });

  final String title;
  final VoidCallback onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = context.color.territoryColor;
    final onBackground = theme.colorScheme.onPrimary;

    final textStyle = theme.textTheme.titleMedium?.copyWith(
          color: onBackground,
          fontWeight: FontWeight.w700,
        ) ??
        TextStyle(
          color: onBackground,
          fontWeight: FontWeight.w700,
          fontSize: theme.textTheme.titleMedium?.fontSize ?? 16,
        );

    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        elevation: 0,
        minimumSize: const Size.fromHeight(52),
        backgroundColor: background,
        foregroundColor: onBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ).merge(
        ButtonStyle(
          overlayColor: WidgetStatePropertyAll(onBackground.withOpacity(0.12)),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textStyle,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    this.balanceText,
    this.lastUpdated,
    this.isLoading = false,
  });

  final String? balanceText;
  final DateTime? lastUpdated;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onPrimary = theme.colorScheme.onPrimary;
    final accent = context.color.territoryColor;
    final secondaryAccent = context.color.forthColor.withOpacity(0.9);
    final captionColor = onPrimary.withOpacity(0.75);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [accent, secondaryAccent],
            begin: AlignmentDirectional.centerStart,
            end: AlignmentDirectional.centerEnd,
          ),
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: secondaryAccent.withOpacity(0.28),
              blurRadius: 32,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              top: -30,
              right: -18,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              bottom: -44,
              left: -12,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Icon(
                          Icons.account_balance_wallet_outlined,
                          size: 24,
                          color: onPrimary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'walletBalance'.translate(context),
                          style: theme.textTheme.titleMedium?.copyWith(
                                color: onPrimary,
                                fontWeight: FontWeight.w600,
                              ) ??
                              TextStyle(
                                color: onPrimary,
                                fontSize:
                                    theme.textTheme.titleMedium?.fontSize ?? 18,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (isLoading)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        minHeight: 10,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  else
                    Text(
                      balanceText ?? '--',
                      style: theme.textTheme.displaySmall?.copyWith(
                            color: onPrimary,
                            fontWeight: FontWeight.w800,
                          ) ??
                          TextStyle(
                            color: onPrimary,
                            fontSize:
                                theme.textTheme.displaySmall?.fontSize ?? 36,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Icon(Icons.schedule_rounded,
                          size: 18, color: captionColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          lastUpdated == null
                              ? 'walletLastUpdatedUnknown'.translate(context)
                              : UiUtils.formatDate(
                                  lastUpdated!.toIso8601String()),
                          style: theme.textTheme.bodySmall?.copyWith(
                                color: captionColor,
                                fontWeight: FontWeight.w500,
                              ) ??
                              TextStyle(
                                color: captionColor,
                                fontSize:
                                    theme.textTheme.bodySmall?.fontSize ?? 12,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
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

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({
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
                const SizedBox(width: 12),
                Text(
                  amountText,
                  textAlign: TextAlign.end,
                  style: theme.textTheme.titleMedium?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w800,
                      ) ??
                      TextStyle(
                        color: accent,
                        fontSize: theme.textTheme.titleMedium?.fontSize ?? 18,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _TransactionInfoRow(
              icon: Icons.schedule_rounded,
              label: timestamp,
            ),
            if (statusLabel != null) ...[
              const SizedBox(height: 8),
              _TransactionInfoRow(
                icon: Icons.verified_outlined,
                label: statusLabel,
                labelStyle: theme.textTheme.bodySmall?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (referenceValues.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'مراجع العملية',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: referenceValues
                    .map((value) => _buildTag(context, value, accent))
                    .toList(),
              ),
            ],
            if (transaction.beforeBalance != null ||
                transaction.afterBalance != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  if (transaction.beforeBalance != null)
                    Expanded(
                      child: _BalanceSummary(
                        label: 'الرصيد قبل العملية',
                        value: _formatBalanceValue(transaction.beforeBalance!),
                      ),
                    ),
                  if (transaction.beforeBalance != null &&
                      transaction.afterBalance != null)
                    const SizedBox(width: 12),
                  if (transaction.afterBalance != null)
                    Expanded(
                      child: _BalanceSummary(
                        label: 'الرصيد بعد العملية',
                        value: _formatBalanceValue(transaction.afterBalance!),
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

class _TransactionInfoRow extends StatelessWidget {
  const _TransactionInfoRow({
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

class _BalanceSummary extends StatelessWidget {
  const _BalanceSummary({required this.label, required this.value});

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
