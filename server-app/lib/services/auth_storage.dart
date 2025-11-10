import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../data/models/server_session.dart';

final authStorageProvider = Provider<AuthStorage>(
  (ref) => AuthStorage(const FlutterSecureStorage()),
);

class AuthStorage {
  const AuthStorage(this._secureStorage);

  final FlutterSecureStorage _secureStorage;

  static const _tokenKey = 'server_token';
  static const _sessionKey = 'server_session';

  Future<void> saveSession(ServerSession session) async {
    await _secureStorage.write(key: _tokenKey, value: session.token);
    await _secureStorage.write(
      key: _sessionKey,
      value: jsonEncode(session.toJson()),
    );
  }

  Future<String?> readToken() => _secureStorage.read(key: _tokenKey);

  Future<ServerSession?> readSession() async {
    final value = await _secureStorage.read(key: _sessionKey);
    if (value == null) return null;
    final decoded = jsonDecode(value) as Map<String, dynamic>;
    return ServerSession.fromJson(decoded);
  }

  Future<void> clear() => _secureStorage.deleteAll();
}
