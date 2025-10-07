import 'dart:developer';

import 'package:dio/dio.dart';


class NetworkRequestInterseptor extends Interceptor {
  int totalAPICallTimes = 0;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler)
  {
    totalAPICallTimes++;

    final normalizedData = options.data is FormData
        ? options.data.fields
        : options.data;

    final serializedData = normalizedData is Map
        ? normalizedData
        : normalizedData is String
        ? normalizedData
        : normalizedData?.toString();

    log({
      "URL": options.path,
      "Parameters": options.method == "POST"
          ? serializedData
          : options.queryParameters,
      "Method": options.method,
      "_total_api_calls": totalAPICallTimes
    }.toString(),name:"Request-API");
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    log({
      "URL": err.response?.requestOptions.path ?? "",
      "Type": err.type,
      "Error": err.error,
      "Message": err.message,
    }.toString(),name: "API-Error");

    handler.next(err);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    log({
      "URL": response.requestOptions.path,
      "Method": response.requestOptions.method,
      "status": response.statusCode,
      "statusMessage": response.statusMessage,
      "response": response.data,
    }.toString(),name: "Response-API");
    handler.next(response);
  }
}
