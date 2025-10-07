import 'package:marib/utils/ui_utils.dart';
import 'package:flutter/cupertino.dart';

extension TranslateString on String {
  String translate(BuildContext context) {
    return UiUtils.getTranslatedLabel(context, this);
  }
}
