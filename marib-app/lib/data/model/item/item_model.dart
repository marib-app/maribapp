import 'package:marib/data/model/category_model.dart';
import 'package:marib/data/model/custom_field/custom_field_model.dart';
import 'package:marib/data/model/seller_ratings_model.dart';
import 'package:marib/utils/currency_utils.dart';
import 'package:marib/utils/delivery_department.dart';
import 'package:marib/utils/slider_interface_mapper.dart';
import 'dart:convert';

class ItemSummary {
  final int? id;
  final String? name;
  final String? slug;
  final String? description;
  final double? price;
  final double? finalPrice;
  final String? image;
  final String? thumbnailUrl;
  final String? thumbnailFallbackUrl;
  final String? productLink;
  final dynamic watermarkImage;
  final double? latitude;
  final double? longitude;
  final String? address;
  final String? type;
  final String? status;
  final bool? isFeature;
  final bool? isLike;
  final String? created;
  final String? itemType;
  final int? userId;
  final int? categoryId;
  final int? totalLikes;
  final int? views;
  final String? currency;
  final String? city;
  final String? state;
  final String? country;
  final ItemDiscount? discount;

  const ItemSummary({
    this.id,
    this.name,
    this.slug,
    this.description,
    this.price,
    this.finalPrice,
    this.image,
    this.thumbnailUrl,
    this.thumbnailFallbackUrl,
    this.productLink,
    this.watermarkImage,
    this.latitude,
    this.longitude,
    this.address,
    this.type,
    this.status,
    this.isFeature,
    this.isLike,
    this.created,
    this.itemType,
    this.userId,
    this.categoryId,
    this.totalLikes,
    this.views,
    this.currency,
    this.city,
    this.state,
    this.country,
    this.discount,
  });

  factory ItemSummary.fromJson(Map<String, dynamic> json) {
    final ItemDiscount? discount = ItemDiscount.fromJson(json['discount']);
    final double? basePrice = ItemModel._toDouble(json['price']);
    double? finalPrice = ItemModel._toDouble(json['final_price']) ?? basePrice;

    // إذا يوجد خصم مفعّل احسب السعر المخفض حتى لو لم يرسله الخادم
    if (discount != null && discount.value != null && basePrice != null) {
      final bool isFixed =
          (discount.type ?? '').toLowerCase() == 'fixed';
      final double discounted = isFixed
          ? (basePrice - discount.value!).clamp(0, basePrice)
          : (basePrice - (basePrice * (discount.value! / 100)))
              .clamp(0, basePrice);
      if (discounted < (finalPrice ?? basePrice)) {
        finalPrice = discounted;
      }
    }

    return ItemSummary(
      id: ItemModel._toInt(json['id']),
      name: json['name'],
      slug: json['slug'],
      description: json['description'],
      price: basePrice,
      finalPrice: finalPrice,
      image: json['image'] ??
          json['thumbnail_fallback_url'] ??
          json['thumbnail_url'],
      thumbnailUrl: json['thumbnail_url'] ?? json['thumbnail'] ?? json['thumb'],
      thumbnailFallbackUrl: json['thumbnail_fallback_url'] ??
          json['thumbnail_fallback'] ??
          json['image'],
      productLink: json['product_link'],
      watermarkImage: json['watermark_image'],
      latitude: ItemModel._toDouble(json['latitude'] ?? json['lat']),
      longitude: ItemModel._toDouble(json['longitude'] ?? json['lng']),
      address: json['address'],
      type: json['type'],
      status: json['status'],
      isFeature: ItemModel._toBool(json['is_feature']),
      isLike: ItemModel._toBool(json['is_liked']),
      created: json['created_at'] ?? json['created'],
      itemType: json['item_type'],
      userId: ItemModel._toInt(json['user_id']),
      categoryId: ItemModel._toInt(json['category_id']),
      totalLikes: ItemModel._toInt(json['total_likes']),
      views: ItemModel._toInt(json['clicks']),
      currency: json['currency'],
      city: json['city'],
      state: json['state'],
      country: json['country'],
      discount: discount,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'slug': slug,
      'description': description,
      'price': price,
      'final_price': finalPrice,
      'image': image,
      'thumbnail_url': thumbnailUrl,
      'thumbnail_fallback_url': thumbnailFallbackUrl,
      'product_link': productLink,
      'watermark_image': watermarkImage,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'type': type,
      'status': status,
      'is_feature': isFeature,
      'is_liked': isLike,
      'created_at': created,
      'item_type': itemType,
      'user_id': userId,
      'category_id': categoryId,
      'total_likes': totalLikes,
      'clicks': views,
      'currency': currency,
      'city': city,
      'state': state,
      'country': country,
      'discount': discount?.toJson(),
    };
  }
}

extension ItemSummaryX on ItemSummary {
  ItemModel toItemModelSkeleton() {
    return ItemModel(
      id: id,
      name: name,
      slug: slug,
      description: description,
      price: price,
      image: image,
      thumbnailUrl: thumbnailUrl,
      thumbnailFallbackUrl: thumbnailFallbackUrl,
      productLink: productLink,
      watermarkimage: watermarkImage,
      latitude: latitude,
      longitude: longitude,
      address: address,
      type: type,
      status: status,
      isFeature: isFeature,
      isLike: isLike,
      created: created,
      itemType: itemType,
      departmentSlug: normalizeDeliveryDepartment(itemType) ?? itemType,
      userId: userId,
      categoryId: categoryId,
      totalLikes: totalLikes,
      views: views,
      currency: currency,
      city: city,
      state: state,
      country: country,
      finalPrice: finalPrice ?? price,
      discount: discount,
    );
  }
}

class ItemModel {
  int? id;
  String? name;
  String? slug;
  String? description;
  double? price;
  double? finalPrice;
  String? image;
  String? thumbnailUrl;
  String? thumbnailFallbackUrl;
  String? detailImageUrl;
  String? detailImageFallbackUrl;
  dynamic watermarkimage;

  double? _latitude;
  double? _longitude;

  String? address;
  String? contact;
  int? totalLikes;
  int? views;
  String? type;
  String? status;
  bool? active;
  String? videoLink;
  String? reviewLink;
  String? productLink;
  ItemDiscount? discount;
  User? user;
  List<GalleryImages>? galleryImages;
  List<ItemOffers>? itemOffers;
  Map<String, dynamic>? stockSnapshot;
  int? availableStock;
  int? remainingStock;
  CategoryModel? category;
  List<CustomFieldModel>? customFields;
  ItemTipsMetadata? tips;

  bool? isLike;
  bool? isFeature;
  String? created;
  String? itemType;
  String? departmentSlug;
  int? userId;
  int? categoryId;
  bool? isAlreadyOffered;
  bool? isAlreadyReported;
  String? allCategoryIds;
  String? rejectedReason;

  int? areaId;
  String? area;
  String? city;
  String? state;
  String? country;

  int? isPurchased;
  List<UserRatings>? review;
  String? currency;
  String? currencyCode;

  double? get latitude => _latitude;

  set latitude(dynamic value) {
    _latitude = _toDouble(value);
  }

  double? get longitude => _longitude;

  set longitude(dynamic value) {
    _longitude = _toDouble(value);
  }

  ItemModel({
    this.id,
    this.name,
    this.slug,
    this.category,
    this.description,
    this.price,
    this.finalPrice,
    this.image,
    String? thumbnailUrl,
    String? thumbnailFallbackUrl,
    String? detailImageUrl,
    String? detailImageFallbackUrl,
    this.watermarkimage,
    dynamic latitude,
    dynamic longitude,
    this.address,
    this.contact,
    this.type,
    this.status,
    this.active,
    this.totalLikes,
    this.discount,
    this.tips,
    this.currencyCode,
    this.views,
    this.videoLink,
    this.reviewLink,
    this.productLink,
    this.user,
    this.galleryImages,
    this.itemOffers,
    this.customFields,
    this.isLike,
    this.departmentSlug,
    this.isFeature,
    this.created,
    this.itemType,
    this.userId,
    this.categoryId,
    this.isAlreadyOffered,
    this.isAlreadyReported,
    this.rejectedReason,
    this.allCategoryIds,
    this.areaId,
    this.area,
    this.city,
    this.state,
    this.country,
    this.review,
    this.currency,
    this.isPurchased,
    this.stockSnapshot,
    this.availableStock,
    this.remainingStock,
  }) {
    this.latitude = latitude;
    this.longitude = longitude;
  }

  ItemModel copyWith({
    int? id,
    String? name,
    String? slug,
    String? description,
    double? price,
    double? finalPrice,
    String? image,
    String? thumbnailUrl,
    String? thumbnailFallbackUrl,
    String? detailImageUrl,
    String? detailImageFallbackUrl,
    dynamic watermarkimage,
    String? currencyCode,
    dynamic latitude,
    dynamic longitude,
    String? address,
    String? contact,
    int? totalLikes,
    int? views,
    String? type,
    String? departmentSlug,
    String? status,
    bool? active,
    String? videoLink,
    String? reviewLink,
    String? productLink,
    ItemDiscount? discount,
    User? user,
    List<GalleryImages>? galleryImages,
    List<ItemOffers>? itemOffers,
    CategoryModel? category,
    List<CustomFieldModel>? customFields,
    bool? isLike,
    bool? isFeature,
    String? created,
    String? itemType,
    int? userId,
    bool? isAlreadyOffered,
    bool? isAlreadyReported,
    String? allCategoryIds,
    int? categoryId,
    int? areaId,
    String? area,
    String? city,
    String? state,
    String? country,
    int? isPurchased,
    String? currency,
    List<UserRatings>? review,
    ItemTipsMetadata? tips,
  }) {
    return ItemModel(
      id: id ?? this.id,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      category: category ?? this.category,
      description: description ?? this.description,
      price: price ?? this.price,
      finalPrice: finalPrice ?? this.finalPrice,
      image: image ?? this.image,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      thumbnailFallbackUrl: thumbnailFallbackUrl ?? this.thumbnailFallbackUrl,
      detailImageUrl: detailImageUrl ?? this.detailImageUrl,
      detailImageFallbackUrl:
          detailImageFallbackUrl ?? this.detailImageFallbackUrl,
      watermarkimage: watermarkimage ?? this.watermarkimage,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      contact: contact ?? this.contact,
      type: type ?? this.type,
      status: status ?? this.status,
      active: active ?? this.active,
      totalLikes: totalLikes ?? this.totalLikes,
      views: views ?? this.views,
      videoLink: videoLink ?? this.videoLink,
      reviewLink: reviewLink ?? this.reviewLink,
      productLink: productLink ?? this.productLink,
      discount: discount ?? this.discount,
      user: user ?? this.user,
      galleryImages: galleryImages ?? this.galleryImages,
      itemOffers: itemOffers ?? this.itemOffers,
      customFields: customFields ?? this.customFields,
      isLike: isLike ?? this.isLike,
      isFeature: isFeature ?? this.isFeature,
      created: created ?? this.created,
      itemType: itemType ?? this.itemType,
      userId: userId ?? this.userId,
      categoryId: categoryId ?? this.categoryId,
      isAlreadyOffered: isAlreadyOffered ?? this.isAlreadyOffered,
      isAlreadyReported: isAlreadyReported ?? this.isAlreadyReported,
      allCategoryIds: allCategoryIds ?? this.allCategoryIds,
      rejectedReason: rejectedReason ?? this.rejectedReason,
      areaId: areaId ?? this.areaId,
      area: area ?? this.area,
      city: city ?? this.city,
      state: state ?? this.state,
      country: country ?? this.country,
      currency: currency ?? this.currency,
      currencyCode: currencyCode ?? this.currencyCode,
      isPurchased: isPurchased ?? this.isPurchased,
      review: review ?? this.review,
      departmentSlug: departmentSlug ?? this.departmentSlug,
      tips: tips ?? this.tips,
    );
  }

  factory ItemModel.fromJson(Map<String, dynamic> json) {
    final m = ItemModel();

    // area (يدعم Map فقط)
    if (json['area'] is Map<String, dynamic>) {
      final a = json['area'] as Map<String, dynamic>;
      m.areaId = a['id'];
      m.area = a['name'];
    }

    // price يدعم int/double/String
    m.price = _toDouble(json['price']);
    m.finalPrice = _toDouble(json['final_price']);

    m.id = json['id'];
    m.name = json['name'];
    m.slug = json['slug'];

    // category آمن
    if (json['category'] is Map<String, dynamic>) {
      m.category = CategoryModel.fromJson(json['category']);
    }

    m.totalLikes = _toInt(json['total_likes']);
    m.views = _toInt(json['clicks']);
    m.description = json['description'];

    m.image = json['image'] ??
        json['thumbnail_fallback_url'] ??
        json['thumbnail_url'];
    m.thumbnailUrl =
        json['thumbnail_url'] ?? json['thumbnail'] ?? json['thumb'];
    m.thumbnailFallbackUrl = json['thumbnail_fallback_url'] ??
        json['thumbnail_fallback'] ??
        json['image'];
    m.detailImageUrl = json['detail_image_url'] ?? json['detailImageUrl'];
    m.detailImageFallbackUrl = json['detail_image_fallback_url'] ??
        json['detail_image_fallback'] ??
        json['detail_image'];

    m.watermarkimage = json['watermark_image'];

    // يدعم مفاتيح بديلة lat/lng
    m.latitude = json['latitude'] ?? json['lat'];
    m.longitude = json['longitude'] ?? json['lng'];

    m.address = json['address'];
    m.contact = json['contact'];
    m.type = json['type'];
    m.status = json['status'];
    m.active = _toBool(json['active']);
    m.videoLink = json['video_link'];
    m.reviewLink = json['review_link'];
    m.productLink = json['product_link'];
    m.discount = ItemDiscount.fromJson(json['discount']);

    m.isLike = _toBool(json['is_liked']);
    m.isFeature = _toBool(json['is_feature']);
    m.created = json['created_at'];
    m.itemType = json['item_type'];
    m.departmentSlug = _parseDepartmentSlug(json);
    m.userId = _toInt(json['user_id']);
    m.categoryId = _toInt(json['category_id']);
    m.isAlreadyOffered = _toBool(json['is_already_offered']);
    m.isAlreadyReported = _toBool(json['is_already_reported']);
    m.allCategoryIds = json['all_category_ids'];
    m.rejectedReason = json['rejected_reason'];
    final CurrencyParseResult currencyInfo = CurrencyUtils.parseCurrency(json);
    final String? rawCurrency = json['currency']?.toString();
    final String? displayCurrency =
        (currencyInfo.display ?? rawCurrency)?.trim();
    m.currency = displayCurrency?.isEmpty == true ? null : displayCurrency;
    final String? normalizedCurrencyCode = currencyInfo.code ??
        CurrencyUtils.normalizeCurrencyCode(displayCurrency);
    m.currencyCode = normalizedCurrencyCode;

    m.city = json['city'];
    m.state = json['state'];
    m.country = json['country'];
    m.isPurchased = _toInt(json['is_purchased']);
    if (json['tips'] is Map<String, dynamic>) {
      m.tips = ItemTipsMetadata.fromJson(
          Map<String, dynamic>.from(json['tips'] as Map<String, dynamic>));
    } else if (json['tips'] is Map) {
      m.tips = ItemTipsMetadata.fromJson((json['tips'] as Map).map(
          (dynamic key, dynamic value) => MapEntry(key.toString(), value)));
    }
    // review أو seller_review (List أو Map)
    final reviewsRaw = json['review'] ?? json['seller_review'];
    if (reviewsRaw != null) {
      m.review = <UserRatings>[];
      if (reviewsRaw is List) {
        for (final v in reviewsRaw) {
          if (v is Map<String, dynamic>) {
            m.review!.add(UserRatings.fromJson(v));
          }
        }
      } else if (reviewsRaw is Map<String, dynamic>) {
        m.review!.add(UserRatings.fromJson(reviewsRaw));
      }
    }

    // user آمن
    if (json['user'] is Map<String, dynamic>) {
      m.user = User.fromJson(json['user']);
    }

    if (json['gallery_images'] is List) {
      m.galleryImages = (json['gallery_images'] as List)
          .whereType<Map<String, dynamic>>()
          .map((v) => GalleryImages.fromJson(v))
          .toList();
    }

    if (json['item_offers'] is List) {
      m.itemOffers = (json['item_offers'] as List)
          .whereType<Map<String, dynamic>>()
          .map((v) => ItemOffers.fromJson(v))
          .toList();
    }

    if (json['custom_fields'] is List) {
      m.customFields = (json['custom_fields'] as List)
          .whereType<Map<String, dynamic>>()
          .map((v) => CustomFieldModel.fromMap(v))
          .toList();
    }

    return m;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['name'] = name;
    data['slug'] = slug;
    data['description'] = description;
    data['price'] = price;
    data['final_price'] = finalPrice;
    data['total_likes'] = totalLikes;
    data['clicks'] = views;
    data['image'] = image;
    data['thumbnail_url'] = thumbnailUrl;
    data['thumbnail_fallback_url'] = thumbnailFallbackUrl;
    data['detail_image_url'] = detailImageUrl;
    data['detail_image_fallback_url'] = detailImageFallbackUrl;
    data['watermark_image'] = watermarkimage;
    data['latitude'] = latitude;
    data['longitude'] = longitude;
    data['address'] = address;
    data['contact'] = contact;
    data['type'] = type;
    data['status'] = status;
    data['active'] = active;
    data['video_link'] = videoLink;
    data['review_link'] = reviewLink;
    data['product_link'] = productLink;
    if (discount != null) {
      data['discount'] = discount!.toJson();
    }
    data['is_liked'] = isLike;
    data['is_feature'] = isFeature;
    data['created_at'] = created;
    data['item_type'] = itemType;
    data['user_id'] = userId;
    data['category_id'] = categoryId;
    data['is_already_offered'] = isAlreadyOffered;
    data['is_already_reported'] = isAlreadyReported;
    data['all_category_ids'] = allCategoryIds;
    data['currency'] = currency;
    if (currencyCode != null && currencyCode!.trim().isNotEmpty) {
      data['currency_code'] = currencyCode;
    }
    data['rejected_reason'] = rejectedReason;
    data['is_purchased'] = isPurchased;

    if (review != null) {
      data['review'] = review!.map((v) => v.toJson()).toList();
    }

    data['city'] = city;
    data['state'] = state;
    data['country'] = country;

    // 🔒 آمن: لا نرسل category/user إلا إذا وُجدت
    if (category != null) data['category'] = category!.toJson();

    if (areaId != null && area != null) {
      data['area'] = {'id': areaId, 'name': area};
    }

    if (user != null) data['user'] = user!.toJson();

    if (galleryImages != null) {
      data['gallery_images'] = galleryImages!.map((v) => v.toJson()).toList();
    }
    if (itemOffers != null) {
      data['item_offers'] = itemOffers!.map((v) => v.toJson()).toList();
    }
    if (customFields != null) {
      data['custom_fields'] = customFields!.map((v) => v.toMap()).toList();
    }

    if (tips != null) {
      data['tips'] = tips!.toJson();
    }
    return data;
  }

  @override
  String toString() {
    return 'ItemModel{id: $id, name: $name, slug:$slug, description: $description, price: $price, image: $image, watermarkimage: $watermarkimage, latitude: $latitude, longitude: $longitude, address: $address, contact: $contact, total_likes: $totalLikes, isLiked: $isLike, isFeature: $isFeature, views: $views, type: $type, status: $status, active: $active, videoLink: $videoLink, reviewLink: $reviewLink, user: $user, galleryImages: $galleryImages, itemOffers:$itemOffers, category: $category, customFields: $customFields, createdAt:$created, itemType:$itemType, departmentSlug:$departmentSlug, userId:$userId, categoryId:$categoryId, isAlreadyOffered:$isAlreadyOffered, isAlreadyReported:$isAlreadyReported, allCategoryId:$allCategoryIds, rejected_reason:$rejectedReason, area_id:$areaId, area:$area, city:$city, state:$state, country:$country, is_purchased:$isPurchased, review:$review}';
  }

  static String? _parseDepartmentSlug(Map<String, dynamic> json) {
    final List<String> candidates = <String>[];

    void addCandidate(dynamic value) {
      if (value == null) {
        return;
      }
      if (value is String) {
        final String trimmed = value.trim();
        if (trimmed.isNotEmpty) {
          candidates.add(trimmed);
        }
        return;
      }
      if (value is Map<String, dynamic>) {
        addCandidate(value['department']);
        addCandidate(value['slug']);
        addCandidate(value['section']);
        addCandidate(value['name']);
        return;
      }
      if (value is Iterable) {
        for (final dynamic entry in value) {
          addCandidate(entry);
        }
      }
    }

    addCandidate(json['department']);
    addCandidate(json['department_slug']);
    addCandidate(json['section']);
    addCandidate(json['department_advertiser']);

    for (final String candidate in candidates) {
      final String? normalizedInterface =
          SliderInterfaceMapper.normalize(candidate);
      if (normalizedInterface == 'public_ads' ||
          normalizedInterface == 'real_estate_services') {
        return normalizedInterface;
      }

      final String condensed =
          _normalizeDepartmentMatchKey(normalizedInterface ?? candidate);
      if (_looksLikePublicAudience(condensed)) {
        return 'public_ads';
      }
      if (_looksLikeRealEstate(condensed)) {
        return 'real_estate_services';
      }
    }

    for (final String candidate in candidates) {
      final String? normalized = normalizeDeliveryDepartment(candidate);
      if (normalized == 'shein' ||
          normalized == 'computer' ||
          normalized == 'store') {
        return normalized;
      }
    }

    return candidates.isNotEmpty ? candidates.first : null;
  }

  static String _normalizeDepartmentMatchKey(String? raw) {
    if (raw == null) {
      return '';
    }
    String value = raw.toLowerCase();
    value = value.replaceAll(RegExp(r'[إأآٱ]'), 'ا');
    value = value.replaceAll(RegExp(r'ة'), 'ه');
    value = value.replaceAll(RegExp(r'ى'), 'ي');
    value = value.replaceAll(RegExp(r'ؤ'), 'و');
    value = value.replaceAll(RegExp(r'ئ'), 'ي');
    value = value.replaceAll(RegExp(r'[\s_\-]+'), '');
    value = value.replaceAll(RegExp(r'[^a-z0-9\u0621-\u064a]+'), '');
    return value;
  }

  static bool _looksLikePublicAudience(String condensed) {
    if (condensed.isEmpty) {
      return false;
    }

    const Set<String> keywords = <String>{
      'public',
      'general',
      'audience',
      'publicads',
      'publicaudience',
      'publicaudienceads',
      'اعلان',
      'اعلانات',
      'الجمهور',
      'جمهور',
      'عام',
      'العام',
      'عامه',
      'القسمالعام',
      'قسمعام',
      'قسمالجمهور',
      'قسمالجمهورالعام',
    };

    for (final String keyword in keywords) {
      if (condensed.contains(keyword)) {
        return true;
      }
    }
    return false;
  }

  static bool _looksLikeRealEstate(String condensed) {
    if (condensed.isEmpty) {
      return false;
    }

    const Set<String> keywords = <String>{
      'realestate',
      'realestateservices',
      'realestateads',
      'realestatedepartment',
      'عقار',
      'العقار',
      'عقارات',
      'العقارات',
      'عقاريا',
      'العقاريا',
      'قسمالعقارات',
      'قسمالعقاريه',
      'اراضي',
      'الاراضي',
    };

    for (final String keyword in keywords) {
      if (condensed.contains(keyword)) {
        return true;
      }
    }
    return false;
  }

  // ===== helpers =====
  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.replaceAll(',', ''));
    return null;
  }

  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  static bool? _toBool(dynamic v) {
    if (v == null) return null;
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final s = v.toLowerCase().trim();
      if (s == 'true' || s == '1') return true;
      if (s == 'false' || s == '0') return false;
    }
    return null;
  }
}

class ItemDiscount {
  final String? type;
  final double? value;
  final DateTime? start;
  final DateTime? end;
  final bool isActive;

  const ItemDiscount({
    this.type,
    this.value,
    this.start,
    this.end,
    this.isActive = false,
  });

  static ItemDiscount? fromJson(dynamic json) {
    if (json == null) {
      return null;
    }

    if (json is! Map) {
      return null;
    }

    final Map<String, dynamic> map = Map<String, dynamic>.from(json);

    return ItemDiscount(
      type: map['type'] as String?,
      value: ItemModel._toDouble(map['value']),
      start: _parseDate(map['start']),
      end: _parseDate(map['end']),
      isActive: ItemModel._toBool(map['is_active']) ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'type': type,
      'value': value,
      'start': start?.toIso8601String(),
      'end': end?.toIso8601String(),
      'is_active': isActive,
    };
  }

  static DateTime? _parseDate(dynamic value) {
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }

    return null;
  }
}

class ItemTipsMetadata {
  const ItemTipsMetadata({
    this.returnPolicyText,
    this.productLink,
    this.actions = const <Map<String, dynamic>>[],
    this.raw,
  });

  factory ItemTipsMetadata.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> _normalizeActions(dynamic value) {
      if (value is List<Map<String, dynamic>>) {
        return value;
      }
      if (value is List) {
        return value
            .whereType<Map>()
            .map((Map entry) => entry.map(
                  (dynamic key, dynamic val) => MapEntry(key.toString(), val),
                ))
            .toList();
      }
      if (value is Map<String, dynamic>) {
        return value.values
            .whereType<Map>()
            .map((Map entry) => entry.map(
                  (dynamic key, dynamic val) => MapEntry(key.toString(), val),
                ))
            .toList();
      }
      if (value is Map) {
        return value.values
            .whereType<Map>()
            .map((Map entry) => entry.map(
                  (dynamic key, dynamic val) => MapEntry(key.toString(), val),
                ))
            .toList();
      }
      return const <Map<String, dynamic>>[];
    }

    String? _coerceString(dynamic value) {
      if (value == null) return null;
      if (value is String) {
        final String trimmed = value.trim();
        return trimmed.isEmpty ? null : trimmed;
      }
      return value.toString();
    }

    final String? returnPolicyText = _coerceString(
      json['return_policy_text'] ?? json['returnPolicyText'],
    );

    final String? productLink = _coerceString(
      json['product_link'] ?? json['productLink'],
    );

    return ItemTipsMetadata(
      returnPolicyText: returnPolicyText,
      productLink: productLink,
      actions: _normalizeActions(json['actions']),
      raw: json,
    );
  }

  final String? returnPolicyText;
  final String? productLink;
  final List<Map<String, dynamic>> actions;
  final Map<String, dynamic>? raw;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (returnPolicyText != null) 'return_policy_text': returnPolicyText,
      if (productLink != null) 'product_link': productLink,
      if (actions.isNotEmpty) 'actions': actions,
      if (raw != null) ...raw!,
    };
  }

  ItemTipsMetadata copyWith({
    String? returnPolicyText,
    String? productLink,
    List<Map<String, dynamic>>? actions,
    Map<String, dynamic>? raw,
  }) {
    return ItemTipsMetadata(
      returnPolicyText: returnPolicyText ?? this.returnPolicyText,
      productLink: productLink ?? this.productLink,
      actions: actions ?? this.actions,
      raw: raw ?? this.raw,
    );
  }
}

class User {
  int? id;
  String? name;
  String? mobile;
  String? email;
  String? type;
  String? profile;
  String? fcmId;
  String? firebaseId;
  int? status;
  String? apiToken;
  dynamic address;
  String? createdAt;
  String? updatedAt;
  int? showPersonalDetails;
  int? isVerified;
  int? accountType;
  String? verificationStatus;
  String? verificationExpiresAt;
  Map<String, dynamic>? additionalInfo;
  Map<String, dynamic>? store;

  User({
    this.id,
    this.name,
    this.mobile,
    this.email,
    this.type,
    this.profile,
    this.fcmId,
    this.firebaseId,
    this.status,
    this.apiToken,
    this.address,
    this.createdAt,
    this.updatedAt,
    this.isVerified,
    this.showPersonalDetails,
    this.accountType,
    this.verificationStatus,
    this.verificationExpiresAt,
    this.additionalInfo,
    this.store,
  });

  User.fromJson(Map<String, dynamic> json) {
    id = ItemModel._toInt(json['id']);
    name = json['name'];
    mobile = json['mobile'];
    email = json['email'];
    type = json['type'];
    profile = json['profile'];
    fcmId = json['fcm_id'];
    firebaseId = json['firebase_id'];
    status = ItemModel._toInt(json['status']);
    apiToken = json['api_token'];
    address = json['address'];
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
    isVerified = ItemModel._toInt(json['is_verified']);
    showPersonalDetails = ItemModel._toInt(json['show_personal_details']);
    accountType = ItemModel._toInt(json['account_type']);
    verificationStatus = json['verification_status'];
    verificationExpiresAt = json['verification_expires_at'];
    additionalInfo = _normalizeAdditionalInfo(json['additional_info']);
    store = _normalizeStoreMap(json['store']);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['name'] = name;
    data['mobile'] = mobile;
    data['email'] = email;
    data['type'] = type;
    data['profile'] = profile;
    data['fcm_id'] = fcmId;
    data['firebase_id'] = firebaseId;
    data['status'] = status;
    data['api_token'] = apiToken;
    data['address'] = address;
    data['created_at'] = createdAt;
    data['updated_at'] = updatedAt;
    data['is_verified'] = isVerified;
    data['show_personal_details'] = showPersonalDetails;
    data['account_type'] = accountType;
    data['verification_status'] = verificationStatus;
    data['verification_expires_at'] = verificationExpiresAt;
    data['additional_info'] = additionalInfo;
    if (store != null) {
      data['store'] = Map<String, dynamic>.from(store!);
    }
    return data;
  }

  static Map<String, dynamic>? _normalizeAdditionalInfo(dynamic raw) {
    if (raw == null) {
      return null;
    }

    if (raw is Map<String, dynamic>) {
      return Map<String, dynamic>.from(raw);
    }

    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
    }

    if (raw is String) {
      final String trimmed = raw.trim();
      if (trimmed.isEmpty) {
        return null;
      }

      try {
        final dynamic decoded = json.decode(trimmed);
        if (decoded is Map<String, dynamic>) {
          return Map<String, dynamic>.from(decoded);
        }
        if (decoded is Map) {
          return decoded.map((key, value) => MapEntry(key.toString(), value));
        }
      } catch (_) {
        return null;
      }
    }

    return null;
  }

  static Map<String, dynamic>? _normalizeStoreMap(dynamic raw) {
    if (raw == null) {
      return null;
    }

    if (raw is Map<String, dynamic>) {
      return Map<String, dynamic>.from(raw);
    }

    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
    }

    return null;
  }
}

class GalleryImages {
  int? id;
  String? image;
  String? thumbnailUrl;
  String? thumbnailFallbackUrl;
  String? detailImageUrl;
  String? detailImageFallbackUrl;
  String? createdAt;
  String? updatedAt;
  int? itemId;

  GalleryImages({
    this.id,
    this.image,
    this.thumbnailUrl,
    this.thumbnailFallbackUrl,
    this.detailImageUrl,
    this.detailImageFallbackUrl,
    this.createdAt,
    this.updatedAt,
    this.itemId,
  });

  GalleryImages.fromJson(Map<String, dynamic> json) {
    id = ItemModel._toInt(json['id']);
    image = json['image'] ??
        json['thumbnail_fallback_url'] ??
        json['thumbnail_url'];
    thumbnailUrl = json['thumbnail_url'] ?? json['thumbnail'];
    thumbnailFallbackUrl = json['thumbnail_fallback_url'] ??
        json['thumbnail_fallback'] ??
        json['image'];
    detailImageUrl = json['detail_image_url'];
    detailImageFallbackUrl =
        json['detail_image_fallback_url'] ?? json['detail_image_fallback'];
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
    itemId = ItemModel._toInt(json['item_id']);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['image'] = image;
    data['thumbnail_url'] = thumbnailUrl;
    data['thumbnail_fallback_url'] = thumbnailFallbackUrl;
    data['detail_image_url'] = detailImageUrl;
    data['detail_image_fallback_url'] = detailImageFallbackUrl;
    data['created_at'] = createdAt;
    data['updated_at'] = updatedAt;
    data['item_id'] = itemId;
    return data;
  }
}

class ItemOffers {
  int? id;

  int? sellerId;
  int? buyerId;
  String? createdAt;
  String? updatedAt;
  double? amount;

  ItemOffers({
    this.id,
    this.sellerId,
    this.createdAt,
    this.updatedAt,
    this.buyerId,
    this.amount,
  });

  ItemOffers.fromJson(Map<String, dynamic> json) {
    id = ItemModel._toInt(json['id']);
    buyerId = ItemModel._toInt(json['buyer_id']);
    sellerId = ItemModel._toInt(json['seller_id']);
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
    amount = ItemModel._toDouble(json['amount']);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['buyer_id'] = buyerId;
    data['seller_id'] = sellerId;
    data['created_at'] = createdAt;
    data['updated_at'] = updatedAt;
    data['amount'] = amount;
    return data;
  }
}
