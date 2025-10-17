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


    num? resolveDataCapGb(Map<String, dynamic> source) {
      num? dataCap = parseNum(
        source['data_cap_gb'] ??
            source['data_cap'] ??
            source['data_cap_in_gb'] ??
            source['data_cap_gigabytes'] ??
            source['data_allowance_gb'],
      );

      final num? dataAllowanceMb = parseNum(source['data_allowance_mb']);
      if (dataCap == null && dataAllowanceMb != null) {
        dataCap = dataAllowanceMb / 1024;
      }

      if (dataCap == null) {
        final dynamic labelCandidate = source['data_allowance_label'] ??
            source['data_cap_label'];
        if (labelCandidate != null) {
          final String label = labelCandidate.toString();
          final RegExpMatch? match =
          RegExp(r'(\d+[\.,]?\d*)').firstMatch(label);
          if (match != null) {
            final String numeric = match.group(1)!.replaceAll(',', '.');
            final num? parsed = num.tryParse(numeric);
            if (parsed != null) {
              if (label.toLowerCase().contains('mb')) {
                dataCap = parsed / 1024;
              } else {
                dataCap = parsed;
              }
            }
          }
          if (label.toLowerCase().contains('unlimit')) {
            dataCap = null;
          }
        }
      }

      return dataCap;
    }

    int? resolveDurationDays(Map<String, dynamic> source) {
      final int? direct = parseInt(
        source['duration_days'] ??
            source['duration'] ??
            source['validity_days'] ??
            source['validity'] ??
            source['validity_in_days'],
      );

      if (direct != null) {
        return direct;
      }

      final int? durationMinutes = parseInt(source['duration_minutes']);
      if (durationMinutes != null && durationMinutes > 0) {
        final double days = durationMinutes / (60 * 24);
        if (days >= 1) {
          return days.ceil();
        }
        return 1;
      }

      return null;
    }

    final num? dataCapGb = resolveDataCapGb(json);
    final bool unlimitedFlag = parseBool(json['is_unlimited'] ?? json['unlimited']);
    final bool labelUnlimited =
    (json['data_allowance_label'] ?? json['data_cap_label'] ?? '')
        .toString()
        .toLowerCase()
        .contains('unlimit');
    final bool resolvedUnlimited = unlimitedFlag || labelUnlimited;


    return WifiPlan(
      id: parseInt(json['id']) ?? 0,
      name: json['name']?.toString() ?? '',
      price: parseNum(json['price']) ?? 0,
      description: json['description']?.toString(),
      currency: json['currency']?.toString(),
      dataCapGb: dataCapGb,
      durationDays: resolveDurationDays(json),
      isUnlimited: resolvedUnlimited,
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