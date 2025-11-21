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
