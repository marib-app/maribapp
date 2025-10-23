import 'dart:convert';

/// Utility helpers to extract seller category identifiers from loosely typed
/// payloads coming from the backend (maps, JSON strings, comma separated values
/// and so on). The identifiers are exposed as strongly typed [List]s of
/// integers or strings so callers can safely forward them to other layers.
class SellerCategoryIdentifiers {
  final List<int> numericIds;
  final List<String> textualIds;

  const SellerCategoryIdentifiers._(this.numericIds, this.textualIds);

  /// Empty identifiers placeholder.
  static const SellerCategoryIdentifiers empty =
  SellerCategoryIdentifiers._(<int>[], <String>[]);

  factory SellerCategoryIdentifiers({
    Iterable<int> numeric = const <int>[],
    Iterable<String> textual = const <String>[],
  }) {
    return SellerCategoryIdentifiers._(
      List<int>.unmodifiable(numeric),
      List<String>.unmodifiable(textual),
    );
  }

  bool get hasNumeric => numericIds.isNotEmpty;

  bool get hasTextual => textualIds.isNotEmpty;

  bool get hasValues => hasNumeric || hasTextual;

  /// Returns the most suitable payload for route arguments.
  ///
  /// Prefers numeric identifiers when available, otherwise falls back to the
  /// textual identifiers list. Returns `null` when no identifiers are present.
  dynamic toRoutePayload() {
    if (hasNumeric) {
      return numericIds;
    }
    if (hasTextual) {
      return textualIds;
    }
    return null;
  }
}

/// Parses the `business_categories` field in [contactInfo] and returns
/// strongly-typed identifiers.
SellerCategoryIdentifiers extractSellerCategoryIdentifiers(
    Map<String, dynamic>? contactInfo) {
  if (contactInfo == null) {
    return SellerCategoryIdentifiers.empty;
  }

  final dynamic raw = contactInfo['business_categories'];
  return _parseSellerCategoryValues(raw);
}

SellerCategoryIdentifiers _parseSellerCategoryValues(dynamic raw) {
  if (raw == null) {
    return SellerCategoryIdentifiers.empty;
  }

  final Set<int> numeric = <int>{};
  final Set<String> textual = <String>{};

  void addValue(dynamic value) {
    if (value == null) {
      return;
    }
    if (value is int) {
      if (value > 0) {
        numeric.add(value);
      }
      return;
    }
    if (value is num) {
      final int normalized = value.toInt();
      if (normalized > 0) {
        numeric.add(normalized);
      }
      return;
    }
    if (value is String) {
      final String trimmed = value.trim();
      if (trimmed.isEmpty) {
        return;
      }

      final int? parsedInt = int.tryParse(trimmed);
      if (parsedInt != null) {
        if (parsedInt > 0) {
          numeric.add(parsedInt);
        }
        return;
      }

      final List<dynamic>? decodedList = _tryDecodeJsonArray(trimmed);
      if (decodedList != null) {
        for (final dynamic entry in decodedList) {
          addValue(entry);
        }
        return;
      }

      if (trimmed.contains(',')) {
        for (final String part in trimmed.split(',')) {
          addValue(part);
        }
        return;
      }

      textual.add(trimmed);
      return;
    }
    if (value is Iterable) {
      for (final dynamic entry in value) {
        addValue(entry);
      }
      return;
    }
    if (value is Map) {
      for (final dynamic entry in value.values) {
        addValue(entry);
      }
    }
  }

  addValue(raw);

  final List<int> numericList;
  if (numeric.isEmpty) {
    numericList = const <int>[];
  } else {
    final List<int> sorted = numeric.toList(growable: false)..sort();
    numericList = List<int>.unmodifiable(sorted);
  }

  final List<String> textualList;
  if (textual.isEmpty) {
    textualList = const <String>[];
  } else {
    final List<String> sorted =
    textual.map((e) => e.trim()).where((e) => e.isNotEmpty).toList()
      ..sort();
    textualList = List<String>.unmodifiable(sorted);
  }

  if (numericList.isEmpty && textualList.isEmpty) {
    return SellerCategoryIdentifiers.empty;
  }

  return SellerCategoryIdentifiers(
    numeric: numericList,
    textual: textualList,
  );
}

List<dynamic>? _tryDecodeJsonArray(String raw) {
  try {
    final dynamic decoded = json.decode(raw);
    if (decoded is List) {
      return decoded;
    }
  } catch (_) {
    // Swallow JSON errors silently and fall back to other parsing strategies.
  }
  return null;
}

/// Normalizes loosely typed structures to a `Map<String, dynamic>` if possible.
Map<String, dynamic>? coerceAdditionalInfo(dynamic raw) {
  if (raw is Map<String, dynamic>) {
    return Map<String, dynamic>.from(raw);
  }
  if (raw is Map) {
    return raw.map((key, value) => MapEntry(key.toString(), value));
  }
  if (raw is String) {
    final String trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    try {
      final dynamic decoded = json.decode(trimmed);
      if (decoded is Map<String, dynamic>) {
        return Map<String, dynamic>.from(decoded);
      }
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(key.toString(), value));
      }
    } catch (_) {
      return null;
    }
  }
  return null;
}

/// Attempts to retrieve the nested `contact_info` map from an additional info
/// payload.
Map<String, dynamic>? extractContactInfo(dynamic additionalInfo) {
  final Map<String, dynamic>? info = coerceAdditionalInfo(additionalInfo);
  if (info == null) {
    return null;
  }
  final dynamic contact = info['contact_info'] ?? info['contactInfo'];
  if (contact is Map<String, dynamic>) {
    return Map<String, dynamic>.from(contact);
  }
  if (contact is Map) {
    return contact.map((key, value) => MapEntry(key.toString(), value));
  }
  return null;
}