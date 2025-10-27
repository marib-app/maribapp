import 'dart:convert';

class ServiceRequestModel {
  final int id;
  final String status;
  final int? serviceId;
  final String? serviceTitle;
  final String? note;
  final DateTime? createdAt;
  final Map<String, dynamic>? payload;
  final String? paymentStatus;
  final int? paymentTransactionId;

  const ServiceRequestModel({
    required this.id,
    required this.status,
    this.serviceId,
    this.serviceTitle,
    this.note,
    this.createdAt,
    this.payload,
    this.paymentStatus,
    this.paymentTransactionId,
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

    int? parseNullableInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String && value.trim().isNotEmpty) {
        return int.tryParse(value.trim());
      }
      return null;
    }

    DateTime? parseDateTime(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      if (value is int) {
        if (value <= 0) return null;
        return DateTime.fromMillisecondsSinceEpoch(
            value * (value < 10000000000 ? 1000 : 1));
      }
      if (value is num) {
        final int asInt = value.toInt();
        if (asInt <= 0) return null;
        return DateTime.fromMillisecondsSinceEpoch(asInt);
      }
      if (value is String) {
        final trimmed = value.trim();
        if (trimmed.isEmpty) return null;
        final normalized = trimmed.replaceAll('T', ' ');
        try {
          return DateTime.parse(trimmed);
        } catch (_) {
          try {
            return DateTime.parse(normalized);
          } catch (_) {
            final int? timestamp = int.tryParse(trimmed);
            if (timestamp != null) {
              final int adjusted =
                  timestamp < 10000000000 ? timestamp * 1000 : timestamp;
              return DateTime.fromMillisecondsSinceEpoch(adjusted);
            }
          }
        }
      }
      return null;
    }

    Map<String, dynamic>? parsePayload(dynamic value) {
      if (value == null) return null;
      if (value is Map<String, dynamic>) {
        return Map<String, dynamic>.from(value);
      }
      if (value is Map) {
        return value.map(
          (dynamic key, dynamic val) => MapEntry(key.toString(), val),
        );
      }
      if (value is String && value.trim().isNotEmpty) {
        try {
          final decoded = jsonDecode(value.trim());
          if (decoded is Map<String, dynamic>) {
            return Map<String, dynamic>.from(decoded);
          }
          if (decoded is Map) {
            return decoded.map(
              (dynamic key, dynamic val) => MapEntry(key.toString(), val),
            );
          }
        } catch (_) {
          return null;
        }
      }
      return null;
    }

    final int? serviceId = parseNullableInt(
      map['service_id'] ?? map['serviceId'],
    );

    String? serviceTitle = parseString(
      map['service_title'] ?? map['serviceTitle'],
    );

    final dynamic serviceRaw = map['service'];
    if (serviceTitle == null && serviceRaw is Map) {
      final Map<String, dynamic> serviceMap = serviceRaw is Map<String, dynamic>
          ? serviceRaw
          : serviceRaw.map(
              (dynamic key, dynamic value) =>
                  MapEntry<String, dynamic>(key.toString(), value),
            );
      serviceTitle = parseString(serviceMap['title'] ?? serviceMap['name']);
    }

    final String? note = parseString(
      map['note'] ?? map['notes'] ?? map['message'] ?? map['remark'],
    );

    final DateTime? createdAt = parseDateTime(
      map['created_at'] ?? map['createdAt'] ?? map['created'],
    );

    final Map<String, dynamic>? payload = parsePayload(
      map['payload'] ?? map['data'] ?? map['fields'],
    );

    final String? paymentStatus = parseString(
      map['payment_status'] ??
          map['paymentStatus'] ??
          map['payment_state'] ??
          (map['payment'] is Map ? map['payment']['status'] : null),
    );

    final int? paymentTransactionId = parseNullableInt(
      map['payment_transaction_id'] ??
          map['paymentTransactionId'] ??
          map['payment_transaction'] ??
          map['transaction_id'] ??
          (map['payment'] is Map ? map['payment']['transaction_id'] : null),
    );

    return ServiceRequestModel(
      id: id,
      status: status,
      serviceId: serviceId,
      serviceTitle: serviceTitle,
      note: note,
      createdAt: createdAt,
      payload: payload,
      paymentStatus: paymentStatus,
      paymentTransactionId: paymentTransactionId,
    );
  }
}
