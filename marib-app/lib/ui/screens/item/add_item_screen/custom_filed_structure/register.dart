import 'dart:convert';


import 'package:marib/ui/screens/item/add_item_screen/custom_filed_structure/custom_field.dart';

import 'package:marib/ui/screens/item/add_item_screen/custom_filed_structure/fields/custom_checkbox_field.dart';

import 'package:marib/ui/screens/item/add_item_screen/custom_filed_structure/fields/custom_color_field.dart';

import 'package:marib/ui/screens/item/add_item_screen/custom_filed_structure/fields/custom_dropdown_field.dart';

import 'package:marib/ui/screens/item/add_item_screen/custom_filed_structure/fields/custom_file_field.dart';
import 'package:marib/ui/screens/item/add_item_screen/custom_filed_structure/fields/custom_color_field2.dart';

import 'package:marib/ui/screens/item/add_item_screen/custom_filed_structure/fields/custom_number_field.dart';

import 'package:marib/ui/screens/item/add_item_screen/custom_filed_structure/fields/custom_radio_field.dart';

import 'package:marib/ui/screens/item/add_item_screen/custom_filed_structure/fields/custom_text_field.dart';

class KRegisteredFields {
  CustomField? resolve(Map<dynamic, dynamic> field) {
    final String type = _normalizeType(field['type']);

    switch (type) {
      case 'textbox':
      case 'text':
      case 'textarea':
        return CustomFieldText();
      case 'dropdown':
      case 'select':
        return CustomFieldDropdown();
      case 'number':
      case 'numeric':
        return CustomNumberField();
      case 'checkbox':
      case 'checkboxes':
        return CustomCheckboxField();
      case 'radio':
      case 'radiobox':
        return CustomRadioField();
      case 'fileinput':
      case 'file':
        return CustomFileField();
      case 'color':
        return _shouldUseAttributeColor(field)
            ? CustomColorFieldAttributes()
            : CustomColorField();
      default:
        return null;
    }
  }

  CustomField? get(String type) {
    return resolve({'type': type});
  }

  String _normalizeType(dynamic type) {
    if (type is String) {
      return type.trim().toLowerCase();
    }
    if (type is Enum) {
      return type.name.toLowerCase();
    }
    return type?.toString().trim().toLowerCase() ?? '';
  }

  bool _shouldUseAttributeColor(Map<dynamic, dynamic> field) {
    bool _truthy(dynamic value) {
      if (value == null) return false;
      if (value is bool) return value;
      if (value is num) return value != 0;
      if (value is String) {
        final normalized = value.trim().toLowerCase();
        if (normalized.isEmpty) return false;
        return ['true', '1', 'yes', 'y', 'on'].contains(normalized);
      }
      return false;

    }

    final dynamic colorEntries = field['color_entries'] ?? field['colorEntries'];
    if (colorEntries is Iterable && colorEntries.isNotEmpty) {
      return true;
    }
    if (colorEntries is Map && colorEntries.isNotEmpty) {
      return true;
    }
    if (colorEntries is String) {
      final trimmed = colorEntries.trim();
      if (trimmed.isNotEmpty) {
        if (trimmed.startsWith('[') || trimmed.startsWith('{')) {
          try {
            final decoded = jsonDecode(trimmed);
            if (decoded is Iterable && decoded.isNotEmpty) {
              return true;
            }
            if (decoded is Map && decoded.isNotEmpty) {
              return true;
            }
          } catch (_) {
            if (trimmed.contains('quantity') || trimmed.contains('code')) {
              return true;
            }
          }
        } else if (trimmed.contains('quantity') || trimmed.contains('code')) {
          return true;
        }
      }
    }

    final dynamic meta = field['meta'];
    if (meta is Map) {
      if (_truthy(meta['allow_quantities']) ||
          _truthy(meta['enable_quantities']) ||
          _truthy(meta['supports_quantities'])) {
        return true;
      }
      final dynamic mode = meta['mode'] ?? meta['context'];
      if (mode is String && _looksLikeAttributeContext(mode)) {
        return true;
      }
    }

    final dynamic context =
        field['context'] ?? field['scope'] ?? field['usage'] ?? field['layout'];
    if (context is String && _looksLikeAttributeContext(context)) {
      return true;
    }

    if (_truthy(field['allow_quantities']) ||
        _truthy(field['enable_quantities']) ||
        _truthy(field['supports_quantities']) ||
        _truthy(field['for_attributes']) ||
        _truthy(field['is_attribute'])) {
      return true;
    }

    return false;
  }

  bool _looksLikeAttributeContext(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) {
      return false;
    }
    return normalized.contains('attribute') ||
        normalized.contains('attributes') ||
        normalized.contains('سمات') ||
        normalized.contains('variants') ||
        normalized.contains('variant');
  }
}
