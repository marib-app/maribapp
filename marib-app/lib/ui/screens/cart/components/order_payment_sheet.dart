import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:marib/data/cubits/orders/order_payment_cubit.dart';
import 'package:marib/data/model/orders/order_payment.dart';
import 'package:marib/utils/payment/gatways/payment_webview.dart';
import 'package:marib/utils/helper_utils.dart';



class OrderPaymentSheet extends StatefulWidget {
  const OrderPaymentSheet({
    super.key,
    required this.orderId,
    required this.outstandingAmount,
    this.outstandingLabel,
    this.currency,
    this.orderLabel,
  });

  final String orderId;
  final double outstandingAmount;
  final String? outstandingLabel;
  final String? currency;
  final String? orderLabel;

  @override
  State<OrderPaymentSheet> createState() => _OrderPaymentSheetState();
}

class _OrderPaymentSheetState extends State<OrderPaymentSheet> {
  bool _webViewOpen = false;

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  void _loadOptions() {
    context.read<OrderPaymentCubit>().loadOptions(
      orderId: widget.orderId,
      amount: widget.outstandingAmount,
      currency: widget.currency,
    );
  }

  String get _formattedAmount {
    if (widget.outstandingLabel != null && widget.outstandingLabel!.trim().isNotEmpty) {
      return widget.outstandingLabel!.trim();
    }
    final NumberFormat formatter = NumberFormat.currency(
      symbol: widget.currency != null && widget.currency!.trim().isNotEmpty
          ? widget.currency!.trim().toUpperCase()
          : '',
      decimalDigits: 2,
    );
    return formatter.format(widget.outstandingAmount).trim();
  }

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.only(bottom: bottomInset),
        child: BlocConsumer<OrderPaymentCubit, OrderPaymentState>(
          listener: (BuildContext context, OrderPaymentState state) async {
            if (state.status == OrderPaymentStatus.success) {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop(true);
              }
              return;
            }

            if (state.status == OrderPaymentStatus.failure &&
                state.errorMessage != null &&
                state.errorMessage!.isNotEmpty) {
              HelperUtils.showSnackBarMessage(
                context,
                state.errorMessage!,
              );
            }

            if (state.status == OrderPaymentStatus.actionRequired) {
              final OrderPaymentAction? action = state.action;
              if (action == null || _webViewOpen) {
                return;
              }

              _webViewOpen = true;
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => PaymentWebView(
                    authorizationUrl: action.authorizationUrl,
                    reference: action.reference,
                    onSuccess: (String reference) {
                      context
                          .read<OrderPaymentCubit>()
                          .confirmPayment(reference: reference);
                    },
                    onFailed: (String reference) {
                      context
                          .read<OrderPaymentCubit>()
                          .reportGatewayFailure('فشل الدفع عبر البوابة.');
                    },
                    onCancel: () {
                      context.read<OrderPaymentCubit>().cancelAction();
                    },
                  ),
                ),
              );
              _webViewOpen = false;
            }
          },
          builder: (BuildContext context, OrderPaymentState state) {
            final List<OrderPaymentMethod> methods = state.methods;
            final OrderPaymentMethod? selectedMethod = state.selectedMethod;
            final bool isBusy = state.isBusy || state.status == OrderPaymentStatus.actionRequired;


            final OrderPaymentMethod? effectiveSelectedMethod = selectedMethod ?? () {
              if (methods.isEmpty) {
                return null;
              }
              try {
                return methods.firstWhere((OrderPaymentMethod method) => method.isDefault);
              } catch (_) {
                return methods.first;
              }
            }();


            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade400,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    Text(
                      'تسديد المبلغ المتبقي',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.orderLabel != null && widget.orderLabel!.trim().isNotEmpty
                          ? 'الطلب: ${widget.orderLabel!.trim()}'
                          : 'رقم الطلب: ${widget.orderId}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Text(
                            'المبلغ المستحق',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _formattedAmount,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (state.status == OrderPaymentStatus.loading && methods.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (methods.isEmpty)
                      _buildEmptyState(context, state)
                    else
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          ...methods.map(
                                (OrderPaymentMethod method) => RadioListTile<OrderPaymentMethod>(
                              value: method,
                                  groupValue: effectiveSelectedMethod,
                                  onChanged: isBusy
                                  ? null
                                  : (OrderPaymentMethod? value) {
                                if (value != null) {
                                  context.read<OrderPaymentCubit>().selectMethod(value);
                                }
                              },
                              title: Text(method.label),
                              subtitle: method.gateway != null && method.gateway!.trim().isNotEmpty
                                  ? Text(method.gateway!)
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: isBusy
                                  ? null
                                  : () => context.read<OrderPaymentCubit>().submitPayment(),
                              child: isBusy
                                  ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                                  : const Text('متابعة الدفع'),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 12),
                    if (state.errorMessage != null && state.errorMessage!.isNotEmpty && methods.isNotEmpty)
                      Text(
                        state.errorMessage!,
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, OrderPaymentState state) {
    final bool canRetry = state.status == OrderPaymentStatus.failure;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text('لا توجد وسائل دفع متاحة حاليًا.'),
        ),
        if (canRetry)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: state.isBusy ? null : _loadOptions,
              child: const Text('إعادة المحاولة'),
            ),
          ),
      ],
    );
  }
}