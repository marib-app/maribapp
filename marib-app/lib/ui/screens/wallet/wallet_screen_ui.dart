import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:marib/data/cubits/wallet/wallet_transfers_cubit.dart';
import 'package:marib/data/cubits/wallet/wallet_withdrawals_cubit.dart';
import 'package:marib/data/cubits/wallet/wallet_summary_cubit.dart';
import 'package:marib/data/cubits/wallet/wallet_transactions_cubit.dart';
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
import 'package:marib/utils/currency_utils.dart';
import 'package:marib/data/model/wallet/wallet_summary.dart';
import 'package:marib/utils/payment/manual_payment_service.dart';
import 'package:marib/ui/screens/wallet/views/wallet_actions_page.dart';
import 'package:marib/ui/screens/wallet/views/wallet_transactions_page.dart';
import 'package:marib/utils/api.dart';

import 'package:marib/data/cubits/wallet/manual_payment_requests_cubit.dart';
import 'package:marib/utils/notification/notification_service.dart';
import 'package:marib/app/app_scroll_behavior.dart';

class WalletScreenUI extends StatefulWidget {
  const WalletScreenUI({super.key});

  @override
  State<WalletScreenUI> createState() => _WalletScreenUIState();
}

class _WalletScreenUIState extends State<WalletScreenUI> {
  final PageController _pageController = PageController();
  final NumberFormat _numberFormat =
      NumberFormat.currency(decimalDigits: 2, symbol: '');
  final DateFormat _dateTimeFormat = DateFormat('dd MMM yyyy, HH:mm');
  WalletNotificationRegistration? _walletScopeRegistration;
  bool _consumedInitialRouteArgs = false;

  @override
  void initState() {
    super.initState();
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
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_consumedInitialRouteArgs) {
      return;
    }

    final ModalRoute<Object?>? route = ModalRoute.of(context);
    final Object? rawArgs = route?.settings.arguments;

    if (rawArgs is Map) {
      final Map<String, dynamic> args =
          rawArgs.map((key, value) => MapEntry(key.toString(), value));
      final String? requestedTab =
          args['initial_tab']?.toString().toLowerCase();

      if (requestedTab == 'actions') {
        _pageController.jumpToPage(1);
      } else if (requestedTab == 'transactions') {
        _pageController.jumpToPage(0);
      }
    }

    _consumedInitialRouteArgs = true;
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
          WalletTransactionsPage(
            onRefresh: _onRefresh,
            formatAmount: _formatAmount,
            dateFormat: _dateTimeFormat,
          ),
          WalletActionsPage(
            onTopUp: () => _startTopUp(),
            onTransfer: _showTransferSheet,
            onWithdrawal: _showWithdrawalSheet,
          ),
        ],
      ),
    );
  }
}
