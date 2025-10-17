import 'package:flutter/foundation.dart';

/// Represents a selectable option in a custom field definition.
class CustomFieldOption {
  const CustomFieldOption({required this.value, required this.label});

  final String value;
  final String label;

  factory CustomFieldOption.fromMap(Map<String, dynamic> map) {
    return CustomFieldOption(
      value: map['value']?.toString() ?? '',
      label: map['label']?.toString() ?? map['name']?.toString() ?? '',
    );
  }
}

/// Supported custom field types in the wizard.
enum CustomFieldType {
  text,
  singleChoice,
  multiChoice,
}

/// Schema definition for a custom field.
class CustomFieldSchema {
  const CustomFieldSchema({
    required this.id,
    required this.label,
    required this.type,
    this.description,
    this.isRequired = false,
    this.options = const <CustomFieldOption>[],
  });

  final String id;
  final String label;
  final CustomFieldType type;
  final String? description;
  final bool isRequired;
  final List<CustomFieldOption> options;

  factory CustomFieldSchema.fromMap(Map<String, dynamic> map) {
    final String rawType = map['type']?.toString().trim().toLowerCase() ?? 'text';
    final CustomFieldType type = _parseType(rawType);

    return CustomFieldSchema(
      id: map['id']?.toString() ?? map['key']?.toString() ?? map['name']?.toString() ?? rawType,
      label: map['label']?.toString() ?? map['name']?.toString() ?? map['title']?.toString() ?? '',
      description: map['description']?.toString() ?? map['notes']?.toString(),
      isRequired: map['required'] == true || map['required'] == 1,
      type: type,
      options: type == CustomFieldType.text
          ? const <CustomFieldOption>[]
          : _parseOptions(map['options'] ?? map['values'] ?? map['choices']),
    );
  }

  static List<CustomFieldOption> _parseOptions(dynamic source) {
    if (source is List) {
      return source
          .map((dynamic option) {
        if (option is CustomFieldOption) {
          return option;
        }
        if (option is Map<String, dynamic>) {
          return CustomFieldOption.fromMap(option);
        }
        return CustomFieldOption(value: option.toString(), label: option.toString());
      })
          .whereType<CustomFieldOption>()
          .toList(growable: false);
    }

    if (source is Map) {
      return source.entries
          .map((MapEntry<dynamic, dynamic> entry) => CustomFieldOption(
        value: entry.key.toString(),
        label: entry.value?.toString() ?? entry.key.toString(),
      ))
          .toList(growable: false);
    }

    if (source is String && source.trim().isNotEmpty) {
      final List<String> segments = source.split(',');
      return segments
          .map((String value) => value.trim())
          .where((String value) => value.isNotEmpty)
          .map((String value) => CustomFieldOption(value: value, label: value))
          .toList(growable: false);
    }

    return const <CustomFieldOption>[];
  }

  static CustomFieldType _parseType(String rawType) {
    switch (rawType) {
      case 'dropdown':
      case 'select':
      case 'single':
      case 'radio':
        return CustomFieldType.singleChoice;
      case 'multi':
      case 'checkbox':
      case 'multiple':
      case 'multi_select':
      case 'multiselect':
        return CustomFieldType.multiChoice;
      case 'text':
      case 'textarea':
      case 'textbox':
      default:
        return CustomFieldType.text;
    }
  }

  /// Formats a value for display in the review step.
  String formatValue(dynamic value) {
    if (value == null) {
      return '';
    }

    if (value is Iterable) {
      final List<String> items = value.map((dynamic e) => e.toString()).toList(growable: false);
      return items.join(', ');
    }

    return value.toString();
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CustomFieldSchema &&
        other.id == id &&
        other.label == label &&
        other.type == type &&
        other.description == description &&
        other.isRequired == isRequired &&
        listEquals(other.options, options);
  }

  @override
  int get hashCode => Object.hash(id, label, type, description, isRequired, Object.hashAll(options));
}