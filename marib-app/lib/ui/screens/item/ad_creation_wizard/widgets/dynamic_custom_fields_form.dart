import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/custom_field_schema.dart';

class DynamicCustomFieldsForm extends StatefulWidget {
  const DynamicCustomFieldsForm({
    super.key,
    required this.fields,
    required this.values,
    required this.onChanged,
  });

  final List<CustomFieldSchema> fields;
  final Map<String, dynamic> values;
  final ValueChanged<Map<String, dynamic>> onChanged;

  @override
  DynamicCustomFieldsFormState createState() => DynamicCustomFieldsFormState();
}

class DynamicCustomFieldsFormState extends State<DynamicCustomFieldsForm> {
  final Map<String, TextEditingController> _controllers = <String, TextEditingController>{};
  final Map<String, String?> _errors = <String, String?>{};

  @override
  void dispose() {
    for (final TextEditingController controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant DynamicCustomFieldsForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    final Set<String> newFieldIds = widget.fields.map((CustomFieldSchema f) => f.id).toSet();
    final Set<String> removed = oldWidget.fields
        .map((CustomFieldSchema f) => f.id)
        .where((String id) => !newFieldIds.contains(id))
        .toSet();

    for (final String id in removed) {
      _controllers.remove(id)?.dispose();
      _errors.remove(id);
    }

    for (final CustomFieldSchema field in widget.fields) {
      if (field.type == CustomFieldType.text) {
        final TextEditingController controller = _ensureController(field);
        final String text = _stringValue(field.id);
        if (controller.text != text) {
          controller.value = controller.value.copyWith(
            text: text,
            selection: TextSelection.collapsed(offset: text.length),
          );
        }
      }
    }
  }

  bool validate() {
    final Map<String, String?> errors = <String, String?>{};
    bool valid = true;

    for (final CustomFieldSchema field in widget.fields) {
      final dynamic value = widget.values[field.id];
      final bool hasValue = _hasValue(field, value);
      if (field.isRequired && !hasValue) {
        errors[field.id] = 'هذا الحقل مطلوب';
        valid = false;
      }
    }

    setState(() {
      _errors
        ..clear()
        ..addAll(errors);
    });

    return valid;
  }

  void clearValidationErrors() {
    if (_errors.isEmpty) {
      return;
    }
    setState(() => _errors.clear());
  }


  void applyValidationErrors(Map<String, String> errors) {
    setState(() {
      _errors
        ..clear()
        ..addAll(errors);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.fields.isEmpty) {
      return const Center(child: Text('لا توجد حقول مخصّصة لهذه الفئة.'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widget.fields
          .map((CustomFieldSchema field) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: _buildField(context, field),
      ))
          .toList(growable: false),
    );
  }

  Widget _buildField(BuildContext context, CustomFieldSchema field) {
    switch (field.type) {
      case CustomFieldType.singleChoice:
        return _buildSingleChoiceField(context, field);
      case CustomFieldType.multiChoice:
        return _buildMultiChoiceField(context, field);
      case CustomFieldType.text:
      default:
        return _buildTextField(context, field);
    }
  }

  Widget _buildLabel(CustomFieldSchema field) {
    final TextStyle baseStyle = Theme.of(context).textTheme.titleMedium ?? const TextStyle(fontSize: 16);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                field.label,
                style: baseStyle.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            if (field.isRequired)
              Text(
                '*',
                style: baseStyle.copyWith(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
        if (field.description != null && field.description!.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              field.description!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }

  Widget _buildTextField(BuildContext context, CustomFieldSchema field) {
    final TextEditingController controller = _ensureController(field);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(field),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            errorText: _errors[field.id],
            hintText: 'أدخل ${field.label.toLowerCase()}',
          ),
        ),
      ],
    );
  }

  Widget _buildSingleChoiceField(BuildContext context, CustomFieldSchema field) {
    final String? selectedValue = widget.values[field.id]?.toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(field),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            errorText: _errors[field.id],
          ),
          value: selectedValue != null && field.options.any((CustomFieldOption option) => option.value == selectedValue)
              ? selectedValue
              : null,
          items: field.options
              .map(
                (CustomFieldOption option) => DropdownMenuItem<String>(
              value: option.value,
              child: Text(option.label),
            ),
          )
              .toList(growable: false),
          onChanged: (String? value) {
            _updateValue(field.id, value);
          },
        ),
      ],
    );
  }

  Widget _buildMultiChoiceField(BuildContext context, CustomFieldSchema field) {
    final List<String> selectedValues = _stringListValue(field.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(field),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: field.options.map((CustomFieldOption option) {
            final bool isSelected = selectedValues.contains(option.value);
            return FilterChip(
              label: Text(option.label),
              selected: isSelected,
              onSelected: (bool selected) {
                final Set<String> next = selectedValues.toSet();
                if (selected) {
                  next.add(option.value);
                } else {
                  next.remove(option.value);
                }
                _updateValue(field.id, next.toList(growable: false));
              },
            );
          }).toList(growable: false),
        ),
        if (_errors[field.id] != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _errors[field.id]!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
    );
  }

  TextEditingController _ensureController(CustomFieldSchema field) {
    return _controllers.putIfAbsent(field.id, () {
      final TextEditingController controller = TextEditingController(text: _stringValue(field.id));
      controller.addListener(() {
        _updateValue(field.id, controller.text.trim());
      });
      return controller;
    });
  }

  bool _hasValue(CustomFieldSchema field, dynamic value) {
    if (value == null) {
      return false;
    }

    if (field.type == CustomFieldType.multiChoice) {
      if (value is Iterable) {
        return value.where((dynamic element) => element.toString().trim().isNotEmpty).isNotEmpty;
      }
      return false;
    }

    if (value is String) {
      return value.trim().isNotEmpty;
    }

    return true;
  }

  String _stringValue(String fieldId) {
    final dynamic value = widget.values[fieldId];
    if (value == null) {
      return '';
    }
    return value.toString();
  }

  List<String> _stringListValue(String fieldId) {
    final dynamic value = widget.values[fieldId];
    if (value is List<String>) {
      return value;
    }
    if (value is Iterable) {
      return value.map((dynamic e) => e.toString()).toSet().toList(growable: false);
    }
    if (value is String && value.trim().isNotEmpty) {
      return value.split(',').map((String e) => e.trim()).where((String e) => e.isNotEmpty).toList(growable: false);
    }
    return const <String>[];
  }

  void _updateValue(String fieldId, dynamic value) {
    final Map<String, dynamic> next = Map<String, dynamic>.from(widget.values);
    final dynamic normalized = _normalizeValue(value);
    if (_areValuesEqual(next[fieldId], normalized)) {
      return;
    }
    if (normalized == null || (normalized is String && normalized.isEmpty)) {
      next.remove(fieldId);
    } else {
      next[fieldId] = normalized;
    }
    widget.onChanged(next);
    if (_errors.containsKey(fieldId)) {
      setState(() {
        _errors.remove(fieldId);
      });
    }
  }

  dynamic _normalizeValue(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is String) {
      final String trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    if (value is Iterable) {
      final List<String> normalized = value
          .map((dynamic e) => e.toString().trim())
          .where((String element) => element.isNotEmpty)
          .toSet()
          .toList(growable: false);
      return normalized.isEmpty ? null : normalized;
    }
    return value;
  }

  bool _areValuesEqual(dynamic a, dynamic b) {
    if (a is Iterable && b is Iterable) {
      return listEquals(a.map((dynamic e) => e.toString()).toList(),
          b.map((dynamic e) => e.toString()).toList());
    }
    return a == b;
  }
}