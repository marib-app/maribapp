

import 'package:marib/ui/screens/item/add_item_screen/custom_filed_structure/register.dart';
import 'package:flutter/material.dart';
import 'package:marib/ui/screens/item/add_item_screen/custom_filed_structure/register.dart';

String resolveFieldLabel(BuildContext context, Map<String, dynamic> j) {
  final locale = Localizations.localeOf(context).languageCode;
  final translations = j['translations'];
  String? translated;

  if (translations is Map) {
    dynamic localeEntry = translations[locale];

    if (localeEntry == null && locale.contains('-')) {
      localeEntry = translations[locale.split('-').first];
    }

    if (localeEntry == null && locale.contains('_')) {
      localeEntry = translations[locale.split('_').first];
    }

    if (localeEntry is Map) {
      translated = (localeEntry['label'] ??
          localeEntry['name'] ??
          localeEntry['title'])
          ?.toString();
    } else if (localeEntry != null) {
      translated = localeEntry.toString();
    }
  }

  String? pick(List<dynamic> values) {
    for (final value in values) {
      if (value is String) {
        final trimmed = value.trim();
        if (trimmed.isNotEmpty) {
          return trimmed;
        }
      }
    }
    return null;
  }

  return pick([
    translated,
    j['display_name'],
    j['label'],
    j['name'],
    j['title'],
    j['key'],
  ]) ??
      '';
}
///Structure
abstract class CustomField {
  abstract String type;

  late BuildContext context;


  // داخل class CustomField { ... }
  static final Map<String, dynamic> fieldsData = {};
  static final Map<String, dynamic> files = {};



  void init() {}
  dynamic update;
  Map parameters = {};

  Widget render();
}

class CustomFieldBuilder {
  final Map field;
  final KRegisteredFields _registry = KRegisteredFields();

  CustomFieldBuilder(this.field) {
    customField = _registry.resolve(field);
  }

  CustomField? customField;


  void init() {
    customField ??= _registry.resolve(field);

    customField?.parameters = field;
    //Calling init of custom field from here and this init will be called into the UI
    customField?.init();
  }

  void stateUpdater(StateSetter updater) {
    customField?.update = updater;

  }

  Widget build(BuildContext context) {
    ///setting parameters from here
    customField?.parameters = field;
    customField ??= _registry.resolve(field);


    ///setting context from here
    customField?.context = context;

    //Calling render function so we can get widget
    Widget? render = customField?.render();
    final Widget? render = customField?.render();
    return render ?? Container();
  }
}
