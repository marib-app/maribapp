import 'dart:convert';

class ServiceRequestModel {
  final int id;
  final String status;
  final String? serviceTitle;
  final DateTime? submittedAt;
  final double? amount;
  final String? currency;
  final dynamic customFields;
  final dynamic attachments;
  final Map<String, dynamic> raw;

  ServiceRequestModel({
    required this.id,
    required this.status,
    required this.raw,
    this.serviceTitle,
    this.submittedAt,
    this.amount,
    this.currency,
    this.customFields,
    this.attachments,
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

    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      if (value is int) {
        return DateTime.fromMillisecondsSinceEpoch(value * 1000, isUtc: true)
            .toLocal();
      }
      if (value is String) {
        if (value.trim().isEmpty) return null;
        try {
          return DateTime.parse(value).toLocal();
        } catch (_) {
          return null;
        }
      }
      return null;
    }

    double? parseAmount(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      if (value is String) {
        final cleaned = value.replaceAll(RegExp(r'[^0-9\.,-]'), '');
        final normalized = cleaned.replaceAll(',', '.');
        return double.tryParse(normalized);
      }
      return null;
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

    String? title = parseString(
      map['service_title'] ??
          map['title'] ??
          map['service'] ??
          map['service_name'] ??
          map['name'],
    );

    title ??= parseString(map['service']?['title'] ?? map['service']?['name']);

    final submittedAt = parseDate(
      map['submitted_at'] ??
          map['created_at'] ??
          map['updated_at'] ??
          map['date'] ??
          map['timestamp'],
    );

    final amount = parseAmount(
      map['amount'] ?? map['price'] ?? map['total'] ?? map['cost'],
    );

    final currency = parseString(
      map['currency'] ??
          map['price_currency'] ??
          map['currency_code'] ??
          map['currency_symbol'],
    );

    final customFields = map['custom_fields'] ?? map['fields'] ?? map['data'];
    final attachments = map['attachments'] ?? map['files'];

    return ServiceRequestModel(
      id: id,
      status: status,
      raw: map,
      serviceTitle: title,
      submittedAt: submittedAt,
      amount: amount,
      currency: currency,
      customFields: customFields,
      attachments: attachments,
    );
  }

  Map<String, dynamic> toBannerData() {
    final Map<String, dynamic> banner = {
      'serviceId': id,
      'serviceTitle': serviceTitle,
      'amount': amount,
      'currency': currency,
      'status': status,
    };
    banner.removeWhere((key, value) => value == null);
    return {...raw, ...banner};
  }

  String? customFieldsJson() {
    final data = customFields;
    if (data == null) return null;
    if (data is String) {
      final trimmed = data.trim();
      if (trimmed.isEmpty || trimmed == '[]' || trimmed == '{}') {
        return null;
      }
      return trimmed;
    }
    try {
      return jsonEncode(data);
    } catch (_) {
      return data.toString();
    }
  }
}
