// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:marib/utils/hive_keys.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive/hive.dart';

class LanguageState {}

class LanguageInitial extends LanguageState {}

class LanguageLoader extends LanguageState {
  final dynamic language;

  LanguageLoader(this.language);
}

class LanguageLoadFail extends LanguageState {
  final dynamic error;
  LanguageLoadFail({required this.error});
}

class LanguageCubit extends Cubit<LanguageState> {
  LanguageCubit() : super(LanguageInitial());

  void loadCurrentLanguage() {
    final box = Hive.box(HiveKeys.languageBox);
    var language = box.get(HiveKeys.currentLanguageKey);
    language ??= {
      'code': 'en',
      'name': 'English',
      'name_in_english': 'English',
      'image': '',
      'data': <String, dynamic>{},
      'rtl': false,
    };

    box.put(HiveKeys.currentLanguageKey, language);
    emit(LanguageLoader(language));
  }

  dynamic currentLanguageCode() {
    return Hive.box(HiveKeys.languageBox)
        .get(HiveKeys.currentLanguageKey)['code'];
  }
}
