import 'package:hooks_riverpod/hooks_riverpod.dart';

const String _defaultBaseUrl = String.fromEnvironment(
  'MARIB_ADMIN_API_BASE',
  defaultValue: 'http://192.168.1.25:8000/api',
);

class AppConfig {
  const AppConfig({
    required this.baseUrl,
    this.connectTimeout = const Duration(seconds: 20),
    this.receiveTimeout = const Duration(seconds: 25),
  });

  final String baseUrl;
  final Duration connectTimeout;
  final Duration receiveTimeout;
}

final appConfigProvider = Provider<AppConfig>(
  (ref) => AppConfig(baseUrl: _defaultBaseUrl),
);
