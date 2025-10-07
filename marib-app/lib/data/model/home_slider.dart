class HomeSlider {
  int? id;
  String? sequence;
  String? thirdPartyLink;
  String? modelType;
  String? image;
  int? modelId;
  CategorySlider? model;
  String? interfaceType;
  String? destination;
  String? actionType;
  HomeSliderActionPayload? actionPayload;
  HomeSliderTargetSummary? targetSummary;
  String? title;
  String? subtitle;
  String? badgeLabel;
  String? ctaLabel;
  Map<String, dynamic>? meta;

  HomeSlider({
    this.id,
    this.sequence,
    this.thirdPartyLink,
    this.modelId,
    this.image,
    this.modelType,
    this.model,
    this.interfaceType,
    this.destination,
    this.actionType,
    this.actionPayload,
    this.targetSummary,
    this.title,
    this.subtitle,
    this.badgeLabel,
    this.ctaLabel,
    this.meta,
  });

  HomeSlider.fromJson(Map<String, dynamic> json) {
    id = _parseInt(json['id']);
    sequence = _asString(json['sequence']);
    thirdPartyLink =
        _asString(json['third_party_link'] ?? json['thirdPartyLink']);
    modelId = _parseInt(json['model_id'] ?? json['modelId']);
    image = _asString(json['image']);
    modelType = _asString(json['model_type'] ?? json['modelType']);
    interfaceType = _asString(json['interface_type'] ?? json['interfaceType']);
    destination = _asString(json['destination']);
    actionType = _asString(json['action_type'] ?? json['actionType']);
    actionPayload = HomeSliderActionPayload.fromJson(json['action_payload']);
    targetSummary =
        HomeSliderTargetSummary.maybeFromJson(json['target_summary']);
    title = _asString(json['title'] ?? json['headline']);
    subtitle = _asString(json['subtitle'] ?? json['description']);
    badgeLabel = _asString(json['badge_label'] ?? json['badgeLabel']);
    ctaLabel = _asString(json['cta_label'] ?? json['ctaLabel']);
    meta = _asMap(json['meta'] ?? json['metadata']);

    if (json['model'] is Map<String, dynamic>) {
      model = CategorySlider.fromJson(json['model']);
    } else if (targetSummary != null &&
        targetSummary!.asCategorySlider != null) {
      model = targetSummary!.asCategorySlider;
    } else {
      model = null;
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['sequence'] = sequence;
    data['third_party_link'] = thirdPartyLink;
    data['model_id'] = modelId;
    data['model_type'] = modelType;
    data['image'] = image;
    data['interface_type'] = interfaceType;
    data['destination'] = destination;
    data['action_type'] = actionType;
    data['action_payload'] = actionPayload?.toJson();
    data['target_summary'] = targetSummary?.toJson();
    data['title'] = title;
    data['subtitle'] = subtitle;
    data['badge_label'] = badgeLabel;
    data['cta_label'] = ctaLabel;
    data['meta'] = meta;

    if (model != null) {
      data['model'] = model!.toJson();
    }
    return data;
  }

  String? get actionTypeNormalized => actionType?.toLowerCase().trim();

  String? get destinationNormalized => destination?.toLowerCase().trim();

  String? get resolvedExternalLink =>
      actionPayload?.resolvedUrl ?? thirdPartyLink;

  String? get resolvedCouponCode => actionPayload?.resolvedCouponCode;
}

class HomeSliderActionPayload {
  final Map<String, dynamic>? raw;
  final String? url;
  final String? couponCode;
  final Map<String, dynamic>? arguments;

  const HomeSliderActionPayload._({
    this.raw,
    this.url,
    this.couponCode,
    this.arguments,
  });

  factory HomeSliderActionPayload.fromJson(dynamic value) {
    if (value == null) {
      return const HomeSliderActionPayload._();
    }

    if (value is String) {
      final String trimmed = value.trim();
      return HomeSliderActionPayload._(
        raw: <String, dynamic>{'raw': trimmed},
        url: _looksLikeUrl(trimmed) ? trimmed : null,
        couponCode: trimmed.isNotEmpty ? trimmed : null,
      );
    }

    if (value is Map<String, dynamic>) {
      final Map<String, dynamic> raw = Map<String, dynamic>.from(value);
      return HomeSliderActionPayload._(
        raw: raw,
        url: _extractString(raw, const ['url', 'link', 'href', 'deep_link']),
        couponCode:
            _extractString(raw, const ['coupon_code', 'coupon', 'code']),
        arguments: _asMap(raw['arguments'] ?? raw['args']),
      );
    }

    return const HomeSliderActionPayload._();
  }

  String? get resolvedUrl =>
      url ?? _extractString(raw, const ['url', 'link', 'href', 'deep_link']);

  String? get resolvedCouponCode =>
      couponCode ??
      _extractString(raw, const ['coupon_code', 'coupon', 'code']);

  Map<String, dynamic>? toJson() => raw;
}

class HomeSliderTargetSummary {
  final String? type;
  final dynamic id;
  final String? slug;
  final String? name;
  final String? route;
  final Map<String, dynamic>? arguments;
  final Map<String, dynamic>? meta;

  HomeSliderTargetSummary({
    this.type,
    this.id,
    this.slug,
    this.name,
    this.route,
    this.arguments,
    this.meta,
  });

  static HomeSliderTargetSummary? maybeFromJson(dynamic value) {
    if (value is Map<String, dynamic>) {
      return HomeSliderTargetSummary.fromJson(value);
    }
    return null;
  }

  factory HomeSliderTargetSummary.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic>? meta =
        _asMap(json['meta'] ?? json['extras'] ?? json['data']);
    return HomeSliderTargetSummary(
      type: _asString(json['type'] ?? json['target_type'] ?? meta?['type']),
      id: json['id'] ?? json['target_id'] ?? meta?['id'],
      slug: _asString(json['slug'] ?? json['target_slug'] ?? meta?['slug']),
      name: _asString(
          json['name'] ?? json['title'] ?? json['label'] ?? meta?['name']),
      route: _asString(json['route'] ?? meta?['route'] ?? json['screen']),
      arguments: _asMap(json['arguments'] ?? meta?['arguments']),
      meta: meta,
    );
  }

  Map<String, dynamic>? toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['type'] = type;
    data['id'] = id;
    data['slug'] = slug;
    data['name'] = name;
    data['route'] = route;
    data['arguments'] = arguments;
    data['meta'] = meta;
    return data;
  }

  String? get normalizedType => type?.toLowerCase().trim();

  bool get isCategory =>
      const ['category', 'categories'].contains(normalizedType);

  bool get isItem =>
      const ['item', 'product', 'listing'].contains(normalizedType);

  int? get idAsInt => _parseInt(id);

  int? get parentCategoryId =>
      _parseInt(meta?['parent_category_id'] ?? meta?['parentId']);

  int? get subCategoriesCount =>
      _parseInt(meta?['subcategories_count'] ?? meta?['sub_categories_count']);

  String? get routeName =>
      route ?? _extractString(meta, const ['route', 'screen', 'path']);

  CategorySlider? get asCategorySlider {
    if (!isCategory) return null;
    return CategorySlider(
      id: idAsInt,
      name: name,
      subCategoriesCount: subCategoriesCount,
      parentCategoryId: parentCategoryId,
    );
  }
}

class CategorySlider {
  int? id;
  String? name;
  int? subCategoriesCount;
  int? parentCategoryId;

  CategorySlider(
      {this.id, this.name, this.subCategoriesCount, this.parentCategoryId});

  CategorySlider.fromJson(Map<String, dynamic> json) {
    id = _parseInt(json['id']);
    name = _asString(json['translated_name'] ?? json['name']);
    subCategoriesCount =
        _parseInt(json['subcategories_count'] ?? json['sub_categories_count']);
    parentCategoryId = _parseInt(json['parent_category_id']);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['translated_name'] = name;
    data['subcategories_count'] = subCategoriesCount;
    data['parent_category_id'] = parentCategoryId;

    return data;
  }
}

int? _parseInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.toInt();
  return int.tryParse(value.toString());
}

String? _asString(dynamic value) {
  if (value == null) return null;
  if (value is String) return value;
  return value.toString();
}

Map<String, dynamic>? _asMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return Map<String, dynamic>.from(value);
  }
  return null;
}

String? _extractString(Map<String, dynamic>? source, List<String> keys) {
  if (source == null) return null;
  for (final String key in keys) {
    if (source.containsKey(key) && source[key] != null) {
      final dynamic value = source[key];
      if (value is String) {
        final String trimmed = value.trim();
        if (trimmed.isNotEmpty) {
          return trimmed;
        }
      } else {
        final String stringified = value.toString().trim();
        if (stringified.isNotEmpty) {
          return stringified;
        }
      }
    }
  }
  return null;
}

bool _looksLikeUrl(String value) {
  final Uri? uri = Uri.tryParse(value);
  if (uri == null) return false;
  if (!uri.hasScheme) return false;
  final String? host = uri.host.isNotEmpty ? uri.host : null;
  return host != null;
}
