import 'dart:convert';

import 'package:marib/data/model/custom_field/custom_field_model.dart';

class VerificationPricing {
  const VerificationPricing({
    required this.amount,
    required this.currency,
    required this.durationDays,
  });

  final double amount;
  final String currency;
  final int? durationDays;

  factory VerificationPricing.fromMap(Map<String, dynamic>? map) {
    final duration = map?['duration_days'];
    return VerificationPricing(
      amount: _asDouble(map?['amount']) ?? 0,
      currency: (map?['currency'] ?? 'SAR').toString(),
      durationDays: _asInt(duration),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'amount': amount,
      'currency': currency,
      'duration_days': durationDays,
    };
  }
}

class VerificationOffering {
  const VerificationOffering({
    required this.accountType,
    required this.benefits,
    required this.pricing,
    required this.requiredFields,
    required this.updatedAt,
  });

  final String accountType;
  final List<String> benefits;
  final VerificationPricing pricing;
  final List<VerificationFieldModel> requiredFields;
  final DateTime? updatedAt;

  factory VerificationOffering.fromMap(Map<String, dynamic> map) {
    return VerificationOffering(
      accountType: _normalizeAccountType(map['account_type']) ?? 'individual',
      benefits: _asStringList(map['benefits']),
      pricing: VerificationPricing.fromMap(map['pricing'] as Map<String, dynamic>?),
      requiredFields: (map['required_fields'] as List? ?? const [])
          .map((e) => VerificationFieldModel.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      updatedAt: _parseDate(map['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'account_type': accountType,
      'benefits': benefits,
      'pricing': pricing.toJson(),
      'required_fields': requiredFields.map((e) => e.toMap()).toList(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}

class VerificationMetadata {
  VerificationMetadata({
    required this.updatedAt,
    required this.offerings,
  });

  final DateTime? updatedAt;
  final List<VerificationOffering> offerings;

  factory VerificationMetadata.fromMap(Map<String, dynamic>? map) {
    final offerings = (map?['account_types'] as List? ?? const [])
        .map((e) => VerificationOffering.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
    return VerificationMetadata(
      updatedAt: _parseDate(map?['updated_at']),
      offerings: offerings,
    );
  }

  factory VerificationMetadata.empty() {
    return VerificationMetadata(updatedAt: null, offerings: const []);
  }

  Map<String, dynamic> toJson() {
    return {
      'updated_at': updatedAt?.toIso8601String(),
      'account_types': offerings.map((e) => e.toJson()).toList(),
    };
  }

  VerificationOffering? findForAccountType(String? accountType) {
    final normalized = _normalizeAccountType(accountType) ?? 'individual';
    try {
      return offerings.firstWhere(
        (element) => element.accountType == normalized,
      );
    } catch (_) {
      return offerings.isNotEmpty ? offerings.first : null;
    }
  }

  List<VerificationFieldModel> fieldsFor(String? accountType) {
    return findForAccountType(accountType)?.requiredFields ?? const [];
  }
}

String? _normalizeAccountType(dynamic value) {
  if (value == null) return null;
  final normalized = value.toString().trim().toLowerCase();
  switch (normalized) {
    case '1':
    case 'individual':
    case 'personal':
    case 'customer':
    case 'private':
      return 'individual';
    case '2':
    case 'realestate':
    case 'real_estate':
    case 'property':
      return 'realestate';
    case '3':
    case 'commercial':
    case 'business':
    case 'merchant':
    case 'seller':
      return 'commercial';
    default:
      return null;
  }
}

int? _asInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

double? _asDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}

List<String> _asStringList(dynamic v) {
  if (v == null) return [];
  if (v is List) {
    return v.map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).toList();
  }
  if (v is String && v.trim().isNotEmpty) {
    try {
      final parsed = jsonDecode(v);
      if (parsed is List) {
        return parsed.map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).toList();
      }
    } catch (_) {}
    return [v];
  }
  return [v.toString()];
}
