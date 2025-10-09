import 'package:marib/data/model/item/item_model.dart';
import 'package:marib/utils/constant.dart';
import 'package:marib/utils/item_category_ids.dart';
import 'package:marib/utils/slider_interface_mapper.dart';

class GeoRules {
  static const Set<String> _disabledInterfaces = <String>{
    'computer',
    'computer_section',
    'shein',
    'shein_products',
    'store',
    'store_products',
    'e_store',
  };

  static const Set<int> _defaultDisabledRoots = <int>{
    Constant.sheinRootCategoryId,
    Constant.computerRootCategoryId,
    Constant.storeRootCategoryId,
  };


  static bool isDisabled({Iterable<int>? categoryIds, String? interfaceType}) {
    final Set<int> disabledCategories = Constant.geoDisabledCategoryIds;
    if (categoryIds != null) {
      for (final int id in categoryIds) {
        if (disabledCategories.contains(id) ||
            _defaultDisabledRoots.contains(id)) {
          return true;
        }
      }
    }

    final String? normalized = SliderInterfaceMapper.normalize(interfaceType);
    if (normalized != null) {
      if (_disabledInterfaces.contains(normalized)) {
        return true;
      }
    }

    if (interfaceType != null) {
      final String fallback = interfaceType.trim().toLowerCase();
      if (fallback.isNotEmpty && _disabledInterfaces.contains(fallback)) {
        return true;
      }
    }

    return false;
  }

  static bool isDisabledForItem(ItemModel item) {
    if (isDisabled(categoryIds: buildItemCategoryIds(item))) {
      return true;
    }

    if (isDisabled(interfaceType: item.departmentSlug)) {
      return true;
    }

    if (isDisabled(interfaceType: item.itemType)) {
      return true;
    }

    return false;
  }

  static bool anyDisabledCategory(Iterable<int>? categoryIds) {
    if (categoryIds == null) {
      return false;
    }
    final Set<int> disabled = Constant.geoDisabledCategoryIds;
    return categoryIds.any(
          (int id) => disabled.contains(id) || _defaultDisabledRoots.contains(id),
    );
  }
}