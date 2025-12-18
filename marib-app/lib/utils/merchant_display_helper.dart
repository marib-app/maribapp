import 'package:marib/utils/seller_category_utils.dart'
    as seller_category_utils;

class MerchantDisplayHelper {
  const MerchantDisplayHelper._();

  static String resolveDisplayName({
    required bool isMerchant,
    dynamic store,
    dynamic additionalInfo,
    String? fallbackName,
  }) {
    final Map<String, dynamic>? normalizedStore = _normalizeStore(store);
    final String? trimmedFallback = _string(fallbackName);
    if (!isMerchant) {
      return trimmedFallback ?? '';
    }

    final String? storeName = _string(normalizedStore?['name']);
    if (storeName != null) {
      return storeName;
    }

    final Map<String, dynamic>? contact =
        seller_category_utils.extractContactInfo(additionalInfo);
    final String? contactName =
        _string(contact?['business_name']) ?? _string(contact?['office_name']);
    if (contactName != null) {
      return contactName;
    }

    return trimmedFallback ?? '';
  }

  static String? resolveProfileImage({
    required bool isMerchant,
    dynamic store,
    String? fallbackImage,
  }) {
    final Map<String, dynamic>? normalizedStore = _normalizeStore(store);
    final List<String?> candidates = <String?>[
      if (isMerchant) _string(normalizedStore?['logo_path']),
      if (isMerchant) _string(normalizedStore?['banner_path']),
      _string(fallbackImage),
    ];

    for (final String? candidate in candidates) {
      if (candidate != null && candidate.isNotEmpty) {
        return candidate;
      }
    }

    return null;
  }

  static Map<String, dynamic>? _normalizeStore(dynamic raw) {
    if (raw == null) {
      return null;
    }
    if (raw is Map<String, dynamic>) {
      return Map<String, dynamic>.from(raw);
    }
    if (raw is Map) {
      return raw
          .map((key, value) => MapEntry(key.toString(), value));
    }
    return null;
  }

  static String? _string(dynamic value) {
    if (value == null) {
      return null;
    }
    final String normalized = value.toString().trim();
    return normalized.isEmpty ? null : normalized;
  }
}
