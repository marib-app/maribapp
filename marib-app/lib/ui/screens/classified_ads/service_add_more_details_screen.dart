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
    show CustomFieldBuilder;

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
      title = _str(m['notes']) ?? _str(m['hint']) ?? '—';
    }

    m['title'] = title;
    m['label'] = m['label'] ?? title;
    m['name'] = m['name'] ?? title;
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
    } catch (_) {}
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



    final customFields = Map<String, dynamic>.from(
      dynamic_fields.AbstractField.fieldsData,
    );
    final attachments = Map<String, dynamic>.from(
      dynamic_fields.AbstractField.files,

    );
    setState(() => _submitting = true);
    try {
      final request = await _requestRepository.createRequest(
        serviceId: _serviceId!,
        serviceUid: _serviceUid,


        customFields: customFields.isEmpty ? null : customFields,
        attachments: attachments.isEmpty ? null : attachments,
      );

      final pendingRequest = <String, dynamic>{
        ...request.raw,
        ...request.toBannerData(),
        if (_serviceUid != null) 'service_uid': _serviceUid,

        if (request.customFields != null)
          'custom_fields': request.customFields,
        if (customFields.isNotEmpty && request.customFields == null)
          'custom_fields': customFields,
        if (attachments.isNotEmpty) 'attachments': attachments,
      };

      if (!mounted) return;
      _clearStores();
      Navigator.pushNamed(
        context,
        Routes.serviceRequestsPage,
        arguments: {
          'pendingRequest': pendingRequest,
          if (_categoryId != null) 'categoryId': _categoryId,
        },
      );
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

