


import 'package:marib/ui/screens/item/add_item_screen/custom_filed_structure/custom_field.dart';

import 'package:marib/ui/screens/item/add_item_screen/custom_filed_structure/fields/custom_checkbox_field.dart';

import 'package:marib/ui/screens/item/add_item_screen/custom_filed_structure/fields/custom_color_field.dart';

import 'package:marib/ui/screens/item/add_item_screen/custom_filed_structure/fields/custom_dropdown_field.dart';

import 'package:marib/ui/screens/item/add_item_screen/custom_filed_structure/fields/custom_file_field.dart';

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
        return CustomColorField();

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


}
