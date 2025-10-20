import 'dart:convert';
import 'dart:developer';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';


class NetworkRequestInterseptor extends Interceptor {
  static const int _maxPreviewStringLength = 512;
  static const int _maxPreviewCollectionEntries = 20;

  int totalAPICallTimes = 0;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra['requestStartTime'] = DateTime.now();

    if (kReleaseMode) {
      handler.next(options);
      return;
    }
    totalAPICallTimes++;

    final normalizedData = options.data is FormData
        ? options.data.fields
        : options.data;

    final serializedData = normalizedData is Map
        ? normalizedData
        : normalizedData is String
        ? normalizedData
        : normalizedData?.toString();

    log(
        {
          "URL": options.path,
          "Parameters": options.method == "POST"
              ? serializedData
              : options.queryParameters,
          "Method": options.method,
          "_total_api_calls": totalAPICallTimes
        }.toString(),
        name: "Request-API");
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (!kReleaseMode) {
      final startTime = err.requestOptions.extra['requestStartTime'] as DateTime?;
      final duration =
      startTime != null ? DateTime.now().difference(startTime) : null;
      final response = err.response;
      final dynamic responseData = response?.data;
      final bool isBinaryResponse =
          response?.requestOptions.responseType == ResponseType.bytes ||
              _isBinaryData(responseData);
      final int? payloadSize = _calculatePayloadSize(responseData);
      final String? payloadPreview = isBinaryResponse
          ? null
          : _buildPayloadPreview(responseData);

      log(
          {
            "URL": err.requestOptions.path,
            "Type": err.type,
            "Error": err.error,
            "Message": err.message,
            if (response?.statusCode != null) "status": response?.statusCode,
            if (duration != null) "durationMs": duration.inMilliseconds,
            if (payloadSize != null) "payloadSize": payloadSize,
            if (isBinaryResponse) "payloadType": "binary",
            if (payloadPreview != null) "payloadPreview": payloadPreview,
          }.toString(),
          name: "API-Error");
    }

    handler.next(err);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (!kReleaseMode) {
      final startTime =
      response.requestOptions.extra['requestStartTime'] as DateTime?;
      final duration =
      startTime != null ? DateTime.now().difference(startTime) : null;
      final bool isBinaryResponse =
          response.requestOptions.responseType == ResponseType.bytes ||
              _isBinaryData(response.data);
      final int? payloadSize = _calculatePayloadSize(response.data);
      final String? payloadPreview = isBinaryResponse
          ? null
          : _buildPayloadPreview(response.data);

      log(
          {
            "URL": response.requestOptions.path,
            "Method": response.requestOptions.method,
            "status": response.statusCode,
            "statusMessage": response.statusMessage,
            if (duration != null) "durationMs": duration.inMilliseconds,
            if (payloadSize != null) "payloadSize": payloadSize,
            if (isBinaryResponse) "payloadType": "binary",
            if (payloadPreview != null) "payloadPreview": payloadPreview,
          }.toString(),
          name: "Response-API");
    }
    handler.next(response);
  }


  int? _calculatePayloadSize(dynamic data) {
    if (data == null) {
      return null;
    }
    if (data is Uint8List) {
      return data.length;
    }
    if (data is List<int>) {
      return data.length;
    }
    if (data is String) {
      return utf8.encode(data).length;
    }
    if (data is List || data is Map) {
      return data.length;
    }
    if (data is Iterable) {
      return data.length;
    }
    return null;
  }

  bool _isBinaryData(dynamic data) {
    return data is Uint8List || data is List<int>;
  }

  String? _buildPayloadPreview(dynamic data) {
    if (data == null) {
      return null;
    }
    if (data is String) {
      if (data.length <= _maxPreviewStringLength) {
        return data;
      }
      return '${data.substring(0, _maxPreviewStringLength)}…';
    }

    if (data is Map) {
      if (data.length <= _maxPreviewCollectionEntries) {
        try {
          return jsonEncode(data);
        } catch (_) {
          return 'Map(${data.length})';
        }
      }
      return 'Map(${data.length})';
    }

    if (data is List) {
      if (data.length <= _maxPreviewCollectionEntries) {
        try {
          return jsonEncode(data);
        } catch (_) {
          return 'List(${data.length})';
        }
      }
      return 'List(${data.length})';
    }

    return data.toString();
  }

}
