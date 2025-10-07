import '../add_item_screen/custom_filed_structure/custom_field.dart';

String? validateRequiredCustomFieldSelections(
    List<CustomFieldBuilder> fields,
    ) {
  for (final CustomFieldBuilder builder in fields) {
    final Map<dynamic, dynamic> rawField = builder.field;
    if (!_isTruthy(rawField['required'])) {
      continue;
    }

    final String fieldKey = rawField['id']?.toString() ?? '';
    final dynamic storedValue =
    fieldKey.isEmpty ? null : CustomField.fieldsData[fieldKey];

    if (_hasMeaningfulSelection(storedValue)) {
      continue;
    }

    final String label = _resolveFieldLabel(rawField);
    if (label.isNotEmpty) {
      return 'الرجاء اختيار $label أولاً';
    }

    return 'الرجاء إكمال جميع الخيارات المطلوبة قبل إضافة المنتج إلى السلة.';
  }

  return null;
}

List<Map<String, dynamic>> buildSelectedCustomFieldsPayload() {
  final List<Map<String, dynamic>> payload = <Map<String, dynamic>>[];

  CustomField.fieldsData.forEach((dynamic rawKey, dynamic rawValue) {
    if (!_hasMeaningfulSelection(rawValue)) {
      return;
    }

    final int? numericId =
    rawKey is int ? rawKey : int.tryParse(rawKey.toString());
    final dynamic fieldId = numericId ?? rawKey.toString();

    payload.add(<String, dynamic>{
      'id': fieldId,
      'field_id': fieldId,
      'value': rawValue,
      'values': rawValue,
    });
  });

  return payload;
}

bool _isTruthy(dynamic value) {
  if (value == null) {
    return false;
  }
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  if (value is String) {
    final String normalized = value.trim().toLowerCase();
    return normalized == '1' ||
        normalized == 'true' ||
        normalized == 'yes' ||
        normalized == 'required';
  }
  return true;
}

String _resolveFieldLabel(Map<dynamic, dynamic> rawField) {
  final List<dynamic> candidates = <dynamic>[
    rawField['name'],
    rawField['label'],
    rawField['title'],
  ];

  for (final dynamic candidate in candidates) {
    if (candidate is String) {
      final String trimmed = candidate.trim();
      if (trimmed.isNotEmpty) {
        return trimmed;
      }
    }
  }

  return '';
}

bool _hasMeaningfulSelection(dynamic value) {
  if (value == null) {
    return false;
  }
  if (value is bool) {
    return value;
  }
  if (value is String) {
    return value.trim().isNotEmpty;
  }
  if (value is num) {
    return true;
  }
  if (value is Iterable) {
    for (final dynamic entry in value) {
      if (_hasMeaningfulSelection(entry)) {
        return true;
      }
    }
    return false;
  }
  if (value is Map) {
    for (final dynamic entry in value.values) {
      if (_hasMeaningfulSelection(entry)) {
        return true;
      }
    }
    return false;
  }
  return true;
}