import 'package:marib/data/model/orders/order_payment.dart';
import 'package:marib/utils/api.dart';
import 'package:marib/utils/payment/manual_payment_service.dart';
import 'package:meta/meta.dart';

class OrderPaymentsRepository {
  const OrderPaymentsRepository();

  Future<OrderPaymentIntentResult> initiatePayment({
    required String orderId,
    String? paymentMethod,
    double? amount,
    String? currency,
    Map<String, dynamic>? extraData,
  }) async {
    final String? normalizedCurrency =
        currency != null && currency.trim().isNotEmpty
            ? currency.trim().toUpperCase()
            : null;

    final String? sanitizedMethod = paymentMethod?.trim();
    final String? normalizedMethod =
        ManualPaymentService.paymentMethodForApiOrNull(sanitizedMethod) ??
            sanitizedMethod;
    final bool requestingOptionsOnly =
        normalizedMethod == null || normalizedMethod.isEmpty;

    final Map<String, dynamic> body = <String, dynamic>{
      'purpose': 'order',
      'order_id': orderId,
      'payable_type': 'order',
      'payable_id': _tryParseInt(orderId) ?? orderId,
      if (!requestingOptionsOnly) 'payment_method': normalizedMethod,
      if (normalizedCurrency != null) 'currency': normalizedCurrency,
      if (amount != null)
        'amount': _formatAmount(
          amount,
          currency: normalizedCurrency,
        ),
      if (extraData != null) ...extraData,
    };

    final Map<String, dynamic> response = await Api.postJson(
      url: Api.paymentsInitiateApi,
      data: body,
      extraHeaders: {
        'Idempotency-Key': Api.generateIdempotencyKey(),
      },
    );

    final OrderPaymentIntentResult parsed = parseOrderPaymentIntent(response);

    if (requestingOptionsOnly && parsed.availableMethods.isEmpty) {
      final List<OrderPaymentMethod> fallback =
          _fallbackMethodsFromResponse(parsed, response);
      if (fallback.isNotEmpty) {
        return parsed.copyWith(availableMethods: fallback);
      }
    }

    return parsed;
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
    final String? normalizedCurrency =
        currency != null && currency.trim().isNotEmpty
            ? currency.trim().toUpperCase()
            : null;

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
      if (transactionId != null &&
          transactionId.trim().isNotEmpty) ...<String, dynamic>{
        'transaction_id': transactionId.trim(),
        'payment_transaction_id': transactionId.trim(),
      },
      if (reference != null &&
          reference.trim().isNotEmpty) ...<String, dynamic>{
        'reference': reference.trim(),
        'gateway_reference': reference.trim(),
        'payment_reference': reference.trim(),
        'transaction_reference': reference.trim(),
      },
      if (normalizedCurrency != null) 'currency': normalizedCurrency,
      if (amount != null)
        'amount': _formatAmount(
          amount,
          currency: normalizedCurrency,
        ),
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

  @visibleForTesting
  String formatAmountForTesting(
    double amount, {
    String? currency,
  }) {
    return _formatAmount(
      amount,
      currency: currency,
    );
  }

  String _formatAmount(
    double amount, {
    String? currency,
  }) {
    final String? normalizedCurrency =
        currency != null && currency.trim().isNotEmpty ? currency : null;

    if (normalizedCurrency == null) {
      return amount.toStringAsFixed(2);
    }

    return ManualPaymentService.formatManualPaymentAmount(
      amount,
      normalizedCurrency,
    );
  }

  List<OrderPaymentMethod> _fallbackMethodsFromResponse(
    OrderPaymentIntentResult result,
    Map<String, dynamic> response,
  ) {
    final dynamic allowed = result.raw['allowed_payment_methods'] ??
        response['allowed_payment_methods'] ??
        result.raw['payment_method_tokens'] ??
        response['payment_method_tokens'];

    final Iterable<dynamic> tokens = _iterable(allowed);
    if (tokens.isEmpty) {
      return const <OrderPaymentMethod>[];
    }

    final String? defaultToken = _stringify(
      result.raw['preferred_payment_method'] ??
          result.raw['default_payment_method'] ??
          response['preferred_payment_method'] ??
          response['default_payment_method'],
    );

    final String? normalizedDefault = defaultToken == null
        ? null
        : ManualPaymentService.paymentMethodForApiOrNull(defaultToken) ??
            defaultToken.trim();

    final Set<String> seen = <String>{};
    final List<OrderPaymentMethod> methods = <OrderPaymentMethod>[];

    for (final dynamic token in tokens) {
      final String? resolvedToken = _resolveTokenIdentifier(token);
      if (resolvedToken == null) {
        continue;
      }

      final String? canonicalCandidate =
          ManualPaymentService.paymentMethodForApiOrNull(resolvedToken) ??
              resolvedToken;
      final String? canonical =
          canonicalCandidate != null ? canonicalCandidate.trim() : null;
      if (canonical == null || canonical.isEmpty || !seen.add(canonical)) {
        continue;
      }

      final bool isDefault = normalizedDefault != null &&
          normalizedDefault.toLowerCase() == canonical.toLowerCase();
      final String label = _labelForPaymentMethod(canonical);
      final String? gateway = _gatewayForPaymentMethod(canonical);

      methods.add(
        OrderPaymentMethod(
          id: canonical,
          label: label,
          gateway: gateway,
          isDefault: isDefault,
          isManual: canonical.contains('manual') || canonical.contains('bank'),
          raw: <String, dynamic>{
            'id': canonical,
            'label': label,
            if (gateway != null) 'gateway': gateway,
            'is_default': isDefault,
            'tokens': <String>{
              canonical,
              resolvedToken,
            }
                .where((String value) => value.trim().isNotEmpty)
                .map((String value) => value.trim())
                .toList(),
          },
        ),
      );
    }

    if (methods.isEmpty && normalizedDefault != null) {
      final String normalized = normalizedDefault.trim();
      if (normalized.isNotEmpty) {
        final String label = _labelForPaymentMethod(normalized);
        final String? gateway = _gatewayForPaymentMethod(normalized);
        methods.add(
          OrderPaymentMethod(
            id: normalized,
            label: label,
            gateway: gateway,
            isDefault: true,
            isManual:
                normalized.contains('manual') || normalized.contains('bank'),
            raw: <String, dynamic>{
              'id': normalized,
              'label': label,
              if (gateway != null) 'gateway': gateway,
              'is_default': true,
              'tokens': <String>[normalized],
            },
          ),
        );
      }
    }

    return methods;
  }

  Iterable<dynamic> _iterable(dynamic value) {
    if (value == null) {
      return const <dynamic>[];
    }
    if (value is Iterable) {
      return value;
    }
    if (value is Map) {
      return value.values;
    }
    return <dynamic>[value];
  }

  String? _stringify(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is String) {
      final String trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    final String converted = value.toString().trim();
    return converted.isEmpty ? null : converted;
  }

  String? _resolveTokenIdentifier(dynamic token) {
    if (token == null) {
      return null;
    }
    if (token is String) {
      return token.trim().isEmpty ? null : token.trim();
    }
    if (token is Map<String, dynamic>) {
      return _stringify(
        token['id'] ??
            token['payment_method'] ??
            token['method'] ??
            token['gateway'],
      );
    }
    if (token is Map) {
      final Map<String, dynamic> map = Map<String, dynamic>.from(token);
      return _stringify(
        map['id'] ?? map['payment_method'] ?? map['method'] ?? map['gateway'],
      );
    }
    return _stringify(token);
  }

  String _labelForPaymentMethod(String method) {
    const Map<String, String> labels = <String, String>{
      'manual_bank': 'الدفع عبر التحويل البنكي اليدوي',
      'east_yemen_bank': 'الدفع عبر بنك الشرق اليمني',
      'wallet': 'الدفع عبر المحفظة',
      'cash': 'الدفع عند الاستلام',
    };

    if (labels.containsKey(method)) {
      return labels[method]!;
    }

    final String sanitized = method.replaceAll(RegExp(r'[_-]+'), ' ').trim();
    if (sanitized.isEmpty) {
      return method.toUpperCase();
    }

    return sanitized
        .split(' ')
        .where((String part) => part.isNotEmpty)
        .map((String part) => part.length == 1
            ? part.toUpperCase()
            : '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  String? _gatewayForPaymentMethod(String method) {
    const Map<String, String> gateways = <String, String>{
      'manual_bank': 'التحويل البنكي اليدوي',
      'east_yemen_bank': 'بنك الشرق اليمني',
      'wallet': 'المحفظة',
      'cash': 'الدفع عند الاستلام',
    };

    return gateways[method];
  }
}
