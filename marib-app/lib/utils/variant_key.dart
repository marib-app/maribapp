import 'dart:collection';
import 'dart:convert';

class VariantKeyCodec {
  const VariantKeyCodec._();

  /// Encodes the provided attribute map into the canonical variant key format.
  static String encode(Map<String, Object?> attributes) {
    if (attributes.isEmpty) {
      return '';
    }

    final Map<String, String> normalized = <String, String>{};
    attributes.forEach((Object? key, Object? value) {
      final String normalizedKey = _normalizeScalar(key);
      normalized[normalizedKey] = _canonicalizeValue(value);
    });

    final SplayTreeMap<String, String> ordered =
    SplayTreeMap<String, String>.from(normalized);
    final List<String> parts = <String>[];
    ordered.forEach((String key, String value) {
      parts.add('${Uri.encodeComponent(key)}=${Uri.encodeComponent(value)}');
    });

    return parts.join('|');
  }

  /// Parses a variant key (canonical or legacy) into an attribute map.
  static Map<String, String> decode(String variantKey) {
    final String trimmed = variantKey.trim();
    if (trimmed.isEmpty) {
      return <String, String>{};
    }

    final Map<String, String> attributes = <String, String>{};

    for (final String segment in trimmed.split('|')) {
      if (segment.isEmpty) {
        continue;
      }

      String key;
      String value;
      final int equalsIndex = segment.indexOf('=');
      if (equalsIndex >= 0) {
        key = Uri.decodeComponent(segment.substring(0, equalsIndex));
        value = Uri.decodeComponent(segment.substring(equalsIndex + 1));
      } else {
        final int colonIndex = segment.indexOf(':');
        if (colonIndex >= 0) {
          key = segment.substring(0, colonIndex);
          value = segment.substring(colonIndex + 1);
        } else {
          key = segment;
          value = '';
        }
      }

      key = key.trim();
      value = value.trim();

      if (key.isEmpty) {
        continue;
      }

      attributes[key] = value;
    }

    return attributes;
  }

  /// Normalizes any variant key string into the canonical representation.
  static String canonicalize(String variantKey) {
    final Map<String, String> attributes = decode(variantKey);
    if (attributes.isEmpty) {
      return '';
    }
    return encode(attributes);
  }

  /// Returns a human-readable representation of the variant key.
  static String describe(String variantKey) {
    final Map<String, String> attributes = decode(variantKey);
    if (attributes.isEmpty) {
      return variantKey;
    }

    final List<String> parts = <String>[];
    attributes.forEach((String key, String value) {
      if (value.isEmpty) {
        parts.add(key);
      } else {
        parts.add('$key: $value');
      }
    });

    return parts.join(' | ');
  }

  static String _normalizeScalar(Object? value) {
    if (value is String) {
      return value.trim();
    }
    if (value is num || value is bool) {
      return value.toString();
    }
    if (value == null) {
      return '';
    }
    return jsonEncode(value);
  }

  static String _canonicalizeValue(Object? value) {
    if (value == null) {
      return '';
    }
    if (value is bool) {
      return value ? '1' : '0';
    }
    if (value is num) {
      return value.toString();
    }
    if (value is String) {
      return value.trim();
    }
    if (value is List) {
      if (value.isEmpty) {
        return '';
      }
      final List<String> items =
      value.map((Object? item) => _canonicalizeValue(item)).toList();
      items.sort((String a, String b) => a.compareTo(b));
      return items.join(',');
    }
    if (value is Map) {
      if (value.isEmpty) {
        return '';
      }
      final Map<String, String> normalized = <String, String>{};
      value.forEach((Object? key, Object? val) {
        normalized[_normalizeScalar(key)] = _canonicalizeValue(val);
      });
      final SplayTreeMap<String, String> ordered =
      SplayTreeMap<String, String>.from(normalized);
      final List<String> parts = <String>[];
      ordered.forEach((String key, String val) {
        parts.add('$key:$val');
      });
      return parts.join(',');
    }
    return value.toString();
  }
}