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

  static const Set<int> _forceLocationRoots = <int>{
    Constant.realEstateRootCategoryId,
    Constant.publicRootCategoryId,
  };

  static const Set<String> _forceLocationInterfaces = <String>{
    'public_ads',
    'real_estate_services',
  };

  static const Set<String> _mapEnabledInterfaces = <String>{
    'public_ads',
    'real_estate_services',
  };

  static bool isDisabled({Iterable<int>? categoryIds, String? interfaceType}) {
    final Set<int> disabledCategories = Constant.geoDisabledCategoryIds;
    if (categoryIds != null) {
      for (final int id in categoryIds) {
        if (_forceLocationRoots.contains(id)) {
          continue;
        }
        if (disabledCategories.contains(id) ||
            _defaultDisabledRoots.contains(id)) {
          return true;
        }
      }
    }

    final String? normalized = SliderInterfaceMapper.normalize(interfaceType);
    if (normalized != null) {
      if (_forceLocationInterfaces.contains(normalized)) {
        return false;
      }
      if (_disabledInterfaces.contains(normalized)) {
        return true;
      }
    }

    if (interfaceType != null) {
      final String fallback = interfaceType.trim().toLowerCase();
      if (fallback.isNotEmpty && _forceLocationInterfaces.contains(fallback)) {
        return false;
      }
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
          (int id) => !_forceLocationRoots.contains(id) &&
          (disabled.contains(id) || _defaultDisabledRoots.contains(id)),
    );
  }
  static bool isMapEnabledForItem(ItemModel item) {
    if (_isMapEnabled(interfaceType: item.departmentSlug)) {
      return true;
    }

    if (_isMapEnabled(interfaceType: item.itemType)) {
      return true;
    }

    return false;
  }

  static bool _isMapEnabled({String? interfaceType}) {
    if (interfaceType == null) {
      return false;
    }

    final String? normalized = SliderInterfaceMapper.normalize(interfaceType);
    if (normalized != null && _mapEnabledInterfaces.contains(normalized)) {
      return true;
    }

    final String fallback = interfaceType.trim().toLowerCase();
    if (fallback.isEmpty) {
      return false;
    }

    return _mapEnabledInterfaces.contains(fallback);
  }
}