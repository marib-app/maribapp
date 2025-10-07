import 'package:marib/data/model/orders/order_payment.dart';
import 'package:marib/utils/api.dart';

class OrderPaymentsRepository {
  const OrderPaymentsRepository();

  Future<OrderPaymentIntentResult> initiatePayment({
    required String orderId,
    String? paymentMethod,
    double? amount,
    String? currency,
    Map<String, dynamic>? extraData,
  }) async {
    final Map<String, dynamic> body = <String, dynamic>{
      'purpose': 'order',
      'order_id': orderId,
      'payable_type': 'order',
      'payable_id': _tryParseInt(orderId) ?? orderId,
      if (paymentMethod != null && paymentMethod.trim().isNotEmpty)
        'payment_method': paymentMethod.trim(),
      if (currency != null && currency.trim().isNotEmpty)
        'currency': currency.trim().toUpperCase(),
      if (amount != null) 'amount': _formatAmount(amount),
      if (extraData != null) ...extraData,
    };

    final Map<String, dynamic> response = await Api.postJson(
      url: Api.paymentsInitiateApi,
      data: body,
      extraHeaders: {
        'Idempotency-Key': Api.generateIdempotencyKey(),
      },
    );

    return parseOrderPaymentIntent(response);
  }

  Future<OrderPaymentIntentResult> confirmPayment({
    required String orderId,
    required String paymentMethod,
    String? intentId,
    String? transactionId,
    String? reference,
    double? amount,
    String? currency,
    Map<String, dynamic>? additionalData,
  }) async {
    final Map<String, dynamic> body = <String, dynamic>{
      'purpose': 'order',
      'order_id': orderId,
      'payable_type': 'order',
      'payable_id': _tryParseInt(orderId) ?? orderId,
      'payment_method': paymentMethod,
      if (intentId != null && intentId.trim().isNotEmpty) ...<String, dynamic>{
        'intent_id': intentId.trim(),
        'payment_intent_id': intentId.trim(),
      },
      if (transactionId != null && transactionId.trim().isNotEmpty) ...<String, dynamic>{
        'transaction_id': transactionId.trim(),
        'payment_transaction_id': transactionId.trim(),
      },
      if (reference != null && reference.trim().isNotEmpty) ...<String, dynamic>{
        'reference': reference.trim(),
        'gateway_reference': reference.trim(),
        'payment_reference': reference.trim(),
        'transaction_reference': reference.trim(),
      },
      if (currency != null && currency.trim().isNotEmpty)
        'currency': currency.trim().toUpperCase(),
      if (amount != null) 'amount': _formatAmount(amount),
      if (additionalData != null) ...additionalData,
    };

    final Map<String, dynamic> response = await Api.postJson(
      url: Api.paymentsConfirmApi,
      data: body,
      extraHeaders: {
        'Idempotency-Key': Api.generateIdempotencyKey(),
      },
    );

    return parseOrderPaymentIntent(response);
  }

  int? _tryParseInt(String value) {
    return int.tryParse(value.trim());
  }

  String _formatAmount(double amount) {
    return amount.toStringAsFixed(2);
  }
}