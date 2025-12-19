class StorefrontUiConfig {
  StorefrontUiConfig({
    required this.enabled,
    required this.featuredCategories,
    required this.promotionSlots,
  });

  factory StorefrontUiConfig.fromJson(Map<String, dynamic> json) {
    return StorefrontUiConfig(
      enabled: json['enabled'] == true || json['enabled'] == 1 || json['enabled'] == '1',
      featuredCategories: (json['featured_categories'] as List?)
              ?.map((e) => FeaturedCategory.fromJson(e as Map<String, dynamic>))
              .toList(growable: false) ??
          const <FeaturedCategory>[],
      promotionSlots: (json['promotion_slots'] as List?)
              ?.map((e) => PromotionSlot.fromJson(e as Map<String, dynamic>))
              .toList(growable: false) ??
          const <PromotionSlot>[],
    );
  }

  final bool enabled;
  final List<FeaturedCategory> featuredCategories;
  final List<PromotionSlot> promotionSlots;
}

class FeaturedCategory {
  FeaturedCategory({
    required this.id,
    required this.label,
    this.color,
    this.icon,
    this.order,
  });

  factory FeaturedCategory.fromJson(Map<String, dynamic> json) {
    return FeaturedCategory(
      id: json['id']?.toString() ?? json['slug']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      color: json['color']?.toString(),
      icon: json['icon']?.toString(),
      order: json['order'] is num ? (json['order'] as num).toInt() : null,
    );
  }

  final String id;
  final String label;
  final String? color;
  final String? icon;
  final int? order;
}

class PromotionSlot {
  PromotionSlot({
    required this.frequency,
    required this.items,
  });

  factory PromotionSlot.fromJson(Map<String, dynamic> json) {
    final int freq = json['frequency'] is num
        ? (json['frequency'] as num).toInt()
        : int.tryParse(json['frequency']?.toString() ?? '') ?? 0;
    return PromotionSlot(
      frequency: freq <= 0 ? 4 : freq,
      items: (json['items'] as List?)
              ?.map((e) => PromotionItem.fromJson(e as Map<String, dynamic>))
              .toList(growable: false) ??
          const <PromotionItem>[],
    );
  }

  final int frequency;
  final List<PromotionItem> items;
}

class PromotionItem {
  PromotionItem({
    this.id,
    this.title,
    this.type,
    this.image,
    this.slug,
    this.subtitle,
  });

  factory PromotionItem.fromJson(Map<String, dynamic> json) {
    return PromotionItem(
      id: json['id']?.toString(),
      title: json['title']?.toString(),
      type: json['type']?.toString(),
      image: json['image']?.toString(),
      slug: json['slug']?.toString(),
      subtitle: json['subtitle']?.toString(),
    );
  }

  final String? id;
  final String? title;
  final String? type;
  final String? image;
  final String? slug;
  final String? subtitle;
}
