import 'dart:math' as math;

import 'package:marib/data/model/notification_data.dart';
import 'package:marib/data/model/notification_preference.dart';
import 'package:marib/utils/api.dart';

class NotificationPageResult {
  final List<NotificationData> items;
  final bool hasMore;
  final String? nextCursor;
  final int unreadCount;

  const NotificationPageResult({
    required this.items,
    required this.hasMore,
    required this.nextCursor,
    required this.unreadCount,
  });

  NotificationPageResult copyWith({
    List<NotificationData>? items,
    bool? hasMore,
    String? nextCursor,
    int? unreadCount,
  }) {
    return NotificationPageResult(
      items: items ?? this.items,
      hasMore: hasMore ?? this.hasMore,
      nextCursor: nextCursor ?? this.nextCursor,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}

class NotificationsRepository {
  Future<NotificationPageResult> fetchNotifications({
    String? cursor,
    int perPage = 20,
  }) async {
    final Map<String, dynamic> query = <String, dynamic>{
      'per_page': perPage,
      if (cursor != null && cursor.isNotEmpty) 'since': cursor,
    };

    final Map<String, dynamic> response = await Api.get(
      url: Api.notificationsApi,
      queryParameters: query,
    );

    final List<dynamic> rawItems =
        _ensureList(response['data']) ?? _ensureList(response['items']) ?? [];

    final List<NotificationData> notifications = rawItems
        .whereType<Map<String, dynamic>>()
        .map(NotificationData.fromJson)
        .toList();

    final Map<String, dynamic>? pagination =
        _ensureMap(response['pagination']) ??
            _ensureMap(response['data']?['pagination']);

    final bool hasMore = pagination?['has_more'] == true ||
        pagination?['hasMore'] == true ||
        _parseInt(pagination?['has_more']) == 1;

    final String? nextCursor = pagination?['next_since']?.toString() ??
        pagination?['next']?.toString();

    final int unreadCount = _parseInt(response['unread_count']) ??
        _parseInt(response['unreadCount']) ??
        0;

    return NotificationPageResult(
      items: notifications,
      hasMore: hasMore,
      nextCursor: nextCursor,
      unreadCount: math.max(unreadCount, 0),
    );
  }

  Future<int> fetchUnreadCount() async {
    final Map<String, dynamic> response =
        await Api.get(url: Api.notificationsUnreadApi);

    return _parseInt(response['unread_count']) ??
        _parseInt(response['data']) ??
        0;
  }

  Future<int> markNotificationsRead(
    List<String> ids, {
    bool markClicked = false,
  }) async {
    if (ids.isEmpty) {
      return 0;
    }

    final Map<String, dynamic> response = await Api.postJson(
      url: Api.notificationsMarkReadApi,
      data: <String, dynamic>{
        'ids': ids,
        if (markClicked) 'mark_clicked': true,
      },
    );

    return _parseInt(response['unread_count']) ?? 0;
  }

  Future<int> markAllRead() async {
    final Map<String, dynamic> response = await Api.postJson(
      url: Api.notificationsMarkAllReadApi,
      data: const <String, dynamic>{},
    );

    return _parseInt(response['unread_count']) ?? 0;
  }

  Future<List<NotificationPreferenceModel>> fetchPreferences() async {
    final Map<String, dynamic> response = await Api.get(
      url: Api.notificationPreferencesApi,
    );

    final List<dynamic> raw =
        _ensureList(response['data']) ?? const <dynamic>[];

    return raw
        .whereType<Map<String, dynamic>>()
        .map(NotificationPreferenceModel.fromJson)
        .toList();
  }

  Future<List<NotificationPreferenceModel>> updatePreferences(
    List<NotificationPreferenceModel> preferences,
  ) async {
    final Map<String, dynamic> response = await Api.postJson(
      url: Api.notificationPreferencesApi,
      data: <String, dynamic>{
        'preferences': preferences.map((p) => p.toJson()).toList(),
      },
    );

    final List<dynamic> raw =
        _ensureList(response['data']) ?? const <dynamic>[];

    return raw
        .whereType<Map<String, dynamic>>()
        .map(NotificationPreferenceModel.fromJson)
        .toList();
  }

  Future<List<String>> fetchTopics() async {
    final Map<String, dynamic> response =
        await Api.get(url: Api.notificationTopicsApi);
    final List<dynamic> raw =
        _ensureList(response['topics']) ?? _ensureList(response['data']) ?? [];
    return raw.map((dynamic e) => e.toString()).toList();
  }

  Future<List<String>> subscribeTopic(String topic) async {
    final Map<String, dynamic> response = await Api.postJson(
      url: Api.notificationTopicSubscribeApi,
      data: <String, dynamic>{'topic': topic},
    );
    final List<dynamic> raw =
        _ensureList(response['topics']) ?? const <dynamic>[];
    return raw.map((dynamic e) => e.toString()).toList();
  }

  Future<List<String>> unsubscribeTopic(String topic) async {
    final Map<String, dynamic> response = await Api.postJson(
      url: Api.notificationTopicUnsubscribeApi,
      data: <String, dynamic>{'topic': topic},
    );
    final List<dynamic> raw =
        _ensureList(response['topics']) ?? const <dynamic>[];
    return raw.map((dynamic e) => e.toString()).toList();
  }

  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  Map<String, dynamic>? _ensureMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value as Map<dynamic, dynamic>);
    }
    return null;
  }

  List<dynamic>? _ensureList(dynamic value) {
    if (value is List) {
      return value;
    }
    if (value is Iterable) {
      return List<dynamic>.from(value);
    }
    return null;
  }

  Future<NotificationData> fetchNotificationDetail(String id) async {
    final Map<String, dynamic> response = await Api.get(
      url: '${Api.notificationsApi}/$id',
    );

    final Map<String, dynamic>? payload =
        _ensureMap(response['data'] ?? response['notification']) ??
            _ensureMap(response);
    if (payload == null || payload.isEmpty) {
      throw ApiException('notification_not_available');
    }

    return NotificationData.fromJson(payload);
  }
}
