import 'dart:convert';

class AdDraftModel {
  const AdDraftModel({
    this.id,
    this.currentStep,
    required this.payload,
    required this.stepPayload,
    required this.temporaryMedia,
    this.createdAt,
    this.updatedAt,
  });

  factory AdDraftModel.fromJson(Map<String, dynamic> json) {
    return AdDraftModel(
      id: _stringOrNull(json['id']),
      currentStep: _stringOrNull(json['current_step']),
      payload: _mapOf(json['payload']),
      stepPayload: _mapOf(json['step_payload']),
      temporaryMedia: _mapOf(json['temporary_media']),
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
    );
  }

  factory AdDraftModel.fromPending(Map<String, dynamic> json) {
    return AdDraftModel(
      id: _stringOrNull(json['draft_id']),
      currentStep: _stringOrNull(json['current_step']),
      payload: _mapOf(json['payload']),
      stepPayload: _mapOf(json['step_payload']),
      temporaryMedia: _mapOf(json['temporary_media']),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  final String? id;
  final String? currentStep;
  final Map<String, dynamic> payload;
  final Map<String, dynamic> stepPayload;
  final Map<String, dynamic> temporaryMedia;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (id != null) 'id': id,
      'current_step': currentStep,
      'payload': payload,
      'step_payload': stepPayload,
      'temporary_media': temporaryMedia,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  static Map<String, dynamic> _mapOf(dynamic source) {
    if (source is Map<String, dynamic>) {
      return Map<String, dynamic>.from(source);
    }
    if (source is Map) {
      return Map<String, dynamic>.from(source as Map);
    }
    if (source is String && source.trim().isNotEmpty) {
      try {
        final dynamic decoded = jsonDecode(source) as Object?;
        if (decoded is Map<String, dynamic>) {
          return Map<String, dynamic>.from(decoded);
        }
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded as Map);
        }
      } catch (_) {
        return <String, dynamic>{};
      }
    }
    return <String, dynamic>{};
  }

  static String? _stringOrNull(dynamic value) {
    if (value == null) {
      return null;
    }
    final String candidate = value.toString();
    return candidate.isEmpty ? null : candidate;
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is DateTime) {
      return value;
    }
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}