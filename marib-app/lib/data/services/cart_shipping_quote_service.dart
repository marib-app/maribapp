import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

import 'package:marib/data/model/cart/checkout_models.dart';
import 'package:marib/utils/api.dart';
import 'package:marib/utils/constant.dart';
import 'package:marib/utils/delivery_department.dart';
import 'package:marib/utils/ui_utils.dart';

@immutable
class CartShippingQuoteException implements Exception {
  const CartShippingQuoteException({
    required this.message,
    this.statusCode,
    this.payload,
    this.cause,
  });

  final String message;
  final int? statusCode;
  final Map<String, dynamic>? payload;
  final Object? cause;

  @override
  String toString() => message;
}

class CartShippingQuoteService {
  CartShippingQuoteService._({String? endpoint})
      : _endpoint = (endpoint ?? Api.cartQuoteShippingApi).trim();

  factory CartShippingQuoteService({String? endpoint}) {
    if (endpoint != null && endpoint.trim().isNotEmpty) {
      return CartShippingQuoteService._(endpoint: endpoint);
    }
    return shared;
  }

  static final CartShippingQuoteService shared =
  CartShippingQuoteService._();

  final String _endpoint;
  bool _forceRefreshNext = false;

  Future<CheckoutShippingQuote> quoteShipping({
    int? addressId,
    String? department,
    bool? forceRefresh,
    bool depositEnabled = false,

    Map<String, dynamic>? extra,
  }) async {
    final bool shouldForceRefresh = (forceRefresh ?? false) || _forceRefreshNext;

    final Map<String, dynamic> payload = <String, dynamic>{};

    if (shouldForceRefresh) {
      payload['force_refresh'] = 1;
    }

    final String? departmentCode = normalizeDeliveryDepartment(department);
    if (departmentCode != null) {
      payload['department'] = departmentCode;
    }

    if (addressId != null) {
      payload['address_id'] = addressId;
    }
    payload['deposit_enabled'] = depositEnabled ? 1 : 0;

    if (extra != null) {
      extra.forEach((String key, dynamic value) {
        if (value != null) {
          payload[key] = value;
        }
      });
    }

    try {
      final Map<String, dynamic> response = await Api.post(
        url: _endpoint,
        parameter: payload,
        useBaseUrl: _shouldUseBaseUrl,
      );

      final Map<String, dynamic> normalized =
          Map<String, dynamic>.from(response);

      if (_isFailure(normalized)) {
        throw CartShippingQuoteException(
          message: _extractMessage(normalized) ??
              _translate('shippingQuoteFetchFailed'),
          payload: normalized,
        );
      }

      final Map<String, dynamic> data = _mapify(_firstValue(
        normalized,
        const <List<String>>[
          <String>['data'],
          <String>['result'],
          <String>['payload'],
        ],
      )) ??
          normalized;

      final CheckoutShippingQuote quote = CheckoutShippingQuote(
        delivery: _mapify(_firstValue(data, const <List<String>>[
          <String>['delivery'],
          <String>['delivery_info'],
          <String>['deliveryData'],
          <String>['shipping'],
        ])),
        deliveryQuote: _mapify(_firstValue(data, const <List<String>>[
          <String>['delivery_quote'],
          <String>['quote'],
          <String>['deliveryQuote'],
        ])),
        address: _mapify(_firstValue(data, const <List<String>>[
          <String>['address'],
          <String>['shipping_address'],
          <String>['delivery_address'],
        ])),
        totals: _mapify(_firstValue(data, const <List<String>>[
          <String>['totals'],
          <String>['summary'],
          <String>['cart'],
          <String>['cart_totals'],
        ])),
        wallet: _mapify(_firstValue(data, const <List<String>>[
          <String>['wallet'],
          <String>['wallet_summary'],
        ])),
        meta: _mapify(_firstValue(data, const <List<String>>[
          <String>['meta'],
          <String>['metadata'],
        ])),
        departmentNotice: _asString(_firstValue(
          data,
          const <List<String>>[
            <String>['department_notice'],
            <String>['departmentNotice'],
            <String>['notice'],
          ],
        ) ??
            _firstValue(normalized, const <List<String>>[
              <String>['department_notice'],
              <String>['departmentNotice'],
            ])),
        fromCache: _asBool(_firstValue(
          data,
          const <List<String>>[
            <String>['from_cache'],
            <String>['cache_hit'],
            <String>['cache', 'hit'],
          ],
        ) ??
            _firstValue(normalized, const <List<String>>[
              <String>['from_cache'],
              <String>['cache_hit'],
            ])),
        cacheKey: _asString(_firstValue(
          data,
          const <List<String>>[
            <String>['cache_key'],
            <String>['cache', 'key'],
          ],
        ) ??
            normalized['cache_key']),
        cacheExpiresAt: _parseDateTime(_asString(_firstValue(
          data,
          const <List<String>>[
            <String>['cache_expires_at'],
            <String>['cache', 'expires_at'],
            <String>['expires_at'],
          ],
        ) ??
            _firstValue(normalized, const <List<String>>[
              <String>['cache_expires_at'],
              <String>['expires_at'],
            ]))),
        cacheTtlSeconds: _asNum(_firstValue(
          data,
          const <List<String>>[
            <String>['cache_ttl'],
            <String>['cache', 'ttl'],
            <String>['ttl'],
            <String>['cache_ttl_seconds'],
          ],
        ) ??
            _firstValue(normalized, const <List<String>>[
              <String>['cache_ttl'],
              <String>['ttl'],
            ])),
        data: data,
        raw: normalized,
      );

      _forceRefreshNext = false;
      return quote;
    } on ApiHttpException catch (error) {
      throw CartShippingQuoteException(
        message: error.errorMessage?.toString() ??
            _translate('shippingQuoteServerUnavailable'),
        statusCode: error.statusCode,
        payload: _mapify(error.payload),
        cause: error,
      );
    } on ApiException catch (error) {
      throw CartShippingQuoteException(
        message: error.errorMessage?.toString() ??
            _translate('shippingQuoteServerUnavailable'),
        cause: error,
      );
    }
  }

  void invalidateCache() {
    _forceRefreshNext = true;
  }

  bool get _shouldUseBaseUrl =>
      !(_endpoint.startsWith('http://') || _endpoint.startsWith('https://'));

  String _translate(String key) {
    final BuildContext? context = Constant.navigatorKey.currentContext ??
        Constant.navigatorKey.currentState?.context;
    if (context == null) {
      return key;
    }
    return UiUtils.getTranslatedLabel(context, key);
  }

  static Map<String, dynamic>? _mapify(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value as Map);
    }
    return null;
  }

  static bool _isFailure(Map<String, dynamic> payload) {
    final dynamic status = payload['status'] ?? payload['success'];
    if (status is bool) {
      return !status;
    }
    if (status is num) {
      return status == 0;
    }
    return false;
  }

  static String? _extractMessage(Map<String, dynamic>? payload) {
    if (payload == null) {
      return null;
    }
    final dynamic message =
        payload['message'] ?? payload['error'] ?? payload['msg'];
    return message?.toString();
  }

  static dynamic _firstValue(
      Map<String, dynamic> source,
      List<List<String>> paths,
      ) {
    for (final List<String> path in paths) {
      dynamic current = source;
      var success = true;
      for (final String segment in path) {
        if (current is Map && current.containsKey(segment)) {
          current = current[segment];
        } else {
          success = false;
          break;
        }
      }
      if (success) {
        return current;
      }
    }
    return null;
  }

  static String? _asString(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is String) {
      return value;
    }
    if (value is num || value is bool) {
      return value.toString();
    }
    return null;
  }

  static num? _asNum(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value;
    }
    if (value is String) {
      final String trimmed = value.replaceAll(',', '').trim();
      return num.tryParse(trimmed);
    }
    return null;
  }

  static bool? _asBool(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      final String normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
        return true;
      }
      if (normalized == 'false' || normalized == '0' || normalized == 'no') {
        return false;
      }
    }
    return null;
  }

  static DateTime? _parseDateTime(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    return DateTime.tryParse(value);
  }
}