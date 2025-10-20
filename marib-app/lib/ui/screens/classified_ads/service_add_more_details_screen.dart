import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:marib/app/routes.dart';


// حقول الفئة (العامّة)
import 'package:marib/data/cubits/custom_field/fetch_custom_fields_cubit.dart';
import 'package:marib/data/model/custom_field/custom_field_model.dart';

// بناة الحقول الديناميكية (new_code)
import 'package:marib/ui/screens/item/add_item_screen/custom_filed_structure/custom_field.dart'
    show CustomField, CustomFieldBuilder, resolveFieldLabel;

// مخزن القيم (الموجود في مشروعكم)
import 'package:marib/ui/screens/widgets/dynamic_field/dynamic_field.dart'
as dynamic_fields;
import 'package:marib/data/repositories/service_request_repository.dart';
import 'package:marib/utils/helper_utils.dart';
import 'service_add_more_details_screen_ui.dart';




class ServiceAddMoreDetailsScreen extends StatefulWidget {
  const ServiceAddMoreDetailsScreen({super.key});

  static Route route(RouteSettings settings) {
    return MaterialPageRoute(
      builder: (_) => BlocProvider(
        create: (_) => FetchCustomFieldsCubit(),
        child: const ServiceAddMoreDetailsScreen(),
      ),
      settings: settings,
    );
  }

  @override
  State<ServiceAddMoreDetailsScreen> createState() =>
      _ServiceAddMoreDetailsScreenState();
}

class _ServiceAddMoreDetailsScreenState
    extends State<ServiceAddMoreDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final ScrollController _scrollController = ScrollController();

  bool _didInitArgs = false;
  int? _categoryId;
  List<Map<String, dynamic>> _schemaFromDetails = [];
  int? _serviceId;
  String? _serviceUid;
  String? _serviceTitle;
  double? _amount;
  String? _currency;

  final List<Map<String, dynamic>> _fieldMaps = [];
  final List<CustomFieldBuilder> _builders = [];

  bool _ready = false;
  bool _submitting = false;
  bool _navigatedOnEmpty = false;

  final ServiceRequestRepository _requestRepository = ServiceRequestRepository();

  static const List<String> _numericMaxKeys = <String>[
    'max',
    'maximum',
    'max_value',
    'maxvalue',
    'max_num',
    'maxnumber',
    'upper',
    'upper_bound',
  ];

  static const List<String> _numericMinKeys = <String>[
    'min',
    'minimum',
    'min_value',
    'minvalue',
    'min_num',
    'minnumber',
    'lower',
    'lower_bound',
  ];

  // ===================== Helpers =====================

  List<Map<String, dynamic>> _parseSchema(dynamic raw) {
    List<Map<String, dynamic>> out = [];

    Map<String, dynamic>? _asMap(dynamic v) {
      if (v is Map) return v.cast<String, dynamic>();
      return null;
    }

    List<Map<String, dynamic>> _fromList(List list) {
      return list
          .map((e) => _asMap(e) ??
          {
            'type': 'textbox',
            'title': '$e',
            'key': 'field_$e',
          })
          .toList();
    }

    if (raw == null) return out;

    if (raw is String) {
      final s = raw.trim();
      if (s.isEmpty || s == '[]' || s == '{}') return out;
      try {
        final decoded = jsonDecode(s);
        return _parseSchema(decoded);
      } catch (_) {
        return out;
      }
    }

    if (raw is List) return _fromList(raw);

    final m = _asMap(raw);
    if (m != null) {
      for (final k in [
        'service_fields_schema',
        'service_fields',
        'custom_fields_schema',
        'custom_fields',
        'fields',
        'schema',
        'data',
      ]) {
        if (m.containsKey(k)) {
          final v = m[k];
          if (v is List) return _fromList(v);
          if (v is String) return _parseSchema(v);
          if (v is Map) return _parseSchema(v);
        }
      }
      if (m.containsKey('type') ||
          m.containsKey('field_type') ||
          m.containsKey('title') ||
          m.containsKey('label') ||
          m.containsKey('name')) {
        out.add(m);
      }
    }

    return out;
  }

  Map<String, dynamic> _normalizeOptions(dynamic raw) {
    final List<String> valuesAsStrings = [];
    final List<Map<String, String>> kvList = [];

    void addPair(String value, String label) {
      final v = value.trim();
      final l = label.trim();
      if (v.isEmpty && l.isEmpty) return;
      valuesAsStrings.add(l.isNotEmpty ? l : v);
      kvList.add({'value': v, 'label': l.isNotEmpty ? l : v});
    }

    if (raw == null) return {'values': valuesAsStrings, 'kv': kvList};

    if (raw is String) {
      final s = raw.replaceAll('\n', '|').replaceAll(',', '|').trim();
      if (s.isNotEmpty) {
        for (final part in s.split('|')) {
          final p = part.trim();
          if (p.isNotEmpty) addPair(p, p);
        }
      }
      return {'values': valuesAsStrings, 'kv': kvList};
    }

    if (raw is List) {
      for (final e in raw) {
        if (e is String) {
          addPair(e, e);
        } else if (e is Map) {
          final m = e.cast<String, dynamic>();
          final v =
              '${m['value'] ?? m['key'] ?? m['id'] ?? m['slug'] ?? m['code'] ?? m['val'] ?? ''}';
          final l =
              '${m['label'] ?? m['title'] ?? m['text'] ?? m['name'] ?? m['display'] ?? m['value'] ?? ''}';
          if (v.trim().isNotEmpty || l.trim().isNotEmpty) addPair(v, l);
        } else {
          addPair('$e', '$e');
        }
      }
      return {'values': valuesAsStrings, 'kv': kvList};
    }

    if (raw is Map) {
      for (final entry in raw.entries) {
        addPair('${entry.key}', '${entry.value}');
      }
    }

    return {'values': valuesAsStrings, 'kv': kvList};
  }

  bool _isDigits(String s) => RegExp(r'^\d+$').hasMatch(s);

  /// ⚠️ نقيّد الأنواع إلى السبعة فقط ونوسع المرادفات
  Map<String, dynamic> _normalizeFieldMap(Map<String, dynamic> input) {
    final m = Map<String, dynamic>.from(input);

    String? _str(dynamic v) {
      if (v == null) return null;
      final s = '$v'.trim();
      return s.isEmpty ? null : s;
    }

    bool _asBool(dynamic v) {
      if (v == null) return false;
      if (v is bool) return v;
      if (v is num) return v != 0;
      if (v is String) {
        final s = v.trim().toLowerCase();
        return s == '1' || s == 'true' || s == 'yes';
      }
      return false;
    }

    // ===== النوع =====
    String t = (_str(m['type']) ??
        _str(m['field_type']) ??
        _str(m['input_type']) ??
        'textbox')!
        .toLowerCase();

    switch (t) {
      case 'text':
      case 'tel':
      case 'phone':
      case 'mobile':
      case 'string':
      case 'input':
      case 'textarea':
        t = 'textbox';
        break;

      case 'dropdown':
      case 'select':
      case 'selectbox':
      case 'select_list':
      case 'combo':
        t = 'dropdown';
        break;

      case 'integer':
      case 'int':
      case 'decimal':
      case 'float':
      case 'double':
      case 'numeric':
      case 'number':
        t = 'number';
        break;

      case 'bool':
      case 'boolean':
      case 'check':
      case 'check_box':
      case 'checkbox':
      case 'checkboxes': // ← مهم
        t = 'checkbox';
        break;

      case 'radio':
      case 'radio_button':
      case 'radiobutton':
      case 'radio-btn':
      case 'radio-btns':
      case 'radio_group':
        t = 'radio';
        break;

      case 'file':
      case 'fileinput':
      case 'file_input':
      case 'file-upload':
      case 'file_upload':
      case 'upload':
      case 'image':
      case 'image_upload':
      case 'photo':
        t = 'fileinput';
        break;

      case 'color':
      case 'colour':
      case 'colorpicker':
        t = 'color';
        break;

      default:
        t = 'textbox';
        break;
    }

    m['type'] = t;
    m['field_type'] = m['field_type'] ?? t;
    m['input_type'] = m['input_type'] ?? t;


    final String? noteText = _str(m['notes']) ??
        _str(m['note']) ??
        _str(m['description']) ??
        _str(m['hint']) ??
        _str(m['help_text']) ??
        _str(m['helper_text']) ??
        _str(m['info']);


    // ===== العنوان (نوسع المرادفات + منع أرقام صِرفة) =====
    String? title = _str(m['label']) ??
        _str(m['title']) ??
        _str(m['name']) ??
        _str(m['field_name']) ??
        _str(m['display_name']) ??
        _str(m['text']) ??
        _str(m['placeholder']);

    if (title == null || _isDigits(title)) {
      // لو جتنا “2” مثل حالتك، لا نستخدمها عنوانًا
      title = noteText ?? '—';
    }

    m['title'] = title;
    m['label'] = m['label'] ?? title;

    if (noteText != null) {
      m['notes'] = noteText;
      m['note'] = m['note'] ?? noteText;
      m['hint'] = m['hint'] ?? noteText;
      m['description'] = m['description'] ?? noteText;
    } else {
      m.remove('notes');
    }

    final rawName = _str(m['name']);
    final keyCandidate = _str(m['key']) ??
        _str(m['field_key']) ??
        _str(m['slug']);
    final shouldReplaceName = rawName == null ||
        rawName.isEmpty ||
        rawName == keyCandidate ||
        (rawName.startsWith('field_') && rawName.length <= 12);

    if (shouldReplaceName && title != null && title.trim().isNotEmpty) {
      m['name'] = title;
    } else if (rawName != null) {
      m['name'] = rawName;
    }

    m['placeholder'] = m['placeholder'] ?? title;

    // ===== المفتاح/المعرّف =====
    final fallbackKey = 'field_${DateTime.now().microsecondsSinceEpoch}';
    final originalId = _str(m['id']) ?? _str(m['field_id']) ?? _str(m['custom_field_id']);
    String? key = _str(m['key']) ??

        _str(m['field_key']) ??
        _str(m['slug']) ??
        _str(m['name']) ??
        originalId;

    key = _str(key) ?? fallbackKey;

    if (originalId != null && originalId.isNotEmpty && originalId != key) {
      m['field_numeric_id'] = originalId;
    }

    m['key'] = key;
    m['field_key'] = m['field_key'] ?? key;
    m['slug'] = m['slug'] ?? key;
    m['id'] = key;

    // ===== مطلوب؟ =====
    final req = m['required'] ?? m['is_required'] ?? m['mandatory'] ?? m['status'];
    m['required'] = _asBool(req);

    // ===== الترتيب =====
    final seq = m['sequence'] ?? m['order'] ?? m['sort_order'];
    if (seq is String) {
      m['sequence'] = int.tryParse(seq) ?? 0;
    } else if (seq is num) {
      m['sequence'] = seq.toInt();
    } else {
      m['sequence'] = 0;
    }

    // ===== القيم/الخيارات (مرادفات أكثر) =====
    dynamic rawOptions = m['values'] ??
        m['options'] ??
        m['choices'] ??
        m['items'] ??
        m['field_values'] ??
        m['values_text'] ??
        m['options_text'] ??
        m['option_values'] ??
        m['option_labels'] ??
        m['options_ar'] ??
        m['choices_ar'];

    if (t == 'radio' || t == 'dropdown' || t == 'checkbox') {
      if (rawOptions == null) {
        rawOptions = m['value'] ?? m['default'] ?? m['placeholder'];
      }
      final opt = _normalizeOptions(rawOptions);
      final List<String> valuesStrings = opt['values'] as List<String>;
      final List<Map<String, String>> kvList =
      opt['kv'] as List<Map<String, String>>;
      if (valuesStrings.isNotEmpty) {
        m['values'] = valuesStrings;
      }
      if (kvList.isNotEmpty) {
        m['options_kv'] = kvList;
      }
    }

    if (m['value'] == null && m['default'] != null) {
      m['value'] = m['default'];
    }

    if (m['type'] == 'number') {
      if (m['min'] is String) m['min'] = int.tryParse(m['min']);
      if (m['max'] is String) m['max'] = int.tryParse(m['max']);
      if (m['step'] is String) m['step'] = num.tryParse(m['step']);
    }

    return m;
  }

  void _mergeAndBuild({
    required List<CustomFieldModel> categoryFields,
    required List<Map<String, dynamic>> schemaFields,
  }) {
    _fieldMaps.clear();

    for (final f in categoryFields) {
      _fieldMaps.add(_normalizeFieldMap(f.toMap()));
    }

    final existingKeys = _fieldMaps
        .map((m) => (m['id'] ?? m['key'] ?? m['title']).toString())
        .toSet();

    for (final raw in schemaFields) {
      final m = _normalizeFieldMap(raw);
      final idKey = (m['id'] ?? m['key'] ?? m['title']).toString();
      if (!existingKeys.contains(idKey)) {
        _fieldMaps.add(m);
        existingKeys.add(idKey);
      }
    }

    _fieldMaps.sort((a, b) {
      final sa = (a['sequence'] ?? 0) as int;
      final sb = (b['sequence'] ?? 0) as int;
      return sa.compareTo(sb);
    });

    _builders
      ..clear()
      ..addAll(_fieldMaps.map((m) {
        final b = CustomFieldBuilder(m);
        b.stateUpdater(setState);
        return b;
      }));

    _ready = false;
    _navigatedOnEmpty = false;

    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 1));
      for (final b in _builders) {
        try {
          b.init();
        } catch (_) {}
      }
      if (mounted) {
        setState(() => _ready = true);
      }
    });
  }

  void _clearStores() {
    try {
      dynamic_fields.AbstractField.fieldsData.clear();
      dynamic_fields.AbstractField.files.clear();
      CustomField.fieldsData.clear();
      CustomField.files.clear();
    } catch (_) {}
  }






  String? _normalizeFieldKey(dynamic value) {
    if (value == null) return null;
    final key = value.toString().trim();
    return key.isEmpty ? null : key;
  }

  Map<String, Map<String, dynamic>> _buildFieldLookup() {
    final lookup = <String, Map<String, dynamic>>{};

    for (final field in _fieldMaps) {
      final candidates = <String?>{
        _normalizeFieldKey(field['id']),
        _normalizeFieldKey(field['key']),
        _normalizeFieldKey(field['field_key']),
        _normalizeFieldKey(field['slug']),
        _normalizeFieldKey(field['name']),
        _normalizeFieldKey(field['field_numeric_id']),
      }..removeWhere((element) => element == null);

      for (final key in candidates) {
        if (key == null) continue;
        lookup.putIfAbsent(key, () => field);
      }
    }

    return lookup;
  }

  Map<String, dynamic> _collectRawCustomFieldValues() {
    final merged = <String, dynamic>{};

    void merge(Map<dynamic, dynamic> source) {
      source.forEach((key, value) {
        final normalizedKey = _normalizeFieldKey(key);
        if (normalizedKey == null) {
          return;
        }
        merged[normalizedKey] = value;
      });
    }

    merge(dynamic_fields.AbstractField.fieldsData);
    merge(CustomField.fieldsData);

    return merged;
  }

  Map<String, dynamic> _collectAttachmentFiles() {
    final merged = <String, dynamic>{};

    void merge(Map<dynamic, dynamic> source) {
      source.forEach((key, value) {
        final normalizedKey = _normalizeFieldKey(key);
        if (normalizedKey == null) {
          return;
        }
        final effectiveKey = normalizedKey.contains('[')
            ? normalizedKey
            : 'custom_field_files[$normalizedKey]';
        merged[effectiveKey] = value;
      });
    }

    merge(dynamic_fields.AbstractField.files);
    merge(CustomField.files);

    return merged;
  }




  bool _isNumericFieldType(String? type) {
    if (type == null) return false;
    switch (type.toLowerCase()) {
      case 'number':
      case 'numeric':
      case 'integer':
      case 'int':
      case 'double':
      case 'float':
      case 'decimal':
        return true;
      default:
        return false;
    }
  }

  String? _fieldTypeOf(Map<String, dynamic> field) {
    final candidates = <String>[];
    for (final key in ['type', 'input_type', 'field_type']) {
      final value = field[key];
      if (value is String && value.trim().isNotEmpty) {
        candidates.add(value.trim().toLowerCase());
      }
    }
    if (candidates.isEmpty) {
      return null;
    }

    for (final candidate in candidates) {
      if (_isNumericFieldType(candidate)) {
        return candidate;
      }
    }

    return candidates.first;
  }

  num? _coerceToNum(dynamic value) {
    if (value == null) return null;
    if (value is num) {
      return value;
    }
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      return num.tryParse(trimmed);
    }
    if (value is Iterable) {
      for (final element in value) {
        final coerced = _coerceToNum(element);
        if (coerced != null) {
          return coerced;
        }
      }
      return null;
    }
    if (value is Map) {
      for (final element in value.values) {
        final coerced = _coerceToNum(element);
        if (coerced != null) {
          return coerced;
        }
      }
    }
    return null;
  }

  num? _parseConstraintFromString(String source, List<String> keys) {
    final normalized = source.trim().toLowerCase();
    if (normalized.isEmpty) return null;

    final parts = normalized.split(RegExp(r'[|,\s]+'));
    for (final part in parts) {
      final segment = part.trim();
      if (segment.isEmpty) continue;

      for (final separator in [':', '=', '>=', '<=']) {
        final index = segment.indexOf(separator);
        if (index <= 0) {
          continue;
        }
        final key = segment.substring(0, index).trim();
        if (!keys.contains(key)) {
          continue;
        }
        final valuePart = segment.substring(index + separator.length).trim();
        if (valuePart.isEmpty) {
          continue;
        }
        final parsed = num.tryParse(valuePart);
        if (parsed != null) {
          return parsed;
        }
      }
    }

    for (final key in keys) {
      if (normalized.startsWith(key)) {
        final remainder = normalized.substring(key.length).trim();
        if (remainder.startsWith(':') || remainder.startsWith('=')) {
          final parsed = num.tryParse(remainder.substring(1).trim());
          if (parsed != null) {
            return parsed;
          }
        }
      }
    }

    return null;
  }

  num? _extractConstraint(
      Map<String, dynamic> field,
      List<String> keys,
      ) {
    final lowerCaseKeys = keys.map((k) => k.toLowerCase()).toSet();
    final keysList = lowerCaseKeys.toList();
    final visitedMaps = <int>{};
    final visitedIterables = <int>{};
    final stack = <dynamic>[field];

    while (stack.isNotEmpty) {
      final current = stack.removeLast();

      if (current is Map) {
        final id = identityHashCode(current);
        if (!visitedMaps.add(id)) {
          continue;
        }

        for (final entry in current.entries) {
          final key = entry.key.toString().toLowerCase();
          final value = entry.value;
          if (lowerCaseKeys.contains(key)) {
            if (value is String) {
              final parsed = _parseConstraintFromString(value, keysList);
              if (parsed != null) return parsed;
            } else {
              final parsed = _coerceToNum(value);
              if (parsed != null) {
                return parsed;
              }
            }
          }

          if (value is Map || value is Iterable) {
            stack.add(value);
          } else if (value is String) {
            final parsed = _parseConstraintFromString(value, keysList);
            if (parsed != null) {
              return parsed;
            }
          }
        }
      } else if (current is Iterable) {
        final id = identityHashCode(current);
        if (!visitedIterables.add(id)) {
          continue;
        }

        for (final element in current) {
          if (element is Map || element is Iterable) {
            stack.add(element);
          } else if (element is String) {
            final parsed = _parseConstraintFromString(element, keysList);
            if (parsed != null) {
              return parsed;
            }
          }
        }
      } else if (current is String) {
        final parsed = _parseConstraintFromString(current, keysList);
        if (parsed != null) {
          return parsed;
        }
      }
    }

    return null;
  }

  String _formatConstraint(num value) {
    if (value is int || value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toString();
  }

  String _fieldLabelForError(
      BuildContext context,
      Map<String, dynamic> field,
      String fallback,
      ) {
    try {
      final resolved = resolveFieldLabel(
        context,
        Map<String, dynamic>.from(field),
      );
      if (resolved.trim().isNotEmpty) {
        return resolved.trim();
      }
    } catch (_) {}

    for (final key in ['title', 'label', 'display_name', 'name']) {
      final value = field[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }

    return fallback;
  }

  String? _validateAndNormalizeCustomFieldValues(
      BuildContext context,
      Map<String, dynamic> rawValues,
      Map<String, Map<String, dynamic>> lookup,
      Map<String, dynamic> normalizedOut,
      ) {
    for (final entry in rawValues.entries) {
      final key = _normalizeFieldKey(entry.key);
      if (key == null) {
        continue;
      }

      final normalizedValue =
      _normalizeFieldValueForRequest(key, entry.value, lookup);
      if (normalizedValue == null) {
        continue;
      }

      normalizedOut[key] = normalizedValue;

      final field = lookup[key];
      if (field == null) {
        continue;
      }

      final type = _fieldTypeOf(field);
      if (!_isNumericFieldType(type)) {
        continue;
      }

      final numericValue = _coerceToNum(normalizedValue);
      if (numericValue == null) {
        final label = _fieldLabelForError(context, field, key);
        return 'الرجاء إدخال رقم صحيح في الحقل "$label".';
      }

      final maxConstraint = _extractConstraint(field, _numericMaxKeys);
      if (maxConstraint != null && numericValue > maxConstraint) {
        final label = _fieldLabelForError(context, field, key);
        return 'الحد الأقصى المسموح به للحقل "$label" هو ${_formatConstraint(maxConstraint)}.';
      }

      final minConstraint = _extractConstraint(field, _numericMinKeys);
      if (minConstraint != null && numericValue < minConstraint) {
        final label = _fieldLabelForError(context, field, key);
        return 'الحد الأدنى المسموح به للحقل "$label" هو ${_formatConstraint(minConstraint)}.';
      }
    }

    return null;
  }


  String? _stringifyFieldValue(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    if (value is num) {
      return value.toString();
    }
    if (value is bool) {
      return value ? '1' : '0';
    }
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  dynamic _normalizeFieldValueForRequest(
      String key,
      dynamic raw,
      Map<String, Map<String, dynamic>> lookup,
      ) {
    if (raw == null) return null;

    final fieldMeta = lookup[key];
    final type = _fieldTypeOf(fieldMeta ?? const <String, dynamic>{});
    final expectsList = type == 'checkbox';

    dynamic candidate = raw;
    if (candidate is Map) {
      for (final mapKey in ['value', 'values', 'selected', 'checked']) {
        if (candidate.containsKey(mapKey)) {
          candidate = candidate[mapKey];
          break;
        }
      }
    }

    if (candidate is Iterable && candidate is! String) {
      final seen = <String>{};
      final cleaned = <String>[];
      for (final entry in candidate) {
        final normalized = _stringifyFieldValue(entry);
        if (normalized == null) continue;
        if (seen.add(normalized)) {
          cleaned.add(normalized);
        }
      }

      if (expectsList) {
        return cleaned.isEmpty ? null : cleaned;
      }
      if (cleaned.isEmpty) return null;
      return cleaned.first;
    }

    final normalized = _stringifyFieldValue(candidate);
    if (normalized == null) {
      return null;
    }

    if (expectsList) {
      return <String>[normalized];
    }


    if (_isNumericFieldType(type)) {
      final parsed = num.tryParse(normalized);
      if (parsed != null) {
        return parsed;
      }
    }



    return normalized;
  }

  Map<String, dynamic> _encodeCustomFieldsForRequest(
      Map<String, dynamic> normalizedValues,
      ) {
    if (normalizedValues.isEmpty) {
      return const <String, dynamic>{};
    }

    final payload = <String, dynamic>{};

    normalizedValues.forEach((key, value) {
      payload['custom_fields[$key]'] = value;
    });

    return payload;
  }


  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInitArgs) return;
    _didInitArgs = true;

    _clearStores();

    final args = ModalRoute.of(context)?.settings.arguments as Map?;
    _categoryId = (args?['categoryId'] as int?) ??
        int.tryParse('${args?['categoryId'] ?? ''}');


    final serviceIdRaw = args?['serviceId'] ?? args?['itemId'];
    if (serviceIdRaw is int) {
      _serviceId = serviceIdRaw;
    } else if (serviceIdRaw is String) {
      _serviceId = int.tryParse(serviceIdRaw);
    } else {
      _serviceId = null;
    }


    final serviceUidRaw = args?['serviceUid'] ?? args?['service_uid'];
    if (serviceUidRaw is String) {
      final trimmed = serviceUidRaw.trim();
      _serviceUid = trimmed.isNotEmpty ? trimmed : null;
    } else {
      _serviceUid = null;
    }



    final serviceTitleRaw = args?['serviceTitle'];
    if (serviceTitleRaw is String) {
      final trimmed = serviceTitleRaw.trim();
      _serviceTitle = trimmed.isNotEmpty ? trimmed : null;
    } else {
      _serviceTitle = null;
    }

    final amountRaw = args?['amount'] ?? args?['price'];
    if (amountRaw is num) {
      _amount = amountRaw.toDouble();
    } else if (amountRaw is String) {
      final trimmed = amountRaw.trim();
      _amount = trimmed.isNotEmpty ? double.tryParse(trimmed) : null;
    } else {
      _amount = null;
    }

    final currencyRaw = args?['currency'] ?? args?['priceCurrency'];
    if (currencyRaw == null) {
      _currency = null;
    } else {
      final c = '$currencyRaw'.trim();
      _currency = c.isNotEmpty ? c : null;
    }




    final rawSchema = args?['serviceFieldsSchema'] ??
        args?['service_fields_schema'] ??
        args?['service_fields'] ??
        args?['custom_fields_schema'] ??
        args?['custom_fields'] ??
        args?['schema'];

    _schemaFromDetails = _parseSchema(rawSchema);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_categoryId != null) {
        context
            .read<FetchCustomFieldsCubit>()
            .fetchCustomFields(categoryIds: '$_categoryId');
      } else {
        _mergeAndBuild(
            categoryFields: const [], schemaFields: _schemaFromDetails);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<FetchCustomFieldsCubit, FetchCustomFieldState>(
        listener: (context, state) {
          if (state is FetchCustomFieldSuccess) {
            _mergeAndBuild(
              categoryFields: state.fields,
              schemaFields: _schemaFromDetails,
            );
          } else {
          if (_builders.isEmpty) {
            _mergeAndBuild(
                categoryFields: const [], schemaFields: _schemaFromDetails);
          }
          }
        },
      builder: (context, state) {
        final effectiveState =
        (!_ready && state is! FetchCustomFieldFail)
            ? FetchCustomFieldInProgress()
            : state;

        final preparedFields =
        _builders.map((b) => b..stateUpdater(setState)).toList();

        final shouldAutoSubmit = state is FetchCustomFieldSuccess &&
            _ready &&
            preparedFields.isEmpty &&
            !_submitting &&
            !_navigatedOnEmpty &&
            _serviceId != null;

        if (shouldAutoSubmit) {
          _navigatedOnEmpty = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _goNext();
          });
        } else if (preparedFields.isNotEmpty && _navigatedOnEmpty) {
          _navigatedOnEmpty = false;
        }
        return MoreDetailsUI(
          formKey: _formKey,
          scrollController: _scrollController,
          state: effectiveState,
          fields: preparedFields,
          onNextPressed: () async {
            if (_submitting) return;
            if (_formKey.currentState?.validate() ?? false) {
              await _goNext();
            }
          },
          onRetry: state is FetchCustomFieldFail && _categoryId != null
              ? () {
            context.read<FetchCustomFieldsCubit>().fetchCustomFields(
              categoryIds: '$_categoryId',
            );
          }
              : null,
        );
      },
    );
  }

  Future<void> _goNext() async {
    if (_serviceId == null) {
      HelperUtils.showSnackBarMessage(context, 'لا يمكن إرسال الطلب الآن.');
      return;
    }


    final rawCustomFields = _collectRawCustomFieldValues();
    final lookup = _buildFieldLookup();
    final normalizedCustomFields = <String, dynamic>{};
    final validationError = _validateAndNormalizeCustomFieldValues(
      context,
      rawCustomFields,
      lookup,
      normalizedCustomFields,
    );

    if (validationError != null) {
      HelperUtils.showSnackBarMessage(context, validationError);
      return;
    }

    final customFieldPayload =
    _encodeCustomFieldsForRequest(normalizedCustomFields);
    final attachmentPayload = _collectAttachmentFiles();
    setState(() => _submitting = true);
    try {
      await _requestRepository.createRequest(
        serviceId: _serviceId!,
        serviceUid: _serviceUid,
        customFields:
        customFieldPayload.isEmpty ? null : customFieldPayload,
        attachments:
        attachmentPayload.isEmpty ? null : attachmentPayload,
      );



      if (!mounted) return;
      _clearStores();
      HelperUtils.showSnackBarMessage(

        context,
        'تم ارسال طلبك بنجاح',
      );
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      HelperUtils.showSnackBarMessage(context, '$e');
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }
}

