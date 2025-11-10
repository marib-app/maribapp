import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../core/exceptions/app_exception.dart';
import '../../core/network/api_result.dart';
import '../../services/api_client.dart';
import '../../services/auth_storage.dart';
import '../models/server_session.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  final storage = ref.watch(authStorageProvider);
  return AuthRepository(client: client, storage: storage);
});

class AuthRepository {
  AuthRepository({
    required ApiClient client,
    required AuthStorage storage,
  })  : _client = client,
        _storage = storage;

  final ApiClient _client;
  final AuthStorage _storage;

  Future<ApiResult<ServerSession>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        '/auth/login',
        data: {'email': email, 'password': password},
      );
      final payload = response.data ?? {};
      final session = ServerSession.fromJson(payload);
      await _storage.saveSession(session);
      return ApiSuccess(session);
    } on AppException catch (error) {
      return ApiFailure(error);
    } catch (error, stackTrace) {
      return ApiFailure(
        UnknownAppException(error.toString(), stackTrace),
      );
    }
  }

  Future<void> logout() async {
    try {
      await _client.post('/auth/logout');
    } on DioException {
      // ignore network issues on logout
    } finally {
      await _storage.clear();
    }
  }

  Future<ServerSession?> restoreSession() => _storage.readSession();
}
