import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:marib/data/cubits/wallet/manual_payment_requests_cubit.dart';
import 'package:marib/data/cubits/wallet/wallet_summary_cubit.dart';
import 'package:marib/data/cubits/wallet/wallet_transactions_cubit.dart';
import 'package:marib/data/cubits/wallet/wallet_transfers_cubit.dart';
import 'package:marib/data/cubits/wallet/wallet_withdrawals_cubit.dart';
import 'package:marib/data/model/wallet/wallet_filter.dart';
import 'package:marib/data/model/wallet/wallet_operation_options.dart';
import 'package:marib/data/model/wallet/wallet_recipient.dart';
import 'package:marib/data/model/wallet/wallet_summary.dart';
import 'package:marib/data/model/wallet/wallet_transaction.dart';
import 'package:marib/data/model/wallet/wallet_withdrawal.dart';
import 'package:marib/ui/screens/wallet/wallet_withdrawal_sheet.dart';
import 'package:marib/ui/screens/widgets/blurred_dialoge_box.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/api.dart';
import 'package:marib/utils/currency_utils.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:marib/utils/hive_utils.dart';
import 'package:marib/utils/notification/notification_service.dart';
import 'package:marib/utils/payment/bank_transfer_args.dart';
import 'package:marib/utils/payment/bank_transfer_screen.dart';
import 'package:marib/utils/payment/manual_payment_service.dart';
import 'package:marib/utils/ui_utils.dart';

class WalletScreenUI extends StatefulWidget {
  const WalletScreenUI({super.key});

  @override
  State<WalletScreenUI> createState() => _WalletScreenUIState();
}

class _WalletScreenUIState extends State<WalletScreenUI> {
  final ScrollController _scrollController = ScrollController();
  final NumberFormat _numberFormat =
      NumberFormat.currency(symbol: '', decimalDigits: 2);
  final DateFormat _dateFormat = DateFormat('dd MMM yyyy, HH:mm');
  WalletNotificationRegistration? _walletScopeRegistration;
  bool _mountedScope = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleLoadMore);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_mountedScope || !mounted) return;
      _walletScopeRegistration = NotificationService.registerWalletScope(
        summaryCubit: context.read<WalletSummaryCubit>(),
        transactionsCubit: context.read<WalletTransactionsCubit>(),
        withdrawalsCubit: context.read<WalletWithdrawalsCubit>(),
        manualPaymentsCubit: context.read<ManualPaymentRequestsCubit>(),
        transfersCubit: context.read<WalletTransfersCubit>(),
      );
      _mountedScope = true;
    });
  }

  @override
  void dispose() {
    _walletScopeRegistration?.dispose();
    _scrollController.removeListener(_handleLoadMore);
    _scrollController.dispose();
    super.dispose();
  }

  void _handleLoadMore() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 160) {
      context.read<WalletTransactionsCubit>().loadMore();
    }
  }

  Future<void> _onRefresh() async {
    await Future.wait([
      context.read<WalletSummaryCubit>().refresh(),
      context.read<WalletTransactionsCubit>().refresh(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.color;
    return Scaffold(
      backgroundColor: colors.backgroundColor,
      appBar: UiUtils.buildAppBar(
        context,
        title: 'walletTitle'.translate(context),
        showBackButton: true,
      ),
      body: RefreshIndicator(
        color: colors.territoryColor,
        onRefresh: _onRefresh,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSummaryCard(context),
                    const SizedBox(height: 16),
                    _buildQuickActions(context),
                    const SizedBox(height: 16),
                    _buildFilterSection(context),
                  ],
                ),
              ),
            ),
            _buildTransactionsSliver(context),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context) {
    final colors = context.color;
    return BlocBuilder<WalletSummaryCubit, WalletSummaryState>(
      builder: (context, state) {
        if (state is WalletSummaryFailure) {
          return _buildErrorCard(
            context,
            message: 'walletSummaryError'.translate(context),
            onRetry: () => context.read<WalletSummaryCubit>().fetchSummary(
                  forceReload: true,
                ),
          );
        }

        WalletSummary? summary;
        bool isLoading = false;

        if (state is WalletSummaryLoadSuccess) {
          summary = state.summary;
        } else if (state is WalletSummaryLoading && state.previous != null) {
          summary = state.previous!.summary;
          isLoading = true;
        }

        if (summary == null) {
          return _buildSkeletonCard(colors);
        }

        final balanceLabel = _formatAmount(summary.balance, summary.currency);
        final lastUpdated = summary.lastUpdatedAt != null
            ? _dateFormat.format(summary.lastUpdatedAt!.toLocal())
            : 'walletLastUpdatedUnknown'.translate(context);
        final filterCount = summary.availableFilters.length;

        return AnimatedOpacity(
          opacity: isLoading ? 0.6 : 1,
          duration: const Duration(milliseconds: 250),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colors.secondaryColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colors.borderColor.withOpacity(0.1)),
              boxShadow: [
                BoxShadow(
                  color: colors.textDefaultColor.withOpacity(0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('walletBalance'.translate(context))
                    .size(context.font.normal)
                    .color(colors.textLightColor),
                const SizedBox(height: 8),
                Text(balanceLabel)
                    .size(context.font.extraLarge)
                    .bold()
                    .color(colors.textDefaultColor),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 16,
                      color: colors.textLightColor.withOpacity(0.7),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(lastUpdated)
                          .size(context.font.smaller)
                          .color(colors.textLightColor),
                    ),
                    if (filterCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colors.territoryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'walletFilterAll'.translate(context),
                          style: TextStyle(
                            color: colors.territoryColor,
                            fontSize: context.font.smaller,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final colors = context.color;
    final actions = [
      _WalletAction(
        icon: Icons.account_balance_wallet_outlined,
        label: 'walletTopUpAction'.translate(context),
        onTap: () => _startTopUp(),
      ),
      _WalletAction(
        icon: Icons.sync_alt,
        label: 'walletTransferAction'.translate(context),
        onTap: () => _showTransferSheet(),
      ),
      _WalletAction(
        icon: Icons.outbond_outlined,
        label: 'walletWithdrawalAction'.translate(context),
        onTap: () => _showWithdrawalSheet(),
      ),
    ];

    return Material(
      color: Colors.transparent,
      child: Row(
        children: actions
            .map(
              (action) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: action.onTap,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: colors.secondaryColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: colors.borderColor.withOpacity(0.12),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(action.icon,
                              color: colors.territoryColor, size: 20),
                          const SizedBox(height: 8),
                          Text(
                            action.label,
                            textAlign: TextAlign.center,
                          )
                              .size(context.font.smaller)
                              .color(colors.textDefaultColor)
                              .bold(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildFilterSection(BuildContext context) {
    final colors = context.color;
    return BlocBuilder<WalletTransactionsCubit, WalletTransactionsState>(
      builder: (context, state) {
        if (state is! WalletTransactionsSuccess ||
            state.availableFilters.isEmpty) {
          return const SizedBox.shrink();
        }
        final filters = state.availableFilters;
        final applied = state.appliedFilter;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('walletTopUpHeader'.translate(context))
                .size(context.font.small)
                .color(colors.textLightColor),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    label: Text('walletFilterAll'.translate(context)),
                    selected: applied == null || applied.isEmpty,
                    onSelected: (_) =>
                        context.read<WalletTransactionsCubit>().clearFilters(),
                  ),
                  ...filters.map(
                    (filter) => Padding(
                      padding: const EdgeInsetsDirectional.only(start: 8),
                      child: ChoiceChip(
                        label: Text(filter.label),
                        selected: applied == filter.value,
                        onSelected: (_) => context
                            .read<WalletTransactionsCubit>()
                            .applyFilter(filter.value),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTransactionsSliver(BuildContext context) {
    return BlocBuilder<WalletTransactionsCubit, WalletTransactionsState>(
      builder: (context, state) {
        if (state is WalletTransactionsLoading ||
            state is WalletTransactionsInitial) {
          return _buildLoadingSliver(context);
        }
        if (state is WalletTransactionsFailure) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: _buildErrorCard(
                context,
                message: 'walletTransactionsError'.translate(context),
                onRetry: () =>
                    context.read<WalletTransactionsCubit>().loadInitial(),
              ),
            ),
          );
        }
        if (state is WalletTransactionsSuccess &&
            state.transactions.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: _buildEmptyState(context),
            ),
          );
        }
        if (state is WalletTransactionsSuccess) {
          final transactions = state.transactions;
          final hasLoader = state.isLoadingMore;
          final childCount = transactions.length + (hasLoader ? 1 : 0);
          return SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (index >= transactions.length) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: context.color.territoryColor,
                          ),
                        ),
                      ),
                    );
                  }
                  final tx = transactions[index];
                  return _buildTransactionTile(context, tx);
                },
                childCount: childCount,
              ),
            ),
          );
        }
        return const SliverToBoxAdapter(child: SizedBox.shrink());
      },
    );
  }

  Widget _buildTransactionTile(BuildContext context, WalletTransaction tx) {
    final colors = context.color;
    final amountLabel = _formatAmount(tx.amount, tx.currency);
    final dateLabel = tx.createdAt != null
        ? _dateFormat.format(tx.createdAt!.toLocal())
        : 'walletUnknownDate'.translate(context);
    final title = _resolveTransactionTitle(context, tx);
    final subtitle = tx.description?.trim().isNotEmpty == true
        ? tx.description!.trim()
        : tx.references.isNotEmpty
            ? tx.references.first
            : tx.referenceCode ?? '';
    final accent =
        tx.isCredit ? Colors.greenAccent.shade400 : Colors.redAccent.shade200;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: tx.deeplink?.isNotEmpty == true
            ? () => UiUtils.launchURL(tx.deeplink!)
            : null,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.secondaryColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: tx.highlighted
                  ? colors.territoryColor.withOpacity(0.4)
                  : colors.borderColor.withOpacity(0.12),
            ),
            boxShadow: [
              BoxShadow(
                color: colors.textDefaultColor.withOpacity(0.03),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 6,
                height: 54,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title)
                        .bold()
                        .size(context.font.normal)
                        .color(colors.textDefaultColor),
                    const SizedBox(height: 4),
                    if (subtitle.isNotEmpty)
                      Text(subtitle)
                          .size(context.font.smaller)
                          .color(colors.textLightColor),
                    const SizedBox(height: 8),
                    Text(dateLabel)
                        .size(context.font.smaller)
                        .color(colors.textLightColor.withOpacity(0.8)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(amountLabel)
                      .bold()
                      .size(context.font.normal)
                      .color(accent),
                  if (tx.afterBalance != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'walletBalanceAfter'.translate(context) +
                            '\n${_formatAmount(tx.afterBalance!, tx.currency)}',
                        textAlign: TextAlign.end,
                      )
                          .size(context.font.smaller)
                          .color(colors.textLightColor),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSkeletonCard(ColorScheme colors) {
    return Container(
      height: 150,
      decoration: BoxDecoration(
        color: colors.secondaryColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.borderColor.withOpacity(0.12)),
      ),
      child: const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }

  Widget _buildErrorCard(
    BuildContext context, {
    required String message,
    required VoidCallback onRetry,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.color.secondaryColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.color.borderColor.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message)
              .bold()
              .size(context.font.normal)
              .color(context.color.textDefaultColor),
          const SizedBox(height: 12),
          UiUtils.buildButton(
            context,
            onPressed: onRetry,
            buttonTitle: 'retry'.translate(context),
            height: 42,
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingSliver(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (index >= 3) return null;
            return Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              height: 90,
              decoration: BoxDecoration(
                color: context.color.secondaryColor,
                borderRadius: BorderRadius.circular(16),
              ),
            );
          },
          childCount: 3,
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colors = context.color;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.account_balance_wallet_outlined,
            size: 40, color: colors.textLightColor),
        const SizedBox(height: 12),
        Text('walletEmptyState'.translate(context))
            .bold()
            .size(context.font.normal)
            .color(colors.textDefaultColor),
        const SizedBox(height: 8),
        Text(
          'walletEmptyDescription'.translate(context),
          textAlign: TextAlign.center,
        ).size(context.font.smaller).color(colors.textLightColor),
      ],
    );
  }

  WalletSummary? _activeSummary() {
    final state = context.read<WalletSummaryCubit>().state;
    if (state is WalletSummaryLoadSuccess) return state.summary;
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

  String? _summaryCurrency() {
    final summary = _activeSummary();
    if (summary == null) return null;
    return summary.currency?.trim().isNotEmpty == true
        ? summary.currency
        : summary.currencyCode;
  }

  String _formatAmount(double amount, String? currency) {
    final formatted = _numberFormat.format(amount.abs());
    final symbol = currency?.trim().isNotEmpty == true
        ? currency!.trim()
        : _summaryCurrency() ?? '';
    final decorated = symbol.isEmpty ? formatted : '$formatted $symbol';
    return amount >= 0 ? '+$decorated' : '-$decorated';
  }

  String _resolveTransactionTitle(BuildContext context, WalletTransaction tx) {
    final description = tx.description?.trim();
    if (description != null && description.isNotEmpty) {
      return description;
    }
    final category = (tx.category ?? tx.classification ?? '')
        .trim()
        .toLowerCase();
    switch (category) {
      case 'deposit':
      case 'topup':
        return 'walletCategoryDeposit'.translate(context);
      case 'transfer':
        return 'walletCategoryTransfer'.translate(context);
      case 'purchase':
      case 'payment':
        return 'walletCategoryPurchase'.translate(context);
      case 'refund':
        return 'walletCategoryRefund'.translate(context);
      default:
        return 'walletUnknownClassification'.translate(context);
    }
  }

  Future<void> _showTransferSheet() async {
    if (!HiveUtils.isUserAuthenticated()) {
      UiUtils.checkUser(onNotGuest: () {}, context: context);
      return;
    }

    final summary = _activeSummary();
    final transfersCubit = context.read<WalletTransfersCubit>();
    final result =
        await _presentTransferBottomSheet(summary, transfersCubit);
    if (result == null || !mounted) {
      return;
    }

    final double amount = result['amount'] as double;
    final String phone = result['phone'] as String;

    await Future.wait([
      context.read<WalletSummaryCubit>().refresh(),
      context.read<WalletTransactionsCubit>().refresh(),
    ]);
    context.read<WalletTransfersCubit>().refresh();

    final remainingBalance = _currentBalance();
    HelperUtils.showSnackBarMessage(
      context,
      'تم خصم ${_formatAmount(amount, _summaryCurrency())} وإرساله إلى $phone',
    );
    if (remainingBalance != null) {
      HelperUtils.showSnackBarMessage(
        context,
        'رصيدك المتبقي الآن ${_formatAmount(remainingBalance, _summaryCurrency())}',
      );
    }
  }

  Future<void> _showWithdrawalSheet() async {
    final withdrawalsCubit = context.read<WalletWithdrawalsCubit>();
    final summary = _activeSummary();
    final options = _resolveWithdrawalOptions(summary);

    final response = await showModalBottomSheet<WalletWithdrawal?>(
      context: context,
      isScrollControlled: true,
      builder: (_) => WalletWithdrawalSheet(
        options: options,
        balance: _currentBalance(),
        currency: _summaryCurrency(),
      ),
    );

    if (response != null) {
      await Future.wait([
        context.read<WalletSummaryCubit>().refresh(),
        context.read<WalletTransactionsCubit>().refresh(),
      ]);
      withdrawalsCubit.refresh();
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
    if (token.isEmpty) {
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

  WalletOperationOptions _resolveTransferOptions(WalletSummary? summary) {
    return _resolveOperationOptions(
      summary,
      hints: const [
        'transfer_options',
        'transferOption',
        'transfer',
      ],
    );
  }

  WalletOperationOptions _resolveWithdrawalOptions(WalletSummary? summary) {
    return _resolveOperationOptions(
      summary,
      hints: const [
        'withdrawal_options',
        'withdrawalOption',
        'withdrawal',
        'payout',
      ],
    );
  }

  WalletOperationOptions _resolveOperationOptions(
    WalletSummary? summary, {
    required List<String> hints,
  }) {
    final raw = summary?.raw;
    if (raw != null && raw.isNotEmpty) {
      final map = _findOptionsMap(raw, hints.map((e) => e.toLowerCase()).toList());
      if (map != null && map.isNotEmpty) {
        return WalletOperationOptions.fromMap(map);
      }
    }

    return WalletOperationOptions(
      balance: summary?.balance,
      currency: summary?.currencyCode ?? summary?.currency,
      raw: summary?.raw ?? const {},
    );
  }

  Map<String, dynamic>? _findOptionsMap(
    dynamic source,
    List<String> hints,
  ) {
    if (source is Map<String, dynamic>) {
      for (final entry in source.entries) {
        final keyLower = entry.key.toLowerCase();
        final value = entry.value;
        if (value is Map) {
          if (_matchKey(keyLower, hints) && _looksLikeOptionsMap(value)) {
            return _normalizeMap(value);
          }
          final nested = _findOptionsMap(value, hints);
          if (nested != null) return nested;
        } else if (value is List) {
          final nested = _findOptionsMap(value, hints);
          if (nested != null) return nested;
        }
      }
    } else if (source is Map) {
      return _findOptionsMap(_normalizeMap(source), hints);
    } else if (source is List) {
      for (final item in source) {
        final nested = _findOptionsMap(item, hints);
        if (nested != null) return nested;
      }
    }
    return null;
  }

  bool _matchKey(String key, List<String> hints) {
    return hints.any((hint) => key.contains(hint));
  }

  bool _looksLikeOptionsMap(Map<dynamic, dynamic> value) {
    if (value.isEmpty) return false;
    const indicators = {
      'fields',
      'inputs',
      'form',
      'schema',
      'options',
      'metadata',
      'meta',
      'config',
      'settings',
    };
    for (final key in value.keys) {
      final keyLower = key.toString().toLowerCase();
      if (indicators.any(keyLower.contains)) {
        return true;
      }
    }
    return true;
  }

  Map<String, dynamic> _normalizeMap(Map<dynamic, dynamic> value) {
    return value.map((key, val) => MapEntry(key.toString(), val));
  }

  Future<Map<String, dynamic>?> _presentTransferBottomSheet(
    WalletSummary? summary,
    WalletTransfersCubit transfersCubit,
  ) async {
    final options = _resolveTransferOptions(summary);
    final double availableBalance = _currentBalance() ?? 0;

    final amountController = TextEditingController();
    final phoneController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    double enteredAmount = 0;
    bool isSubmitting = false;

    double? parseAmount(String? value) {
      if (value == null) return null;
      final normalized =
          value.replaceAll(RegExp(r'[^0-9.,-]'), '').replaceAll(',', '.');
      return double.tryParse(normalized);
    }

    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final colors = context.color;
        final theme = Theme.of(context);
        final Color warningColor = theme.colorScheme.error;
        final Color successColor = Colors.green;
        return SafeArea(
          child: StatefulBuilder(
            builder: (context, setModalState) {
              final double remainingBalance = availableBalance - enteredAmount;
              final bool exceedsBalance = remainingBalance < 0;
              final EdgeInsets viewInsets =
                  MediaQuery.of(sheetContext).viewInsets;

              return AnimatedPadding(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.only(bottom: viewInsets.bottom),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: colors.secondaryColor,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(32),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: colors.textDefaultColor.withOpacity(0.14),
                            blurRadius: 28,
                            offset: const Offset(0, -8),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(22, 20, 22, 26),
                        child: Form(
                          key: formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Center(
                                child: Container(
                                  width: 48,
                          height: 4,
                          decoration: BoxDecoration(
                            color: colors.borderColor.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text('الرصيد المتاح')
                          .size(context.font.smaller)
                          .color(colors.textLightColor),
                      const SizedBox(height: 4),
                      Text(
                        _formatAmount(availableBalance, _summaryCurrency()),
                      )
                          .bold()
                          .size(context.font.extraLarge)
                          .color(colors.textDefaultColor),
                      const SizedBox(height: 18),
                      TextFormField(
                        controller: amountController,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                        ],
                        decoration: InputDecoration(
                          labelText: 'المبلغ المراد تحويله',
                          suffixText: _summaryCurrency(),
                        ),
                        onChanged: (value) {
                          setModalState(() {
                            enteredAmount = parseAmount(value) ?? 0;
                          });
                        },
                        validator: (value) {
                          final amount = parseAmount(value);
                          if (amount == null || amount <= 0) {
                            return 'يرجى إدخال مبلغ صالح';
                          }
                          if (options.minimumAmount != null &&
                              amount < options.minimumAmount!) {
                            return 'الحد الأدنى للتحويل هو ${options.minimumAmount}';
                          }
                          if (options.maximumAmount != null &&
                              amount > options.maximumAmount!) {
                            return 'الحد الأعلى للتحويل هو ${options.maximumAmount}';
                          }
                          if (amount > availableBalance) {
                            return 'المبلغ يتجاوز الرصيد المتاح';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            exceedsBalance
                                ? Icons.warning_amber_rounded
                                : Icons.check_circle,
                            color:
                                exceedsBalance ? warningColor : successColor,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text(
                                exceedsBalance
                                    ? 'المبلغ يتجاوز الرصيد المتاح'
                                    : 'الرصيد بعد التحويل: ${_formatAmount(remainingBalance, _summaryCurrency())}',
                              )
                                  .size(context.font.smaller)
                                  .color(exceedsBalance
                                      ? warningColor
                                      : colors.textLightColor),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      TextFormField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[0-9+ ]'),
                          ),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'رقم هاتف المستفيد',
                          hintText: '77XXXXXXX',
                        ),
                        validator: (value) {
                          final trimmed = value
                                  ?.replaceAll(RegExp(r'[^0-9+]'), '')
                                  .trim() ??
                              '';
                          if (trimmed.isEmpty) {
                            return 'يرجى إدخال رقم الهاتف';
                          }
                          if (trimmed.length < 6) {
                            return 'رقم الهاتف غير مكتمل';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'سنتحقق من صحة الرقم قبل تنفيذ التحويل.',
                      )
                          .size(context.font.smaller)
                          .color(colors.textLightColor),
                      const SizedBox(height: 20),
                      UiUtils.buildButton(
                        context,
                        onPressed: () async {
                          if (isSubmitting) {
                            return;
                          }
                          FocusScope.of(sheetContext).unfocus();
                          if (!formKey.currentState!.validate()) {
                            return;
                          }
                          final double amount =
                              parseAmount(amountController.text.trim()) ?? 0;
                          final String phone = phoneController.text.trim();
                          final String normalizedPhone =
                              phone.replaceAll(RegExp(r'[^0-9+]'), '');

                          setModalState(() {
                            isSubmitting = true;
                          });

                          WalletRecipient recipient;
                          try {
                            recipient = await transfersCubit
                                .fetchRecipientByMobile(normalizedPhone);
                          } catch (error) {
                            if (!mounted) return;
                            HelperUtils.showSnackBarMessage(
                              context,
                              error.toString(),
                            );
                            setModalState(() {
                              isSubmitting = false;
                            });
                            return;
                          }

                          final bool confirmed =
                              await _showTransferConfirmationDialog(
                            amount: amount,
                            phone: phone,
                          );

                          if (!confirmed) {
                            if (!mounted) return;
                            setModalState(() {
                              isSubmitting = false;
                            });
                            return;
                          }

                          final payload = <String, dynamic>{
                            'recipient_id': recipient.id,
                            'amount': amount,
                            'client_tag': Api.generateIdempotencyKey(),
                            'recipient_mobile': normalizedPhone,
                          };

                          try {
                            final response =
                                await transfersCubit.submitTransfer(payload);
                            if (!mounted) return;
                            Navigator.of(sheetContext).pop(
                              {
                                'amount': amount,
                                'phone': phone,
                                'response': response,
                              },
                            );
                            final message = response['message']?.toString() ??
                                'تم إرسال التحويل بنجاح';
                            HelperUtils.showSnackBarMessage(
                              context,
                              message,
                            );
                          } catch (error) {
                            if (!mounted) return;
                            HelperUtils.showSnackBarMessage(
                              context,
                              error.toString(),
                            );
                            setModalState(() {
                              isSubmitting = false;
                            });
                          }
                        },
                        buttonTitle: 'تحويل',
                        titleWhenProgress: 'جاري التحويل...',
                        isInProgress: isSubmitting,
                        showProgressTitle: true,
                        height: 48,
                        radius: 12,
                        ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<bool> _showTransferConfirmationDialog({
    required double amount,
    required String phone,
  }) async {
    final String formattedAmount = _formatAmount(amount, _summaryCurrency());
    final bool? confirmed = await UiUtils.showBlurredDialoge(
      context,
      dialoge: BlurredDialogBox(
        title: 'تأكيد التحويل',
        content: Text(
          'هل أنت متأكد من تحويل $formattedAmount إلى مالك الرقم "$phone"؟\n\n'
          'لا يمكن التراجع عن هذه العملية بعد التأكيد.',
        )
            .size(context.font.normal)
            .color(context.color.textDefaultColor),
        acceptButtonName: 'تأكيد التحويل',
        cancelButtonName: 'إلغاء',
        onAccept: () async {},
        onCancel: () {},
        barrierDismissable: false,
      ),
    );

    return confirmed == true;
  }
}

class _WalletAction {
  const _WalletAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}
