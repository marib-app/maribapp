import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:marib/data/model/orders/user_order.dart';
import 'package:marib/utils/api.dart';
import 'package:marib/utils/constant.dart';
import 'package:marib/utils/network_request_interseptor.dart';

class OrdersRepository {
  const OrdersRepository();

  Future<List<UserOrder>> fetchOrders({
    Map<String, dynamic>? filters,
  }) async {
    final Map<String, dynamic>? query =
        filters == null ? null : Map<String, dynamic>.from(filters);
    query?.removeWhere((key, value) => value == null);

    final Map<String, dynamic> response = await Api.get(
      url: Api.userOrdersApi,
      queryParameters: query,
      useBaseUrl: true,
    );

    final List<Map<String, dynamic>> rows = _extractOrders(response);
    return rows.map(UserOrder.fromJson).toList();
  }

  Future<OrderDetails> fetchOrderDetails(String id) async {
    final Map<String, dynamic> response = await Api.get(
      url: '${Api.userOrdersApi}/$id',
      useBaseUrl: true,
    );
    return OrdersRepository.parseOrderDetailsResponse(response);
  }

  Future<OrderDetails> cancelOrder(String id) async {
    final Map<String, dynamic> response = await Api.post(
      url: '${Api.userOrdersApi}/$id/cancel',
      useBaseUrl: true,
    );

    return OrdersRepository.parseOrderDetailsResponse(response);
  }

  Future<InvoiceDownloadResult> fetchInvoicePdf(String id) async {
    final Dio dio = Dio();
    dio.options.followRedirects = false;
    dio.options.validateStatus = (status) => status != null && status < 400;
    if (Api.networkLoggingEnabled) {
      dio.interceptors.add(NetworkRequestInterseptor());
    }

    final String url = '${Api.userOrdersApi}/$id/invoice.pdf';
    final String requestUrl = Constant.baseUrl + url;

    try {
      final Response<dynamic> response = await dio.get<dynamic>(
        requestUrl,
        options: Options(
          headers: Api.headers(),
          followRedirects: false,
          responseType: ResponseType.bytes,
        ),
      );

      final List<int> rawBytes = _normalizeBytes(response.data);
      final String? contentType =
          response.headers.value(HttpHeaders.contentTypeHeader)?.toLowerCase();
      final bool isHtmlResponse =
          contentType != null && contentType.contains('text/html');

      if (contentType != null && contentType.contains('application/pdf')) {
        final String? fileName = _resolveFileName(response.headers);
        return InvoiceDownloadResult.bytes(
          Uint8List.fromList(rawBytes),
          fileName: fileName,
        );
      }

      if (contentType != null && contentType.contains('application/json')) {
        final dynamic payload = jsonDecode(utf8.decode(rawBytes));
        final String? url = _extractUrl(payload);
        if (url != null) {
          return InvoiceDownloadResult.link(url);
        }
      }

      final String decoded = utf8.decode(rawBytes, allowMalformed: true).trim();
      if (isHtmlResponse || _looksLikeHtml(decoded)) {
        return InvoiceDownloadResult.html(
          decoded,
          fileName: 'invoice-$id.html',
        );
      }
      final String? urlFromText = _extractUrl(decoded);
      if (urlFromText != null) {
        return InvoiceDownloadResult.link(urlFromText);
      }

      throw const FormatException('Unexpected invoice response format.');
    } on DioException catch (error) {
      final int? statusCode = error.response?.statusCode;
      if (statusCode == 401 || statusCode == 302 || statusCode == 307) {
        Api.userExpired();
        if (statusCode != 401) {
          throw ApiHttpException(
            errorMessage: 'unauthenticated',
            statusCode: 401,
            payload: error.response?.data,
            cause: error,
          );
        }
      }
      if (statusCode == 503) {
        throw 'server-not-available';
      }

      throw ApiHttpException(
        errorMessage: error.error is SocketException
            ? 'no-internet'
            : 'Something went wrong with error ${error.response?.statusCode}',
        statusCode: statusCode,
        payload: error.response?.data,
        cause: error,
      );
    } on ApiException {
      rethrow;
    } on FormatException {
      rethrow;
    } catch (error) {
      throw ApiException(error.toString());
    }
  }

  bool _looksLikeHtml(String value) {
    final String normalized = value.trimLeft().toLowerCase();
    if (normalized.isEmpty) {
      return false;
    }

    return normalized.startsWith('<!doctype html') ||
        normalized.startsWith('<html') ||
        (normalized.contains('<html') && normalized.contains('<body'));
  }

  static OrderDetails parseOrderDetailsResponse(
    Map<String, dynamic> response,
  ) {
    final List<Map<String, dynamic>> extracted = _extractOrders(response);
    Map<String, dynamic>? order = extracted.isNotEmpty ? extracted.first : null;

    order ??= _mapify(
      response['data'] ??
          response['order'] ??
          response['result'] ??
          response['payload'],
    );

    if (order == null) {
      final dynamic data = response['data'];
      if (data is Map) {
        order = _mapify(data['order']) ?? _mapify(data['result']);
      }
    }

    order ??= _mapify(response);

    if (order == null) {
      throw const FormatException(
          'Order details are missing from the response.');
    }

    final Map<String, dynamic> normalized = Map<String, dynamic>.from(order);

    const Set<String> structuralKeys = <String>{
      'status_timestamps',
      'payment_summary',
      'delivery_payment_summary',
      'payment_intent',
      'deposit_receipts',
    };

    for (final String key in structuralKeys) {
      _copyIfMissing(normalized, key, response);
    }

    final Map<String, List<String>> aliasKeys = <String, List<String>>{
      'status_display': <String>[
        'status_display',
        'statusDisplay',
        'order_status_display',
        'status_display_data',
      ],
      'status_reserve_options': <String>[
        'status_reserve_options',
        'statusReserveOptions',
        'order_status_reserve',
        'status_reserve',
      ],
      'actions': <String>[
        'actions',
        'order_actions',
        'orderActions',
        'available_actions',
      ],
    };

    for (final MapEntry<String, List<String>> entry in aliasKeys.entries) {
      _ensureAlias(normalized, entry.key, entry.value, response);
    }

    final Map<String, dynamic>? policyMap = _mapify(normalized['policy']) ??
        _findMapByPaths(
          response,
          const <List<String>>[
            <String>['policy'],
            <String>['data', 'policy'],
            <String>['data', 'policies', 'return'],
            <String>['data', 'order', 'policy'],
            <String>['order', 'policy'],
            <String>['result', 'policy'],
            <String>['result', 'order', 'policy'],
            <String>['section', 'policy'],
            <String>['department', 'policy'],
          ],
        );

    final Map<String, dynamic>? supportMap = _mapify(normalized['support']) ??
        _findMapByPaths(
          response,
          const <List<String>>[
            <String>['support'],
            <String>['data', 'support'],
            <String>['data', 'order', 'support'],
            <String>['order', 'support'],
            <String>['result', 'support'],
            <String>['result', 'order', 'support'],
            <String>['section', 'support'],
            <String>['department', 'support'],
          ],
        );

    final Map<String, dynamic>? paymentSummary =
        _mapify(normalized['payment_summary'] ?? normalized['paymentSummary']);

    final Map<String, dynamic>? deliveryPaymentSummary = _mapify(
      normalized['delivery_payment_summary'] ??
          normalized['deliveryPaymentSummary'],
    );

    final Map<String, dynamic>? depositReceipts = _wrapDepositReceipts(
            normalized['deposit_receipts'] ?? normalized['depositReceipts']) ??
        _wrapDepositReceipts(
            response['deposit_receipts'] ?? response['depositReceipts']);

    final Map<String, dynamic>? depositSummary = _mapify(
      normalized['deposit_summary'] ?? normalized['depositSummary'],
    );

    final UserOrder orderModel = UserOrder.fromJson(normalized);
    final OrderPolicy? policy =
        policyMap != null ? OrderPolicy.fromJson(policyMap) : null;
    final OrderSupport? support =
        supportMap != null ? OrderSupport.fromJson(supportMap) : null;

    return OrderDetails(
      order: orderModel,
      policy: policy,
      support: support,
      paymentSummary: paymentSummary,
      deliveryPaymentSummary: deliveryPaymentSummary,
      depositReceipts: depositReceipts,
      raw: Map<String, dynamic>.from(response),
      depositSummary: depositSummary,
    );
  }

  static List<Map<String, dynamic>> _extractOrders(
      Map<String, dynamic> payload) {
    final List<Map<String, dynamic>> results = <Map<String, dynamic>>[];
    final List<dynamic>? directList =
        _findListByPaths(payload, const <List<String>>[
      <String>['data', 'orders'],
      <String>['data', 'items'],
      <String>['data', 'data'],
      <String>['data'],
      <String>['orders'],
      <String>['result', 'orders'],
      <String>['result', 'data'],
      <String>['result'],
    ]);

    if (directList != null) {
      for (final dynamic entry in directList) {
        final Map<String, dynamic>? map = _mapify(entry);
        if (map != null) {
          results.add(map);
        }
      }
      return results;
    }

    final dynamic data = payload['data'] ?? payload['result'];
    if (data is List) {
      for (final dynamic entry in data) {
        final Map<String, dynamic>? map = _mapify(entry);
        if (map != null) {
          results.add(map);
        }
      }
    } else if (data is Map) {
      final Map<String, dynamic> normalized =
          Map<String, dynamic>.from(data as Map);
      for (final dynamic entry in normalized.values) {
        if (entry is List) {
          for (final dynamic item in entry) {
            final Map<String, dynamic>? map = _mapify(item);
            if (map != null) {
              results.add(map);
            }
          }
        }
      }
    }

    return results;
  }

  static List<dynamic>? _findListByPaths(
    Map<String, dynamic> payload,
    List<List<String>> candidates,
  ) {
    for (final List<String> path in candidates) {
      dynamic current = payload;
      var success = true;
      for (final String segment in path) {
        if (current is Map && current.containsKey(segment)) {
          current = current[segment];
        } else {
          success = false;
          break;
        }
      }

      if (success && current is List) {
        return current;
      }
    }

    return null;
  }

  static dynamic _findValueByPaths(
    Map<String, dynamic> payload,
    List<List<String>> candidates,
  ) {
    for (final List<String> path in candidates) {
      dynamic current = payload;
      var success = true;
      for (final String segment in path) {
        if (current is Map && current.containsKey(segment)) {
          current = current[segment];
        } else {
          success = false;
          break;
        }
      }

      if (success && current != null) {
        return current;
      }
    }

    return null;
  }

  static Map<String, dynamic>? _findMapByPaths(
    Map<String, dynamic> payload,
    List<List<String>> candidates,
  ) {
    final dynamic value = _findValueByPaths(payload, candidates);
    return _mapify(value);
  }

  static void _copyIfMissing(
    Map<String, dynamic> target,
    String key,
    Map<String, dynamic> response,
  ) {
    if (target.containsKey(key)) {
      return;
    }

    if (response.containsKey(key)) {
      final dynamic value = response[key];
      _assignValue(target, key, value);
      return;
    }

    for (final String containerKey in const <String>[
      'data',
      'result',
      'payload',
      'order'
    ]) {
      final dynamic container = response[containerKey];
      if (container is Map<String, dynamic>) {
        if (container.containsKey(key)) {
          _assignValue(target, key, container[key]);
          return;
        }
      } else if (container is Map) {
        final Map<String, dynamic> map =
            Map<String, dynamic>.from(container as Map);
        if (map.containsKey(key)) {
          _assignValue(target, key, map[key]);
          return;
        }
      }
    }
  }

  static void _ensureAlias(
    Map<String, dynamic> target,
    String canonicalKey,
    List<String> aliases,
    Map<String, dynamic> response,
  ) {
    if (target.containsKey(canonicalKey) && target[canonicalKey] != null) {
      return;
    }

    for (final String alias in aliases) {
      if (target.containsKey(alias) && target[alias] != null) {
        _assignValue(target, canonicalKey, target[alias]);
        return;
      }
    }

    final List<Map<String, dynamic>> candidates = <Map<String, dynamic>>[
      response
    ];

    for (final String key in const <String>[
      'data',
      'order',
      'result',
      'payload'
    ]) {
      final dynamic value = response[key];
      if (value is Map<String, dynamic>) {
        candidates.add(value);
      } else if (value is Map) {
        candidates.add(Map<String, dynamic>.from(value as Map));
      }
    }

    for (final Map<String, dynamic> candidate in candidates) {
      for (final String alias in aliases) {
        if (candidate.containsKey(alias) && candidate[alias] != null) {
          _assignValue(target, canonicalKey, candidate[alias]);
          return;
        }
      }
    }
  }

  static void _assignValue(
    Map<String, dynamic> target,
    String key,
    dynamic value,
  ) {
    if (value == null) {
      return;
    }

    if (value is Map<String, dynamic>) {
      target[key] = Map<String, dynamic>.from(value);
    } else if (value is Map) {
      target[key] = Map<String, dynamic>.from(value as Map);
    } else {
      target[key] = value;
    }
  }

  static Map<String, dynamic>? _mapify(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value as Map);
    return null;
  }

  static Map<String, dynamic>? _wrapDepositReceipts(dynamic value) {
    if (value == null) {
      return null;
    }

    final Map<String, dynamic>? mapified = _mapify(value);
    if (mapified != null) {
      return mapified;
    }

    if (value is Iterable) {
      final List<Map<String, dynamic>> entries = <Map<String, dynamic>>[];
      for (final dynamic element in value) {
        final Map<String, dynamic>? map = _mapify(element);
        if (map != null) {
          entries.add(map);
        }
      }
      if (entries.isEmpty) {
        return null;
      }
      return <String, dynamic>{'items': entries};
    }

    return null;
  }

  List<int> _normalizeBytes(dynamic data) {
    if (data == null) {
      return <int>[];
    }

    if (data is List<int>) {
      return List<int>.from(data);
    }

    if (data is Uint8List) {
      return data.toList();
    }

    if (data is List<dynamic>) {
      return data.map((dynamic value) {
        if (value is int) return value;
        if (value is num) return value.toInt();
        if (value is String) {
          final int? parsed = int.tryParse(value);
          return parsed ?? 0;
        }
        return 0;
      }).toList();
    }

    if (data is String) {
      return utf8.encode(data);
    }

    throw const FormatException('Unsupported response data type.');
  }

  String? _resolveFileName(Headers headers) {
    const String contentDispositionHeader = 'content-disposition';
    final String? disposition = headers.value(contentDispositionHeader);
    if (disposition == null) {
      return null;
    }

    final RegExpMatch? encodedMatch =
        RegExp("filename\*=UTF-8''([^;]+)").firstMatch(disposition);
    if (encodedMatch != null && encodedMatch.groupCount >= 1) {
      return Uri.decodeFull(encodedMatch.group(1)!);
    }

    final RegExpMatch? simpleMatch =
        RegExp("filename=\"?([^\";]+)\"?").firstMatch(disposition);
    if (simpleMatch != null && simpleMatch.groupCount >= 1) {
      return simpleMatch.group(1);
    }

    return null;
  }

  String? _extractUrl(dynamic payload) {
    if (payload == null) {
      return null;
    }

    if (payload is String) {
      final String trimmed = payload.trim();
      return _isValidUrl(trimmed) ? trimmed : null;
    }

    if (payload is Iterable) {
      for (final dynamic element in payload) {
        final String? candidate = _extractUrl(element);
        if (candidate != null) {
          return candidate;
        }
      }
      return null;
    }

    if (payload is Map) {
      final Map<dynamic, dynamic> rawMap = payload;
      for (final dynamic key in rawMap.keys) {
        final String keyString = key.toString();
        if (_isInvoiceUrlKey(keyString)) {
          final String? candidate = _extractUrl(rawMap[key]);
          if (candidate != null) {
            return candidate;
          }
        }
      }

      for (final dynamic value in rawMap.values) {
        final String? candidate = _extractUrl(value);
        if (candidate != null) {
          return candidate;
        }
      }
    }

    return null;
  }

  bool _isInvoiceUrlKey(String key) {
    const List<String> keys = <String>[
      'invoice_url',
      'invoiceUrl',
      'invoice',
      'invoice_link',
      'invoiceLink',
      'receipt_url',
      'receiptUrl',
      'receipt',
      'receipt_link',
      'receiptLink',
      'url',
      'link',
      'href',
    ];

    final String lower = key.toLowerCase();
    return keys.any((String candidate) =>
        candidate.toLowerCase() == lower ||
        lower.contains(candidate.toLowerCase()));
  }

  bool _isValidUrl(String value) {
    if (value.isEmpty) {
      return false;
    }
    final Uri? uri = Uri.tryParse(value);
    if (uri == null) {
      return false;
    }
    if (!uri.hasScheme) {
      return false;
    }
    return uri.scheme == 'http' || uri.scheme == 'https';
  }
}

class InvoiceDownloadResult {
  const InvoiceDownloadResult._({
    this.bytes,
    this.fileName,
    this.downloadUrl,
    this.html,
  });

  final Uint8List? bytes;
  final String? fileName;
  final String? downloadUrl;
  final String? html;

  bool get hasBytes => bytes != null && bytes!.isNotEmpty;

  bool get hasDownloadUrl =>
      downloadUrl != null && downloadUrl!.trim().isNotEmpty;

  bool get hasHtml => html != null && html!.trim().isNotEmpty;

  factory InvoiceDownloadResult.bytes(Uint8List bytes, {String? fileName}) {
    return InvoiceDownloadResult._(bytes: bytes, fileName: fileName);
  }

  factory InvoiceDownloadResult.link(String url) {
    return InvoiceDownloadResult._(downloadUrl: url);
  }

  factory InvoiceDownloadResult.html(String html, {String? fileName}) {
    return InvoiceDownloadResult._(html: html, fileName: fileName);
  }
}
