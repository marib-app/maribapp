import 'package:equatable/equatable.dart';

class WifiPlan extends Equatable {
  const WifiPlan({
    required this.id,
    required this.name,
    required this.price,
    this.description,
    this.currency,
    this.dataCapGb,
    this.durationDays,
    this.isUnlimited = false,
  });

  final int id;
  final String name;
  final num price;
  final String? description;
  final String? currency;
  final num? dataCapGb;
  final int? durationDays;
  final bool isUnlimited;

  factory WifiPlan.fromJson(Map<String, dynamic> json) {
    num? parseNum(dynamic value) {
      if (value == null) return null;
      if (value is num) return value;
      final parsed = num.tryParse(value.toString());
      return parsed;
    }

    bool parseBool(dynamic value) {
      if (value is bool) return value;
      if (value is num) return value != 0;
      if (value is String) {
        final lower = value.toLowerCase();
        return lower == 'true' || lower == '1' || lower == 'yes';
      }
      return false;
    }

    int? parseInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value.toString());
    }

    return WifiPlan(
      id: parseInt(json['id']) ?? 0,
      name: json['name']?.toString() ?? '',
      price: parseNum(json['price']) ?? 0,
      description: json['description']?.toString(),
      currency: json['currency']?.toString(),
      dataCapGb: parseNum(
        json['data_cap_gb'] ?? json['data_cap'] ?? json['data_cap_in_gb'],
      ),
      durationDays: parseInt(json['duration_days'] ?? json['duration']),
      isUnlimited: parseBool(json['is_unlimited'] ?? json['unlimited']),
    );
  }

  WifiPlan copyWith({
    int? id,
    String? name,
    num? price,
    String? description,
    String? currency,
    num? dataCapGb,
    int? durationDays,
    bool? isUnlimited,
  }) {
    return WifiPlan(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      description: description ?? this.description,
      currency: currency ?? this.currency,
      dataCapGb: dataCapGb ?? this.dataCapGb,
      durationDays: durationDays ?? this.durationDays,
      isUnlimited: isUnlimited ?? this.isUnlimited,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      if (description != null) 'description': description,
      if (currency != null) 'currency': currency,
      if (dataCapGb != null) 'data_cap_gb': dataCapGb,
      if (durationDays != null) 'duration_days': durationDays,
      'is_unlimited': isUnlimited,
    };
  }

  @override
  List<Object?> get props => [
    id,
    name,
    price,
    description,
    currency,
    dataCapGb,
    durationDays,
    isUnlimited,
  ];
}