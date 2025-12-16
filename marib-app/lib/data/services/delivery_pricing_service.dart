import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

import 'package:marib/settings.dart';
import 'package:marib/utils/api.dart';
import 'package:marib/utils/constant.dart';
import 'package:marib/utils/delivery_department.dart';
import 'package:marib/utils/network_request_interseptor.dart';
import 'package:marib/utils/extensions/lib/translate.dart';

/// Exception thrown when delivery pricing requests fail.
@immutable
class DeliveryPricingException implements Exception {
  const DeliveryPricingException(this.message,
      {this.statusCode, this.payload, this.cause});

  final String message;
  final int? statusCode;
  final Map<String, dynamic>? payload;
  final Object? cause;

  @override
  String toString() => message;
}

/// Supported package sizes when inferring the default weight.
enum DeliveryPackageSize { small, medium, large }

extension DeliveryPackageSizeLabel on DeliveryPackageSize {
  String get label => switch (this) {
        DeliveryPackageSize.small => 'small',
        DeliveryPackageSize.medium => 'medium',
        DeliveryPackageSize.large => 'large',
      };
}

/// Runtime configuration resolved from `--dart-define` entries.
class DeliveryPricingConfig {
  DeliveryPricingConfig._({
    required this.baseUrl,
    required this.policyEndpoint,
    required this.calculateEndpoint,
    required this.timeout,
    required this.smallWeight,
    required this.mediumWeight,
    required this.largeWeight,
  });

  factory DeliveryPricingConfig.fromEnvironment() {
    final String envBase =
        const String.fromEnvironment('DELIVERY_PRICING_BASE_URL').trim();
    final String baseCandidate =
        envBase.isNotEmpty ? envBase : _fallbackBaseUrl();

    final String policyEndpoint = const String.fromEnvironment(
      'DELIVERY_PRICING_LIST_ENDPOINT',
      defaultValue: '/api/delivery-prices',
    ).trim();

    final String calculateEndpoint = const String.fromEnvironment(
      'DELIVERY_PRICING_CALCULATE_ENDPOINT',
      defaultValue: '/api/delivery-prices/calculate',
    ).trim();

    final int timeoutSeconds = int.tryParse(
          const String.fromEnvironment(
            'DELIVERY_PRICING_TIMEOUT',
            defaultValue: '10',
          ),
        ) ??
        10;

    double parseWeight(String rawValue, double fallback) {
      final String trimmed = rawValue.trim();
      if (trimmed.isEmpty) return fallback;
      return double.tryParse(trimmed) ?? fallback;
    }

    final String smallWeightRaw =
        const String.fromEnvironment('DELIVERY_PRICING_SMALL_WEIGHT');
    final String mediumWeightRaw =
        const String.fromEnvironment('DELIVERY_PRICING_MEDIUM_WEIGHT');
    final String largeWeightRaw =
        const String.fromEnvironment('DELIVERY_PRICING_LARGE_WEIGHT');

    return DeliveryPricingConfig._(
      baseUrl: baseCandidate,
      policyEndpoint:
          policyEndpoint.isEmpty ? '/api/delivery-prices' : policyEndpoint,
      calculateEndpoint: calculateEndpoint.isEmpty
          ? '/api/delivery-prices/calculate'
          : calculateEndpoint,
      timeout: Duration(seconds: timeoutSeconds.clamp(1, 60)),
      smallWeight: parseWeight(smallWeightRaw, 3),
      mediumWeight: parseWeight(mediumWeightRaw, 7),
      largeWeight: parseWeight(largeWeightRaw, 12),
    );
  }

  static String _fallbackBaseUrl() {
    final String host = AppSettings.hostUrl.trim();
    if (host.isNotEmpty) {
      return host;
    }

    final String base = Constant.baseUrl.trim();
    if (base.isEmpty) {
      return base;
    }

    if (base.endsWith('/api/')) {
      return base.substring(0, base.length - 4);
    }

    if (base.endsWith('/api')) {
      return base.substring(0, base.length - 3);
    }

    return base;
  }

  final String baseUrl;
  final String policyEndpoint;
  final String calculateEndpoint;
  final Duration timeout;
  final double smallWeight;
  final double mediumWeight;
  final double largeWeight;

  double weightForSize(DeliveryPackageSize size) => switch (size) {
        DeliveryPackageSize.small => smallWeight,
        DeliveryPackageSize.medium => mediumWeight,
        DeliveryPackageSize.large => largeWeight,
      };
}

/// Low-level client responsible for interacting with the delivery pricing API.
class DeliveryPricingService {
  DeliveryPricingService({
    DeliveryPricingConfig? config,
    Dio? client,
  })  : _config = config ?? DeliveryPricingConfig.fromEnvironment(),
        _client = client ?? Dio() {
    _client.options = BaseOptions(
      connectTimeout: _config.timeout,
      receiveTimeout: _config.timeout,
      sendTimeout: _config.timeout,
    );

    if (Api.networkLoggingEnabled) {
      bool hasInterceptor = false;
      for (final Interceptor interceptor in _client.interceptors) {
        if (interceptor is NetworkRequestInterseptor) {
          hasInterceptor = true;
          break;
        }
      }
      if (!hasInterceptor) {
        _client.interceptors.add(NetworkRequestInterseptor());
      }
    }
  }

  final DeliveryPricingConfig _config;
  final Dio _client;

  /// Returns the active delivery pricing policy for the selected department.
  Future<Map<String, dynamic>?> fetchPolicy({String? department}) async {
    final String? departmentCode = normalizeDeliveryDepartment(department);
    final Uri uri = _resolveUri(
      _config.policyEndpoint,
      departmentCode != null
          ? <String, dynamic>{'department': departmentCode}
          : null,
    );

    try {
      final Response<dynamic> response = await _client.getUri(
        uri,
        options: Options(headers: Api.headers()),
      );

      final Map<String, dynamic>? map = _mapify(response.data);
      if (map == null) {
        return null;
      }

      if (_isFailure(map)) {
        throw DeliveryPricingException(
          _extractMessage(map) ??
              _translateDeliveryPricing('deliveryPolicyFetchFailed'),
          statusCode: response.statusCode,
          payload: map,
        );
      }

      return map;
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) {
        return null;
      }
      throw DeliveryPricingException(
        error.message ??
            _translateDeliveryPricing('deliveryPricingConnectionFailed'),
        statusCode: error.response?.statusCode,
        payload: _mapify(error.response?.data),
        cause: error,
      );
    }
  }

  /// Calls the calculate endpoint and returns the computed delivery fee.
  Future<DeliveryPricingResult> calculate({
    double? distanceKm,
    double? distance,
    double? weightKg,
    double? weight,
    DeliveryPackageSize? packageSize,
    String? mode,
    String? department,
    num? orderTotal,
    Map<String, dynamic>? extra,
  }) async {
    final double? resolvedDistance = distanceKm ?? distance;
    if (resolvedDistance == null) {
      throw DeliveryPricingException(
        _translateDeliveryPricing(_deliveryDistanceRequiredKey),
      );
    }

    double? resolvedWeight = weightKg ?? weight;
    if (resolvedWeight == null && packageSize != null) {
      resolvedWeight = _config.weightForSize(packageSize);
    }

    final String? departmentCode = normalizeDeliveryDepartment(department);

    final Map<String, dynamic> payload = <String, dynamic>{
      'distance_km': resolvedDistance,
      if (resolvedWeight != null) 'weight_kg': resolvedWeight,
      if (mode != null && mode.trim().isNotEmpty) 'mode': mode.trim(),
      if (departmentCode != null) 'department': departmentCode,
      if (orderTotal != null) 'order_total': orderTotal,
    };

    if (extra != null) {
      for (final MapEntry<String, dynamic> entry in extra.entries) {
        if (entry.value != null) {
          payload.putIfAbsent(entry.key, () => entry.value);
        }
      }
    }

    final Uri uri = _resolveUri(_config.calculateEndpoint);

    try {
      final Response<dynamic> response = await _client.postUri(
        uri,
        data: payload,
        options: Options(headers: Api.headers()),
      );

      final Map<String, dynamic>? map = _mapify(response.data);
      if (map == null) {
        throw DeliveryPricingException(
          _translateDeliveryPricing(_deliveryUnexpectedResponseKey),
        );
      }

      if (_isFailure(map)) {
        throw DeliveryPricingException(
          _extractMessage(map) ??
              _translateDeliveryPricing('deliveryCalculationFailed'),
          statusCode: response.statusCode,
          payload: map,
        );
      }

      final Map<String, dynamic>? data = _extractData(map);
      return DeliveryPricingResult.fromPayload(
        payload: map,
        data: data ?? map,
      );
    } on DioException catch (error) {
      final Map<String, dynamic>? errorMap = _mapify(error.response?.data);
      throw DeliveryPricingException(
        _extractMessage(errorMap) ??
            error.message ??
            _translateDeliveryPricing('deliveryCalculationRequestFailed'),
        statusCode: error.response?.statusCode,
        payload: errorMap,
        cause: error,
      );
    }
  }

  /// Returns the inferred default weight for a given package size.
  double defaultWeightForSize(DeliveryPackageSize size) =>
      _config.weightForSize(size);

  Uri _resolveUri(String endpoint, [Map<String, dynamic>? query]) {
    final String trimmedEndpoint = endpoint.trim();
    final Uri uri = trimmedEndpoint.startsWith('http://') ||
            trimmedEndpoint.startsWith('https://')
        ? Uri.parse(trimmedEndpoint)
        : _baseUri.resolve(trimmedEndpoint.startsWith('/')
            ? trimmedEndpoint.substring(1)
            : trimmedEndpoint);

    if (query == null || query.isEmpty) {
      return uri;
    }

    final Map<String, String> normalized = <String, String>{};
    query.forEach((String key, dynamic value) {
      if (value == null) return;
      normalized[key] = value.toString();
    });

    return uri.replace(queryParameters: normalized);
  }

  Uri get _baseUri {
    final String base = _config.baseUrl.trim();
    if (base.isEmpty) {
      throw DeliveryPricingException(
        _translateDeliveryPricing(_deliveryPricingBaseUrlMissingKey),
      );
    }
    final String normalized = base.endsWith('/') ? base : '$base/';
    return Uri.parse(normalized);
  }

  static Map<String, dynamic>? _mapify(dynamic source) {
    if (source is Map<String, dynamic>) return source;
    if (source is Map) return Map<String, dynamic>.from(source as Map);
    return null;
  }

  static bool _isFailure(Map<String, dynamic> payload) {
    final dynamic status = payload['status'] ?? payload['success'];
    if (status is bool) return !status;
    if (status is num) return status == 0;
    return false;
  }

  static Map<String, dynamic>? _extractData(Map<String, dynamic> payload) {
    final dynamic data = payload['data'] ?? payload['result'];
    return _mapify(data);
  }

  static String? _extractMessage(Map<String, dynamic>? payload) {
    if (payload == null) return null;
    final dynamic message =
        payload['message'] ?? payload['error'] ?? payload['msg'];
    return message?.toString();
  }
}

const String _deliveryDistanceRequiredKey = 'deliveryDistanceRequired';
const String _deliveryUnexpectedResponseKey = 'deliveryUnexpectedResponse';
const String _deliveryPricingBaseUrlMissingKey =
    'deliveryPricingBaseUrlMissing';

String _translateDeliveryPricing(String key) {
  final BuildContext? context = Constant.navigatorKey.currentContext ??
      Constant.navigatorKey.currentState?.context;
  if (context != null) {
    return key.translate(context);
  }

  return key;
}

/// Normalised delivery pricing calculation payload returned by the API.
@immutable
class DeliveryPricingResult {
  const DeliveryPricingResult({
    this.total,
    this.totalDisplay,
    this.currency,
    this.isFree = false,
    this.mode,
    this.department,
    this.distanceKm,
    this.weightKg,
    this.policy,
    this.weightTier,
    this.rule,
    this.breakdown,
    this.policyId,
    this.weightTierId,
    this.ruleId,
    this.raw,
  });

  final num? total;
  final String? totalDisplay;
  final String? currency;
  final bool isFree;
  final String? mode;
  final String? department;
  final double? distanceKm;
  final double? weightKg;
  final Map<String, dynamic>? policy;
  final Map<String, dynamic>? weightTier;
  final Map<String, dynamic>? rule;
  final Map<String, dynamic>? breakdown;
  final String? policyId;
  final String? weightTierId;
  final String? ruleId;
  final Map<String, dynamic>? raw;

  String? get formattedTotal =>
      totalDisplay ?? (total != null ? total.toString() : null);

  factory DeliveryPricingResult.fromPayload({
    required Map<String, dynamic> payload,
    required Map<String, dynamic> data,
  }) {
    Map<String, dynamic>? breakdownMap;
    final dynamic breakdownRaw = data['breakdown'] ?? data['details'];
    if (breakdownRaw is Map<String, dynamic>) {
      breakdownMap = breakdownRaw;
    } else if (breakdownRaw is Map) {
      breakdownMap = Map<String, dynamic>.from(breakdownRaw as Map);
    } else if (breakdownRaw is List) {
      breakdownMap = <String, dynamic>{'items': breakdownRaw};
    }

    final Map<String, dynamic>? policyMap = _mapify(data['policy']);
    final Map<String, dynamic>? tierMap =
        _mapify(data['weight_tier'] ?? data['tier']);
    final Map<String, dynamic>? ruleMap = _mapify(data['rule']);

    final num? total = _asNum(_firstValue(data, const [
      ['total'],
      ['amount'],
      ['delivery_fee'],
      ['fee'],
      ['price'],
      ['total_fee'],
    ]));

    final String? totalDisplay = _asString(_firstValue(data, const [
      ['total_display'],
      ['amount_display'],
      ['delivery_fee_display'],
      ['fee_display'],
      ['formatted_total'],
      ['delivery_fee_text'],
    ]));

    final String? currency = _asString(_firstValue(data, const [
      ['currency'],
      ['currency_code'],
      ['currency_symbol'],
    ]));

    final bool isFree = _asBool(_firstValue(data, const [
          ['is_free'],
          ['free_shipping'],
          ['is_free_shipping'],
        ])) ??
        (total != null && total == 0);

    final String? mode = _asString(data['mode']);
    final String? departmentRaw = _asString(data['department']);
    final String? department =
        normalizeDeliveryDepartment(departmentRaw) ?? departmentRaw;

    final double? distanceKm = _asDouble(_firstValue(data, const [
      ['distance_km'],
      ['distance'],
      ['metrics', 'distance_km'],
      ['metrics', 'distance'],
    ]));

    final double? weightKg = _asDouble(_firstValue(data, const [
      ['weight_kg'],
      ['weight'],
      ['metrics', 'weight_kg'],
      ['metrics', 'weight'],
    ]));

    final String? policyId = _asString(_firstValue(data, const [
      ['policy_id'],
      ['policy', 'id'],
      ['policy', 'uuid'],
    ]));

    final String? tierId = _asString(_firstValue(data, const [
      ['weight_tier_id'],
      ['tier_id'],
      ['weight_tier', 'id'],
      ['tier', 'id'],
    ]));

    final String? ruleId = _asString(_firstValue(data, const [
      ['rule_id'],
      ['distance_rule_id'],
      ['rule', 'id'],
    ]));

    return DeliveryPricingResult(
      total: total,
      totalDisplay: totalDisplay,
      currency: currency,
      isFree: isFree,
      mode: mode,
      department: department,
      distanceKm: distanceKm,
      weightKg: weightKg,
      policy: policyMap,
      weightTier: tierMap,
      rule: ruleMap,
      breakdown: breakdownMap,
      policyId: policyId,
      weightTierId: tierId,
      ruleId: ruleId,
      raw: payload,
    );
  }

  static dynamic _firstValue(
    Map<String, dynamic> map,
    List<List<String>> paths,
  ) {
    for (final List<String> path in paths) {
      dynamic current = map;
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
    if (value == null) return null;
    if (value is String) return value;
    if (value is num || value is bool) return value.toString();
    return null;
  }

  static num? _asNum(dynamic value) {
    if (value == null) return null;
    if (value is num) return value;
    if (value is String) {
      final String normalized = value.replaceAll(',', '').trim();
      return num.tryParse(normalized);
    }
    return null;
  }

  static double? _asDouble(dynamic value) {
    final num? result = _asNum(value);
    return result?.toDouble();
  }

  static bool? _asBool(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is num) return value != 0;
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

  static Map<String, dynamic>? _mapify(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value as Map);
    return null;
  }
}
