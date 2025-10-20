import 'dart:convert';

class ServiceRequestModel {
  final int id;
  final String status;

  const ServiceRequestModel({
    required this.id,
    required this.status,
  });

  factory ServiceRequestModel.fromJson(Map<String, dynamic> json) {
    final map = Map<String, dynamic>.from(json);

    int parseId(dynamic value) {
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) {
        final parsed = int.tryParse(value);
        if (parsed != null) return parsed;
      }
      return DateTime.now().millisecondsSinceEpoch;
    }

    String? parseString(dynamic value) {
      if (value == null) return null;
      final s = value.toString().trim();
      return s.isEmpty ? null : s;
    }

    String status = parseString(
          map['status'] ??
              map['state'] ??
              map['request_status'] ??
              map['current_status'],
        )?.toLowerCase() ??
        'review';

    final id = parseId(
      map['id'] ?? map['request_id'] ?? map['service_request_id'],
    );

    return ServiceRequestModel(
      id: id,
      status: status,
    );
  }
}
