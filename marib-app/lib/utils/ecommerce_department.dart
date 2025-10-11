import 'package:marib/data/model/item/item_model.dart';
import 'package:marib/utils/constant.dart';
import 'package:marib/utils/delivery_department.dart';
import 'package:marib/utils/item_category_ids.dart';

const Set<int> _kEcommerceRootIds = <int>{
  Constant.sheinRootCategoryId,
  Constant.computerRootCategoryId,
  Constant.storeRootCategoryId,
};

const Set<String> _kEcommerceDepartments = <String>{
  'shein',
  'computer',
  'store',
};


const Set<String> _kGeneralAudienceKeywords = <String>{
  'public',
  'general',
  'audience',
  'اعلان',
  'اعلانات',
  'الجمهور',
  'جمهور',
  'عام',
  'العام',
  'عامه',
  'القسمالعام',
  'القسمالعامه',
  'قسمعام',
  'قسمالمتجرالعام',
  'قسمالسوق',
  'قسمالبقالة',
};

const Set<String> _kStoreKeywords = <String>{
  'store',
  'stores',
  'storeproducts',
  'storeproduct',
  'store_section',
  'storedepartment',
  'estore',
  'e_store',
  'estoreproducts',
  'merchant',
  'merchants',
  'ecommerce',
  'متجر',
  'المتجر',
};



bool isEcommerceDepartmentSlug(String? rawSlug) {
  if (rawSlug == null) {
    return false;
  }

  final String trimmed = rawSlug.trim();
  if (trimmed.isEmpty) {
    return false;
  }

  final String lower = trimmed.toLowerCase();

  if (_looksLikeGeneralAudienceSlug(lower)) {
    return false;
  }

  if (_kEcommerceDepartments.contains(lower)) {
    return true;
  }

  final String? normalized = normalizeDeliveryDepartment(lower);
  if (normalized == null) {
    return false;
  }

  if (normalized == 'store') {
    if (_looksLikeGeneralAudienceSlug(lower)) {
      return false;
    }
    return _looksLikeStoreSlug(lower);
  }

  return _kEcommerceDepartments.contains(normalized);
}

bool isEcommerceCategoryId(int? id) {
  if (id == null) {
    return false;
  }
  return _kEcommerceRootIds.contains(id);
}

bool isEcommerceCategoryIds(Iterable<int> ids) {
  for (final int id in ids) {
    if (isEcommerceCategoryId(id)) {
      return true;
    }
  }
  return false;
}

bool isEcommerceItem(ItemModel item) {

  final Iterable<int> ids = buildItemCategoryIds(item);
  if (ids.isNotEmpty && isEcommerceCategoryIds(ids)) {
    return true;
  }

  if (isEcommerceCategoryId(item.categoryId)) {
    return true;
  }

  if (isEcommerceCategoryId(item.category?.id)) {
    return true;
  }

  return isEcommerceDepartmentSlug(item.departmentSlug);

}

bool supportsEcommerceByCategories(Iterable<int> categoryIds) {
  return isEcommerceCategoryIds(categoryIds);
}

bool _looksLikeGeneralAudienceSlug(String value) {
  final String condensed = value.replaceAll(RegExp(r'[\s_\-]+'), '');

  for (final String keyword in _kGeneralAudienceKeywords) {
    if (condensed.contains(keyword)) {
      return true;
    }
  }
  return false;
}

bool _looksLikeStoreSlug(String value) {
  final String condensed = value.replaceAll(RegExp(r'[\s_\-]+'), '');

  for (final String keyword in _kStoreKeywords) {
    if (condensed.contains(keyword)) {
      return true;
    }
  }
  return false;
}