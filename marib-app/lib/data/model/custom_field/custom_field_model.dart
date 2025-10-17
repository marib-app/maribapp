import 'dart:convert';
import 'dart:collection';

/// ========== Helpers: تحويلات آمنة لأنواع السيرفر ==========

int? _asInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is bool) return v ? 1 : 0;
  if (v is String) return int.tryParse(v);
  return null;
}

String? _asStr(dynamic v) => v?.toString();

bool _isJsonArray(String s) {
  final t = s.trim();
  return t.startsWith('[') && t.endsWith(']');
}

/// يعيد دائمًا List<String> حتى لو كانت القيمة مفردة/JSON/string/null
List<String> _asStringList(dynamic v) {
  if (v == null) return [];
  if (v is List) {
    return v.map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).toList();
  }
  if (v is String && v.trim().isNotEmpty) {
    try {
      if (_isJsonArray(v)) {
        final d = jsonDecode(v);
        if (d is List) {
          return d.map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).toList();
        }
      }
      // نص مفرد
      return [v];
    } catch (_) {
      return [v];
    }
  }
  // أي نوع آخر: حوّله لنص داخل قائمة
  return [v.toString()];
}

/// يلتقط قيمة الحقل من مفاتيح متعددة (للتوافق الخلفي مع الواجهات)
List<String> _pickValueList(Map<String, dynamic> map) {
  const keys = ['value', 'item_value', 'selected', 'selected_values'];
  for (final k in keys) {
    if (map.containsKey(k) && map[k] != null) {
      return _asStringList(map[k]);
    }
  }
  return const [];
}


String? _sanitizeHex(String? value) {
  if (value == null) {
    return null;
  }
  final candidate = value.replaceAll('#', '').trim().toUpperCase();
  final hexRegExp = RegExp(r'^[0-9A-F]{6}$');
  return hexRegExp.hasMatch(candidate) ? candidate : null;
}

int? _parseQuantityValue(dynamic value) {
  if (value == null) {
    return null;
  }

  if (value is bool) {
    return value ? 1 : 0;
  }

  if (value is int) {
    return value < 0 ? 0 : value;
  }

  if (value is num) {
    final normalized = value.floor();
    return normalized < 0 ? 0 : normalized;
  }

  final match = RegExp(r'-?\d+').firstMatch(value.toString());
  if (match == null) {
    return null;
  }

  final parsed = int.tryParse(match.group(0)!);
  if (parsed == null) {
    return null;
  }

  return parsed < 0 ? 0 : parsed;
}

List<String> _sanitizeColorList(List<String> values) {
  if (values.isEmpty) {
    return const [];
  }

  final seen = <String>{};
  final sanitized = <String>[];

  for (final raw in values) {
    final hex = _sanitizeHex(raw);
    if (hex != null && seen.add(hex)) {
      sanitized.add(hex);
    }
  }

  return sanitized;
}

class CustomFieldColorEntry {
  const CustomFieldColorEntry({required this.code, this.quantity});

  final String code;
  final int? quantity;

  CustomFieldColorEntry copyWith({String? code, int? quantity}) {
    return CustomFieldColorEntry(
      code: code ?? this.code,
      quantity: quantity ?? this.quantity,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      if (quantity != null) 'quantity': quantity,
    };
  }
}

CustomFieldColorEntry? _parseColorEntry(dynamic source) {
  if (source is CustomFieldColorEntry) {
    return source;
  }

  if (source is String) {
    final hex = _sanitizeHex(source);
    return hex == null ? null : CustomFieldColorEntry(code: hex);
  }

  if (source is num) {
    return null;
  }

  if (source is Map) {
    String? code;
    int? quantity;

    for (final key in ['code', 'hex', 'color', 'value']) {
      if (source.containsKey(key)) {
        final hex = _sanitizeHex(source[key]?.toString());
        if (hex != null) {
          code = hex;
          break;
        }
      }
    }

    if (code == null) {
      for (final entry in source.entries) {
        final candidate = _sanitizeHex(entry.key.toString());
        if (candidate != null) {
          code = candidate;
          quantity = _parseQuantityValue(entry.value);
          break;
        }
      }
    }

    if (code == null) {
      for (final value in source.values) {
        final candidate = _sanitizeHex(value?.toString());
        if (candidate != null) {
          code = candidate;
          break;
        }
      }
    }

    for (final key in ['quantity', 'qty', 'count', 'stock', 'amount', 'available']) {
      if (source.containsKey(key)) {
        quantity = _parseQuantityValue(source[key]);
        break;
      }
    }

    if (code == null) {
      return null;
    }

    return CustomFieldColorEntry(code: code, quantity: quantity);
  }

  if (source is Iterable) {
    for (final entry in source) {
      final parsed = _parseColorEntry(entry);
      if (parsed != null) {
        return parsed;
      }
    }
  }

  return null;
}

List<CustomFieldColorEntry> parseCustomFieldColorEntries(dynamic source) {
  if (source == null) {
    return const [];
  }

  dynamic data = source;

  if (source is String) {
    final trimmed = source.trim();
    if (trimmed.isEmpty) {
      return const [];
    }

    try {
      final decoded = jsonDecode(trimmed);
      data = decoded;
    } catch (_) {
      final hex = _sanitizeHex(trimmed);
      return hex == null ? const [] : [CustomFieldColorEntry(code: hex)];
    }
  }

  final entries = LinkedHashMap<String, CustomFieldColorEntry>();

  void addEntry(CustomFieldColorEntry entry) {
    entries[entry.code] = entry;
  }

  void parse(dynamic value) {
    if (value == null) {
      return;
    }

    if (value is Map) {
      for (final mapEntry in value.entries) {
        final key = mapEntry.key;
        final mapValue = mapEntry.value;

        if (mapValue is Map || mapValue is Iterable) {
          parse(mapValue);
          continue;
        }

        final parsed = _parseColorEntry({key: mapValue});
        if (parsed != null) {
          addEntry(parsed);
        }
      }
      return;
    }

    if (value is Iterable) {
      for (final item in value) {
        if (item is Map || item is Iterable) {
          parse(item);
        } else {
          final parsed = _parseColorEntry(item);
          if (parsed != null) {
            addEntry(parsed);
          }
        }
      }
      return;
    }

    final parsed = _parseColorEntry(value);
    if (parsed != null) {
      addEntry(parsed);
    }
  }

  parse(data);

  return entries.values.toList(growable: false);
}

/// مساعدات عرض عامة (بدون اعتماد على Flutter Widgets)
bool hasValueForDisplay(CustomFieldModel f) =>
    (f.value.isNotEmpty) || (f.type == 'color' && f.value.isNotEmpty);

String displayValueFor(CustomFieldModel f) {
  if ((f.type ?? '').toLowerCase() == 'color') {
    if (f.colorEntries.isNotEmpty) {
      return f.colorEntries
          .map((entry) {
        final label = '#${entry.code}';
        final qty = entry.quantity;
        if (qty != null && qty > 0) {
          return '$label × $qty';
        }
        return label;
      })
          .join(', ');
    }

    final sanitized = _sanitizeColorList(f.value);
    return sanitized.map((hex) => '#$hex').join(', ');
  }
  if (f.value.isNotEmpty) return f.value.join(', ');
  return '';
}

/// ========== CustomFieldModel ==========
/// يمثل الحقل المخصص (إنشاء/تفاصيل إعلان).
/// - values: List<String> (خيارات الحقل)
/// - value : List<String> (القيمة/القيم المختارة)
/// - required/isCustomerOption: أرقام 0/1 لضمان التوافق مع الكود القديم.
class CustomFieldModel {
  int? id;
  String? name;
  String? type;
  String? image;
  int? required;              // 0/1
  int? minLength;
  int? maxLength;
  List<String> values;        // دائمًا قائمة
  List<String> value;         // دائمًا قائمة
  List<CustomFieldColorEntry> colorEntries;
  String? notes;
  int? isCustomerOption;      // 0/1

  CustomFieldModel({
    this.id,
    this.name,
    this.type,
    this.image,
    this.required,
    this.minLength,
    this.maxLength,
    List<String>? values,
    List<CustomFieldColorEntry>? colorEntries,
    List<String>? value,
    this.notes,
    this.isCustomerOption,
  })  : values = values ?? const [],
        value  = value  ?? const [],
        colorEntries = colorEntries ?? const [];
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'title': name,
      'label': name,
      'type': type,
      'image': image,
      'required': required,
      'min_length': minLength,
      'max_length': maxLength,
      'values': values,
      'value': value,
      'color_entries': colorEntries.map((e) => e.toJson()).toList(),
      'notes': notes,
      'is_customer_option': isCustomerOption,
    };
  }

  factory CustomFieldModel.fromMap(Map<String, dynamic> map) {
    // دعم مفاتيح بديلة للتوافق الخلفي
    final reqRaw = map.containsKey('required') ? map['required'] : map['is_required'];
    final icoRaw = map.containsKey('is_customer_option')
        ? map['is_customer_option']
        : map['customer_option'];


    final resolvedName = _asStr(
      map['title'] ??
          map['label'] ??
          map['display_name'] ??
          map['placeholder'] ??
          map['name'] ??
          map['field'] ??
          map['slug'],
    ) ??
        _asStr(map['notes']) ??
        _asStr(map['hint']);

    final typeRaw = _asStr(map['type']) ?? 'textbox';
    final normalizedType = typeRaw.toLowerCase();

    List<String> allowedValues = _asStringList(map['values']);
    List<String> selectedValues = _pickValueList(map);
    List<CustomFieldColorEntry> colorEntries = const [];

    if (normalizedType == 'color') {
      colorEntries = parseCustomFieldColorEntries(
        map['color_entries'] ?? map['value'] ?? map['values'],
      );

      allowedValues = _sanitizeColorList(allowedValues);
      selectedValues = _sanitizeColorList(selectedValues);

      if (allowedValues.isEmpty && colorEntries.isNotEmpty) {
        allowedValues = colorEntries.map((entry) => entry.code).toList();
      }

      if (selectedValues.isEmpty && colorEntries.isNotEmpty) {
        selectedValues = colorEntries.map((entry) => entry.code).toList();
      }
    }

    return CustomFieldModel(
      id: _asInt(map['id']),
      name: resolvedName,
      type: typeRaw,
      image: _asStr(map['image']),
      required: _asInt(reqRaw) ?? 0,
      minLength: _asInt(map['min_length']),
      maxLength: _asInt(map['max_length']),
      values: allowedValues,
      value: selectedValues,
      colorEntries: colorEntries,
      notes: _asStr(map['notes']),
      isCustomerOption: _asInt(icoRaw) ?? 0,
    );
  }

  @override
  String toString() {
    return 'CustomFieldModel(id: $id, name: $name, type: $type, image: $image, '
        'required: $required, minLength: $minLength, maxLength: $maxLength, '
        'values: $values, value: $value, colorEntries: $colorEntries, notes: $notes, '

        'isCustomerOption: $isCustomerOption)';
  }
}

/// ========== VerificationFieldModel ==========
/// نفس فلسفة التحمل للأنواع.
/// ملاحظة: هنا جعلت status رقمًا (0/1). لو API يعيده نصًا (مثل "approved"),
/// غيّر النوع إلى String? واستبدل _asInt بـ _asStr في fromMap.
class VerificationFieldModel {
  int? id;
  String? name;
  String? type;
  int? required;          // 0/1
  int? minLength;
  int? maxLength;
  int? status;            // 0/1 (عدّل لنص إن لزم)
  List<String> values;    // دائمًا قائمة

  VerificationFieldModel({
    this.id,
    this.name,
    this.type,
    this.required,
    this.minLength,
    this.maxLength,
    this.status,
    List<String>? values,
  }) : values = values ?? const [];

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'title': name,
      'label': name,
      'type': type,
      'required': required,
      'min_length': minLength,
      'max_length': maxLength,
      'status': status,
      'values': values,
    };
  }

  factory VerificationFieldModel.fromMap(Map<String, dynamic> map) {
    final reqRaw = map.containsKey('required') ? map['required'] : map['is_required'];

    return VerificationFieldModel(
      id: _asInt(map['id']),
      name: _asStr(map['name']),
      type: _asStr(map['type']),
      required: _asInt(reqRaw) ?? 0,
      minLength: _asInt(map['min_length']),
      maxLength: _asInt(map['max_length']),
      status: _asInt(map['status']),
      values: _asStringList(map['values']),
    );
  }

  @override
  String toString() {
    return 'VerificationFieldModel(id: $id, name: $name, type: $type, required: $required, '
        'minLength: $minLength, maxLength: $maxLength, status: $status, values: $values)';
  }
}
