import 'package:collection/collection.dart';

class WalletFilter {
  const WalletFilter({
    required this.value,
    required this.label,
    this.metadata = const {},
    this.isDefault = false,
  });

  final String value;
  final String label;
  final Map<String, dynamic> metadata;
  final bool isDefault;

  factory WalletFilter.fromJson(Map<String, dynamic> json) {
    final rawValue = json['value'] ?? json['key'] ?? json['id'] ?? '';
    final rawLabel = json['label'] ?? json['title'] ?? json['name'] ?? rawValue;
    return WalletFilter(
      value: rawValue.toString(),
      label: rawLabel.toString(),
      metadata: Map<String, dynamic>.from(json['meta'] ?? json['metadata'] ?? {}),
      isDefault: _parseBool(json['default'] ?? json['is_default']),
    );
  }

  static bool _parseBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      switch (value.toLowerCase()) {
        case '1':
        case 'true':
        case 'yes':
          return true;
      }
    }
    return false;
  }

  WalletFilter copyWith({
    String? value,
    String? label,
    Map<String, dynamic>? metadata,
    bool? isDefault,
  }) {
    return WalletFilter(
      value: value ?? this.value,
      label: label ?? this.label,
      metadata: metadata ?? this.metadata,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  static List<WalletFilter> fromResponse(dynamic response) {
    if (response == null) {
      return const [];
    }

    if (response is List) {
      return response
          .whereType<dynamic>()
          .map((e) {
        if (e is WalletFilter) {
          return e;
        }
        if (e is Map<String, dynamic>) {
          return WalletFilter.fromJson(e);
        }
        if (e is Map) {
          return WalletFilter.fromJson(Map<String, dynamic>.from(e as Map));
        }
        final value = e.toString();
        return WalletFilter(value: value, label: value);
      })
          .toList();
    }

    if (response is Map) {
      final map = Map<String, dynamic>.from(response as Map);
      final candidates = [
        map['filters'],
        map['available_filters'],
        map['available'],
        map['data'],
        map['options'],
      ].whereNotNull().firstOrNull;
      if (candidates != null) {
        return fromResponse(candidates);
      }
      if (map.containsKey('value') || map.containsKey('label')) {
        return [WalletFilter.fromJson(map)];
      }
    }

    return const [];
  }
}