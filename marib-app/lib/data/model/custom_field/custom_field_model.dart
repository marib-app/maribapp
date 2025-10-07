import 'dart:convert';

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

/// مساعدات عرض عامة (بدون اعتماد على Flutter Widgets)
bool hasValueForDisplay(CustomFieldModel f) =>
    (f.value.isNotEmpty) || (f.type == 'color' && f.value.isNotEmpty);

String displayValueFor(CustomFieldModel f) {
  if (f.type == 'color') {
    // لو تحب تعرض كـ #HEX منضمّ
    return f.value.map((h) => h.startsWith('#') ? h : '#$h').join(', ');
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
    List<String>? value,
    this.notes,
    this.isCustomerOption,
  })  : values = values ?? const [],
        value  = value  ?? const [];

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'image': image,
      'required': required,
      'min_length': minLength,
      'max_length': maxLength,
      'values': values,
      'value': value,
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

    return CustomFieldModel(
      id: _asInt(map['id']),
      name: _asStr(map['name']),
      type: _asStr(map['type']) ?? 'textbox',
      image: _asStr(map['image']),
      required: _asInt(reqRaw) ?? 0,
      minLength: _asInt(map['min_length']),
      maxLength: _asInt(map['max_length']),
      values: _asStringList(map['values']),
      value:  _pickValueList(map),
      notes: _asStr(map['notes']),
      isCustomerOption: _asInt(icoRaw) ?? 0,
    );
  }

  @override
  String toString() {
    return 'CustomFieldModel(id: $id, name: $name, type: $type, image: $image, '
        'required: $required, minLength: $minLength, maxLength: $maxLength, '
        'values: $values, value: $value, notes: $notes, '
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
