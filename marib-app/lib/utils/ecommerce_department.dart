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

bool isEcommerceDepartmentSlug(String? rawSlug) {
  if (rawSlug == null) {
    return false;
  }

  final String trimmed = rawSlug.trim();
  if (trimmed.isEmpty) {
    return false;
  }

  final String lower = trimmed.toLowerCase();
  if (_kEcommerceDepartments.contains(lower)) {
    return true;
  }

  final String? normalized = normalizeDeliveryDepartment(lower);
  if (normalized != null && _kEcommerceDepartments.contains(normalized)) {
    return true;
  }

  return false;
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
  if (isEcommerceDepartmentSlug(item.departmentSlug)) {
    return true;
  }

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

  return false;
}

bool supportsEcommerceByCategories(Iterable<int> categoryIds) {
  return isEcommerceCategoryIds(categoryIds);
}