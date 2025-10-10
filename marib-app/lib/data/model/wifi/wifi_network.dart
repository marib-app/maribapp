import 'package:equatable/equatable.dart';

import 'wifi_plan.dart';

class WifiNetwork extends Equatable {
  const WifiNetwork({
    required this.id,
    required this.name,
    this.slug,
    this.latitude,
    this.longitude,
    this.description,
    this.iconUrl,
    this.coverageKm,
    this.loginScreenshotUrl,
    this.address,
    this.planCount = 0,
    this.currencies = const <String>[],
    this.contacts = const <String>[],
    this.notes,
    this.meta,
    this.plans = const <WifiPlan>[],
  });

  final int id;
  final String name;
  final String? slug;
  final double? latitude;
  final double? longitude;
  final String? description;
  final String? iconUrl;
  final double? coverageKm;
  final String? loginScreenshotUrl;

  final String? address;
  final List<WifiPlan> plans;
  final int planCount;
  final List<String> currencies;
  final List<String> contacts;
  final String? notes;
  final Map<String, dynamic>? meta;



  factory WifiNetwork.fromJson(Map<String, dynamic> json) {
    double? parseDouble(dynamic value) {
      if (value == null) return null;
      if (value is double) return value;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString());
    }

    int? parseInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value.toString());
    }

    List<WifiPlan> parsePlans(dynamic value) {
      if (value is List) {
        return value
            .map((dynamic e) {
          if (e is Map<String, dynamic>) {
            return WifiPlan.fromJson(e);
          }
          if (e is Map) {
            return WifiPlan.fromJson(Map<String, dynamic>.from(e as Map));
          }
          return null;
        })
            .whereType<WifiPlan>()
            .toList();
      }
      return const [];
    }


    String? resolveIconUrl(Map<String, dynamic> source) {
      final List<String> keys = <String>[
        'icon',
        'icon_url',
        'iconUrl',
        'logo_url',
        'logo',
        'logo_path',
      ];

      for (final String key in keys) {
        final dynamic value = source[key];
        if (value == null) continue;
        final String text = value.toString().trim();
        if (text.isEmpty) continue;
        return text;
      }

      return null;
    }

    final double? coverage = parseDouble(json['radius']) ??
        parseDouble(json['radius_km']) ??
        parseDouble(json['coverage_radius_km']) ??
        parseDouble(json['coverage_km']);

     List<String> resolveStringList(dynamic source) {
      if (source is List) {
        return source
            .map((dynamic element) => element?.toString())
            .whereType<String>()
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toList();
      }
      if (source is String) {
        return source
            .split(RegExp(r'[\r\n,;]+'))
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toList();
      }
      return const <String>[];
    }

    Map<String, dynamic>? parseMeta(dynamic value) {
      if (value is Map<String, dynamic>) {
        return value;
      }
      if (value is Map) {
        return Map<String, dynamic>.from(value as Map);
      }
      return null;
    }



    final List<WifiPlan> parsedPlans =
    parsePlans(json['plans'] ?? json['wifi_plans'] ?? json['available_plans']);



    return WifiNetwork(
      id: parseInt(json['id']) ?? 0,
      name: json['name']?.toString() ?? '',
      slug: json['slug']?.toString(),
      latitude: parseDouble(json['latitude']),
      longitude: parseDouble(json['longitude']),
      description: json['description']?.toString(),
      iconUrl: resolveIconUrl(json),
      loginScreenshotUrl: json['login_screenshot_url']?.toString(),
      coverageKm: coverage,
      address: json['address']?.toString() ?? json['location_name']?.toString(),
      planCount: parseInt(json['plan_count']) ?? parsedPlans.length,
      currencies: resolveStringList(json['currencies']).map((e) => e.toUpperCase()).toList(),
      contacts: resolveStringList(json['contacts']),
      notes: json['notes']?.toString(),
      meta: parseMeta(json['meta']),
      plans: parsedPlans,
    );
  }

  WifiNetwork copyWith({
    int? id,
    String? name,
    String? slug,
    double? latitude,
    double? longitude,
    String? description,
    String? iconUrl,
    double? coverageKm,
    String? loginScreenshotUrl,
    String? address,
    int? planCount,
    List<String>? currencies,
    List<String>? contacts,
    String? notes,
    Map<String, dynamic>? meta,
    List<WifiPlan>? plans,
  }) {
    return WifiNetwork(
      id: id ?? this.id,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      loginScreenshotUrl: loginScreenshotUrl ?? this.loginScreenshotUrl,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      description: description ?? this.description,
      iconUrl: iconUrl ?? this.iconUrl,
      coverageKm: coverageKm ?? this.coverageKm,
      planCount: planCount ?? this.planCount,
      currencies: currencies ?? this.currencies,
      contacts: contacts ?? this.contacts,
      notes: notes ?? this.notes,
      meta: meta ?? this.meta,
      address: address ?? this.address,
      plans: plans ?? this.plans,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (slug != null) 'slug': slug,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (description != null) 'description': description,
      if (iconUrl != null) 'icon_url': iconUrl,
      if (coverageKm != null) 'radius_km': coverageKm,
      if (coverageKm != null) 'coverage_radius_km': coverageKm,
      if (loginScreenshotUrl != null)
        'login_screenshot_url': loginScreenshotUrl,
      if (address != null) 'address': address,
      'plan_count': planCount,
      if (currencies.isNotEmpty) 'currencies': currencies,
      if (contacts.isNotEmpty) 'contacts': contacts,
      if (notes != null) 'notes': notes,
      if (meta != null) 'meta': meta,
      'plans': plans.map((plan) => plan.toJson()).toList(),

    };
  }

  @override
  List<Object?> get props => [
    id,
    name,
    slug,
    latitude,
    longitude,
    description,
    iconUrl,
    coverageKm,
    loginScreenshotUrl,
    planCount,
    currencies,
    contacts,
    notes,
    meta,
    address,
    plans,
  ];
}