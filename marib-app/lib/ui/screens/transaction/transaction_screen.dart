import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'package:marib/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/payment/manual_payment.dart';
import 'package:marib/utils/payment/manual_payment_service.dart';
import 'package:marib/utils/ui_utils.dart';

import 'manual_payments_controller.dart';
import 'widgets/manual_payment_tile.dart';
import 'widgets/transaction_body.dart';

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

  Future<void> _showTransactionDetails(ManualPayment payment) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      builder: (BuildContext sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: ManualPaymentTile(
              manualPayment: payment,
              dateFormat: _dateFormat,
              pollInterval: ManualPaymentsController.pollInterval,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<ManualPayment> transactions = _controller.transactions;

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
          onPressed: _controller.fetching ? null : _handleManualRefresh,
          child: _controller.fetching && transactions.isEmpty
              ? const CircularProgressIndicator.adaptive()
              : const Icon(Icons.refresh),
        ),
        body: RefreshIndicator(
          onRefresh: _onRefresh,
          child: TransactionBody(
            loading: _controller.loading,
            error: _controller.error,
            transactions: transactions,
            onRetry: _handleManualRefresh,
            manualPaymentBuilder: (context, manualPayment) => ManualPaymentTile(
              manualPayment: manualPayment,
              dateFormat: _dateFormat,
              pollInterval: ManualPaymentsController.pollInterval,
            ),
          ),
        ),
      ),
    );
  }
}
