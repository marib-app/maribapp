import 'package:marib/utils/logger.dart';

/// Lightweight telemetry helper that writes debug logs during development.
class AppTelemetry {
  const AppTelemetry._();

  /// Record a telemetry [event] with optional [context] metadata.
  static void record(String event, [Map<String, dynamic>? context]) {
    final Map<String, dynamic> safeContext =
    context == null ? <String, dynamic>{} : Map<String, dynamic>.from(context);

    final String payload = safeContext.entries.map((MapEntry<String, dynamic> entry) {
      final dynamic value = entry.value;
      final dynamic printable =
      (value is Map || value is Iterable) ? value : (value ?? 'null');
      return '${entry.key}=$printable';
    }).join(', ');

    if (payload.isEmpty) {
      Logger.debug(event, name: 'TELEMETRY');
    } else {
      Logger.debug('$event | $payload', name: 'TELEMETRY');
    }
  }
}