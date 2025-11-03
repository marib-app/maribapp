import 'package:marib/data/model/data_output.dart';
import 'package:marib/data/model/notification_data.dart';
import 'package:marib/utils/api.dart';

class NotificationsRepository {
  Future<DataOutput<NotificationData>> fetchNotifications({
    required int page,
    int perPage = 20,
    DateTime? since,
  }) async {

    try {
      Map<String, dynamic> parameters = {
        Api.page: page,
        Api.perPageQuery: perPage,

      };
      if (since != null) {
        parameters['since'] = since.toUtc().toIso8601String();
      }

      final Map<String, dynamic> response = await Api.get(
        url: Api.getNotificationListApi,
        queryParameters: parameters,
      );

      final dynamic data = response['data'];
      final List<dynamic> items = _extractItems(data);

      final List<NotificationData> modelList = items
          .whereType<Map<String, dynamic>>()
          .map(NotificationData.fromJson)
          .toList();

      final int total = _extractTotal(data, modelList.length);

      return DataOutput(total: total, modelList: modelList);
    } catch (e) {
      rethrow;
    }
  }


  List<dynamic> _extractItems(dynamic data) {
    if (data is List) {
      return data;
    }

    if (data is Map<String, dynamic>) {
      final dynamic primary = data['data'] ?? data['items'];

      if (primary is List) {
        return primary;
      }

      if (primary is Iterable) {
        return List<dynamic>.from(primary);
      }

      if (primary is Map<String, dynamic>) {
        final dynamic nested = primary['data'] ?? primary['items'];
        if (nested is List) {
          return nested;
        }
        if (nested is Iterable) {
          return List<dynamic>.from(nested);
        }
      }
    }

    return const <dynamic>[];
  }

  int _extractTotal(dynamic data, int fallback) {
    int? parseInt(dynamic value) {
      if (value is int) {
        return value;
      }
      if (value is String) {
        return int.tryParse(value);
      }
      if (value is num) {
        return value.toInt();
      }
      return null;
    }

    if (data is Map<String, dynamic>) {
      final int? direct = parseInt(data['total']);
      if (direct != null) {
        return direct;
      }

      final dynamic meta = data['meta'];
      if (meta is Map<String, dynamic>) {
        final int? metaTotal = parseInt(meta['total']);
        if (metaTotal != null) {
          return metaTotal;
        }
      }

      final dynamic pagination = data['pagination'];
      if (pagination is Map<String, dynamic>) {
        final int? paginationTotal = parseInt(pagination['total']);
        if (paginationTotal != null) {
          return paginationTotal;
        }
      }
    }

    return fallback;
  }

}
