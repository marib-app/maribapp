import 'dart:convert';

class ItemFilterModel {
  final String? maxPrice;
  final String? minPrice;
  final String? categoryId;
  final String? postedSince;
  final String? sortBy;
  final String? city;
  final String? state;
  final String? country;
  final String? area;
  final int? areaId;
  final int? radius;
  final double? latitude;
  final double? longitude;
  final String? currency;
  final Map<String, dynamic>? customFields;
  final int? userId;
  final int? storeId;

  ItemFilterModel({
    this.maxPrice,
    this.minPrice,
    this.categoryId,
    this.postedSince,
    this.sortBy,
    this.city,
    this.state,
    this.country,
    this.area,
    this.areaId,
    this.radius,
    this.latitude,
    this.longitude,
    this.currency,
    this.userId,
    this.storeId,
    this.customFields = const {},
  });

  ItemFilterModel copyWith({
    String? maxPrice,
    String? minPrice,
    String? categoryId,
    String? postedSince,
    String? sortBy,
    String? city,
    String? state,
    String? country,
    String? area,
    int? areaId,
    int? radius,
    double? latitude,
    double? longitude,
    String? currency,
    int? userId,
    int? storeId,
    Map<String, dynamic>? customFields,
  }) {
    return ItemFilterModel(
      maxPrice: maxPrice ?? this.maxPrice,
      minPrice: minPrice ?? this.minPrice,
      categoryId: categoryId ?? this.categoryId,
      postedSince: postedSince ?? this.postedSince,
      sortBy: sortBy ?? this.sortBy,
      city: city ?? this.city,
      state: state ?? this.state,
      country: country ?? this.country,
      area: area ?? this.area,
      areaId: areaId ?? this.areaId,
      radius: radius ?? this.radius,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      currency: currency ?? this.currency,
      userId: userId ?? this.userId,
      storeId: storeId ?? this.storeId,
      customFields: customFields ?? this.customFields,
    );
  }

  Map<String, dynamic> toMap() {
    final Map<String, dynamic> map = <String, dynamic>{
      'max_price': maxPrice,
      'min_price': minPrice,
      'category_id': categoryId,
      'posted_since': postedSince,
      'sort_by': sortBy,
      'city': city,
      'state': state,
      'country': country,
      'area': area,
      'radius': radius,
      'area_id': areaId,
      'longitude': longitude,
      'latitude': latitude,
      'currency': currency,
    };
    map.removeWhere((key, value) => value == null);
    if (userId != null) {
      map['user_id'] = userId;
    }
    if (storeId != null) {
      map['store_id'] = storeId;
    }
    if (customFields != null && customFields!.isNotEmpty) {
      map['custom_fields'] = customFields;
    }

    return map;
  }

  factory ItemFilterModel.fromMap(Map<String, dynamic> map) {
    return ItemFilterModel(
      city: map['city']?.toString(),
      state: map['state']?.toString(),
      country: map['country'] != null ? map['country'].toString() : null,
      maxPrice: map['max_price']?.toString(),
      minPrice: map['min_price']?.toString(),
      categoryId: map['category_id']?.toString(),
      postedSince: map['posted_since']?.toString(),
      sortBy: map['sort_by']?.toString(),
      area: map['area']?.toString(),
      radius:
          map['radius'] != null ? int.tryParse(map['radius'].toString()) : null,
      areaId: map['area_id'] != null
          ? int.tryParse(map['area_id'].toString())
          : null,
      latitude: map['latitude'] != null ? map['latitude'] : null,
      longitude: map['longitude'] != null ? map['longitude'] : null,
      currency: map['currency']?.toString(),
      userId: map['user_id'] != null
          ? int.tryParse(map['user_id'].toString())
          : null,
      storeId: map['store_id'] != null
          ? int.tryParse(map['store_id'].toString())
          : null,
      customFields: Map<String, dynamic>.from(map['custom_fields'] ?? {}),
    );
  }

  String toJson() => json.encode(toMap());

  factory ItemFilterModel.fromJson(String source) =>
      ItemFilterModel.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'ItemFilterModel(maxPrice: $maxPrice, minPrice: $minPrice, categoryId: $categoryId, postedSince: $postedSince, sortBy: $sortBy, city: $city, state: $state, country: $country, area: $area, areaId: $areaId, custom_fields: $customFields,radius:$radius,latitude:$latitude,longitude:$longitude,userId:$userId,storeId:$storeId)';
  }

  factory ItemFilterModel.createEmpty() {
    return ItemFilterModel(
      maxPrice: "",
      minPrice: "",
      categoryId: "",
      postedSince: "",
      sortBy: null,
      city: '',
      state: '',
      country: '',
      area: null,
      areaId: null,
      radius: null,
      latitude: null,
      longitude: null,
      customFields: const {},
      userId: null,
      storeId: null,
    );
  }

  @override
  bool operator ==(covariant ItemFilterModel other) {
    if (identical(this, other)) return true;

    return other.maxPrice == maxPrice &&
        other.minPrice == minPrice &&
        other.categoryId == categoryId &&
        other.postedSince == postedSince &&
        other.sortBy == sortBy &&
        other.city == city &&
        other.state == state &&
        other.country == country &&
        other.area == area &&
        other.radius == radius &&
        other.areaId == areaId &&
        other.latitude == latitude &&
        other.longitude == longitude &&
        other.currency == currency &&
        other.userId == userId &&
        other.storeId == storeId &&
        other.customFields == customFields;
  }

  @override
  int get hashCode {
    return maxPrice.hashCode ^
        minPrice.hashCode ^
        categoryId.hashCode ^
        postedSince.hashCode ^
        sortBy.hashCode ^
        city.hashCode ^
        state.hashCode ^
        country.hashCode ^
        area.hashCode ^
        radius.hashCode ^
        areaId.hashCode ^
        latitude.hashCode ^
        longitude.hashCode ^
        currency.hashCode ^
        (storeId?.hashCode ?? 0) ^
        (userId?.hashCode ?? 0) ^
        customFields.hashCode;
  }
}
