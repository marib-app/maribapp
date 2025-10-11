import 'package:marib/data/model/item/item_model.dart';
import 'package:marib/utils/constant.dart';
import 'package:marib/utils/delivery_department.dart';
import 'package:marib/utils/item_category_ids.dart';

const Set<int> _kEcommerceRootIds = <int>{
  Constant.sheinRootCategoryId,
  Constant.computerRootCategoryId,
  Constant.storeRootCategoryId,
};


const Set<int> _kClassifiedRootIds = <int>{
  Constant.realEstateRootCategoryId,
  2, // قسم السياحة (مُحدد مسبقًا داخل المشروع)
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


const Set<String> _kRealEstateKeywords = <String>{
  'realestate',
  'estate',
  'real-estate',
  'rent',
  'property',
  'properties',
  'housing',
  'عقار',
  'عقارات',
  'مساكن',
  'سكن',
  'سكني',
  'ايجار',
  'إيجار',
  'ايجارات',
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

  if (isClassifiedDepartmentSlug(lower)) {
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
    if (isClassifiedDepartmentSlug(lower)) {
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



bool isClassifiedCategoryId(int? id) {
  if (id == null) {
    return false;
  }
  return _kClassifiedRootIds.contains(id);
}



bool isEcommerceCategoryIds(Iterable<int> ids) {
  for (final int id in ids) {
    if (isEcommerceCategoryId(id)) {
      return true;
    }
  }
  return false;
}

bool isClassifiedCategoryIds(Iterable<int> ids) {
  for (final int id in ids) {
    if (isClassifiedCategoryId(id)) {
      return true;
    }
  }
  return false;
}

bool isEcommerceItem(ItemModel item) {


  final Iterable<int> ids = buildItemCategoryIds(item);
  if (ids.isNotEmpty && !isClassifiedCategoryIds(ids) &&
      isEcommerceCategoryIds(ids)) {

    return true;
  }

  if (!isClassifiedCategoryId(item.categoryId) &&
      isEcommerceCategoryId(item.categoryId)) {

    return true;
  }

  if (!isClassifiedCategoryId(item.category?.id) &&
      isEcommerceCategoryId(item.category?.id)) {
    return true;
  }

  if (isClassifiedItem(item)) {
    return false;
  }

  return isEcommerceDepartmentSlug(item.departmentSlug);

}

bool isClassifiedItem(ItemModel item) {
  final Iterable<int> ids = buildItemCategoryIds(item);
  if (ids.isNotEmpty && isClassifiedCategoryIds(ids)) {
    return true;
  }

  if (isClassifiedCategoryId(item.categoryId)) {
    return true;
  }

  if (isClassifiedCategoryId(item.category?.id)) {
    return true;
  }

  final String? slug = item.departmentSlug ?? item.itemType;
  final String? type = item.type;

  final bool hasPublicId = ids.contains(Constant.publicRootCategoryId) ||
      item.categoryId == Constant.publicRootCategoryId ||
      item.category?.id == Constant.publicRootCategoryId;

  if (hasPublicId) {
    final String? raw = slug ?? type;
    final String? lower = raw?.toLowerCase();
    final bool looksStore = lower != null && _looksLikeStoreSlug(lower);
    if (!looksStore) {
      if (raw == null || raw.trim().isEmpty) {
        return true;
      }
      if (isClassifiedDepartmentSlug(raw)) {
        return true;
      }
    }
  }

  if (isClassifiedDepartmentSlug(slug)) {
    return true;
  }

  if (isClassifiedDepartmentSlug(type)) {
    return true;
  }

  return false;

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


bool _looksLikeRealEstateSlug(String value) {
  final String condensed = value.replaceAll(RegExp(r'[\s_\-]+'), '');

  for (final String keyword in _kRealEstateKeywords) {
    if (condensed.contains(keyword)) {
      return true;
    }
  }
  return false;
}

bool isClassifiedDepartmentSlug(String? value) {
  if (value == null) {
    return false;
  }

  final String trimmed = value.trim();
  if (trimmed.isEmpty) {
    return false;
  }

  final String lower = trimmed.toLowerCase();

  if (_looksLikeGeneralAudienceSlug(lower)) {
    return true;
  }

  if (_looksLikeRealEstateSlug(lower)) {
    return true;
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