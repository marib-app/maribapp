import 'dart:async';

import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import '../core/exceptions/app_exception.dart';
import '../utils/app_config.dart';
import 'auth_storage.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  final config = ref.watch(appConfigProvider);
  final storage = ref.watch(authStorageProvider);
  return ApiClient(config: config, storage: storage);
});

class ApiClient {
  ApiClient({
    required AppConfig config,
    required AuthStorage storage,
  }) : _storage = storage {
    _dio = Dio(
      BaseOptions(
        baseUrl: config.baseUrl,
        connectTimeout: config.connectTimeout,
        receiveTimeout: config.receiveTimeout,
        contentType: 'application/json',
        headers: const {'Accept': 'application/json'},
      ),
    )..interceptors.addAll(
        [
          InterceptorsWrapper(
            onRequest: (options, handler) async {
              final token = await _storage.readToken();
              if (token != null && token.isNotEmpty) {
                options.headers['Authorization'] = 'Bearer $token';
              }
              handler.next(options);
            },
            onError: (error, handler) async {
              if (error.response?.statusCode == 401) {
                await _storage.clear();
              }
              handler.next(error);
            },
          ),
          PrettyDioLogger(
            requestBody: true,
            responseBody: true,
            compact: true,
          ),
        ],
      );
  }

  late final Dio _dio;
  final AuthStorage _storage;

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
  }) {
    return _handle(() => _dio.get<T>(
          path,
          queryParameters: query,
          cancelToken: cancelToken,
        ));
  }

  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? query,
  }) {
    return _handle(() => _dio.post<T>(
          path,
          data: data,
          queryParameters: query,
        ));
  }

  Future<Response<T>> put<T>(
    String path, {
    Object? data,
  }) {
    return _handle(() => _dio.put<T>(path, data: data));
  }

  Future<Response<T>> delete<T>(
    String path, {
    Object? data,
  }) {
    return _handle(() => _dio.delete<T>(path, data: data));
  }

  Future<Response<T>> _handle<T>(
    Future<Response<T>> Function() runner,
  ) async {
    try {
      return await runner();
    } on DioException catch (error, stackTrace) {
      throw _mapException(error, stackTrace);
    } catch (error, stackTrace) {
      throw UnknownAppException(error.toString(), stackTrace);
    }
  }

  AppException _mapException(DioException error, StackTrace stackTrace) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError) {
      return NetworkException('Check the connection to the server', stackTrace);
    }

    final response = error.response;
    if (response == null) {
      return UnknownAppException(error.message ?? 'Unexpected error occurred', stackTrace);
    }

    if (response.statusCode == 401) {
      return const UnauthorizedException('Session expired');
    }

    if (response.statusCode == 422 && response.data is Map<String, dynamic>) {
      return ValidationException(
        Map<String, dynamic>.from(response.data as Map),
        stackTrace: stackTrace,
      );
    }

    return UnknownAppException(
      response.data?['message']?.toString() ?? 'Unknown error',
      stackTrace,
    );
  }
}
