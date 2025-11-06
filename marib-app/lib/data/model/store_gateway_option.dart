/// Lightweight representation of a store payment gateway option returned from
/// the backend for merchant onboarding.
class StoreGatewayOption {
  const StoreGatewayOption({
    required this.id,
    required this.name,
    this.logoUrl,
    this.isActive = true,
  });

  factory StoreGatewayOption.fromJson(Map<String, dynamic> json) {
    final dynamic rawId = json['id'];
    final int parsedId = switch (rawId) {
      int value => value,
      num value => value.toInt(),
      String value => int.tryParse(value.trim()) ?? 0,
      Object value => int.tryParse(value.toString()) ?? 0,
      _ => 0,
    };

    return StoreGatewayOption(
      id: parsedId,
      name: (json['name'] ?? '').toString(),
      logoUrl: json['logo_url']?.toString().trim().isEmpty ?? true
          ? null
          : json['logo_url'].toString(),
      isActive: _parseBool(json['is_active'], defaultValue: true),
    );
  }

  final int id;
  final String name;
  final String? logoUrl;
  final bool isActive;

  static bool _parseBool(dynamic value, {required bool defaultValue}) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized.isEmpty) return defaultValue;
      if (const {'1', 'true', 'yes', 'on', 'enabled'}.contains(normalized)) {
        return true;
      }
      if (const {'0', 'false', 'no', 'off', 'disabled'}.contains(normalized)) {
        return false;
      }
    }
    return defaultValue;
  }
}
