import 'package:meta/meta.dart';
import 'package:marib/data/model/orders/user_order.dart';

@immutable
class OrderSubmissionResult {
  const OrderSubmissionResult({
    this.orderId,
    this.orderCode,
    Map<String, dynamic>? order,
    this.details,
    required this.raw,
  }) : _order = order;

  final String? orderId;
  final String? orderCode;
  final Map<String, dynamic>? _order;
  final OrderDetails? details;
  final Map<String, dynamic> raw;

  Map<String, dynamic>? get order =>
      _order ?? details?.order.raw ?? details?.raw;

  OrderPolicy? get policy => details?.policy;
  OrderSupport? get support => details?.support;
  Map<String, dynamic>? get paymentSummary =>
      details?.paymentSummary ?? details?.order.paymentSummary;
  Map<String, dynamic>? get deliveryPaymentSummary =>
      details?.deliveryPaymentSummary ?? details?.order.deliveryPaymentSummary;
  Map<String, dynamic>? get depositReceipts => details?.depositReceipts;
  Map<String, dynamic>? get paymentIntent => details?.order.paymentIntent;

  String? get primaryIdentifier {
    final List<String?> identifiers = <String?>[
      orderCode,
      orderId,
      details?.order.code,
      details?.order.id,
    ];

    for (final String? candidate in identifiers) {
      final String? trimmed = candidate?.trim();
      if (trimmed != null && trimmed.isNotEmpty) {
        return trimmed;
      }
    }

    return null;
  }
}
