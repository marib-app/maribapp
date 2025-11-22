import 'package:marib/utils/extensions/lib/adaptive_type.dart';

class NotificationData {
  final String id;
  final String? title;
  final String? message;
  final String? body;
  final String? image;
  final String? type;
  final int? sendType;
  final String? customersId;
  final String? itemsId;
  final String? createdAt;
  final String? created;
  final String? deeplink;
  final String? category;
  final Map<String, dynamic> data;
  final DateTime? deliveredAt;
  final DateTime? openedAt;
  final DateTime? clickedAt;
  final Map<String, dynamic>? meta;

  const NotificationData({
    required this.id,
    this.title,
    this.message,
    this.body,
    this.image,
    this.type,
    this.sendType,
    this.customersId,
    this.itemsId,
    this.createdAt,
    this.created,
    this.deeplink,
    this.category,
    this.data = const <String, dynamic>{},
    this.deliveredAt,
    this.openedAt,
    this.clickedAt,
    this.meta,
  });

  factory NotificationData.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> payloadData =
        _ensureMap(json['data']) ?? const <String, dynamic>{};
    final String idValue =
        (json['id'] ?? json['notification_id'] ?? '').toString();
    final String? resolvedTitle =
        json['title']?.toString() ?? json['heading']?.toString();
    final String? resolvedBody =
        json['body']?.toString() ?? json['message']?.toString();
    final String? resolvedMessage =
        json['message']?.toString() ?? json['body']?.toString();
    final String? resolvedImage =
        json['image']?.toString() ?? payloadData['image']?.toString();
    final String? resolvedDeeplink =
        json['deeplink']?.toString() ?? payloadData['deeplink']?.toString();
    final String? resolvedCategory =
        json['category']?.toString() ?? payloadData['category']?.toString();

    return NotificationData(
      id: idValue,
      title: resolvedTitle,
      message: resolvedMessage,
      body: resolvedBody,
      image: resolvedImage,
      type: json['type']?.toString(),
      sendType: Adapter.forceInt(json['send_type']),
      customersId: json['customers_id']?.toString(),
      itemsId: (json['items_id'] ?? json['item_id'])?.toString(),
      createdAt:
          json['created_at']?.toString() ?? json['delivered_at']?.toString(),
      created: json['created']?.toString(),
      deeplink: resolvedDeeplink,
      category: resolvedCategory,
      data: payloadData,
      deliveredAt: _parseDate(json['delivered_at'] ?? json['created_at']),
      openedAt: _parseDate(json['opened_at']),
      clickedAt: _parseDate(json['clicked_at']),
      meta: _ensureMap(json['meta']),
    );
  }

  NotificationData copyWith({
    String? title,
    String? message,
    String? body,
    String? image,
    String? type,
    int? sendType,
    String? customersId,
    String? itemsId,
    String? createdAt,
    String? created,
    String? deeplink,
    Map<String, dynamic>? data,
    DateTime? deliveredAt,
    DateTime? openedAt,
    DateTime? clickedAt,
    Map<String, dynamic>? meta,
    String? category,
  }) {
    return NotificationData(
      id: id,
      title: title ?? this.title,
      message: message ?? this.message,
      body: body ?? this.body,
      image: image ?? this.image,
      type: type ?? this.type,
      sendType: sendType ?? this.sendType,
      customersId: customersId ?? this.customersId,
      itemsId: itemsId ?? this.itemsId,
      createdAt: createdAt ?? this.createdAt,
      created: created ?? this.created,
      deeplink: deeplink ?? this.deeplink,
      category: category ?? this.category,
      data: data ?? Map<String, dynamic>.from(this.data),
      deliveredAt: deliveredAt ?? this.deliveredAt,
      openedAt: openedAt ?? this.openedAt,
      clickedAt: clickedAt ?? this.clickedAt,
      meta: meta ?? this.meta,
    );
  }

  bool get isRead => openedAt != null;

  String? get displayMessage => body ?? message;

  DateTime? get effectiveTimestamp =>
      openedAt ?? deliveredAt ?? clickedAt ?? _parseDate(createdAt);

  NotificationPaymentRequest? get paymentRequest {
    Map<String, dynamic>? resolve(dynamic value) {
      final Map<String, dynamic>? map =
          NotificationPaymentRequest.mapFrom(value);
      if (map == null || map.isEmpty) {
        return null;
      }
      return map;
    }

    Map<String, dynamic>? candidate =
        resolve(meta?['payment_request']) ?? resolve(data['payment_request']);
    if (candidate == null) {
      final Map<String, dynamic>? metaNested =
          resolve(data['meta']) ?? resolve(meta);
      candidate = resolve(metaNested?['payment_request']);
    }
    if (candidate == null || candidate.isEmpty) {
      return null;
    }
    return NotificationPaymentRequest.fromJson(candidate);
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    final String raw = value.toString();
    if (raw.isEmpty) return null;
    try {
      return DateTime.parse(raw).toUtc();
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic>? _ensureMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return null;
  }
}

class NotificationPaymentRequest {
  const NotificationPaymentRequest({
    required this.id,
    required this.amount,
    required this.currency,
    required this.status,
    this.note,
    this.allowedGateways = const <String>[],
    this.transactionId,
    this.transactionReference,
    this.clientNote,
    this.updatedAt,
    this.createdAt,
  });

  final String id;
  final double amount;
  final String currency;
  final String status;
  final String? note;
  final List<String> allowedGateways;
  final String? transactionId;
  final String? transactionReference;
  final String? clientNote;
  final DateTime? updatedAt;
  final DateTime? createdAt;

  bool get isPending => status == 'pending';
  bool get isSubmitted => status == 'submitted';
  bool get isPaid => status == 'paid';

  String get formattedAmount {
    final bool hasFraction = amount % 1 != 0;
    final String value = hasFraction
        ? amount.toStringAsFixed(2)
        : amount.toStringAsFixed(0);
    return '$value $currency';
  }

  NotificationPaymentRequest copyWith({
    double? amount,
    String? currency,
    String? status,
    String? note,
    List<String>? allowedGateways,
    String? transactionId,
    String? transactionReference,
    String? clientNote,
    DateTime? updatedAt,
    DateTime? createdAt,
  }) {
    return NotificationPaymentRequest(
      id: id,
      amount: amount ?? this.amount,
      currency: (currency ?? this.currency).toUpperCase(),
      status: status ?? this.status,
      note: note ?? this.note,
      allowedGateways: allowedGateways ?? this.allowedGateways,
      transactionId: transactionId ?? this.transactionId,
      transactionReference: transactionReference ?? this.transactionReference,
      clientNote: clientNote ?? this.clientNote,
      updatedAt: updatedAt ?? this.updatedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory NotificationPaymentRequest.fromJson(Map<String, dynamic> json) {
    double parseAmount(dynamic value) {
      if (value is num) {
        return value.toDouble();
      }
      if (value is String) {
        final sanitized = value.replaceAll(RegExp(r'[^0-9\.-]'), '');
        return double.tryParse(sanitized) ?? 0;
      }
      return 0;
    }

    List<String> parseGateways(dynamic value) {
      if (value is Iterable) {
        return value
            .map((dynamic entry) => entry?.toString().trim() ?? '')
            .where((element) => element.isNotEmpty)
            .map((e) => e.toLowerCase())
            .toList();
      }
      if (value is String && value.isNotEmpty) {
        return value
            .split(',')
            .map((e) => e.trim().toLowerCase())
            .where((element) => element.isNotEmpty)
            .toList();
      }
      return const <String>[];
    }

    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value);
      }
      return null;
    }

    return NotificationPaymentRequest(
      id: json['id']?.toString() ?? '',
      amount: parseAmount(json['amount']),
      currency: (json['currency']?.toString() ?? 'YER').toUpperCase(),
      status: json['status']?.toString().toLowerCase() ?? 'pending',
      note: json['note']?.toString(),
      allowedGateways: parseGateways(json['allowed_gateways']),
      transactionId: json['transaction_id']?.toString(),
      transactionReference: json['transaction_reference']?.toString(),
      clientNote: json['client_note']?.toString(),
      updatedAt: parseDate(json['updated_at']),
      createdAt: parseDate(json['created_at']),
    );
  }

  static Map<String, dynamic>? mapFrom(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return null;
  }
}
