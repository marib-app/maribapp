import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import 'package:marib/app/routes.dart';
import 'package:marib/data/cubits/custom_field/fetch_custom_fields_cubit.dart';
import 'package:marib/data/model/custom_field/custom_field_model.dart';
import 'package:marib/data/model/service_request_model.dart';
import 'package:marib/ui/screens/item/add_item_screen/custom_filed_structure/custom_field.dart'
    show CustomField, CustomFieldBuilder, resolveFieldLabel;
import 'package:marib/ui/screens/widgets/dynamic_field/dynamic_field.dart'
    as dynamic_fields;
import 'package:marib/data/repositories/service_request_repository.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:marib/utils/api.dart' show ApiHttpException;
import 'package:marib/utils/hive_utils.dart';
import 'package:marib/utils/payment/bank_transfer_args.dart';
import 'package:marib/utils/payment/bank_transfer_screen.dart';
import 'package:marib/utils/payment/manual_payment_service.dart';
import 'package:marib/utils/payment/manual_payment.dart';
import 'package:marib/ui/screens/transaction/manual_payment_details_screen.dart';
import 'package:marib/ui/screens/transaction/manual_payments_controller.dart';
import 'package:marib/ui/screens/classified_ads/service_add_more_details_screen_ui.dart';
import 'package:marib/app/navigation/app_page_route.dart';
import 'package:marib/app/navigation/motion/route_motion.dart';
import 'package:marib/utils/payment/payment_route_result.dart';






class ServiceAddMoreDetailsScreen extends StatefulWidget {
  const ServiceAddMoreDetailsScreen({super.key});

  static Route route(RouteSettings settings) {
    return AppPageRoute.build(
      builder: (_) => BlocProvider(
        create: (_) => FetchCustomFieldsCubit(),
        child: const ServiceAddMoreDetailsScreen(),
      ),
      settings: settings,
      motionPattern: AppMotionPattern.glide,
    );
  }

  @override
  State<ServiceAddMoreDetailsScreen> createState() =>
      _ServiceAddMoreDetailsScreenState();
}

class _ServiceAddMoreDetailsScreenState
    extends State<ServiceAddMoreDetailsScreen> {
  static const String _nextRouteTransactionsHistory = 'transactions.history';
  static const String _nextRouteWalletTransactions = 'wallet.transactions';

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
  int? _pendingServiceRequestId;

  final List<Map<String, dynamic>> _fieldMaps = [];
  final List<CustomFieldBuilder> _builders = [];

  bool _ready = false;
  bool _submitting = false;
  bool _navigatedOnEmpty = false;

  final ServiceRequestRepository _requestRepository =
      ServiceRequestRepository();
  final ManualPaymentService _manualPaymentService = ManualPaymentService();

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
          .map((e) =>
              _asMap(e) ??
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
            'textbox')
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

    final String? normalizedNoteText =
        noteText != null && noteText.trim().isNotEmpty ? noteText.trim() : null;

    // ===== العنوان (نوسع المرادفات + منع أرقام صِرفة) =====
    String title = (_str(m['label']) ??
        _str(m['title']) ??
        _str(m['name']) ??
        _str(m['field_name']) ??
        _str(m['display_name']) ??
        _str(m['text']) ??
        _str(m['placeholder']) ??
        '')
        .trim();

    if (title.isEmpty || _isDigits(title)) {
      // لو جتنا “2” مثل حالتك، لا نستخدمها عنوانًا
      title = normalizedNoteText ?? '—';
    }

    m['title'] = title;
    m['label'] = m['label'] ?? title;

    if (normalizedNoteText != null) {
      m['notes'] = normalizedNoteText;
      m['note'] = m['note'] ?? normalizedNoteText;
      m['hint'] = m['hint'] ?? normalizedNoteText;
      m['description'] = m['description'] ?? normalizedNoteText;
    } else {
      m.remove('notes');
    }

    final rawName = _str(m['name']);
    final keyCandidate =
        _str(m['key']) ?? _str(m['field_key']) ?? _str(m['slug']);
    final shouldReplaceName = rawName == null ||
        rawName.isEmpty ||
        rawName == keyCandidate ||
        (rawName.startsWith('field_') && rawName.length <= 12);

    if (shouldReplaceName && title.isNotEmpty) {
      m['name'] = title;
    } else if (rawName != null) {
      m['name'] = rawName;
    }

    m['placeholder'] = m['placeholder'] ?? title;

    // ===== المفتاح/المعرّف =====
    final fallbackKey = 'field_${DateTime.now().microsecondsSinceEpoch}';
    final originalId =
        _str(m['id']) ?? _str(m['field_id']) ?? _str(m['custom_field_id']);
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
    final req =
        m['required'] ?? m['is_required'] ?? m['mandatory'] ?? m['status'];
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

    _pendingServiceRequestId = null;

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
        final effectiveState = (!_ready && state is! FetchCustomFieldFail)
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
      final ServiceRequestModel request =
          await _requestRepository.createRequest(
        serviceId: _serviceId!,
        serviceUid: _serviceUid,
        customFields: customFieldPayload.isEmpty ? null : customFieldPayload,
        attachments: attachmentPayload.isEmpty ? null : attachmentPayload,
        serviceRequestId: _pendingServiceRequestId,
      );

      _pendingServiceRequestId = request.id;

      final bool paymentPending = _amount != null &&
          _amount! > 0 &&
          ((request.paymentStatus ?? '').toLowerCase() != 'paid');

      if (paymentPending) {
        final PaymentRouteResult? routeResult = await _startManualPaymentFlow(
          serviceId: _serviceId!,
          serviceRequestId: request.id,
          amount: _amount!,
          currency: _currency,
          priceNote: request.note,
          serviceTitle: _serviceTitle,
          initialGateway: null,
          fallbackTransaction: request.paymentTransactionId,
        );

        if (routeResult != null) {
          await _handlePaymentRouteNavigation(routeResult);
          return;
        }

        return;
      }

      await _onRequestSubmitted();
    } on ApiHttpException catch (error) {
      if (error.statusCode == 402) {
        final PaymentRouteResult? paymentRoute = await _handlePaymentRequired(
          error: error,
        );

        if (paymentRoute != null) {
          await _handlePaymentRouteNavigation(paymentRoute);
          return;
        }
      }

      if (!mounted) return;
      final message = error.errorMessage ?? error.payload ?? error.toString();
      HelperUtils.showSnackBarMessage(context, '$message');
    } catch (e) {
      if (!mounted) return;
      HelperUtils.showSnackBarMessage(context, '$e');
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _onRequestSubmitted({
    Map<String, dynamic>? subject,
    Map<String, dynamic>? next,
    String? transactionId,
    ManualPayment? manualPaymentSnapshot,
  }) async {
    if (!mounted) return;

    _clearStores();
    setState(() {
      _pendingServiceRequestId = null;
      _submitting = false;
    });

    HelperUtils.showSnackBarMessage(
      context,
      'Request submitted successfully.',
    );

    final String? focusId = transactionId?.trim();

    if (focusId != null && focusId.isNotEmpty) {
      if (_tryNavigateUsingNext(next, focusId)) {
        return;
      }

      if (manualPaymentSnapshot != null) {
        unawaited(
          Navigator.of(context).pushReplacement(
            AppPageRoute.build(
              builder: (_) => ManualPaymentDetailsScreen(
                manualPayment: manualPaymentSnapshot,
                dateFormat: DateFormat('d MMM yyyy, h:mm a', 'ar'),
                pollInterval: ManualPaymentsController.pollInterval,
              ),
              motionPattern: AppMotionPattern.glide,
            ),
          ),
        );
        return;
      }

      await _navigateToTransactionDetails(focusId);
      return;
    }

    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop(true);
    }
  }

  Future<PaymentRouteResult?> _startManualPaymentFlow({
    required int serviceId,
    required int serviceRequestId,
    required double amount,
    String? currency,
    String? priceNote,
    String? serviceTitle,
    String? initialGateway,
    dynamic fallbackTransaction,

  }) async {
    if (!mounted) return null;

    _pendingServiceRequestId = serviceRequestId;

    final String token = HiveUtils.getJWT();
    if (token.trim().isEmpty) {
      HelperUtils.showSnackBarMessage(
        context,
        'Please sign in to continue with the payment.',
      );
      return null;
    }

    final String? normalizedCurrency =
        (currency != null && currency.trim().isNotEmpty)
            ? currency.trim().toUpperCase()
            : null;

    final BankTransferArgs args = BankTransferArgs(
      token: token,
      packageId: serviceId,
      amount: amount,
      currency: normalizedCurrency,
      packageType: 'service',
      itemId: serviceId,
      purpose: 'service',
      initialGateway: initialGateway,
      serviceId: serviceId,
      serviceTitle: serviceTitle ?? _serviceTitle,
      priceNote: priceNote,
      serviceRequestId: serviceRequestId,
    );

    if (args.priceNote != null && args.priceNote!.isNotEmpty) {
      HelperUtils.showSnackBarMessage(context, args.priceNote!);
    }

    final dynamic paymentResult = await BankTransferScreen.show(context, args);

    if (!mounted) {
      return null;
    }

    if (paymentResult == null || paymentResult == false) {
      return null;
    }

    PaymentRouteResult? routeResult;
    if (paymentResult is PaymentRouteResult) {
      routeResult = paymentResult;
    } else if (paymentResult is ManualPaymentSubmissionResult) {
      routeResult = _buildRouteResultFromSubmission(paymentResult);
    }

    if (routeResult == null) {
      HelperUtils.showSnackBarMessage(
        context,
        'Unable to determine payment result.',
      );
      return null;
    }

    final int? transactionId = await _resolveTransactionIdForRoute(
      routeResult,
      fallbackTransaction: fallbackTransaction,
    );

    if (transactionId == null) {
      HelperUtils.showSnackBarMessage(
        context,
        'Unable to determine payment transaction.',
      );
      return null;
    }

    setState(() => _submitting = true);

    var submitted = false;
    try {
      await _requestRepository.createRequest(
        serviceId: serviceId,
        serviceUid: _serviceUid,
        paymentTransactionId: transactionId,
        serviceRequestId: serviceRequestId,
      );
      submitted = true;
      await _handlePostPaymentSubmission();
      return routeResult;
    } on ApiHttpException catch (err) {
      if (!mounted) return null;
      final String message = err.errorMessage ?? err.payload ?? err.toString();
      HelperUtils.showSnackBarMessage(context, '$message');
    } catch (err) {
      if (!mounted) return null;
      HelperUtils.showSnackBarMessage(context, '$err');
    } finally {
      if (!submitted && mounted) {
        setState(() => _submitting = false);
      }
    }

    return null;
  }




  Future<void> _handlePostPaymentSubmission() async {
    if (!mounted) return;
    _clearStores();
    setState(() {
      _pendingServiceRequestId = null;
      _submitting = false;
    });
    HelperUtils.showSnackBarMessage(
      context,
      'Request submitted successfully.',
    );
  }

  PaymentRouteResult? _buildRouteResultFromSubmission(
      ManualPaymentSubmissionResult submission) {
    final int? manualRequestId = submission.manualPaymentIdAsInt ??
        _extractIdFromMap(
          submission.manualPaymentRequest,
          const [
            'manual_payment_request_id',
            'manualPaymentRequestId',
            'manual_payment_id',
            'manualPaymentId',
            'id',
          ],
        ) ??
        _extractIdFromMap(
          submission.raw,
          const [
            'manual_payment_request_id',
            'manualPaymentRequestId',
            'manual_payment_id',
            'manualPaymentId',
            'id',
          ],
        );

    if (manualRequestId != null) {
      return PaymentRouteResult.bank(manualRequestId);
    }

    final int? transactionId = submission.paymentTransactionIdAsInt ??
        _extractIdFromMap(
          submission.paymentTransaction,
          const [
            'payment_transaction_id',
            'paymentTransactionId',
            'transaction_id',
            'transactionId',
            'id',
          ],
        ) ??
        _extractIdFromMap(
          submission.raw,
          const [
            'payment_transaction_id',
            'paymentTransactionId',
            'transaction_id',
            'transactionId',
            'id',
          ],
        );

    if (transactionId != null) {
      return PaymentRouteResult.wallet(transactionId);
    }

    return null;
  }

  int? _extractIdFromMap(
      Map<String, dynamic>? source,
      List<String> keys,
      ) {
    if (source == null || source.isEmpty) {
      return null;
    }
    for (final key in keys) {
      if (!source.containsKey(key)) continue;
      final int? value = _flexInt(source[key]);
      if (value != null) {
        return value;
      }
    }
    return null;
  }

  Future<int?> _resolveTransactionIdForRoute(
      PaymentRouteResult routeResult, {
        dynamic fallbackTransaction,
      }) async {
    if (routeResult.kind == PaymentRouteKind.walletSuccess) {
      final int? direct = routeResult.walletTxnId;
      if (direct != null) {
        return direct;
      }
      final String? fallback =
      _extractPaymentTransactionId(fallbackTransaction);
      return fallback == null ? null : int.tryParse(fallback);
    }

    final int? manualRequestId = routeResult.manualRequestId;
    if (manualRequestId != null) {
      ManualPayment? manualPayment =
      await _manualPaymentService.fetchManualPaymentRequestById(
        manualRequestId,
      );

      if (manualPayment == null) {
        for (int attempt = 0; attempt < 2 && manualPayment == null; attempt++) {
          await Future<void>.delayed(const Duration(milliseconds: 500));
          manualPayment = await _manualPaymentService.fetchManualPaymentRequestById(
            manualRequestId,
          );
        }
      }

      final int? fromManual = _transactionIdFromManualPayment(manualPayment);
      if (fromManual != null) {
        return fromManual;
      }
    }

    final String? fallback = _extractPaymentTransactionId(fallbackTransaction);
    return fallback == null ? null : int.tryParse(fallback);
  }

  int? _transactionIdFromManualPayment(ManualPayment? manualPayment) {
    if (manualPayment == null) {
      return null;
    }

    final List<dynamic> candidates = <dynamic>[
      manualPayment.paymentTransactionId,
      manualPayment.manualPaymentId,
      manualPayment.transactionIdentifier,
      manualPayment.transactionReference,
      manualPayment.manualPaymentData?['payment_transaction_id'],
      manualPayment.manualPaymentData?['transaction_id'],
      manualPayment.manualPaymentData?['id'],
    ];

    for (final dynamic candidate in candidates) {
      final int? parsed = _flexInt(candidate);
      if (parsed != null) {
        return parsed;
      }
    }

    return null;
  }

  Future<void> _handlePaymentRouteNavigation(
      PaymentRouteResult result) async {
    if (!mounted) return;

    final NavigatorState navigator = Navigator.of(context);
    final NavigatorState rootNavigator =
    Navigator.of(context, rootNavigator: true);

    navigator.pop();

    Future.microtask(() {
      if (result.kind == PaymentRouteKind.walletSuccess &&
          result.walletTxnId != null) {
        rootNavigator.pushNamed(
          Routes.walletTransactionDetails,
          arguments: {'id': result.walletTxnId},
        );
      } else if (result.kind == PaymentRouteKind.bankTransferCreated &&
          result.manualRequestId != null) {
        rootNavigator.pushNamed(
          Routes.paymentRequestDetails,
          arguments: {'id': result.manualRequestId},
        );
      }
    });
  }




  Future<void> _navigateToTransactionDetails(String transactionId) async {
    try {
      final ManualPayment? manualPayment =
          await _fetchManualPaymentByTransactionId(transactionId);

      if (!mounted) return;

      if (manualPayment == null) {
        HelperUtils.showSnackBarMessage(
          context,
          'تعذّر العثور على تفاصيل المعاملة، سيتم فتح سجل المعاملات.',
        );
        unawaited(_openTransactionHistory(transactionId));
        return;
      }

      unawaited(
        Navigator.of(context, rootNavigator: true).pushReplacement(
          AppPageRoute.build(
            builder: (_) => ManualPaymentDetailsScreen(
              manualPayment: manualPayment,
              dateFormat: DateFormat('d MMM yyyy, h:mm a', 'ar'),
              pollInterval: ManualPaymentsController.pollInterval,
            ),
            motionPattern: AppMotionPattern.glide,
          ),
        ),
      );
      return;
    } catch (error) {
      if (!mounted) return;

      HelperUtils.showSnackBarMessage(
        context,
        'تعذّر تحميل تفاصيل المعاملة، سيتم فتح سجل المعاملات.',
      );
      unawaited(_openTransactionHistory(transactionId));
    }
  }

  Future<ManualPayment?> _fetchManualPaymentByTransactionId(
    String transactionId,
  ) async {
    final String trimmedId = transactionId.trim();
    if (trimmedId.isEmpty) {
      return null;
    }

    ManualPayment? manualPayment;
    for (int attempt = 0; attempt < 3; attempt++) {
      final List<ManualPayment> manualPayments =
          await _manualPaymentService.fetchMyManualPayments(
        latestOnly: false,
      );

      manualPayment = _matchManualPayment(manualPayments, trimmedId);
      if (manualPayment != null) {
        return manualPayment;
      }

      if (attempt < 2) {
        await Future<void>.delayed(const Duration(milliseconds: 600));
      }
    }

    return manualPayment;
  }

  ManualPayment? _matchManualPayment(
    Iterable<ManualPayment> manualPayments,
    String transactionId,
  ) {
    final String trimmedId = transactionId.trim();
    if (trimmedId.isEmpty) {
      return null;
    }

    for (final ManualPayment payment in manualPayments) {
      final Iterable<String?> candidates = <String?>[
        payment.paymentTransactionId,
        payment.manualPaymentId,
        payment.transactionIdentifier,
        payment.transactionReference,
        payment.manualPaymentIdentifierLabel,
      ];

      for (final String? value in candidates) {
        if (value == null) continue;
        final String candidate = value.trim();
        if (candidate.isEmpty) continue;
        if (candidate == trimmedId) {
          return payment;
        }
      }
    }

    return null;
  }

  Future<void> _openTransactionHistory(String transactionId) async {
    if (!mounted) {
      return;
    }

    await Navigator.of(context, rootNavigator: true).pushReplacementNamed(
      Routes.transactionHistory,
      arguments: {'focus_transaction_id': transactionId},
    );
  }

  bool _tryNavigateUsingNext(Map<String, dynamic>? next, String transactionId) {
    final String? routeToken = _extractNextRoute(next);

    if (routeToken == null) {
      return false;
    }

    final NavigatorState navigator =
        Navigator.of(context, rootNavigator: true);
    final String targetTransactionId =
        _extractNextTransactionId(next) ?? transactionId;

    if (routeToken == _nextRouteWalletTransactions) {
      navigator.pushReplacementNamed(
        Routes.wallet,
        arguments: {
          'initial_tab': 'transactions',
          'focus_transaction_id': targetTransactionId,
        },
      );
      return true;
    }

    if (routeToken == _nextRouteTransactionsHistory) {
      navigator.pushReplacementNamed(
        Routes.transactionHistory,
        arguments: {'focus_transaction_id': targetTransactionId},
      );
      return true;
    }

    return false;
  }

  ManualPayment? _manualPaymentFromResult(
    dynamic result, {
    Map<String, dynamic>? subject,
    Map<String, dynamic>? next,
  }) {
    final Set<int> visited = <int>{};
    final List<Map<String, dynamic>> candidates = <Map<String, dynamic>>[];

    void collect(dynamic value) {
      if (value == null) return;

      if (value is ManualPaymentSubmissionResult) {
        collect(value.manualPaymentRequest);
        collect(value.paymentTransaction);
        collect(value.subject);
        collect(value.next);
        collect(value.raw);
        return;
      }

      if (value is Map<String, dynamic>) {
        _collectManualPaymentMaps(value, candidates, visited);
        return;
      }

      if (value is Map) {
        _collectManualPaymentMaps(_normalizeMap(value), candidates, visited);
        return;
      }

      if (value is Iterable) {
        for (final dynamic element in value) {
          collect(element);
        }
      }
    }

    collect(result);
    collect(subject);
    collect(next);

    for (final Map<String, dynamic> map in candidates) {
      try {
        final ManualPayment manualPayment = ManualPayment.fromJson(map);
        if ((manualPayment.paymentTransactionId?.isNotEmpty ?? false) ||
            (manualPayment.manualPaymentId?.isNotEmpty ?? false)) {
          return manualPayment;
        }
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  String? _extractNextRoute(Map<String, dynamic>? next) {
    if (next == null || next.isEmpty) {
      return null;
    }

    final dynamic candidate =
        next['route'] ?? next['redirect_route'] ?? next['redirect'] ?? next['screen'];

    if (candidate is String) {
      final String trimmed = candidate.trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    return null;
  }

  String? _extractNextTransactionId(Map<String, dynamic>? next) {
    if (next == null || next.isEmpty) {
      return null;
    }

    final dynamic candidate =
        next['transaction_id'] ?? next['payment_transaction_id'] ?? next['id'];

    if (candidate is String) {
      final String trimmed = candidate.trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    if (candidate is num) {
      return candidate.toString();
    }

    return null;
  }

  void _collectManualPaymentMaps(
    Map<String, dynamic>? map,
    List<Map<String, dynamic>> output,
    Set<int> visited,
  ) {
    if (map == null || map.isEmpty) {
      return;
    }

    final Map<String, dynamic> normalized = Map<String, dynamic>.from(map);
    if (!visited.add(identityHashCode(normalized))) {
      return;
    }

    final Map<String, dynamic>? nestedManual =
        _extractManualPaymentCandidate(normalized);
    if (nestedManual != null) {
      _collectManualPaymentMaps(nestedManual, output, visited);
    }

    if (_looksLikeManualPaymentMap(normalized)) {
      output.add(normalized);
    }

    for (final dynamic value in normalized.values) {
      if (value is Map<String, dynamic>) {
        _collectManualPaymentMaps(value, output, visited);
      } else if (value is Map) {
        _collectManualPaymentMaps(_normalizeMap(value), output, visited);
      } else if (value is Iterable) {
        for (final dynamic entry in value) {
          if (entry is Map<String, dynamic>) {
            _collectManualPaymentMaps(entry, output, visited);
          } else if (entry is Map) {
            _collectManualPaymentMaps(_normalizeMap(entry), output, visited);
          }
        }
      }
    }
  }

  Map<String, dynamic>? _extractManualPaymentCandidate(
    Map<String, dynamic> map,
  ) {
    for (final String key in map.keys) {
      final String lowerKey = key.toLowerCase();
      if (lowerKey == 'manual_payment' || lowerKey == 'manualpayment') {
        final dynamic value = map[key];
        if (value is Map<String, dynamic>) {
          return value;
        }
        if (value is Map) {
          return _normalizeMap(value);
        }
      }
    }
    return null;
  }

  bool _looksLikeManualPaymentMap(Map<String, dynamic> map) {
    final Set<String> lowerKeys =
        map.keys.map((dynamic key) => key.toString().toLowerCase()).toSet();
    const Set<String> identifiers = <String>{
      'payment_transaction_id',
      'paymenttransactionid',
      'manual_payment_id',
      'manualpaymentid',
      'transaction_identifier',
      'transactionidentifier',
    };
    const Set<String> essentials = <String>{
      'payment_gateway',
      'paymentgateway',
      'amount',
      'currency',
      'payable_type',
      'payabletype',
    };

    final bool hasIdentifier =
        lowerKeys.any((String key) => identifiers.contains(key));
    final bool hasEssentials =
        essentials.every((String key) => lowerKeys.contains(key));

    return hasIdentifier || hasEssentials;
  }

  Future<PaymentRouteResult?> _handlePaymentRequired({
    required ApiHttpException error,
  }) async {
    if (!mounted) return null;

    final Map<String, dynamic> payload = _normalizeMap(error.payload);

    final int? payloadServiceRequestId = _flexInt(
      payload['service_request_id'] ??
          payload['serviceRequestId'] ??
          payload['request_id'],
    );

    if (payloadServiceRequestId != null) {
      _pendingServiceRequestId = payloadServiceRequestId;
    }

    final int? serviceRequestId =
        payloadServiceRequestId ?? _pendingServiceRequestId;

    if (serviceRequestId == null) {
      HelperUtils.showSnackBarMessage(
        context,
        'Missing service request identifier. Please try again.',
      );
      return null;
    }

    if (mounted) {
      setState(() => _submitting = false);
    }

    final int? serviceId =
        _serviceId ?? _flexInt(payload['service_id'] ?? payload['serviceId']);
    if (serviceId == null) {
      HelperUtils.showSnackBarMessage(
        context,
        'Unable to determine the service for payment.',
      );
      return null;
    }

    final double? amount =
        _amount ?? _flexDouble(payload['amount'] ?? payload['price']);
    if (amount == null || amount <= 0) {
      HelperUtils.showSnackBarMessage(
        context,
        'Payment amount is missing or invalid.',
      );
      return null;
    }

    final String? currencyCandidate = _stringify(
      payload['currency'] ??
          payload['currency_code'] ??
          payload['currencyCode'],
    );

    final String? priceNote =
        _stringify(payload['price_note'] ?? payload['note']);

    final String? serviceTitle =
        _stringify(payload['service_title'] ?? payload['serviceName']);

    final PaymentRouteResult? routeResult = await _startManualPaymentFlow(
      serviceId: serviceId,
      serviceRequestId: serviceRequestId,
      amount: amount,
      currency: currencyCandidate ?? _currency,
      priceNote: priceNote,
      serviceTitle: serviceTitle,
      initialGateway: _preferredGatewayFromPayload(payload),
      fallbackTransaction:
          payload['payment_transaction'] ?? payload['payment_transaction_id'],
    );

    return routeResult;
  }

  Map<String, dynamic>? _extractSubjectFromResult(dynamic value) {
    if (value is ManualPaymentSubmissionResult) {
      return value.subject;
    }

    final Map<String, dynamic> map = _normalizeMap(value);
    if (map.isEmpty) {
      return null;
    }

    final Map<String, dynamic> subject = _normalizeMap(map['subject']);
    return subject.isEmpty ? null : subject;
  }

  Map<String, dynamic>? _extractNextFromResult(dynamic value) {
    if (value is ManualPaymentSubmissionResult) {
      return value.next;
    }

    final Map<String, dynamic> map = _normalizeMap(value);
    if (map.isEmpty) {
      return null;
    }

    final Map<String, dynamic> next = _normalizeMap(map['next']);
    return next.isEmpty ? null : next;
  }

  Map<String, dynamic> _normalizeMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return Map<String, dynamic>.from(value);
    }
    if (value is Map) {
      return value.map((dynamic key, dynamic val) =>
          MapEntry<String, dynamic>(key.toString(), val));
    }
    return <String, dynamic>{};
  }

  int? _flexInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      return int.tryParse(trimmed);
    }
    return null;
  }

  double? _flexDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      return double.tryParse(trimmed);
    }
    return null;
  }

  String? _stringify(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    if (value is num) {
      return value.toString();
    }
    if (value is bool) {
      return value ? 'true' : 'false';
    }
    final String stringified = value.toString().trim();
    return stringified.isEmpty ? null : stringified;
  }

  String? _preferredGatewayFromPayload(Map<String, dynamic> payload) {
    final List<dynamic> candidates = [
      payload['preferred_payment_method'],
      payload['preferred_payment_gateway'],
      payload['default_payment_method'],
      payload['default_payment_gateway'],
    ];

    for (final candidate in candidates) {
      final normalized = _stringify(candidate);
      if (normalized != null && normalized.isNotEmpty) {
        return normalized;
      }
    }

    final dynamic allowedRaw =
        payload['allowed_gateways'] ?? payload['allowed_payment_methods'];
    if (allowedRaw is Iterable) {
      for (final entry in allowedRaw) {
        final normalized = _stringify(entry);
        if (normalized != null && normalized.isNotEmpty) {
          return normalized;
        }
      }
    }

    return null;
  }

  String? _extractPaymentTransactionId(
    dynamic source, {
    dynamic fallback,
  }) {
    String? fromValue(dynamic value) {
      if (value is Map || value is Map<String, dynamic>) {
        final map = _normalizeMap(value);
        final String? candidate = _stringify(
          map['payment_transaction_id'] ??
              map['paymentTransactionId'] ??
              map['transaction_id'] ??
              map['id'],
        );
        if (candidate != null) {
          return candidate;
        }
        if (map.containsKey('payment_transaction')) {
          return fromValue(map['payment_transaction']);
        }
        if (map.containsKey('transaction')) {
          return fromValue(map['transaction']);
        }
        if (map.containsKey('data')) {
          return fromValue(map['data']);
        }
        return null;
      }

      return _stringify(value);
    }

    if (source is ManualPaymentSubmissionResult) {
      final List<dynamic> candidates = [
        source.paymentTransactionId,
        source.manualPaymentId,
        source.paymentTransaction,
        source.manualPaymentRequest,
        source.raw,
      ];

      for (final candidate in candidates) {
        final normalized = fromValue(candidate);
        if (normalized != null && normalized.isNotEmpty) {
          return normalized;
        }
      }
    } else {
      final normalized = fromValue(source);
      if (normalized != null && normalized.isNotEmpty) {
        return normalized;
      }
    }

    if (fallback != null) {
      final normalized = fromValue(fallback);
      if (normalized != null && normalized.isNotEmpty) {
        return normalized;
      }
    }

    return null;
  }
}
