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
import 'package:marib/utils/payment/manual_payment_service.dart';
import 'package:marib/ui/screens/wallet/components/wallet_summary_card.dart';
import 'package:marib/ui/screens/wallet/components/wallet_withdrawals_cards.dart';
import 'package:marib/ui/screens/wallet/components/wallet_filters_list.dart';
import 'package:marib/ui/screens/wallet/components/wallet_transactions_sliver.dart';
import 'package:marib/ui/screens/wallet/components/wallet_actions_card.dart';
import 'package:marib/utils/api.dart';

import 'package:marib/data/cubits/wallet/manual_payment_requests_cubit.dart';
import 'package:marib/utils/notification/notification_service.dart';


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
  WalletNotificationRegistration? _walletScopeRegistration;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _walletScopeRegistration = NotificationService.registerWalletScope(
        summaryCubit: context.read<WalletSummaryCubit>(),
        transactionsCubit: context.read<WalletTransactionsCubit>(),
        withdrawalsCubit: context.read<WalletWithdrawalsCubit>(),
        manualPaymentsCubit: context.read<ManualPaymentRequestsCubit>(),
        transfersCubit: context.read<WalletTransfersCubit>(),
      );
    });


  }

  @override
  void dispose() {
    _walletScopeRegistration?.dispose();

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
    if (transferOptions == null) {

      HelperUtils.showSnackBarMessage(
          context, 'لا تتوفر إعدادات صالحة لعملية التحويل حالياً.');
      return;
    }


    final WalletOperationOptions resolvedOptions;
    final String? existingClientTag = transferOptions.clientTag?.trim();
    if (existingClientTag == null || existingClientTag.isEmpty) {
      resolvedOptions = transferOptions.copyWith(
        clientTag: Api.generateIdempotencyKey(),
      );
    } else {
      resolvedOptions = transferOptions;
    }



    final response = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => WalletTransferSheet(
        options: resolvedOptions,
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
      purpose: ManualPaymentService.walletTopUpPurpose,
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
        physics: AppScrollBehavior.defaultPhysics,
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
        physics: AppScrollBehavior.defaultPhysics,
        slivers: [
          SliverToBoxAdapter(child: _buildSummarySection()),
          SliverToBoxAdapter(child: _buildWithdrawalsSection()),
          SliverToBoxAdapter(child: _buildFiltersSection()),
          BlocBuilder<WalletTransactionsCubit, WalletTransactionsState>(
            builder: (context, state) {
              return WalletTransactionsSliver(
                state: state,
                formatAmount: _formatAmount,
                dateFormat: _dateTimeFormat,
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
          return WalletSummaryCard(
            balanceText: _formatAmount(state.previous!.summary.balance,
                state.previous!.summary.currency),
            lastUpdated: state.previous!.summary.lastUpdatedAt,
            isLoading: true,
          );
        }
        if (state is WalletSummaryLoadSuccess) {
          return WalletSummaryCard(

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
        return const WalletSummaryCard(isLoading: true);
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
        return WalletFiltersList(
          filters: filters,
          activeFilter: activeFilter,
          onClear: () =>
              context.read<WalletTransactionsCubit>().clearFilters(),
          onFilterSelected: (value) =>
              context.read<WalletTransactionsCubit>().applyFilter(value),
        );
      },
    );
  }

  Widget _buildActionButtonsCard() {
    return WalletActionsCard(
      onTopUp: _startTopUp,
      onTransfer: _showTransferSheet,
      onWithdrawal: _showWithdrawalSheet,
    );
  }
}
