import 'dart:developer';
import 'dart:typed_data';
import 'package:marib/settings.dart';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class NetworkRequestInterseptor extends Interceptor {
  static const int _maxPreviewStringLength = 256;
  static const int _maxPreviewCollectionEntries = 10;

  int totalAPICallTimes = 0;

  bool get _isLoggingEnabled =>
      !kReleaseMode && AppSettings.isNetworkLoggingEnabled;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (!_isLoggingEnabled) {
      handler.next(options);
      return;
    }
    options.extra['requestStartTime'] = DateTime.now();
    options.extra['requestSequence'] = ++totalAPICallTimes;

    final Map<String, dynamic> logEntry = <String, dynamic>{
      'url': options.uri.toString(),
      'method': options.method,
      'sequence': options.extra['requestSequence'],
    };

    if (options.queryParameters.isNotEmpty) {
      logEntry['query'] = <String, dynamic>{
        'count': options.queryParameters.length,
        'keys': options.queryParameters.keys
            .take(_maxPreviewCollectionEntries)
            .map((dynamic key) => key.toString())
            .toList(growable: false),
      };
    }

    final Map<String, dynamic>? payloadSummary =
        _summarizePayload(options.data);
    if (payloadSummary != null) {
      logEntry['payload'] = payloadSummary;
    }

    log('$logEntry', name: 'Request-API');
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (!_isLoggingEnabled) {
      handler.next(err);
      return;
    }
    final DateTime? startTime =
        err.requestOptions.extra['requestStartTime'] as DateTime?;
    final Duration? duration =
        startTime != null ? DateTime.now().difference(startTime) : null;
    final Response<dynamic>? response = err.response;
    final dynamic responseData = response?.data;
    final bool isBinaryResponse =
        response?.requestOptions.responseType == ResponseType.bytes ||
            _isBinaryData(responseData);

    final Map<String, dynamic> logEntry = <String, dynamic>{
      'url': err.requestOptions.uri.toString(),
      'method': err.requestOptions.method,
      'type': err.type.toString(),
      'sequence': err.requestOptions.extra['requestSequence'],
      if (response?.statusCode != null) 'status': response!.statusCode,
      if (duration != null) 'durationMs': duration.inMilliseconds,
      if (err.message != null) 'message': err.message,
    };

    if (isBinaryResponse) {
      final int? payloadSize = _binaryLength(responseData);
      logEntry['payload'] = <String, dynamic>{
        'type': 'binary',
        if (payloadSize != null) 'size': payloadSize,
      };
    } else {
      final Map<String, dynamic>? payloadSummary =
          _summarizePayload(responseData);
      if (payloadSummary != null) {
        logEntry['payload'] = payloadSummary;
      }
    }

    log('$logEntry', name: 'API-Error');
    handler.next(err);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (!_isLoggingEnabled) {
      handler.next(response);
      return;
    }

    final DateTime? startTime =
        response.requestOptions.extra['requestStartTime'] as DateTime?;
    final Duration? duration =
        startTime != null ? DateTime.now().difference(startTime) : null;
    final bool isBinaryResponse =
        response.requestOptions.responseType == ResponseType.bytes ||
            _isBinaryData(response.data);

    final Map<String, dynamic> logEntry = <String, dynamic>{
      'url': response.requestOptions.uri.toString(),
      'method': response.requestOptions.method,
      'status': response.statusCode,
      'sequence': response.requestOptions.extra['requestSequence'],
      if (response.statusMessage?.isNotEmpty ?? false)
        'statusMessage': response.statusMessage,
      if (duration != null) 'durationMs': duration.inMilliseconds,
    };

    if (isBinaryResponse) {
      final int? payloadSize = _binaryLength(response.data);
      logEntry['payload'] = <String, dynamic>{
        'type': 'binary',
        if (payloadSize != null) 'size': payloadSize,
      };
    } else {
      final Map<String, dynamic>? payloadSummary =
          _summarizePayload(response.data);
      if (payloadSummary != null) {
        logEntry['payload'] = payloadSummary;
      }
    }
    log('$logEntry', name: 'Response-API');
    handler.next(response);
  }

  bool _isBinaryData(dynamic data) {
    return data is Uint8List || data is List<int>;
  }

  int? _binaryLength(dynamic data) {
    if (data is Uint8List) {
      return data.lengthInBytes;
    }
    if (data is List<int>) {
      return data.length;
    }

    return null;
  }

  Map<String, dynamic>? _summarizePayload(dynamic data) {
    if (data == null) {
      return null;
    }

    if (data is FormData) {
      return <String, dynamic>{
        'type': 'form-data',
        if (data.fields.isNotEmpty)
          'fieldKeys': data.fields
              .take(_maxPreviewCollectionEntries)
              .map((MapEntry<String, String> entry) => entry.key)
              .toList(growable: false),
        if (data.fields.isNotEmpty) 'fieldCount': data.fields.length,
        if (data.files.isNotEmpty)
          'fileKeys': data.files
              .take(_maxPreviewCollectionEntries)
              .map((MapEntry<String, MultipartFile> entry) => entry.key)
              .toList(growable: false),
        if (data.files.isNotEmpty) 'fileCount': data.files.length,
      };
    }

    if (_isBinaryData(data)) {
      final int? size = _binaryLength(data);
      return <String, dynamic>{
        'type': 'binary',
        if (size != null) 'size': size,
      };
    }

    if (data is Map) {
      return <String, dynamic>{
        'type': 'map',
        'entries': data.length,
        if (data.isNotEmpty)
          'keys': data.keys
              .take(_maxPreviewCollectionEntries)
              .map((dynamic key) => key.toString())
              .toList(growable: false),
      };
    }

    if (data is List) {
      return <String, dynamic>{
        'type': 'list',
        'length': data.length,
        if (data.isNotEmpty) 'firstType': data.first.runtimeType.toString(),
      };
    }
    if (data is String) {
      final bool truncated = data.length > _maxPreviewStringLength;
      final String preview =
          truncated ? '${data.substring(0, _maxPreviewStringLength)}…' : data;

      return <String, dynamic>{
        'type': 'string',
        'length': data.length,
        if (preview.isNotEmpty) 'preview': preview,
        if (truncated) 'truncated': true,
      };
    }

    if (data is num || data is bool) {
      return <String, dynamic>{
        'type': data.runtimeType.toString(),
        'value': data,
      };
    }

    return <String, dynamic>{
      'type': data.runtimeType.toString(),
    };
  }
}
