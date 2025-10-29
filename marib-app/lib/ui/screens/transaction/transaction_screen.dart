import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'package:marib/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:marib/ui/screens/widgets/errors/no_data_found.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/payment/manual_payment.dart';
import 'package:marib/utils/payment/manual_payment_service.dart';
import 'package:marib/utils/ui_utils.dart';

import 'package:marib/ui/screens/transaction/manual_payment_details_screen.dart';
import 'package:marib/ui/screens/transaction/manual_payments_controller.dart';
import 'package:marib/ui/screens/transaction/widgets/manual_payment_summary_card.dart';
import 'package:marib/ui/screens/transaction/widgets/transaction_error_banner.dart';

enum _TransactionsFilter { all, orders, packages, services }

class TransactionScreen extends StatefulWidget {
  const TransactionScreen({super.key, this.service, this.focusTransactionId});

  final ManualPaymentService? service;
  final String? focusTransactionId;

  static Route<dynamic> route(RouteSettings routeSettings) {
    final Map<String, dynamic>? args =
        (routeSettings.arguments as Map?)?.cast<String, dynamic>();
    final String? focusId = args?['focus_transaction_id']?.toString();

    return BlurredRouter(
      builder: (_) => TransactionScreen(
        focusTransactionId: focusId,
      ),
      settings: routeSettings,
    );
  }

  @override
  State<TransactionScreen> createState() => _TransactionScreenState();
}

class _TransactionScreenState extends State<TransactionScreen> {
  late final ManualPaymentsController _controller;
  final DateFormat _dateFormat = DateFormat('d MMM yyyy, h:mm a', 'ar');
  String? _focusTransactionId;
  bool _focusHandled = false;
  _TransactionsFilter _selectedFilter = _TransactionsFilter.all;

  @override
  void initState() {
    super.initState();
    _focusTransactionId = widget.focusTransactionId;
    _controller = ManualPaymentsController(service: widget.service)
      ..addListener(_onControllerChanged);
    _controller.loadManualPayments();
  }

  void _onControllerChanged() {
    if (!mounted) return;
    setState(() {});
    _maybeShowFocusedTransaction();
  }

  @override
  void didUpdateWidget(covariant TransactionScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusTransactionId != oldWidget.focusTransactionId) {
      _focusTransactionId = widget.focusTransactionId;
      _focusHandled = false;
      _maybeShowFocusedTransaction();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  void _handleManualRefresh() {
    _controller.loadManualPayments();
  }

  Future<void> _onRefresh() {
    return _controller.loadManualPayments(showLoader: false);
  }

  void _maybeShowFocusedTransaction() {
    if (_focusHandled) {
      return;
    }

    final String? targetId = _focusTransactionId;
    if (targetId == null || targetId.isEmpty) {
      return;
    }

    final ManualPayment? payment = _findTransactionById(targetId);
    if (payment == null) {
      return;
    }

    _focusHandled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showTransactionDetails(payment);
    });
  }

  ManualPayment? _findTransactionById(String id) {
    for (final ManualPayment payment in _controller.transactions) {
      final String? transactionId = payment.paymentTransactionId;
      final String? manualPaymentId = payment.manualPaymentId;
      if (transactionId != null && transactionId.trim() == id.trim()) {
        return payment;
      }
      if (manualPaymentId != null && manualPaymentId.trim() == id.trim()) {
        return payment;
      }
    }
    return null;
  }

  Future<void> _showTransactionDetails(ManualPayment payment) {
    return ManualPaymentDetailsScreen.push(
      context,
      manualPayment: payment,
      dateFormat: _dateFormat,
      pollInterval: ManualPaymentsController.pollInterval,
    );
  }

  List<ManualPayment> _filteredTransactions(List<ManualPayment> transactions) {
    if (_selectedFilter == _TransactionsFilter.all) {
      return transactions
          .where((ManualPayment mp) => !_isServiceTransaction(mp))
          .toList();
    }

    return transactions
        .where((ManualPayment mp) => _matchesFilter(mp, _selectedFilter))
        .toList();
  }

  int _countForFilter(
      List<ManualPayment> transactions, _TransactionsFilter filter) {
    if (filter == _TransactionsFilter.all) {
      return transactions.where((mp) => !_isServiceTransaction(mp)).length;
    }
    return transactions.where((mp) => _matchesFilter(mp, filter)).length;
  }

  bool _matchesFilter(ManualPayment mp, _TransactionsFilter filter) {
    final _TransactionsFilter? category = _resolveCategory(mp);
    switch (filter) {
      case _TransactionsFilter.all:
        return true;
      case _TransactionsFilter.orders:
        return category == _TransactionsFilter.orders;
      case _TransactionsFilter.packages:
        return category == _TransactionsFilter.packages;
      case _TransactionsFilter.services:
        return category == _TransactionsFilter.services;
    }
  }

  _TransactionsFilter? _resolveCategory(ManualPayment mp) {
    final String lowerType = mp.payableType?.toLowerCase().trim() ?? '';

    if (mp.isServiceRequest || lowerType.contains('service')) {
      return _TransactionsFilter.services;
    }
    if (lowerType.contains('package') || lowerType.contains('subscription')) {
      return _TransactionsFilter.packages;
    }
    if (lowerType.contains('order')) {
      return _TransactionsFilter.orders;
    }

    return null;
  }

  bool _isServiceTransaction(ManualPayment mp) =>
      _resolveCategory(mp) == _TransactionsFilter.services;

  void _onFilterSelected(_TransactionsFilter filter) {
    if (_selectedFilter == filter) return;
    setState(() => _selectedFilter = filter);
  }

  Widget _buildFilterBar(
      BuildContext context, List<ManualPayment> transactions) {
    final colors = context.color;
    final options = <({String label, _TransactionsFilter filter})>[
      (label: 'الكل', filter: _TransactionsFilter.all),
      (label: 'الطلبات', filter: _TransactionsFilter.orders),
      (label: 'الباقات', filter: _TransactionsFilter.packages),
      (label: 'الخدمات', filter: _TransactionsFilter.services),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 6),
          child: Text('تصفية المعاملات')
              .bold(weight: FontWeight.w600)
              .size(context.font.small)
              .color(colors.onSurfaceVariant.withValues(alpha: 0.8)),
        ),
        SizedBox(
          height: 48,
          child: ListView.separated(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 0),
            scrollDirection: Axis.horizontal,
            itemCount: options.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (BuildContext context, int index) {
              final option = options[index];
              return _FilterChip(
                label: option.label,
                count: _countForFilter(transactions, option.filter),
                selected: _selectedFilter == option.filter,
                onTap: () => _onFilterSelected(option.filter),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<ManualPayment> allTransactions = _controller.transactions;
    final List<ManualPayment> filteredTransactions =
        _filteredTransactions(allTransactions);
    final bool hasTransactions = allTransactions.isNotEmpty;
    final bool hasFilteredResults = filteredTransactions.isNotEmpty;
    final bool loading = _controller.loading;
    final Object? error = _controller.error;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: UiUtils.getSystemUiOverlayStyle(
        context: context,
        statusBarColor: context.color.secondaryColor,
      ),
      child: Scaffold(
        backgroundColor: context.color.primaryColor,
        appBar: UiUtils.buildAppBar(
          context,
          title: 'transactionHistory'.translate(context),
          bottomHeight: 20,
        ),
        floatingActionButton: FloatingActionButton(
          heroTag: 'transactions_refresh_fab',
          onPressed: _controller.fetching ? null : _handleManualRefresh,
          child: _controller.fetching && allTransactions.isEmpty
              ? const CircularProgressIndicator.adaptive()
              : const Icon(Icons.refresh),
        ),
        body: RefreshIndicator(
          onRefresh: _onRefresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: <Widget>[
              if (hasTransactions)
                SliverToBoxAdapter(
                  child: _buildFilterBar(context, allTransactions),
                ),
              if (loading && !hasTransactions)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: UiUtils.progress()),
                )
              else if (error != null && !hasTransactions)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: TransactionErrorBanner(
                      onRetry: _handleManualRefresh,
                      includeRetry: true,
                    ),
                  ),
                )
              else if (!hasTransactions)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: NoDataFound(
                      onTap: _handleManualRefresh,
                      category: EmptyStateCategory.transactions,
                    ),
                  ),
                )
              else ...[
                if (error != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: TransactionErrorBanner(
                        onRetry: _handleManualRefresh,
                        includeRetry: true,
                      ),
                    ),
                  ),
                if (!hasFilteredResults)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Icon(
                            Icons.inbox_outlined,
                            size: 56,
                            color: context.color.onSurfaceVariant
                                .withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'لا توجد معاملات ضمن هذا التصنيف.',
                            textAlign: TextAlign.center,
                          ).size(context.font.normal).color(context
                              .color.onSurfaceVariant
                              .withValues(alpha: 0.8)),
                        ],
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 112),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (BuildContext context, int index) {
                          final manualPayment = filteredTransactions[index];
                          return Padding(
                            padding: EdgeInsetsDirectional.only(
                              bottom: index == filteredTransactions.length - 1
                                  ? 0
                                  : 12,
                            ),
                            child: ManualPaymentSummaryCard(
                              manualPayment: manualPayment,
                              dateFormat: _dateFormat,
                              onTap: () => ManualPaymentDetailsScreen.push(
                                context,
                                manualPayment: manualPayment,
                                dateFormat: _dateFormat,
                                pollInterval:
                                    ManualPaymentsController.pollInterval,
                              ),
                            ),
                          );
                        },
                        childCount: filteredTransactions.length,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.color;
    final bg = selected ? colors.territoryColor : colors.secondaryColor;
    final borderColor = selected ? colors.territoryColor : colors.borderColor;
    final textColor = selected ? colors.onPrimary : colors.onSurfaceVariant;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: selected ? 1.4 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(label)
                .bold(weight: FontWeight.w600)
                .size(context.font.small)
                .color(textColor),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: selected
                    ? colors.onPrimary.withValues(alpha: 0.18)
                    : colors.onSurfaceVariant.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text('$count')
                  .bold(weight: FontWeight.w600)
                  .size(12)
                  .color(selected ? colors.onPrimary : colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
