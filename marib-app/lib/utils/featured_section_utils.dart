import 'package:marib/utils/slider_interface_mapper.dart';

class FeaturedSectionUtils {
  const FeaturedSectionUtils._();

  static String? resolveRootIdentifier({
    String? interfaceType,
    int? rootCategoryId,
    String? cachedRootIdentifier,
  }) {
    final String? trimmedCache = cachedRootIdentifier?.trim();
    if (trimmedCache != null && trimmedCache.isNotEmpty) {
      return trimmedCache;
    }



    final String? normalizedInterface =
        SliderInterfaceMapper.normalize(interfaceType) ?? interfaceType?.trim();

    if (normalizedInterface != null && normalizedInterface.isNotEmpty) {
      return normalizedInterface;
    }

    if (rootCategoryId != null && rootCategoryId > 0) {
      return rootCategoryId.toString();
    }

    return null;

  }
}