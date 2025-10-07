import 'dart:collection';

import 'package:marib/data/model/classified_model.dart';
import 'package:marib/data/model/data_output.dart';
import 'package:marib/utils/api.dart';

class MyServicesRepository {
  Future<DataOutput<ClassifiedModel>> fetchMyServices({
    int page = 1,
    String? status,
  }) async {
    final Map<String, dynamic> query = <String, dynamic>{
      if (page > 0) Api.page: page,
      if (status != null && status.trim().isNotEmpty) 'status': status.trim(),
    };

    final Map<String, dynamic> response =
    await Api.get(url: Api.myServicesApi, queryParameters: query);

    final List<Map<String, dynamic>> rawServices =
    _extractServiceList(response);
    final List<ClassifiedModel> services = rawServices
        .map((Map<String, dynamic> e) => ClassifiedModel.fromJson(e))
        .toList();

    final int total = _extractTotal(response) ?? services.length;
    final int currentPage = _extractPage(response) ?? page;

    return DataOutput<ClassifiedModel>(
      total: total,
      modelList: services,
      page: currentPage,
    );
  }

  Future<ClassifiedModel> updateService(
      int serviceId,
      Map<String, dynamic> fields,
      ) async {
    final Map<String, dynamic> sanitized =
    _sanitizeUpdatePayload(fields)..['_method'] = 'PATCH';

    final Map<String, dynamic> response = await Api.post(
      url: Api.myServiceManageApi(serviceId),
      parameter: sanitized,
    );

    final Map<String, dynamic>? raw = _extractSingleService(response);
    if (raw == null) {
      throw ApiException('invalid-response');
    }
    return ClassifiedModel.fromJson(raw);
  }

  Future<void> deleteService(int serviceId) async {
    try {
      await Api.delete(url: Api.myServiceManageApi(serviceId));
      return;
    } on ApiHttpException catch (error) {
      if (error.statusCode == 405 || error.statusCode == 404) {
        await Api.post(
          url: Api.myServiceManageApi(serviceId),
          parameter: <String, dynamic>{'_method': 'DELETE'},
        );
        return;
      }
      rethrow;
    }
  }

  List<Map<String, dynamic>> _extractServiceList(dynamic source) {
    final Queue<dynamic> queue = Queue<dynamic>()..add(source);
    final Set<int> visited = <int>{};

    List<Map<String, dynamic>>? _asMapList(List<dynamic> input) {
      final List<Map<String, dynamic>> mapped = input
          .where((dynamic element) => element is Map)
          .map<Map<String, dynamic>>(
              (dynamic e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (mapped.isNotEmpty) {
        return mapped;
      }
      return null;
    }

    while (queue.isNotEmpty) {
      final dynamic current = queue.removeFirst();
      if (current == null) continue;
      if (visited.contains(identityHashCode(current))) {
        continue;
      }
      visited.add(identityHashCode(current));

      if (current is List) {
        final List<Map<String, dynamic>>? mapped = _asMapList(current);
        if (mapped != null && mapped.isNotEmpty) {
          return mapped;
        }
        for (final dynamic value in current) {
          if (value is Map || value is List) queue.add(value);
        }
        continue;
      }

      if (current is Map) {
        final Map<String, dynamic> map =
        current is Map<String, dynamic>
            ? current
            : current.map(
              (dynamic key, dynamic value) =>
              MapEntry<String, dynamic>(key.toString(), value),
        );

        for (final String key in <String>{
          'data',
          'services',
          'items',
          'records',
          'results',
          'list',
          'payload',
          'response',
        }) {
          if (map.containsKey(key)) {
            queue.add(map[key]);
          }
        }

        for (final dynamic value in map.values) {
          if (value is Map || value is List) queue.add(value);
        }
      }
    }

    return <Map<String, dynamic>>[];
  }

  Map<String, dynamic>? _extractSingleService(dynamic source) {
    final Queue<dynamic> queue = Queue<dynamic>()..add(source);
    final Set<int> visited = <int>{};

    bool _looksLikeService(Map<dynamic, dynamic> map) {
      final Set<String> keys =
      map.keys.map((dynamic e) => e.toString().toLowerCase()).toSet();
      if (!keys.contains('id')) return false;
      if (keys.contains('service_uid') || keys.contains('serviceuid')) {
        return true;
      }
      if (keys.contains('service_fields') || keys.contains('service_fields_schema')) {
        return true;
      }
      if (keys.contains('title') || keys.contains('name')) {
        return keys.contains('status') || keys.contains('is_active');
      }
      return false;
    }

    while (queue.isNotEmpty) {
      final dynamic current = queue.removeFirst();
      if (current == null) continue;
      if (visited.contains(identityHashCode(current))) {
        continue;
      }
      visited.add(identityHashCode(current));

      if (current is Map) {
        final Map<dynamic, dynamic> rawMap = current;
        if (_looksLikeService(rawMap)) {
          return Map<String, dynamic>.from(rawMap);
        }

        for (final String key in <String>{
          'data',
          'service',
          'payload',
          'result',
          'record',
          'item',
        }) {
          if (rawMap.containsKey(key)) queue.add(rawMap[key]);
        }

        for (final dynamic value in rawMap.values) {
          if (value is Map || value is List) queue.add(value);
        }
      } else if (current is List) {
        for (final dynamic element in current) {
          if (element is Map && _looksLikeService(element)) {
            return Map<String, dynamic>.from(element);
          }
          if (element is Map || element is List) queue.add(element);
        }
      }
    }

    return null;
  }

  Map<String, dynamic> _sanitizeUpdatePayload(Map<String, dynamic> fields) {
    final Map<String, dynamic> sanitized = <String, dynamic>{};
    bool? active;
    String? expiryIso;

    bool? _asBool(dynamic value) {
      if (value == null) return null;
      if (value is bool) return value;
      if (value is num) return value != 0;
      if (value is String) {
        final String normalized = value.trim().toLowerCase();
        if (normalized.isEmpty) return null;
        if (<String>{'1', 'true', 'yes', 'active', 'on'}.contains(normalized)) {
          return true;
        }
        if (<String>{'0', 'false', 'no', 'inactive', 'off'}.contains(normalized)) {
          return false;
        }
      }
      return null;
    }

    String? _asDate(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value.toIso8601String();
      if (value is String) {
        final String trimmed = value.trim();
        if (trimmed.isEmpty) return null;
        final DateTime? parsed = DateTime.tryParse(trimmed);
        return parsed?.toIso8601String() ?? trimmed;
      }
      return null;
    }

    fields.forEach((String key, dynamic value) {
      if (value == null) return;
      final String normalizedKey = key.trim().toLowerCase();
      switch (normalizedKey) {
        case 'status':
        case 'is_active':
        case 'active':
        case 'state':
          active ??= _asBool(value);
          break;
        case 'expiry_at':
        case 'expires_at':
        case 'expiry_date':
        case 'expired_at':
        case 'expire_at':
          expiryIso ??= _asDate(value);
          break;
        default:
          sanitized[key] = value;
      }
    });

    if (active != null) {
      final bool isActive = active!;
      sanitized['status'] = isActive ? 'active' : 'inactive';
      sanitized['is_active'] = isActive ? 1 : 0;
      sanitized['active'] = isActive ? 1 : 0;
    }

    if (expiryIso != null) {
      sanitized['expiry_at'] = expiryIso;
      sanitized['expires_at'] = expiryIso;
      sanitized['expiry_date'] = expiryIso;
      sanitized['expired_at'] = expiryIso;
    }

    return sanitized;
  }

  int? _extractTotal(Map<String, dynamic> response) {
    final Queue<dynamic> queue = Queue<dynamic>()..add(response);
    final Set<int> visited = <int>{};

    int? _asInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value);
      return null;
    }

    while (queue.isNotEmpty) {
      final dynamic current = queue.removeFirst();
      if (current == null) continue;
      if (visited.contains(identityHashCode(current))) {
        continue;
      }
      visited.add(identityHashCode(current));

      if (current is Map) {
        for (final String key in <String>{
          'total',
          'total_count',
          'count',
          'records_total',
        }) {
          final int? parsed = _asInt(current[key]);
          if (parsed != null) return parsed;
        }
        for (final dynamic value in current.values) {
          if (value is Map || value is List) queue.add(value);
        }
      } else if (current is List) {
        for (final dynamic value in current) {
          if (value is Map || value is List) queue.add(value);
        }
      }
    }

    return null;
  }

  int? _extractPage(Map<String, dynamic> response) {
    final Queue<dynamic> queue = Queue<dynamic>()..add(response);
    final Set<int> visited = <int>{};

    int? _asInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value);
      return null;
    }

    while (queue.isNotEmpty) {
      final dynamic current = queue.removeFirst();
      if (current == null) continue;
      if (visited.contains(identityHashCode(current))) {
        continue;
      }
      visited.add(identityHashCode(current));

      if (current is Map) {
        for (final String key in <String>{
          'current_page',
          'page',
          'currentPage',
        }) {
          final int? parsed = _asInt(current[key]);
          if (parsed != null) return parsed;
        }
        for (final dynamic value in current.values) {
          if (value is Map || value is List) queue.add(value);
        }
      } else if (current is List) {
        for (final dynamic value in current) {
          if (value is Map || value is List) queue.add(value);
        }
      }
    }

    return null;
  }
}