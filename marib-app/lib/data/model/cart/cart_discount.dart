import 'package:meta/meta.dart';

import 'package:marib/data/model/item/cart_model.dart';
import 'package:marib/utils/currency_utils.dart';




@immutable
class CartDiscount {
  const CartDiscount({
    this.code,
    this.status,
    this.label,
    this.message,
    this.amount,
    this.currency,
    this.details,
    this.raw,

  });

  factory CartDiscount.fromJson(Map<String, dynamic> json) {
    String? readString(dynamic value) {
      if (value == null) return null;
      if (value is String) {
        final String trimmed = value.trim();
        return trimmed.isEmpty ? null : trimmed;
      }
      return value.toString();
    }

    num? readNum(dynamic value) {
      if (value == null) return null;
      if (value is num) return value;
      if (value is String) {
        final String trimmed = value.trim();
        if (trimmed.isEmpty) return null;
        return num.tryParse(trimmed);
      }
      return null;
    }

    final Map<String, dynamic> data = Map<String, dynamic>.from(json);

    final Map<String, dynamic>? detailsMap = () {
      final dynamic detailsRaw = data['details'] ?? data['meta'];
      if (detailsRaw is Map<String, dynamic>) {
        return Map<String, dynamic>.from(detailsRaw);
      }
      if (detailsRaw is Map) {
        final Map<String, dynamic> converted = <String, dynamic>{};
        detailsRaw.forEach((dynamic key, dynamic value) {
          if (key == null) return;
          converted[key is String ? key : key.toString()] = value;
        });
        return converted;
      }
      return null;
    }();

    return CartDiscount(
      code: readString(data['code'] ?? data['coupon'] ?? data['coupon_code'] ?? data['id']),
      status: readString(data['status'] ?? data['state'] ?? data['result']),
      label: readString(
        data['label'] ??
            data['title'] ??
            data['name'] ??
            data['display'] ??
            data['heading'],
      ),
      message: readString(
        data['message'] ??
            data['description'] ??
            data['note'] ??
            data['status_message'] ??
            data['reason'],
      ),
      amount: readNum(
        data['amount'] ??
            data['value'] ??
            data['discount'] ??
            data['savings'] ??
            data['total'],
      ),
      currency: readString(data['currency']),
      details: detailsMap,
      raw: data,
    );
  }

  final String? code;
  final String? status;
  final String? label;
  final String? message;
  final num? amount;
  final String? currency;
  final Map<String, dynamic>? details;
  final Map<String, dynamic>? raw;

  String get normalizedStatus {
    final String? value = status ?? details?['status'];
    if (value == null) return '';
    return value.toString().trim().toLowerCase();
  }

  bool get isApplied {
    final String normalized = normalizedStatus;
    if (normalized.isEmpty) return false;
    return <String>{'applied', 'active', 'success', 'accepted', 'ok', 'valid'}
        .contains(normalized);
  }

  bool get isRejected {
    final String normalized = normalizedStatus;
    if (normalized.isEmpty) return false;
    return <String>{
      'rejected',
      'failed',
      'invalid',
      'error',
      'expired',
      'removed',
      'denied',
    }.contains(normalized);
  }

  bool get isPending {
    final String normalized = normalizedStatus;
    return normalized.isNotEmpty && !isApplied && !isRejected;
  }

  String get displayTitle {
    return label ?? code ?? 'القسيمة';
  }

  String get displayMessage {
    final String? messageCandidate =
        message ?? details?['message']?.toString() ?? raw?['message']?.toString();
    if (messageCandidate != null && messageCandidate.trim().isNotEmpty) {
      return messageCandidate.trim();
    }
    if (isApplied) {
      return 'تم تطبيق القسيمة بنجاح.';
    }
    if (isRejected) {
      return 'تعذر تطبيق القسيمة. يرجى التحقق من الصلاحية.';
    }
    if (isPending) {
      return 'تم إرسال القسيمة وهي قيد المراجعة.';
    }
    return 'تم تحديث حالة القسيمة.';
  }

  String? get amountDisplay {
    if (amount == null) return null;
    final String formatted = amount!.toStringAsFixed(2);
    final String? token = currency ?? details?['currency']?.toString();
    return token != null && token.trim().isNotEmpty
        ? '$formatted ${token.trim()}'
        : formatted;
  }
}

@immutable
class CartSummary {
  CartSummary({
    required List<Cart> items,
    List<CartDiscount> discounts = const <CartDiscount>[],
    Map<String, dynamic>? raw,
    Map<String, dynamic>? departmentPolicy,
    Map<String, dynamic>? support,
    Map<String, dynamic>? deliveryQuote,
    Map<String, dynamic>? blocking,
    List<dynamic>? deliveryPaymentOptions,
    String? deliveryPaymentTiming,
    String? currency,
    String? currencyCode,
    Map<String, dynamic>? store,
  })  : items = List<Cart>.unmodifiable(List<Cart>.from(items)),
        discounts =
        List<CartDiscount>.unmodifiable(List<CartDiscount>.from(discounts)),
        raw = raw == null
            ? null
            : Map<String, dynamic>.unmodifiable(Map<String, dynamic>.from(raw)),
        departmentPolicy = _normalizeMap(departmentPolicy),
        support = _normalizeMap(support),
        deliveryQuote = _normalizeMap(deliveryQuote),
        blocking = _normalizeMap(blocking),
        deliveryPaymentOptions = deliveryPaymentOptions == null
            ? null
            : List<dynamic>.unmodifiable(List<dynamic>.from(
          deliveryPaymentOptions,
        )),
        deliveryPaymentTiming = deliveryPaymentTiming,
        currency = _sanitize(currency),
        currencyCode = CurrencyUtils.normalizeCurrencyCode(
          currencyCode ?? currency,
        ),
        store = _normalizeMap(store);

  final List<Cart> items;
  final List<CartDiscount> discounts;
  final Map<String, dynamic>? raw;
  final Map<String, dynamic>? departmentPolicy;
  final Map<String, dynamic>? support;
  final Map<String, dynamic>? deliveryQuote;
  final Map<String, dynamic>? blocking;
  final List<dynamic>? deliveryPaymentOptions;
  final String? deliveryPaymentTiming;
  final String? currency;
  final String? currencyCode;
  final Map<String, dynamic>? store;
  double get subtotal =>
      items.fold(0, (double sum, Cart item) => sum + item.subtotalAmount);

  CartSummary copyWith({
    List<Cart>? items,
    List<CartDiscount>? discounts,
    Map<String, dynamic>? raw,
    Object? departmentPolicy = _sentinel,
    Object? support = _sentinel,
    Object? deliveryQuote = _sentinel,
    Object? blocking = _sentinel,
    Object? deliveryPaymentOptions = _sentinel,
    Object? deliveryPaymentTiming = _sentinel,
    Object? currency = _sentinel,
    Object? currencyCode = _sentinel,
    Object? store = _sentinel,
  }) {
    return CartSummary(
      items: items ?? this.items,
      discounts: discounts ?? this.discounts,
      raw: raw ?? this.raw,
      departmentPolicy: identical(departmentPolicy, _sentinel)
          ? this.departmentPolicy
          : departmentPolicy as Map<String, dynamic>?,
      support: identical(support, _sentinel)
          ? this.support
          : support as Map<String, dynamic>?,
      deliveryQuote: identical(deliveryQuote, _sentinel)
          ? this.deliveryQuote
          : deliveryQuote as Map<String, dynamic>?,
      blocking: identical(blocking, _sentinel)
          ? this.blocking
          : blocking as Map<String, dynamic>?,
      deliveryPaymentOptions:
      identical(deliveryPaymentOptions, _sentinel)
          ? this.deliveryPaymentOptions
          : deliveryPaymentOptions as List<dynamic>?,
      deliveryPaymentTiming:
      identical(deliveryPaymentTiming, _sentinel)
          ? this.deliveryPaymentTiming
          : deliveryPaymentTiming as String?,
      currency: identical(currency, _sentinel)
          ? this.currency
          : currency as String?,
      currencyCode: identical(currencyCode, _sentinel)
          ? this.currencyCode
          : currencyCode as String?,
      store: identical(store, _sentinel)
          ? this.store
          : store as Map<String, dynamic>?,
    );
  }
  static const Object _sentinel = Object();

  static Map<String, dynamic>? _normalizeMap(Map<String, dynamic>? source) {
    if (source == null || source.isEmpty) {
      return null;
    }
    return Map<String, dynamic>.unmodifiable(Map<String, dynamic>.from(source));
  }

  static String? _sanitize(String? value) {
    if (value == null) {
      return null;
    }
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

@immutable
class CartCheckoutDetails {
  const CartCheckoutDetails({
    this.departmentPolicy,
    this.support,
    this.deliveryQuote,
    this.blocking,
    this.deliveryPaymentOptions,
    this.deliveryPaymentTiming,
    this.departmentNotice,
  });

  final Map<String, dynamic>? departmentPolicy;
  final Map<String, dynamic>? support;
  final Map<String, dynamic>? deliveryQuote;
  final Map<String, dynamic>? blocking;
  final List<dynamic>? deliveryPaymentOptions;
  final String? deliveryPaymentTiming;
  final String? departmentNotice;

  CartCheckoutDetails copyWith({
    Map<String, dynamic>? departmentPolicy,
    Map<String, dynamic>? support,
    Map<String, dynamic>? deliveryQuote,
    Map<String, dynamic>? blocking,
    List<dynamic>? deliveryPaymentOptions,
    String? deliveryPaymentTiming,
    String? departmentNotice,
  }) {
    return CartCheckoutDetails(
      departmentPolicy: departmentPolicy ?? this.departmentPolicy,
      support: support ?? this.support,
      deliveryQuote: deliveryQuote ?? this.deliveryQuote,
      blocking: blocking ?? this.blocking,
      deliveryPaymentOptions:
      deliveryPaymentOptions ?? this.deliveryPaymentOptions,
      deliveryPaymentTiming:
      deliveryPaymentTiming ?? this.deliveryPaymentTiming,
      departmentNotice: departmentNotice ?? this.departmentNotice,
    );
  }

}
