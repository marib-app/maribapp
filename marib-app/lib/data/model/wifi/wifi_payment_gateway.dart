import 'package:equatable/equatable.dart';

class WifiPaymentGateway extends Equatable {
  const WifiPaymentGateway({
    required this.id,
    required this.name,
    this.description,
    this.isWallet = false,
    this.isDefault = false,
    this.metadata = const <String, dynamic>{},
  });

  final String id;
  final String name;
  final String? description;
  final bool isWallet;
  final bool isDefault;
  final Map<String, dynamic> metadata;

  factory WifiPaymentGateway.fromJson(Map<String, dynamic> json) {
    bool parseBool(dynamic value) {
      if (value is bool) return value;
      if (value is num) return value != 0;
      if (value is String) {
        final lower = value.toLowerCase();
        return lower == 'true' || lower == '1' || lower == 'yes';
      }
      return false;
    }

    String resolveName(Map<String, dynamic> source) {
      final dynamic nameCandidate = source['name'] ??
          source['title'] ??
          source['label'] ??
          source['display_name'];
      if (nameCandidate == null) {
        return (source['id'] ?? source['code'] ?? '').toString();
      }
      return nameCandidate.toString();
    }

    Map<String, dynamic> resolveMetadata(dynamic value) {
      if (value is Map<String, dynamic>) {
        return value;
      }
      if (value is Map) {
        return Map<String, dynamic>.from(value);
      }
      return const <String, dynamic>{};
    }

    final Map<String, dynamic> metadata = {
      ...resolveMetadata(json['meta']),
      ...resolveMetadata(json['metadata']),
      ...resolveMetadata(json['extras']),
    };

    final String id =
        (json['id'] ?? json['code'] ?? json['slug'] ?? '').toString().trim();

    final String lowerId = id.toLowerCase();
    final String type = (json['type'] ?? '').toString().toLowerCase();

    final bool isWallet = parseBool(json['is_wallet']) ||
        lowerId == 'wallet' ||
        type == 'wallet' ||
        metadata['is_wallet'] == true;

    final bool isDefault = parseBool(json['is_default']) ||
        parseBool(json['default']) ||
        metadata['default'] == true;

    return WifiPaymentGateway(
      id: id.isEmpty ? (json['gateway'] ?? 'wallet').toString() : id,
      name: resolveName(json),
      description: json['description']?.toString(),
      isWallet: isWallet,
      isDefault: isDefault,
      metadata: metadata,
    );
  }

  WifiPaymentGateway copyWith({
    String? id,
    String? name,
    String? description,
    bool? isWallet,
    bool? isDefault,
    Map<String, dynamic>? metadata,
  }) {
    return WifiPaymentGateway(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      isWallet: isWallet ?? this.isWallet,
      isDefault: isDefault ?? this.isDefault,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  List<Object?> get props =>
      [id, name, description, isWallet, isDefault, metadata];
}
