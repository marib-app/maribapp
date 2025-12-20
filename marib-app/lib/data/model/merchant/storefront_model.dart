class StorefrontDetails {
  StorefrontDetails({
    required this.id,
    this.userId,
    required this.name,
    required this.slug,
    required this.status,
    this.description,
    this.logoUrl,
    this.bannerUrl,
    this.isFollowed = false,
    this.followersCount,
    this.itemsCount,
    this.ratingsAverage,
    this.ratingsCount,
    this.contact,
    this.location,
    this.settings,
    this.policies = const <StorefrontPolicy>[],
    this.workingHours = const <StorefrontWorkingHour>[],
    this.manualBanks = const <StorefrontManualBank>[],
  });

  StorefrontDetails copyWith({
    int? id,
    int? userId,
    String? name,
    String? slug,
    StorefrontStatus? status,
    String? description,
    String? logoUrl,
    String? bannerUrl,
    bool? isFollowed,
    int? followersCount,
    int? itemsCount,
    double? ratingsAverage,
    int? ratingsCount,
    StorefrontContact? contact,
    StorefrontLocation? location,
    StorefrontSettings? settings,
    List<StorefrontPolicy>? policies,
    List<StorefrontWorkingHour>? workingHours,
    List<StorefrontManualBank>? manualBanks,
  }) {
    return StorefrontDetails(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      status: status ?? this.status,
      description: description ?? this.description,
      logoUrl: logoUrl ?? this.logoUrl,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      isFollowed: isFollowed ?? this.isFollowed,
      followersCount: followersCount ?? this.followersCount,
      itemsCount: itemsCount ?? this.itemsCount,
      ratingsAverage: ratingsAverage ?? this.ratingsAverage,
      ratingsCount: ratingsCount ?? this.ratingsCount,
      contact: contact ?? this.contact,
      location: location ?? this.location,
      settings: settings ?? this.settings,
      policies: policies ?? this.policies,
      workingHours: workingHours ?? this.workingHours,
      manualBanks: manualBanks ?? this.manualBanks,
    );
  }

  factory StorefrontDetails.fromJson(Map<String, dynamic> json) {
    final int? userId =
        _intValue(json['user_id'] ?? json['owner_id']);
    final int? followersCount = _intValue(
      json['followers_count'] ??
          json['followersCount'] ??
          json['followers'] ??
          json['followers_total'],
    );
    final int? itemsCount = _intValue(
      json['items_count'] ??
          json['itemsCount'] ??
          json['products_count'] ??
          json['productsCount'] ??
          json['products_total'],
    );
    final double? ratingsAverage = _doubleValue(
      json['ratings_avg'] ??
          json['ratingsAverage'] ??
          json['average_rating'] ??
          json['rating_avg'],
    );
    final int? ratingsCount = _intValue(
      json['ratings_count'] ??
          json['reviews_count'] ??
          json['ratingsCount'] ??
          json['reviewsCount'],
    );

    return StorefrontDetails(
      id: json['id'] as int? ?? 0,
      userId: userId,
      name: json['name']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      description: json['description']?.toString(),
      logoUrl: json['logo_url']?.toString(),
      bannerUrl: json['banner_url']?.toString(),
      isFollowed: _boolValue(
            json['is_followed'] ??
                json['is_following'] ??
                json['following'],
          ) ??
          false,
      followersCount: followersCount,
      itemsCount: itemsCount,
      ratingsAverage: ratingsAverage,
      ratingsCount: ratingsCount,
      status: StorefrontStatus.fromJson(
        (json['status'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
      ),
      contact: json['contact'] is Map<String, dynamic>
          ? StorefrontContact.fromJson(
              json['contact'] as Map<String, dynamic>,
            )
          : null,
      location: json['location'] is Map<String, dynamic>
          ? StorefrontLocation.fromJson(
              json['location'] as Map<String, dynamic>,
            )
          : null,
      settings: json['settings'] is Map<String, dynamic>
          ? StorefrontSettings.fromJson(
              json['settings'] as Map<String, dynamic>,
            )
          : null,
      policies: (json['policies'] as List<dynamic>?)
              ?.map((dynamic e) =>
                  StorefrontPolicy.fromJson(e as Map<String, dynamic>))
              .toList(growable: false) ??
          const <StorefrontPolicy>[],
      workingHours: (json['working_hours'] as List<dynamic>?)
              ?.map((dynamic e) =>
                  StorefrontWorkingHour.fromJson(e as Map<String, dynamic>))
              .toList(growable: false) ??
          const <StorefrontWorkingHour>[],
      manualBanks: (json['manual_banks'] as List<dynamic>?)
              ?.map((dynamic e) =>
                  StorefrontManualBank.fromJson(e as Map<String, dynamic>))
              .toList(growable: false) ??
          const <StorefrontManualBank>[],
    );
  }

  factory StorefrontDetails.fromSnapshot(Map<String, dynamic> json) {
    final int id =
        _intValue(json['id']) ?? _intValue(json['store_id']) ?? 0;
    final int? userId =
        _intValue(json['user_id'] ?? json['owner_id']);
    final String slug = json['slug']?.toString() ?? '';
    final String name = json['name']?.toString() ?? '';
    final String? description = json['description']?.toString();
    final String? logo =
        json['logo_url']?.toString() ?? json['logo_path']?.toString();
    final String? banner =
        json['banner_url']?.toString() ?? json['banner_path']?.toString();

    final bool isFollowed =
        _boolValue(json['is_followed'] ?? json['is_following']) ?? false;
    final int? followersCount = _intValue(
      json['followers_count'] ??
          json['followersCount'] ??
          json['followers'] ??
          json['followers_total'],
    );
    final int? itemsCount = _intValue(
      json['items_count'] ??
          json['itemsCount'] ??
          json['products_count'] ??
          json['productsCount'] ??
          json['products_total'],
    );
    final double? ratingsAverage = _doubleValue(
      json['ratings_avg'] ??
          json['ratingsAverage'] ??
          json['average_rating'] ??
          json['rating_avg'],
    );
    final int? ratingsCount = _intValue(
      json['ratings_count'] ??
          json['reviews_count'] ??
          json['ratingsCount'] ??
          json['reviewsCount'],
    );

    final bool allowDelivery = _boolValue(json['allow_delivery']);
    final bool allowPickup = _boolValue(json['allow_pickup']);
    final bool allowManualPayments =
        _boolValue(json['allow_manual_payments']);
    final bool allowWallet = _boolValue(json['allow_wallet']);
    final bool allowCod = _boolValue(json['allow_cod']);
    final bool isOpenNow = _boolValue(json['is_open_now']);
    final double? minOrderAmount =
        _doubleValue(json['min_order_amount'] ?? json['min_order_total']);
    final String? checkoutNotice = _stringValue(json['checkout_notice']);

    final StorefrontStatus status = StorefrontStatus(
      state: json['status']?.toString() ?? '',
      displayLabel:
          json['status_label']?.toString() ?? json['status']?.toString() ?? '',
      allowDelivery: allowDelivery,
      allowPickup: allowPickup,
      allowManualPayments: allowManualPayments,
      allowWallet: allowWallet,
      allowCod: allowCod,
      isOpenNow: isOpenNow,
      minOrderAmount: minOrderAmount,
      checkoutNotice: checkoutNotice,
    );

    final String? contactEmail =
        _stringValue(json['contact_email']) ?? _stringValue(json['email']);
    final String? contactPhone = _stringValue(json['contact_phone']);
    final String? contactWhatsapp = _stringValue(json['contact_whatsapp']);
    StorefrontContact? contact;
    if (contactEmail != null ||
        contactPhone != null ||
        contactWhatsapp != null ||
        checkoutNotice != null) {
      contact = StorefrontContact(
        email: contactEmail,
        phone: contactPhone,
        whatsapp: contactWhatsapp,
        checkoutNotice: checkoutNotice,
      );
    }

    final String? locationAddress = _stringValue(json['location_address']);
    final String? locationCity = _stringValue(json['location_city']);
    final String? locationState = _stringValue(json['location_state']);
    final String? locationCountry = _stringValue(json['location_country']);
    final double? locationLat = _doubleValue(json['location_latitude']);
    final double? locationLon = _doubleValue(json['location_longitude']);
    StorefrontLocation? location;
    if (locationAddress != null ||
        locationCity != null ||
        locationState != null ||
        locationCountry != null ||
        locationLat != null ||
        locationLon != null) {
      location = StorefrontLocation(
        address: locationAddress,
        city: locationCity,
        state: locationState,
        country: locationCountry,
        latitude: locationLat,
        longitude: locationLon,
      );
    }

    StorefrontSettings? settings;
    if (allowDelivery ||
        allowPickup ||
        allowManualPayments ||
        allowWallet ||
        allowCod ||
        minOrderAmount != null ||
        checkoutNotice != null) {
      settings = StorefrontSettings(
        allowDelivery: allowDelivery,
        allowPickup: allowPickup,
        allowManualPayments: allowManualPayments,
        allowWallet: allowWallet,
        allowCod: allowCod,
        minOrderAmount: minOrderAmount,
        checkoutNotice: checkoutNotice,
      );
    }

    return StorefrontDetails(
      id: id,
      userId: userId,
      name: name,
      slug: slug,
      description: description,
      logoUrl: logo,
      bannerUrl: banner,
      isFollowed: isFollowed,
      followersCount: followersCount,
      itemsCount: itemsCount,
      ratingsAverage: ratingsAverage,
      ratingsCount: ratingsCount,
      status: status,
      contact: contact,
      location: location,
      settings: settings,
    );
  }

  final int id;
  final int? userId;
  final String name;
  final String slug;
  final String? description;
  final String? logoUrl;
  final String? bannerUrl;
  final bool isFollowed;
  final int? followersCount;
  final int? itemsCount;
  final double? ratingsAverage;
  final int? ratingsCount;
  final StorefrontStatus status;
  final StorefrontContact? contact;
  final StorefrontLocation? location;
  final StorefrontSettings? settings;
  final List<StorefrontPolicy> policies;
  final List<StorefrontWorkingHour> workingHours;
  final List<StorefrontManualBank> manualBanks;

  bool get isOpenNow => status.isOpenNow;

  static int? _intValue(dynamic raw) {
    if (raw == null) {
      return null;
    }
    if (raw is int) {
      return raw;
    }
    if (raw is num) {
      return raw.toInt();
    }
    if (raw is String) {
      return int.tryParse(raw.trim());
    }
    return null;
  }

  static double? _doubleValue(dynamic raw) {
    if (raw == null) {
      return null;
    }
    if (raw is double) {
      return raw;
    }
    if (raw is num) {
      return raw.toDouble();
    }
    if (raw is String) {
      return double.tryParse(raw.trim());
    }
    return null;
  }

  static bool _boolValue(dynamic raw) {
    if (raw == null) {
      return false;
    }
    if (raw is bool) {
      return raw;
    }
    if (raw is num) {
      return raw != 0;
    }
    if (raw is String) {
      final String normalized = raw.trim().toLowerCase();
      return normalized == '1' ||
          normalized == 'true' ||
          normalized == 'yes' ||
          normalized == 'on';
    }
    return false;
  }

  static String? _stringValue(dynamic raw) {
    if (raw == null) {
      return null;
    }
    final String value = raw.toString().trim();
    return value.isEmpty ? null : value;
  }
}

class StorefrontStatus {
  StorefrontStatus({
    required this.state,
    required this.displayLabel,
    required this.allowDelivery,
    required this.allowPickup,
    required this.allowManualPayments,
    required this.allowWallet,
    required this.allowCod,
    required this.isOpenNow,
    this.minOrderAmount,
    this.checkoutNotice,
  });

  factory StorefrontStatus.fromJson(Map<String, dynamic> json) {
    return StorefrontStatus(
      state: json['status']?.toString() ?? '',
      displayLabel: json['status_label']?.toString() ?? '',
      allowDelivery: json['allow_delivery'] as bool? ?? false,
      allowPickup: json['allow_pickup'] as bool? ?? false,
      allowManualPayments: json['allow_manual_payments'] as bool? ?? false,
      allowWallet: json['allow_wallet'] as bool? ?? false,
      allowCod: json['allow_cod'] as bool? ?? false,
      isOpenNow: json['is_open_now'] as bool? ?? false,
      minOrderAmount: (json['min_order_amount'] as num?)?.toDouble(),
      checkoutNotice: json['checkout_notice']?.toString(),
    );
  }

  final String state;
  final String displayLabel;
  final bool allowDelivery;
  final bool allowPickup;
  final bool allowManualPayments;
  final bool allowWallet;
  final bool allowCod;
  final bool isOpenNow;
  final double? minOrderAmount;
  final String? checkoutNotice;
}

class StorefrontContact {
  StorefrontContact({
    this.email,
    this.phone,
    this.whatsapp,
    this.checkoutNotice,
  });

  factory StorefrontContact.fromJson(Map<String, dynamic> json) {
    return StorefrontContact(
      email: json['email']?.toString(),
      phone: json['phone']?.toString(),
      whatsapp: json['whatsapp']?.toString(),
      checkoutNotice: json['checkout_notice']?.toString(),
    );
  }

  final String? email;
  final String? phone;
  final String? whatsapp;
  final String? checkoutNotice;
}

class StorefrontLocation {
  StorefrontLocation({
    this.address,
    this.city,
    this.state,
    this.country,
    this.latitude,
    this.longitude,
  });

  factory StorefrontLocation.fromJson(Map<String, dynamic> json) {
    return StorefrontLocation(
      address: json['address']?.toString(),
      city: json['city']?.toString(),
      state: json['state']?.toString(),
      country: json['country']?.toString(),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }

  final String? address;
  final String? city;
  final String? state;
  final String? country;
  final double? latitude;
  final double? longitude;

  String? get primaryLine {
    final parts = <String>[];
    if (address?.trim().isNotEmpty == true) {
      parts.add(address!.trim());
    }
    if (city?.trim().isNotEmpty == true) {
      parts.add(city!.trim());
    }
    if (state?.trim().isNotEmpty == true) {
      parts.add(state!.trim());
    }
    if (country?.trim().isNotEmpty == true) {
      parts.add(country!.trim());
    }
    if (parts.isEmpty) return null;
    return parts.join(', ');
  }
}

class StorefrontPolicy {
  StorefrontPolicy({
    required this.title,
    required this.content,
    required this.type,
    required this.isRequired,
  });

  factory StorefrontPolicy.fromJson(Map<String, dynamic> json) {
    return StorefrontPolicy(
      title: json['title']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      isRequired: json['is_required'] as bool? ?? false,
    );
  }

  final String title;
  final String content;
  final String type;
  final bool isRequired;
}

class StorefrontWorkingHour {
  StorefrontWorkingHour({
    required this.weekday,
    required this.label,
    required this.isOpen,
    this.opensAt,
    this.closesAt,
  });

  factory StorefrontWorkingHour.fromJson(Map<String, dynamic> json) {
    return StorefrontWorkingHour(
      weekday: json['weekday'] as int? ?? 0,
      label: json['label']?.toString() ?? '',
      isOpen: json['is_open'] as bool? ?? false,
      opensAt: json['opens_at']?.toString(),
      closesAt: json['closes_at']?.toString(),
    );
  }

  final int weekday;
  final String label;
  final bool isOpen;
  final String? opensAt;
  final String? closesAt;
}

class StorefrontSettings {
  StorefrontSettings({
    required this.allowDelivery,
    required this.allowPickup,
    required this.allowManualPayments,
    required this.allowWallet,
    required this.allowCod,
    this.minOrderAmount,
    this.checkoutNotice,
  });

  factory StorefrontSettings.fromJson(Map<String, dynamic> json) {
    return StorefrontSettings(
      allowDelivery: json['allow_delivery'] as bool? ?? false,
      allowPickup: json['allow_pickup'] as bool? ?? false,
      allowManualPayments: json['allow_manual_payments'] as bool? ?? false,
      allowWallet: json['allow_wallet'] as bool? ?? false,
      allowCod: json['allow_cod'] as bool? ?? false,
      minOrderAmount: (json['min_order_amount'] as num?)?.toDouble(),
      checkoutNotice: json['checkout_notice']?.toString(),
    );
  }

  final bool allowDelivery;
  final bool allowPickup;
  final bool allowManualPayments;
  final bool allowWallet;
  final bool allowCod;
  final double? minOrderAmount;
  final String? checkoutNotice;
}

class StorefrontManualBank {
  StorefrontManualBank({
    required this.accountNumber,
    required this.beneficiaryName,
    this.gateway,
  });

  factory StorefrontManualBank.fromJson(Map<String, dynamic> json) {
    return StorefrontManualBank(
      accountNumber: json['account_number']?.toString() ?? '',
      beneficiaryName: json['beneficiary_name']?.toString() ?? '',
      gateway: json['gateway'] is Map<String, dynamic>
          ? StorefrontGatewayInfo.fromJson(
              json['gateway'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  final String accountNumber;
  final String beneficiaryName;
  final StorefrontGatewayInfo? gateway;
}

class StorefrontGatewayInfo {
  StorefrontGatewayInfo({
    required this.id,
    required this.name,
    this.logoUrl,
  });

  factory StorefrontGatewayInfo.fromJson(Map<String, dynamic> json) {
    return StorefrontGatewayInfo(
      id: json['id'] as int? ?? 0,
      name: json['name']?.toString() ?? '',
      logoUrl: json['logo_url']?.toString(),
    );
  }

  final int id;
  final String name;
  final String? logoUrl;
}
