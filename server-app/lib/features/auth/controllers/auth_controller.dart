import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/exceptions/app_exception.dart';
import '../../../data/models/server_session.dart';
import '../../../data/repositories/auth_repository.dart';

final authControllerProvider =
    AsyncNotifierProvider<AuthController, ServerSession?>(
  AuthController.new,
);

class AuthController extends AsyncNotifier<ServerSession?> {
  late final AuthRepository _repository = ref.read(authRepositoryProvider);

  @override
  Future<ServerSession?> build() async {
    final session = await _repository.restoreSession();
    return session;
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    try {
      final result = await _repository.login(email: email, password: password);
      state = result.when(
        success: (session) => AsyncValue.data(session),
        failure: (error) => AsyncValue.error(error, StackTrace.current),
      );
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> logout() async {
    state = const AsyncValue.loading();
    try {
      await _repository.logout();
      state = const AsyncValue.data(null);
    } on AppException catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
}
