//For localization of app

import 'dart:convert';

import 'package:marib/utils/hive_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppLocalization {
  final Locale locale;

  //it will hold key of text and it's values in given language
  late Map<String, String> _localizedValues;

  AppLocalization(this.locale);

  //to access app-localization instance any where in app using context
  static AppLocalization? of(BuildContext context) {
    return Localizations.of(context, AppLocalization);
  }

  //to load json(language) from assets
  Future loadJson() async {

    String jsonStringValues =
        await rootBundle.loadString('assets/languages/template.json');
    // value from root-bundle will be encoded string
    final Map<String, dynamic> templateJson =
    Map<String, dynamic>.from(json.decode(jsonStringValues));
    final Map<String, dynamic> mergedJson = Map<String, dynamic>.from(templateJson);

    final String localeFilePath = 'assets/languages/${locale.languageCode}.json';
    try {
      final String localeJsonString = await rootBundle.loadString(localeFilePath);
      final Map<String, dynamic> localeJson =
      Map<String, dynamic>.from(json.decode(localeJsonString));
      mergedJson.addAll(localeJson);
    } on FlutterError catch (_) {
      // ignore when specific locale file does not exist and fall back to template values
    } catch (_) {
      // ignore any other errors while loading optional locale file
    }

    final dynamic hiveLanguage = HiveUtils.getLanguage();
    if (hiveLanguage != null && hiveLanguage['data'] != null) {
      final Map<String, dynamic> hiveJson =
      Map<String, dynamic>.from(hiveLanguage['data']);
      hiveJson.forEach((key, value) {
        mergedJson[key] = value;
      });
    }


    _localizedValues = mergedJson
        .map((key, value) => MapEntry(key, value.toString()));
  }

  //to get translated value of given title/key
  String? getTranslatedValues(String? key) {
    return _localizedValues[key!];
  }

  //need to declare custom delegate
  static const LocalizationsDelegate<AppLocalization> delegate =
      _AppLocalizationDelegate();
}

//Custom app delegate
class _AppLocalizationDelegate extends LocalizationsDelegate<AppLocalization> {
  const _AppLocalizationDelegate();

  //providing all supported languages
  @override
  bool isSupported(Locale locale) {
    //
    return true;
  }

  //load languageCode.json files
  @override
  Future<AppLocalization> load(Locale locale) async {
    AppLocalization localization = AppLocalization(locale);
    await localization.loadJson();
    return localization;
  }

  @override
  bool shouldReload(LocalizationsDelegate<AppLocalization> old) {
    return true;
  }
}
