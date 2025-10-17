import 'package:marib/utils/constant.dart';


/// Utility helpers for normalising delivery department identifiers sent to
/// the pricing API. The backend expects lowercase ASCII slugs such as
/// `shein`, `computer`, or `general`. Any other value should fall back to the
/// default policy by omitting the parameter entirely.
String? normalizeDeliveryDepartment(String? raw) {
  if (raw == null) {
    return null;
  }

  final String trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return null;
  }

  final String lower = trimmed.toLowerCase();
  final String asciiSlug = _asciiSlug(lower);
  if (asciiSlug.isNotEmpty) {
    final String? matched = _matchDepartment(asciiSlug);
    if (matched != null) {
      return matched;
    }

  }

  final String normalizedKey = _normalizeDepartmentKey(lower);
  if (normalizedKey.isEmpty) {


    return null;
  }



  return _matchDepartment(normalizedKey);
}

String _asciiSlug(String value) {
  final String sanitized = value.replaceAll(RegExp(r'[^a-z0-9]+'), '');


  return sanitized;
}



String? _matchDepartment(String key) {
  if (key.isEmpty) {
    return null;
  }

  final String? alias = _departmentAliases[key];
  if (alias != null) {
    return alias;
  }

  if (_looksLikeShein(key)) {
    return 'shein';
  }

  if (_looksLikeComputer(key)) {
    return 'computer';
  }

  if (_looksLikeGeneral(key)) {
    return 'store';
  }

  if (key.startsWith('category')) {
    final String digits = key.replaceFirst('category', '');
    final int? categoryId = int.tryParse(digits);
    if (categoryId != null) {
      return _departmentFromCategoryId(categoryId);
    }
  }

  return null;
}

bool _looksLikeShein(String value) {
  return value.contains('shein') ||
      value.contains('شيان') ||
      value.contains('شيئن') ||
      value.contains('شي ان') ||
      value.contains('شين');
}

bool _looksLikeComputer(String value) {
  return value.contains('computer') ||
      value.contains('كمبيوتر') ||
      value.contains('الكترون') ||
      value.contains('حاسب');
}

bool _looksLikeGeneral(String value) {
  return value.contains('store') ||
      value.contains('stores') ||
      value.contains('market') ||
      value.contains('عام') ||
      value.contains('عامه') ||
      value.contains('متجر') ||
      value.contains('متجرعام') ||
      value.contains('المتجر') ||
      value.contains('السوق') ||
      value.contains('سوق') ||
      value.contains('بقاله') ||
      value.contains('بقالة') ||
      value.contains('سوبرماركت') ||
      value.contains('ماركت') ||
      value.contains('default') ||
      value.contains('public') ||
      value.contains('accessor');
}

String? _departmentFromCategoryId(int categoryId) {
  if (categoryId == Constant.sheinRootCategoryId) {
    return 'shein';
  }

  if (categoryId == Constant.computerRootCategoryId) {
    return 'computer';
  }


  if (categoryId == Constant.storeRootCategoryId) {
    return 'store';
  }

  return null;
}

String? resolveDeliveryDepartmentFromCategoryIds(Iterable<int> categoryIds) {
  for (final int id in categoryIds) {
    final String? department = _departmentFromCategoryId(id);
    if (department != null) {
      return department;
    }
  }
  return null;
}




String _normalizeDepartmentKey(String value) {
  String result = value
      .replaceAll(RegExp(r'[إأآٱ]'), 'ا')
      .replaceAll(RegExp(r'ة'), 'ه')
      .replaceAll(RegExp(r'ى'), 'ي')
      .replaceAll(RegExp(r'ؤ'), 'و')
      .replaceAll(RegExp(r'ئ'), 'ي');

  result = result.replaceAll(RegExp(r'[\s_\-]+'), '');
  result = result.replaceAll(RegExp(r'[^a-z0-9\u0621-\u064a]+'), '');

  return result;
}

const Map<String, String> _departmentAliases = <String, String>{
  // General store aliases.
  'general': 'store',
  'default': 'store',
  'public': 'store',
  'common': 'store',
  'accessories': 'store',
  'store': 'store',
  'stores': 'store',
  'generalstore': 'store',
  'storesection': 'store',
  'storedepartment': 'store',
  'shop': 'store',
  'market': 'store',
  'departmentstore': 'store',
  'commonstore': 'store',
  'عام': 'store',
  'عامه': 'store',
  'العام': 'store',
  'القسمالعام': 'store',
  'قسمعام': 'store',
  'القسمالعامه': 'store',
  'متجر': 'store',
  'المتجر': 'store',
  'متجرعام': 'store',
  'المتجرالعام': 'store',
  'السوق': 'store',
  'سوق': 'store',
  'ماركت': 'store',
  'سوبرماركت': 'store',
  'بقاله': 'store',
  'بقالة': 'store',
  'قسمالمتجر': 'store',
  'قسمالمتجرالعام': 'store',
  'قسمالسوق': 'store',
  'قسمالبقالة': 'store',
  'اكسسوارات': 'store',
  'الاكسسوارات': 'store',
  'قسمالاكسسوارات': 'store',

  // Shein department aliases.
  'shein': 'shein',
  'شيان': 'shein',
  'شيئن': 'shein',
  'قسمشيان': 'shein',

  'sheinproducts': 'shein',
  'sheinproduct': 'shein',
  'sheinsection': 'shein',
  'category${Constant.sheinRootCategoryId}': 'shein',





  // Computer / electronics department aliases.
  'computer': 'computer',
  'computers': 'computer',
  'electronics': 'computer',
  'electronic': 'computer',
  'computersection': 'computer',
  'computersections': 'computer',
  'computerproducts': 'computer',
  'computerproduct': 'computer',
  'كمبيوتر': 'computer',
  'الكمبيوتر': 'computer',
  'قسمالكمبيوتر': 'computer',
  'كمبيوترات': 'computer',
  'قسمكمبيوترات': 'computer',
  'الكترونيات': 'computer',
  'الالكترونيات': 'computer',
  'قسمالكترونيات': 'computer',
  'category${Constant.computerRootCategoryId}': 'computer',
};