import 'dart:convert';

import 'package:marib/data/model/item/cart_model.dart';
import 'package:marib/utils/api.dart';
import 'package:marib/utils/delivery_department.dart';
import 'package:marib/data/services/cart_shipping_quote_service.dart';
import 'package:marib/data/model/cart/cart_discount.dart';

/// Environment overrides (comma-separated lists allowed).
const String _cartGetEndpointOverride =
String.fromEnvironment('CART_GET_ENDPOINTS');
const String _cartAddEndpointOverride =
String.fromEnvironment('CART_ADD_ENDPOINTS');
const String _cartUpdateEndpointOverride =
String.fromEnvironment('CART_UPDATE_ENDPOINTS');
const String _cartRemoveEndpointOverride =
String.fromEnvironment('CART_REMOVE_ENDPOINTS');
const String _cartClearEndpointOverride =
String.fromEnvironment('CART_CLEAR_ENDPOINTS');
const String _cartApplyCouponEndpointOverride =
String.fromEnvironment('CART_APPLY_COUPON_ENDPOINTS');
const String _cartRemoveCouponEndpointOverride =
String.fromEnvironment('CART_REMOVE_COUPON_ENDPOINTS');

const String _cartDeliveryTimingEndpointOverride =
String.fromEnvironment('CART_DELIVERY_PAYMENT_TIMING_ENDPOINTS');

const String _cartCheckoutInfoEndpointOverride =
String.fromEnvironment('CART_CHECKOUT_INFO_ENDPOINTS');

/// Endpoint candidates in priority order. First working one wins.
final List<String> _cartFetchEndpointCandidates = _buildCartEndpointCandidates(
  override: _cartGetEndpointOverride,
  defaults: <String>[
    // Known constants (if defined inside Api)
    Api.getCartApi,
    // Fallbacks
    'cart',
    'cart/items',
    'cart/list',
  ],
);

final List<String> _cartAddEndpointCandidates = _buildCartEndpointCandidates(
  override: _cartAddEndpointOverride,
  defaults: <String>[
    Api.addToCartApi,
    'cart',
    // Preferred
    'cart/items',
    // Aliases
    'cart/add',
    'add-to-cart',
    'cart/items/add',
    'cart/add-item',
    'cart/store',
    'cart/items/store',
  ],
);

final List<String> _cartUpdateEndpointCandidates =
_buildCartEndpointCandidates(
  override: _cartUpdateEndpointOverride,
  defaults: <String>[
    // Many backends accept re-posting to the add endpoint to update quantity
    'cart/items',
    // Optional alternate routes
    'cart/update',
    'cart/items/update',
    'cart/update-quantity',
  ],
);

final List<String> _cartRemoveEndpointCandidates =
_buildCartEndpointCandidates(
  override: _cartRemoveEndpointOverride,
  defaults: <String>[
    Api.removeCartItemApi,
    'cart/remove',
    'cart/remove-item',
    'cart/destroy',
    'cart/items/remove',
    'cart/items/delete',
    'cart/items/destroy',
  ],
);

final List<String> _cartClearEndpointCandidates = _buildCartEndpointCandidates(
  override: _cartClearEndpointOverride,
  defaults: <String>[
    Api.clearCartApi,
    'cart/clear',
    'cart/empty',
    'cart/items/clear',
    'cart/items/empty',
  ],
);

final List<String> _cartApplyCouponEndpointCandidates =
_buildCartEndpointCandidates(
  override: _cartApplyCouponEndpointOverride,
  defaults: <String>[
    'api/cart/coupon',
    'cart/coupon',
    'api/cart/apply-coupon',
    'cart/apply-coupon',
    'cart/coupons/apply',
    'cart/apply-coupon-code',
  ],
);

final List<String> _cartRemoveCouponEndpointCandidates =
_buildCartEndpointCandidates(
  override: _cartRemoveCouponEndpointOverride,
  defaults: <String>[
    'api/cart/coupon',
    'cart/coupon',
    'api/cart/remove-coupon',
    'cart/remove-coupon',
    'cart/coupons/remove',
    'cart/remove-coupon-code',
  ],
);


final List<String> _cartDeliveryTimingEndpointCandidates =
_buildCartEndpointCandidates(
  override: _cartDeliveryTimingEndpointOverride,
  defaults: <String>[
    'cart/delivery-payment-timing',
    'cart/delivery_payment_timing',
    'cart/payment-timing',
    'cart/payment-timings',
  ],
);

final List<String> _cartCheckoutInfoEndpointCandidates =
_buildCartEndpointCandidates(
  override: _cartCheckoutInfoEndpointOverride,
  defaults: <String>[
    'checkout-info',
    'cart/checkout-info',
    'cart/checkout',
    'cart/checkout-details',
  ],
);


List<String> _buildCartEndpointCandidates({
  required String override,
  required List<String> defaults,
}) {
  final Set<String> seen = <String>{};
  final List<String> result = <String>[];

  void add(String value) {
    final String? normalized = _normalizeCartEndpoint(value);
    if (normalized == null) return;
    if (seen.add(normalized)) {
      result.add(normalized);
    }
  }

  if (override is String && override.trim().isNotEmpty) {
    for (final String part in override.split(',')) {
      add(part);
    }
  }

  for (final String d in defaults) {
    add(d);
  }

  return result;
}

String? _normalizeCartEndpoint(String? raw) {
  if (raw == null) return null;
  final String trimmed = raw.trim();
  if (trimmed.isEmpty || trimmed == '.') return null;

  // Allow absolute URLs as-is
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    return trimmed;
  }

  // Strip leading slash so Api.useBaseUrl can join correctly
  if (trimmed.startsWith('/')) {
    return trimmed.substring(1);
  }

  return trimmed;
}

bool _shouldUseBaseUrl(String endpoint) {
  return !(endpoint.startsWith('http://') || endpoint.startsWith('https://'));
}

String? _normSection(String? v) {
  final String? s = normalizeDeliveryDepartment(v);
  if (s == null) return null;
  if (s == 'general') return 'store';  return s;
}



class _DirectCartRequest {
  const _DirectCartRequest({
    required this.endpoint,
    this.parameters = const <String, dynamic>{},
  });

  final String endpoint;
  final Map<String, dynamic> parameters;
}



/// Repository that wraps the backend cart endpoints and normalises the
/// responses into [Cart] models. All methods return the server's latest cart
/// payload so the caller can keep state in sync with the backend.



class CartRepository {
  CartRepository({CartShippingQuoteService? shippingQuoteService})
      : _shippingQuoteService =
      shippingQuoteService ?? CartShippingQuoteService.shared;

  final CartShippingQuoteService _shippingQuoteService;

  Future<CartSummary> fetchCart() async {
    final Map<String, dynamic> response = await _getWithFallback(
      _cartFetchEndpointCandidates,
      queryParameters: const <String, dynamic>{},
    );
    final Map<String, dynamic> normalized = Map<String, dynamic>.from(response);
    final CartSummary summary = _parseCartSummary(normalized);
    return summary;

  }


  Future<CartSummary> fetchDeliveryPaymentTiming() async {
    try {
      final Map<String, dynamic> response = await _getWithFallback(
        _cartDeliveryTimingEndpointCandidates,
        queryParameters: const <String, dynamic>{},
      );
      return _parseCartSummary(response);
    } on ApiHttpException catch (error) {
      if (error.statusCode == 405) {
        final Map<String, dynamic> fallbackResponse = await _postWithFallback(
          _cartDeliveryTimingEndpointCandidates,
          const <String, dynamic>{},
        );
        return _parseCartSummary(fallbackResponse);
      }
      rethrow;
    }
  }


  Future<CartCheckoutDetails> fetchCheckoutInfo() async {
    final Map<String, dynamic> response = await _getWithFallback(
      _cartCheckoutInfoEndpointCandidates,
      queryParameters: const <String, dynamic>{},
    );

    return _parseCheckoutDetails(response);
  }

  Future<CartSummary> addItem({
    required int itemId,
    int quantity = 1,
    String? section,
    String? department,
    double? weight,
    double? vendorLat,
    double? vendorLng,
    Object? selectedCustomFields,
    Object? variantId,
    Object? attributes,
    Object? stockSnapshot,
    double? unitPrice,
    bool? unitPriceLocked,
    String? currency,
  }) async {
    final String? sectionValue =
        _normSection(section) ?? _normSection(department);
    final String? departmentCode = _normSection(department);

    final Map<String, dynamic> parameters = <String, dynamic>{
      'item_id': itemId,
      'quantity': quantity,
      if (_encodeSCF(selectedCustomFields) != null)
        'selected_custom_fields': _encodeSCF(selectedCustomFields),
      if (weight != null) 'weight': weight,
      if (vendorLat != null) 'vendor_lat': vendorLat,
      if (vendorLng != null) 'vendor_lng': vendorLng,
      if (sectionValue != null) 'section': sectionValue,
    };

    if (departmentCode != null) {
      parameters['department'] = departmentCode;
    }

    if (variantId != null) {
      parameters['variant_id'] = variantId;
    }

    final dynamic encodedAttributes = _encodePayload(attributes);
    if (encodedAttributes != null) {
      parameters['attributes'] = encodedAttributes;
    }

    final dynamic encodedStock = _encodePayload(stockSnapshot);
    if (encodedStock != null) {
      parameters['stock_snapshot'] = encodedStock;
    }

    if (unitPrice != null) {
      parameters['unit_price'] = unitPrice;
    }

    if (unitPriceLocked != null) {
      parameters['unit_price_locked'] = unitPriceLocked;
    }

    if (currency != null && currency.trim().isNotEmpty) {
      parameters['currency'] = currency.trim();
    }

    final Map<String, dynamic> response = await _postWithFallback(
      _cartAddEndpointCandidates,
      parameters,
    );

    _shippingQuoteService.invalidateCache();
    return _parseCartSummary(response);
  }

  Future<CartSummary> updateQuantity({
    required int itemId,
    required int quantity,
    int? cartItemId,
    Object? variantId,
    Object? attributes,
    Object? stockSnapshot,
    double? unitPrice,
    String? currency,
  }) async {
    Map<String, dynamic>? response;

    Map<String, dynamic> _buildVariantPayload() {
      final Map<String, dynamic> payload = <String, dynamic>{
        'quantity': quantity,
      };

      if (variantId != null) {
        payload['variant_id'] = variantId;
      }

      final dynamic encodedAttributes = _encodePayload(attributes);
      if (encodedAttributes != null) {
        payload['attributes'] = encodedAttributes;
      }

      final dynamic encodedStock = _encodePayload(stockSnapshot);
      if (encodedStock != null) {
        payload['stock_snapshot'] = encodedStock;
      }

      if (unitPrice != null) {
        payload['unit_price'] = unitPrice;
      }

      if (currency != null) {
        final String trimmedCurrency = currency.trim();
        if (trimmedCurrency.isNotEmpty) {
          payload['currency'] = trimmedCurrency;
        }
      }

      return payload;
    }

    final Map<String, dynamic> variantPayload = _buildVariantPayload();

    if (cartItemId != null) {
      response = await _tryPostDirect(<_DirectCartRequest>[
        _DirectCartRequest(
          endpoint: 'cart/items/$cartItemId/update',
          parameters: Map<String, dynamic>.from(variantPayload),
        ),
        _DirectCartRequest(
          endpoint: 'cart/items/$cartItemId/quantity',
          parameters: <String, dynamic>{
            ...variantPayload,
            '_method': 'PATCH',
          },
        ),
        _DirectCartRequest(
          endpoint: 'cart/items/$cartItemId',
          parameters: <String, dynamic>{
            ...variantPayload,
            '_method': 'PATCH',
          },
        ),
      ]);
    }

    response ??= await _postWithFallback(
      _cartUpdateEndpointCandidates,
      <String, dynamic>{
        'item_id': itemId,
        ...variantPayload,
      },
    );

    final CartSummary summary = _parseCartSummary(response);
    _shippingQuoteService.invalidateCache();
    return summary;
  }

  String? _encodeSCF(Object? v) {
    if (v == null) return null;
    if (v is String && v.trim().isNotEmpty) return v; // جاهز
    if (v is Map && v.isNotEmpty) return jsonEncode(v);
    if (v is List && v.isNotEmpty) return jsonEncode(v);
    return null;
  }

  dynamic _encodePayload(Object? value) {
    if (value == null) return null;
    if (value is String) {
      final String trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    if (value is num || value is bool) {
      return value;
    }
    if (value is Map) {
      if (value.isEmpty) return null;
      final Map<String, dynamic> normalized = <String, dynamic>{};
      value.forEach((dynamic key, dynamic v) {
        if (key == null) return;
        normalized[key is String ? key : key.toString()] = v;
      });
      return normalized;

    }
    if (value is Iterable) {
      final List<dynamic> list = value.toList();
      if (list.isEmpty) return null;
      return list;
    }
    return value;
  }

  Future<CartSummary> removeItem({
    required int itemId,
    int? cartItemId,
  }) async {
    Map<String, dynamic>? response;

    if (cartItemId != null) {
      response = await _tryDeleteDirect(<String>[
        'cart/items/$cartItemId',
        'cart/items/$cartItemId/remove',
      ]);

      response ??= await _tryPostDirect(<_DirectCartRequest>[
        _DirectCartRequest(
          endpoint: 'cart/items/$cartItemId/remove',
        ),
      ]);
    }

    response ??= await _postWithFallback(
      _cartRemoveEndpointCandidates,
      <String, dynamic>{
        'item_id': itemId,
      },
    );

    final CartSummary summary = _parseCartSummary(response);
    _shippingQuoteService.invalidateCache();
    return summary;
  }

  Future<CartSummary> clearCart() async {
    Map<String, dynamic>? response = await _tryDeleteDirect(<String>[
      'cart/clear',
      'cart/items/clear',
    ]);

    response ??= await _postWithFallback(
      _cartClearEndpointCandidates,
      const <String, dynamic>{},
    );

    final CartSummary summary = _parseCartSummary(response);
    _shippingQuoteService.invalidateCache();
    return summary;
  }

  Future<CartSummary> applyCoupon({
    String? code,
    String? couponCode,
  }) async {
    final Map<String, dynamic> payload = _buildCouponPayload(
      code: code,
      couponCode: couponCode,
    );

    Map<String, dynamic>? response;
    ApiHttpException? unsupportedError;

    try {
      response = await _postWithFallback(
        _cartApplyCouponEndpointCandidates,
        payload,
      );
    } on ApiHttpException catch (error) {
      if (error.statusCode == 404 || error.statusCode == 405) {
        unsupportedError = error;
      } else {
        rethrow;
      }
    }

    response ??= await _tryDeleteDirect(

      _cartRemoveCouponEndpointCandidates,
    );

    if (response == null) {
      if (unsupportedError != null) {
        throw unsupportedError;
      }
      throw ApiException('تعذر تطبيق القسيمة على الخادم.');
    }



    final CartSummary summary = _parseCartSummary(response);
    _shippingQuoteService.invalidateCache();
    return summary;
  }

  Future<CartSummary> removeCoupon({
    String? code,
    String? couponCode,
  }) async {
    final Map<String, dynamic> payload = _buildCouponPayload(
      code: code,
      couponCode: couponCode,
    );

    Map<String, dynamic>? response = await _tryDeleteDirect(
      _cartRemoveCouponEndpointCandidates,
    );

    response ??= await _postWithFallback(
      _cartRemoveCouponEndpointCandidates,
      payload,
    );

    final CartSummary summary = _parseCartSummary(response);
    _shippingQuoteService.invalidateCache();
    return summary;
  }


  /// Updates the delivery payment timing using the delivery timing endpoint
  /// and returns the refreshed cart summary from the server.




  Future<CartSummary> setDeliveryPaymentTiming({
    required String timing,
  }) async {

    final String normalized = timing.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(timing, 'timing', 'Timing cannot be empty.');
    }

    final Map<String, dynamic> response = await _postWithFallback(
      _cartDeliveryTimingEndpointCandidates,
      <String, dynamic>{
        'delivery_payment_timing': normalized,
        'payment_timing': normalized,
        'timing': normalized,
      },
    );

    final CartSummary summary = _parseCartSummary(response);
    _shippingQuoteService.invalidateCache();
    return summary;
  }

  Future<CartSummary> updateDeliveryPaymentTiming({
    required String timing,
  }) {
    return setDeliveryPaymentTiming(timing: timing);
  }


  Future<Map<String, dynamic>> _getWithFallback(
      List<String> endpoints, {
        Map<String, dynamic>? queryParameters,
      }) async {
    ApiHttpException? notFound;

    for (final String endpoint in endpoints) {
      try {
        return await Api.get(
          url: endpoint,
          queryParameters: queryParameters,
          useBaseUrl: _shouldUseBaseUrl(endpoint),
        );
      } on ApiHttpException catch (error) {
        if (error.statusCode == 404) {
          notFound = error;
          continue;
        }
        rethrow;
      }
    }

    if (notFound != null) {
      throw notFound;
    }

    throw ApiException('تعذر الوصول إلى مسار السلة على الخادم.');
  }

  Future<Map<String, dynamic>> _postWithFallback(
      List<String> endpoints,
      Map<String, dynamic> parameters,
      ) async {
    ApiHttpException? notFound;
    final Map<String, dynamic> filteredParameters =
    Map<String, dynamic>.from(parameters)
      ..removeWhere((String key, dynamic value) => value == null);

    for (final String endpoint in endpoints) {
      try {
        return await Api.postJson(
          url: endpoint,
          data: filteredParameters,
          useBaseUrl: _shouldUseBaseUrl(endpoint),
        );
      } on ApiHttpException catch (error) {
        if (error.statusCode == 404) {
          notFound = error;
          continue;
        }
        rethrow;
      }
    }

    if (notFound != null) {
      throw notFound;
    }

    throw ApiException('تعذر الوصول إلى مسار السلة على الخادم.');
  }

  Future<Map<String, dynamic>?> _tryPostDirect(
      List<_DirectCartRequest> candidates) async {
    for (final _DirectCartRequest candidate in candidates) {
      final String? endpoint = _normalizeCartEndpoint(candidate.endpoint);
      if (endpoint == null) continue;

      final Map<String, dynamic> params =
      Map<String, dynamic>.from(candidate.parameters)
        ..removeWhere((String key, dynamic value) => value == null);

      try {
        return await Api.postJson(
          url: endpoint,
          data: params,
          useBaseUrl: _shouldUseBaseUrl(endpoint),
        );
      } on ApiHttpException catch (error) {
        if (error.statusCode == 404 || error.statusCode == 405) {
          continue;
        }
        rethrow;
      }
    }

    return null;
  }

  Future<Map<String, dynamic>?> _tryDeleteDirect(
      List<String> endpoints) async {
    for (final String endpointRaw in endpoints) {
      final String? endpoint = _normalizeCartEndpoint(endpointRaw);
      if (endpoint == null) continue;

      try {
        return await Api.delete(
          url: endpoint,
          useBaseUrl: _shouldUseBaseUrl(endpoint),
        );
      } on ApiHttpException catch (error) {
        if (error.statusCode == 404 || error.statusCode == 405) {
          continue;
        }
        rethrow;
      }
    }

    return null;
  }

  Map<String, dynamic> _buildCouponPayload({
    String? code,
    String? couponCode,
  }) {
    String? normalize(dynamic value) {
      if (value == null) return null;
      final String stringValue = value.toString().trim();
      return stringValue.isEmpty ? null : stringValue;
    }

    final String? normalizedCode = normalize(code);
    final String? normalizedCouponCode = normalize(couponCode);

    final Map<String, dynamic> payload = <String, dynamic>{};

    if (normalizedCode != null) {
      payload['code'] = normalizedCode;
      payload.putIfAbsent('coupon_code', () => normalizedCode);
    }

    if (normalizedCouponCode != null) {
      payload['coupon_code'] = normalizedCouponCode;
      payload.putIfAbsent('code', () => normalizedCouponCode);
    }

    if (payload.isEmpty) {
      throw ApiException('يرجى إدخال رمز قسيمة صالح.');
    }

    return payload;
  }

  CartSummary _parseCartSummary(Map<String, dynamic> response) {
    final dynamic data = response['data'] ?? response['cart'];
    List<dynamic> rows = const <dynamic>[];

    if (data is List) {
      rows = data;
    } else if (data is Map<String, dynamic>) {
      final dynamic inner = data['items'] ??
          data['cart'] ??
          data['data'] ??
          data['rows'] ??
          data['records'];
      if (inner is List) rows = inner;
    } else if (response['items'] is List) {
      rows = response['items'] as List<dynamic>;
    }

    final List<dynamic> normalisedRows = rows.map<dynamic>((dynamic e) {
      final Map<String, dynamic>? map = _castToStringKeyedMap(e);
      if (map == null) {
        return e;
      }
      return _ensureSellerRow(map);
    }).toList();

    final List<Cart> items = normalisedRows.map<Cart?>((dynamic e) {
      if (e is Cart) return e;
      final Map<String, dynamic>? map = _castToStringKeyedMap(e);
      if (map != null) {
        return Cart.fromJson(map);
      }
      return null;
    }).whereType<Cart>().toList();

    final List<CartDiscount> discounts = _parseDiscounts(response);


    Map<String, dynamic>? departmentPolicy;
    Map<String, dynamic>? support;
    Map<String, dynamic>? deliveryQuote;
    Map<String, dynamic>? blocking;
    List<dynamic>? deliveryPaymentOptions;
    String? deliveryPaymentTiming;

    Map<String, dynamic>? _normalizeMap(Map<String, dynamic>? map) {
      if (map == null || map.isEmpty) {
        return null;
      }
      return Map<String, dynamic>.unmodifiable(Map<String, dynamic>.from(map));
    }

    List<dynamic>? _normalizeOptions(dynamic value) {
      if (value == null) {
        return null;
      }
      if (value is List<dynamic>) {
        return List<dynamic>.unmodifiable(value);
      }
      if (value is Iterable<dynamic>) {
        return List<dynamic>.unmodifiable(List<dynamic>.from(value));
      }
      return List<dynamic>.unmodifiable(<dynamic>[value]);
    }

    String? _asString(dynamic value) {
      if (value == null) return null;
      if (value is String) {
        final String trimmed = value.trim();
        return trimmed.isEmpty ? null : trimmed;
      }
      final String text = value.toString();
      return text.trim().isEmpty ? null : text.trim();
    }

    Map<String, dynamic>? _findFirstMapValue(
        Map<String, dynamic> map, List<String> keys) {
      for (final String key in keys) {
        if (!map.containsKey(key)) {
          continue;
        }
        final dynamic candidate = map[key];
        final Map<String, dynamic>? cast = _castToStringKeyedMap(candidate);
        if (cast != null) {
          return cast;
        }
        if (candidate is Iterable) {
          for (final dynamic entry in candidate) {
            final Map<String, dynamic>? inner = _castToStringKeyedMap(entry);
            if (inner != null) {
              return inner;
            }
          }
        }
      }
      return null;
    }

    dynamic _findFirstValue(Map<String, dynamic> map, List<String> keys) {
      for (final String key in keys) {
        if (!map.containsKey(key)) {
          continue;
        }
        final dynamic value = map[key];
        if (value != null) {
          return value;
        }
      }
      return null;
    }

    Map<String, dynamic>? _normalizeQuote(Map<String, dynamic>? map) {
      if (map == null || map.isEmpty) {
        return null;
      }
      final Map<String, dynamic> normalized = Map<String, dynamic>.from(map);
      final dynamic depositRaw = map['deposit'];
      final Map<String, dynamic>? depositMap =
      _castToStringKeyedMap(depositRaw);
      if (depositMap != null) {
        normalized['deposit'] =
        Map<String, dynamic>.unmodifiable(Map<String, dynamic>.from(depositMap));
      } else if (depositRaw != null) {
        normalized['deposit'] = depositRaw;
      }
      return Map<String, dynamic>.unmodifiable(normalized);
    }

    void _considerCandidate(Map<String, dynamic> map) {
      departmentPolicy ??= _normalizeMap(_findFirstMapValue(map, const <String>[
        'department_policy',
        'departmentPolicy',
        'policy',
        'department_policy_info',
        'department_policy_data',
      ]));

      support ??= _normalizeMap(_findFirstMapValue(map, const <String>[
        'support',
        'support_info',
        'supportInfo',
        'cart_support',
        'support_block',
      ]));

      blocking ??= _normalizeMap(_findFirstMapValue(map, const <String>[
        'blocking',
        'cart_block',
        'cart_blocking',
        'blocks',
      ]));

      final Map<String, dynamic>? quoteCandidate =
      _findFirstMapValue(map, const <String>[
        'delivery_quote',
        'deliveryQuote',
        'delivery_quote_info',
        'quote',
        'shipping_quote',
      ]);

      if (quoteCandidate != null) {
        final Map<String, dynamic>? normalizedQuote =
        _normalizeQuote(quoteCandidate);
        if (normalizedQuote != null) {
          if (deliveryQuote == null) {
            deliveryQuote = normalizedQuote;
          } else if (!deliveryQuote!.containsKey('deposit') &&
              normalizedQuote.containsKey('deposit')) {
            deliveryQuote = normalizedQuote;
          }
        }

        deliveryPaymentOptions ??= _normalizeOptions(_findFirstValue(
          quoteCandidate,
          const <String>[
            'delivery_payment_options',
            'payment_options',
            'options',
          ],
        ));

        deliveryPaymentTiming ??= _asString(_findFirstValue(
          quoteCandidate,
          const <String>[
            'delivery_payment_timing',
            'payment_timing',
            'timing',
          ],
        ));
      }

      deliveryPaymentOptions ??= _normalizeOptions(_findFirstValue(
        map,
        const <String>[
          'delivery_payment_options',
          'deliveryPaymentOptions',
          'payment_options',
        ],
      ));

      deliveryPaymentTiming ??= _asString(_findFirstValue(
        map,
        const <String>[
          'delivery_payment_timing',
          'deliveryPaymentTiming',
          'payment_timing',
        ],
      ));
    }

    final List<dynamic> queue = <dynamic>[];
    final Set<int> visitedIdentities = <int>{};

    void enqueue(dynamic value) {
      if (value == null) {
        return;
      }
      if (value is Iterable) {
        for (final dynamic entry in value) {
          enqueue(entry);
        }
        return;
      }
      if (value is Map || value is List) {
        final int identity = identityHashCode(value);
        if (!visitedIdentities.add(identity)) {
          return;
        }
      }
      queue.add(value);
    }

    enqueue(response);
    enqueue(data);

    const List<String> nestedKeys = <String>[
      'cart',
      'data',
      'payload',
      'result',
      'meta',
      'summary',
      'totals',
      'info',
      'details',
      'context',
      'cart_summary',
      'cartSummary',
      'extras',
      'extra',
      'checkout',
    ];

    while (queue.isNotEmpty) {
      final dynamic current = queue.removeAt(0);
      final Map<String, dynamic>? map = _castToStringKeyedMap(current);
      if (map == null) {
        continue;
      }

      _considerCandidate(map);

      for (final String key in nestedKeys) {
        if (map.containsKey(key)) {
          enqueue(map[key]);
        }
      }
    }

    return CartSummary(
      items: items,
      discounts: discounts,
      raw: response,
      departmentPolicy: departmentPolicy,
      support: support,
      deliveryQuote: deliveryQuote,
      blocking: blocking,
      deliveryPaymentOptions: deliveryPaymentOptions,
      deliveryPaymentTiming: deliveryPaymentTiming,

    );
  }



  CartCheckoutDetails _parseCheckoutDetails(Map<String, dynamic> response) {
    final CartSummary summary = _parseCartSummary(response);
    final Map<String, dynamic>? data =
        _castToStringKeyedMap(response['data']) ?? _castToStringKeyedMap(response);
    final Map<String, dynamic>? checkout = data == null
        ? null
        : _castToStringKeyedMap(
        data['checkout'] ?? data['checkout_info'] ?? data['checkoutInfo']);

    String? departmentNotice = _stringFrom(
      checkout?['department_notice'] ?? checkout?['departmentNotice'],
    );

    departmentNotice ??=
        _stringFrom(data?['department_notice'] ?? data?['departmentNotice']);
    departmentNotice ??= _stringFrom(
      response['department_notice'] ?? response['departmentNotice'],
    );

    Map<String, dynamic>? deliveryQuote = summary.deliveryQuote == null
        ? null
        : Map<String, dynamic>.from(summary.deliveryQuote!);

    if (departmentNotice != null) {
      deliveryQuote ??= <String, dynamic>{};
      deliveryQuote['department_notice'] = departmentNotice;
    }

    return CartCheckoutDetails(
      departmentPolicy: summary.departmentPolicy,
      support: summary.support,
      deliveryQuote: deliveryQuote,
      blocking: summary.blocking,
      deliveryPaymentOptions: summary.deliveryPaymentOptions,
      deliveryPaymentTiming: summary.deliveryPaymentTiming,
      departmentNotice: departmentNotice,
    );
  }


  List<CartDiscount> _parseDiscounts(Map<String, dynamic> response) {
    final List<CartDiscount> discounts = <CartDiscount>[];
    final Set<String> seen = <String>{};

    void addDiscount(Map<String, dynamic> map) {
      final Map<String, dynamic> normalized = Map<String, dynamic>.from(map);
      normalized.removeWhere((String key, dynamic value) => value == null);
      if (normalized.isEmpty) return;
      final String fingerprint = jsonEncode(normalized);
      if (seen.add(fingerprint)) {
        discounts.add(CartDiscount.fromJson(normalized));
      }
    }

    void absorb(dynamic value) {
      if (value == null) return;
      if (value is Iterable) {
        for (final dynamic entry in value) {
          absorb(entry);
        }
        return;
      }
      final Map<String, dynamic>? map = _castToStringKeyedMap(value);
      if (map != null) {
        addDiscount(map);
        return;
      }
      final String? text = value is String
          ? value.trim().isEmpty
          ? null
          : value.trim()
          : value?.toString();
      if (text != null && text.isNotEmpty) {
        addDiscount(<String, dynamic>{'message': text});
      }
    }

    final List<dynamic> candidates = <dynamic>[
      response,
      response['data'],
      response['cart'],
      response['result'],
      response['payload'],
      response['meta'],
    ];

    const List<String> discountKeys = <String>[
      'discounts',
      'applied_discounts',
      'cart_discounts',
      'coupon_statuses',
      'coupon_status',
      'coupon',
      'coupons',
      'coupon_history',
      'discount_codes',
      'applied_coupons',
      'appliedCoupon',
      'appliedCoupons',
      'discount_summary',
    ];

    for (final dynamic candidate in candidates) {
      final Map<String, dynamic>? map = _castToStringKeyedMap(candidate);
      if (map == null) continue;

      for (final String key in discountKeys) {
        if (!map.containsKey(key)) continue;
        absorb(map[key]);
      }

      final Map<String, dynamic>? nestedCart =
      _castToStringKeyedMap(map['cart'] ?? map['data']);
      if (nestedCart != null) {
        for (final String key in discountKeys) {
          if (!nestedCart.containsKey(key)) continue;
          absorb(nestedCart[key]);
        }
      }
    }

    return discounts;
  }

  Map<String, dynamic>? _castToStringKeyedMap(dynamic raw) {
    if (raw == null) return null;
    if (raw is Map<String, dynamic>) {
      return Map<String, dynamic>.from(raw);
    }
    if (raw is Map) {
      final Map<String, dynamic> converted = <String, dynamic>{};
      raw.forEach((dynamic key, dynamic value) {
        if (key == null) return;
        converted[key is String ? key : key.toString()] = value;
      });
      return converted;
    }
    return null;
  }



  String? _stringFrom(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is String) {
      final String trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    final String text = value.toString().trim();
    return text.isEmpty ? null : text;
  }





  Map<String, dynamic> _ensureSellerRow(Map<String, dynamic> row) {
    final Map<String, dynamic> result = Map<String, dynamic>.from(row);

    Map<String, dynamic>? mergedSeller;

    void absorb(dynamic candidate) {
      final Map<String, dynamic>? normalised = _normaliseSellerPayload(candidate);
      if (normalised == null) return;
      mergedSeller = _mergeSellerMaps(mergedSeller, normalised);
    }

    absorb(result['seller']);
    absorb(result['vendor']);
    absorb(result['user']);

    final Map<String, dynamic> directAliases = <String, dynamic>{
      if (result.containsKey('seller_name')) 'seller_name': result['seller_name'],
      if (result.containsKey('vendor_name')) 'vendor_name': result['vendor_name'],
      if (result.containsKey('store_name')) 'store_name': result['store_name'],
      if (result.containsKey('shop_name')) 'shop_name': result['shop_name'],
      if (result.containsKey('business_name')) 'business_name': result['business_name'],
      if (result.containsKey('company_name')) 'company_name': result['company_name'],
      if (result.containsKey('seller_mobile')) 'seller_mobile': result['seller_mobile'],
      if (result.containsKey('seller_phone')) 'seller_phone': result['seller_phone'],
      if (result.containsKey('vendor_phone')) 'vendor_phone': result['vendor_phone'],
      if (result.containsKey('vendor_mobile')) 'vendor_mobile': result['vendor_mobile'],
      if (result.containsKey('phone')) 'phone': result['phone'],
      if (result.containsKey('phone_number')) 'phone_number': result['phone_number'],
      if (result.containsKey('contact')) 'contact': result['contact'],
      if (result.containsKey('contact_number')) 'contact_number': result['contact_number'],
      if (result.containsKey('whatsapp')) 'whatsapp': result['whatsapp'],
      if (result.containsKey('whatsapp_number'))
        'whatsapp_number': result['whatsapp_number'],
      if (result.containsKey('seller_address')) 'seller_address': result['seller_address'],
      if (result.containsKey('vendor_address')) 'vendor_address': result['vendor_address'],
      if (result.containsKey('location')) 'location': result['location'],
      if (result.containsKey('address')) 'address': result['address'],
      if (result.containsKey('seller_email')) 'seller_email': result['seller_email'],
      if (result.containsKey('vendor_email')) 'vendor_email': result['vendor_email'],
    };
    if (directAliases.isNotEmpty) {
      absorb(directAliases);
    }

    final Map<String, dynamic>? pivot = _castToStringKeyedMap(result['pivot']);
    if (pivot != null) {
      absorb(pivot['seller']);
      absorb(pivot['vendor']);
      absorb(pivot['user']);
    }

    final Map<String, dynamic>? item = _castToStringKeyedMap(result['item']);
    if (item != null) {
      absorb(item['seller']);
      absorb(item['vendor']);
      absorb(item['user']);
      final Map<String, dynamic> itemAlias = <String, dynamic>{
        if (item.containsKey('seller_name')) 'seller_name': item['seller_name'],
        if (item.containsKey('vendor_name')) 'vendor_name': item['vendor_name'],
        if (item.containsKey('store_name')) 'store_name': item['store_name'],
        if (item.containsKey('shop_name')) 'shop_name': item['shop_name'],
        if (item.containsKey('business_name')) 'business_name': item['business_name'],
        if (item.containsKey('company_name')) 'company_name': item['company_name'],
        if (item.containsKey('seller_mobile')) 'seller_mobile': item['seller_mobile'],
        if (item.containsKey('seller_phone')) 'seller_phone': item['seller_phone'],
        if (item.containsKey('vendor_phone')) 'vendor_phone': item['vendor_phone'],
        if (item.containsKey('vendor_mobile')) 'vendor_mobile': item['vendor_mobile'],
        if (item.containsKey('phone')) 'phone': item['phone'],
        if (item.containsKey('phone_number')) 'phone_number': item['phone_number'],
        if (item.containsKey('contact')) 'contact': item['contact'],
        if (item.containsKey('contact_number')) 'contact_number': item['contact_number'],
        if (item.containsKey('whatsapp')) 'whatsapp': item['whatsapp'],
        if (item.containsKey('whatsapp_number'))
          'whatsapp_number': item['whatsapp_number'],
        if (item.containsKey('seller_address')) 'seller_address': item['seller_address'],
        if (item.containsKey('vendor_address')) 'vendor_address': item['vendor_address'],
        if (item.containsKey('location')) 'location': item['location'],
        if (item.containsKey('address')) 'address': item['address'],
        if (item.containsKey('seller_email')) 'seller_email': item['seller_email'],
        if (item.containsKey('vendor_email')) 'vendor_email': item['vendor_email'],
      };
      if (itemAlias.isNotEmpty) {
        absorb(itemAlias);
      }
    }

    if (mergedSeller != null && mergedSeller!.isNotEmpty) {
      final Map<String, dynamic>? normalisedSeller =
      _normaliseSellerFields(mergedSeller!);
      if (normalisedSeller != null && normalisedSeller.isNotEmpty) {
        final Map<String, dynamic> sellerContact =
        _projectSellerContact(normalisedSeller);
        result['seller'] = sellerContact;
        result['vendor'] ??= sellerContact;
      }
    }

    return result;
  }

  Map<String, dynamic> _projectSellerContact(Map<String, dynamic> data) {
    String _stringValue(dynamic value) {
      if (value == null) return '';
      if (value is String) {
        final String trimmed = value.trim();
        return trimmed;
      }
      return value.toString();
    }

    dynamic _addressValue(dynamic value) {
      if (value == null) return '';
      if (value is String) {
        final String trimmed = value.trim();
        return trimmed;
      }
      return value;
    }

    final Map<String, dynamic> contact = <String, dynamic>{
      'name': _stringValue(data['name']),
      'mobile': _stringValue(data['mobile']),
      'address': _addressValue(data['address']),
    };

    if (_hasMeaningfulValue(data['email'])) {
      contact['email'] = data['email'];
    }

    if (_hasMeaningfulValue(data['id'])) {
      contact['id'] = data['id'];
    }

    return contact;
  }

  Map<String, dynamic>? _normaliseSellerPayload(dynamic raw) {
    if (raw == null) return null;
    if (raw is Map<String, dynamic>) {
      return _normaliseSellerFields(Map<String, dynamic>.from(raw));
    }
    if (raw is Map) {
      final Map<String, dynamic> converted = <String, dynamic>{};
      raw.forEach((dynamic key, dynamic value) {
        if (key == null) return;
        converted[key is String ? key : key.toString()] = value;
      });
      return _normaliseSellerFields(converted);
    }
    if (raw is String) {
      final String trimmed = raw.trim();
      if (trimmed.isEmpty) return null;
      return <String, dynamic>{'name': trimmed};
    }
    return null;
  }

  Map<String, dynamic>? _mergeSellerMaps(
      Map<String, dynamic>? base, Map<String, dynamic>? incoming) {
    if (incoming == null) return base;
    if (base == null) return Map<String, dynamic>.from(incoming);

    final Map<String, dynamic> merged = Map<String, dynamic>.from(base);
    incoming.forEach((String key, dynamic value) {
      if (_hasMeaningfulValue(value)) {
        final dynamic existing = merged[key];
        if (!_hasMeaningfulValue(existing)) {
          merged[key] = value;
        }
      }
    });
    return merged;
  }

  bool _hasMeaningfulValue(dynamic value) {
    if (value == null) return false;
    if (value is String) {
      return value.trim().isNotEmpty;
    }
    return true;
  }

  Map<String, dynamic>? _normaliseSellerFields(Map<String, dynamic> map) {
    final Map<String, dynamic> result = Map<String, dynamic>.from(map);

    String? pickString(List<String> keys) {
      for (final String key in keys) {
        final dynamic value = result[key];
        if (value == null) continue;
        if (value is String) {
          final String trimmed = value.trim();
          if (trimmed.isNotEmpty) {
            return trimmed;
          }
        } else {
          return value.toString();
        }
      }
      return null;
    }

    dynamic pickDynamic(List<String> keys) {
      for (final String key in keys) {
        final dynamic value = result[key];
        if (_hasMeaningfulValue(value)) {
          return value;
        }
      }
      return null;
    }

    result['name'] ??= pickString(<String>[
      'seller_name',
      'vendor_name',
      'store_name',
      'shop_name',
      'business_name',
      'company_name',
      'full_name',
      'username',
      'seller',
      'vendor',
    ]);

    result['mobile'] ??= pickString(<String>[
      'seller_mobile',
      'seller_phone',
      'vendor_phone',
      'vendor_mobile',
      'phone',
      'phone_number',
      'contact',
      'contact_number',
      'whatsapp',
      'whatsapp_number',
    ]);

    result['address'] ??= pickDynamic(<String>[
      'seller_address',
      'vendor_address',
      'location',
      'address',
      'address_line',
      'address1',
      'address_1',
      'full_address',
      'city',
    ]);

    result['email'] ??= pickString(<String>[
      'seller_email',
      'contact_email',
      'vendor_email',
    ]);

    result['id'] ??= pickDynamic(<String>[
      'seller_id',
      'vendor_id',
      'user_id',
    ]);

    result.removeWhere((String key, dynamic value) {
      if (value == null) return true;
      if (value is String) {
        return value.trim().isEmpty;
      }
      return false;
    });

    if (result.isEmpty) {
      return null;
    }
    return result;
  }
}
