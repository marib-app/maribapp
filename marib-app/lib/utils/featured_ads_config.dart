import 'package:marib/utils/constant.dart';

class FeaturedAdsConfig {
  final int rootCategoryId;
  final String? interfaceType;
  final bool enableFeaturedAds;
  final bool enableAdSlider;
  final String? styleOverride;
  final String?
      orderMode; // e.g., latest, most_viewed, highest_price, lowest_price, premium
  final String? titleOverride;

  const FeaturedAdsConfig({
    required this.rootCategoryId,
    this.interfaceType,
    this.enableFeaturedAds = true,
    this.enableAdSlider = true,
    this.styleOverride,
    this.orderMode,
    this.titleOverride,
  });
}

class FeaturedAdsConfigProvider {
  static const List<FeaturedAdsConfig> _defaults = <FeaturedAdsConfig>[
    FeaturedAdsConfig(
      rootCategoryId: Constant.realEstateRootCategoryId,
      enableFeaturedAds: true,
      enableAdSlider: true,
      orderMode: 'latest',
      styleOverride: 'style_1',
    ),
    FeaturedAdsConfig(
      rootCategoryId: Constant.sheinRootCategoryId,
      interfaceType: 'shein',
      enableFeaturedAds: true,
      enableAdSlider: true,
      orderMode: 'latest',
      styleOverride: 'style_2',
    ),
    FeaturedAdsConfig(
      rootCategoryId: Constant.computerRootCategoryId,
      interfaceType: 'computer',
      enableFeaturedAds: true,
      enableAdSlider: true,
      orderMode: 'most_viewed',
      styleOverride: 'style_3',
    ),
    FeaturedAdsConfig(
      rootCategoryId: Constant.publicRootCategoryId,
      enableFeaturedAds: true,
      enableAdSlider: true,
      orderMode: 'premium',
      styleOverride: 'style_4',
    ),
  ];

  static FeaturedAdsConfig? resolve(
    int rootId, {
    String? interfaceType,
  }) {
    final String? normalizedInterface = interfaceType?.trim().toLowerCase();

    FeaturedAdsConfig? bestMatch;
    for (final FeaturedAdsConfig config in _defaults) {
      if (config.rootCategoryId != rootId) {
        continue;
      }
      if (config.interfaceType == null) {
        bestMatch = config;
        continue;
      }
      if (normalizedInterface != null &&
          normalizedInterface == config.interfaceType!.toLowerCase()) {
        return config;
      }
    }

    return bestMatch;
  }
}
