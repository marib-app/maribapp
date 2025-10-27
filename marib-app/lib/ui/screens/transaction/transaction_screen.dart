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
  const TransactionScreen({super.key, this.service});

  final ManualPaymentService? service;

  static Route<dynamic> route(RouteSettings routeSettings) {
    return BlurredRouter(
      builder: (_) => const TransactionScreen(),
    );
  }

  @override
  State<TransactionScreen> createState() => _TransactionScreenState();
}

class _TransactionScreenState extends State<TransactionScreen> {
  late final ManualPaymentsController _controller;
  final DateFormat _dateFormat = DateFormat('d MMM yyyy, h:mm a', 'ar');

  @override
  void initState() {
    super.initState();
    _controller = ManualPaymentsController(service: widget.service)
      ..addListener(_onControllerChanged);
    _controller.loadManualPayments();
  }

  void _onControllerChanged() {
    if (!mounted) return;
    setState(() {});
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