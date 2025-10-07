import 'package:equatable/equatable.dart';

import 'wifi_plan.dart';

class WifiNetwork extends Equatable {
  const WifiNetwork({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.description,
    this.iconUrl,
    this.coverageKm,
    this.rating,
    this.distanceKm,
    this.address,
    this.plans = const [],
  });

  final int id;
  final String name;
  final double latitude;
  final double longitude;
  final String? description;
  final String? iconUrl;
  final double? coverageKm;
  final double? rating;
  final double? distanceKm;
  final String? address;
  final List<WifiPlan> plans;

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

    return WifiNetwork(
      id: parseInt(json['id']) ?? 0,
      name: json['name']?.toString() ?? '',
      latitude: parseDouble(json['latitude']) ?? 0,
      longitude: parseDouble(json['longitude']) ?? 0,
      description: json['description']?.toString(),
      iconUrl: json['icon']?.toString() ?? json['icon_url']?.toString(),
      coverageKm: parseDouble(json['radius']) ?? parseDouble(json['radius_km']),
      rating: parseDouble(json['rating']),
      distanceKm: parseDouble(json['distance']) ?? parseDouble(json['distance_km']),
      address: json['address']?.toString(),
      plans: parsePlans(json['plans'] ?? json['wifi_plans'] ?? json['available_plans']),
    );
  }

  WifiNetwork copyWith({
    int? id,
    String? name,
    double? latitude,
    double? longitude,
    String? description,
    String? iconUrl,
    double? coverageKm,
    double? rating,
    double? distanceKm,
    String? address,
    List<WifiPlan>? plans,
  }) {
    return WifiNetwork(
      id: id ?? this.id,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      description: description ?? this.description,
      iconUrl: iconUrl ?? this.iconUrl,
      coverageKm: coverageKm ?? this.coverageKm,
      rating: rating ?? this.rating,
      distanceKm: distanceKm ?? this.distanceKm,
      address: address ?? this.address,
      plans: plans ?? this.plans,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      if (description != null) 'description': description,
      if (iconUrl != null) 'icon_url': iconUrl,
      if (coverageKm != null) 'radius_km': coverageKm,
      if (rating != null) 'rating': rating,
      if (distanceKm != null) 'distance_km': distanceKm,
      if (address != null) 'address': address,
      'plans': plans.map((plan) => plan.toJson()).toList(),
    };
  }

  @override
  List<Object?> get props => [
    id,
    name,
    latitude,
    longitude,
    description,
    iconUrl,
    coverageKm,
    rating,
    distanceKm,
    address,
    plans,
  ];
}