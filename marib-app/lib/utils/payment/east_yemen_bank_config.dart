class EastYemenBankConfig {
  EastYemenBankConfig({
    required this.enabled,
    required this.displayName,
    this.note,
    this.logoUrl,
    this.currencyCode,
    this.accountName,
    this.accountNumber,
    this.iban,
    this.branch,
    Map<String, dynamic>? raw,
  }) : raw = raw == null
      ? const <String, dynamic>{}
      : Map<String, dynamic>.unmodifiable(Map<String, dynamic>.from(raw));

  final bool enabled;
  final String displayName;
  final String? note;
  final String? logoUrl;
  final String? currencyCode;
  final String? accountName;
  final String? accountNumber;
  final String? iban;
  final String? branch;
  final Map<String, dynamic> raw;

  bool get isEnabled => enabled;

  static bool _asBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is num) return value != 0;
    final normalized = value.toString().trim().toLowerCase();
    if (normalized.isEmpty) return false;
    return {
      '1',
      'true',
      'yes',
      'y',
      'on',
      'enabled',
      'active',
    }.contains(normalized);
  }

  static String? _asString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    return value.toString();
  }

  factory EastYemenBankConfig.fromMap(Map<String, dynamic> map) {
    final String? name = _asString(map['display_name'] ??
        map['name'] ??
        map['title'] ??
        map['label']);

    final String resolvedName = (name ?? '').trim().isEmpty
        ? 'بنك الشرق اليمني'
        : name!.trim();

    String? stringFromKeys(List<String> keys) {
      for (final key in keys) {
        if (!map.containsKey(key)) continue;
        final value = _asString(map[key]);
        if (value != null && value.trim().isNotEmpty) {
          return value.trim();
        }
      }
      return null;
    }

    final bool enabled = _asBool(map['enabled'] ??
        map['status'] ??
        map['is_enabled'] ??
        map['isEnabled'] ??
        map['active']);

    final Map<String, dynamic> raw = Map<String, dynamic>.from(map);

    return EastYemenBankConfig(
      enabled: enabled,
      displayName: resolvedName,
      note: stringFromKeys(const ['note', 'notes', 'description', 'help_text']),
      logoUrl: stringFromKeys(const ['logo_url', 'logo', 'image']),
      currencyCode: stringFromKeys(
          const ['currency', 'currency_code', 'currencyCode']),
      accountName: stringFromKeys(
          const ['account_name', 'beneficiary_name', 'recipient_name']),
      accountNumber:
      stringFromKeys(const ['account_number', 'number', 'accountNumber']),
      iban: stringFromKeys(const ['iban', 'iban_number']),
      branch: stringFromKeys(const ['branch', 'branch_name']),
      raw: raw,
    );
  }
}