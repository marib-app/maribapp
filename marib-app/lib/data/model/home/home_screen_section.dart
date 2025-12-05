import 'package:marib/data/model/item/item_model.dart';

class HomeScreenSection {
  int? sectionId;
  String? title;
  int? totalData;
  String? style;
  String? sectionType;
  String? filter;
  String? slug;
  int? sequence;
  String? rootIdentifier;
  double? minPrice;
  double? maxPrice;
  bool? hasMore;
  List<ItemModel>? sectionData;

  HomeScreenSection(
      {this.sectionId,
      this.style,
      this.title,
      this.sectionType,
      this.filter,
      this.slug,
      this.minPrice,
      this.maxPrice,
      this.sequence,
      this.rootIdentifier,
      this.hasMore,
      this.totalData,
      this.sectionData});

  HomeScreenSection copyWith({
    int? sectionId,
    String? style,
    String? title,
    String? sectionType,
    String? filter,
    String? slug,
    int? sequence,
    String? rootIdentifier,
    int? totalData,
    double? minPrice,
    double? maxPrice,
    bool? hasMore,
    List<ItemModel>? sectionData,
  }) {
    return HomeScreenSection(
      sectionId: sectionId ?? this.sectionId,
      style: style ?? this.style,
      title: title ?? this.title,
      sectionType: sectionType ?? this.sectionType,
      filter: filter ?? this.filter,
      slug: slug ?? this.slug,
      sequence: sequence ?? this.sequence,
      rootIdentifier: rootIdentifier ?? this.rootIdentifier,
      totalData: totalData ?? this.totalData,
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
      hasMore: hasMore ?? this.hasMore,
      sectionData: sectionData ?? this.sectionData,
    );
  }

  HomeScreenSection.fromJson(Map<String, dynamic> json) {
    sectionId = json['id'];
    title = json['title'];
    style = json['style'];
    sectionType = json['section_type'] ?? json['interface_type'];
    filter = json['filter'];
    slug = json['slug'];
    sequence = _parseInt(json['sequence']);
    rootIdentifier =
        _asString(json['root_identifier']) ?? _asString(json['rootIdentifier']);
    totalData = json['total_data'];
    minPrice = _parseDouble(json['min_price'] ?? json['minPrice']);
    maxPrice = _parseDouble(json['max_price'] ?? json['maxPrice']);
    final dynamic hasMoreRaw = json['has_more'];
    if (hasMoreRaw is bool) {
      hasMore = hasMoreRaw;
    } else if (hasMoreRaw is num) {
      hasMore = hasMoreRaw != 0;
    } else if (hasMoreRaw is String) {
      hasMore = hasMoreRaw.toLowerCase() == 'true' || hasMoreRaw == '1';
    }
    if (json['section_data'] != null) {
      sectionData = <ItemModel>[];
      json['section_data'].forEach((v) {
        sectionData!.add(ItemModel.fromJson(v));
      });
    }
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static String? _asString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    return value.toString();
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    final String text = value.toString();
    if (text.trim().isEmpty) {
      return null;
    }
    return double.tryParse(text);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = sectionId;
    data['title'] = title;
    data['total_data'] = totalData;
    data['style'] = style;
    data['section_type'] = sectionType;
    data['filter'] = filter;
    data['slug'] = slug;
    data['sequence'] = sequence;
    data['root_identifier'] = rootIdentifier;
    data['min_price'] = minPrice;
    data['max_price'] = maxPrice;
    data['has_more'] = hasMore;
    if (sectionData != null) {
      data['section_data'] = sectionData!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class SectionData {
  int? id;
  String? name;
  String? description;
  int? price;
  String? image;
  Null watermarkimage;
  double? latitude;
  double? longitude;
  String? address;
  String? contact;
  String? type;
  String? status;
  int? active;
  String? videoLink;
  UserDetails? userDetails;
  List<GalleryImages>? galleryImages;
  int? clicks;
  int? likes;
  List<CustomFields>? customFields;

  SectionData(
      {this.id,
      this.name,
      this.description,
      this.price,
      this.image,
      this.watermarkimage,
      this.latitude,
      this.longitude,
      this.address,
      this.contact,
      this.type,
      this.status,
      this.active,
      this.videoLink,
      this.userDetails,
      this.galleryImages,
      this.clicks,
      this.likes,
      this.customFields});

  SectionData.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    name = json['name'];
    description = json['description'];
    price = json['price'];
    image = json['image'];
    watermarkimage = json['watermarkimage'];
    latitude = json['latitude'];
    longitude = json['longitude'];
    address = json['address'];
    contact = json['contact'];
    type = json['type'];
    status = json['status'];
    active = json['active'];
    videoLink = json['video_link'];
    userDetails = json['user_details'] != null
        ? UserDetails.fromJson(json['user_details'])
        : null;
    if (json['gallery_images'] != null) {
      galleryImages = <GalleryImages>[];
      json['gallery_images'].forEach((v) {
        galleryImages!.add(GalleryImages.fromJson(v));
      });
    }
    clicks = json['clicks'];
    likes = json['likes'];
    if (json['custom_fields'] != null) {
      customFields = <CustomFields>[];
      json['custom_fields'].forEach((v) {
        customFields!.add(CustomFields.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['name'] = name;
    data['description'] = description;
    data['price'] = price;
    data['image'] = image;
    data['watermarkimage'] = watermarkimage;
    data['latitude'] = latitude;
    data['longitude'] = longitude;
    data['address'] = address;
    data['contact'] = contact;
    data['type'] = type;
    data['status'] = status;
    data['active'] = active;
    data['video_link'] = videoLink;
    if (userDetails != null) {
      data['user_details'] = userDetails!.toJson();
    }
    if (galleryImages != null) {
      data['gallery_images'] = galleryImages!.map((v) => v.toJson()).toList();
    }
    data['clicks'] = clicks;
    data['likes'] = likes;
    if (customFields != null) {
      data['custom_fields'] = customFields!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class UserDetails {
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
  Null address;
  String? createdAt;
  String? updatedAt;

  UserDetails(
      {this.id,
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
      this.updatedAt});

  UserDetails.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    name = json['name'];
    mobile = json['mobile'];
    email = json['email'];
    type = json['type'];
    profile = json['profile'];
    fcmId = json['fcm_id'];
    firebaseId = json['firebase_id'];
    status = json['status'];
    apiToken = json['api_token'];
    address = json['address'];
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
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
    return data;
  }
}

class GalleryImages {
  int? id;
  String? image;
  String? createdAt;
  String? updatedAt;
  int? itemId;

  GalleryImages(
      {this.id, this.image, this.createdAt, this.updatedAt, this.itemId});

  GalleryImages.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    image = json['image'];
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
    itemId = json['item_id'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['image'] = image;
    data['created_at'] = createdAt;
    data['updated_at'] = updatedAt;
    data['item_id'] = itemId;
    return data;
  }
}

class CustomFields {
  int? id;
  String? name;
  String? type;
  String? image;
  List<String>? value;

  CustomFields({this.id, this.name, this.type, this.image, this.value});

  CustomFields.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    name = json['name'];
    type = json['type'];
    image = json['image'];
    value = json['value'].cast<String>();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['name'] = name;
    data['type'] = type;
    data['image'] = image;
    data['value'] = value;
    return data;
  }
}
