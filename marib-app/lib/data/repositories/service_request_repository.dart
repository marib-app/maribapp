import 'dart:collection';

import 'package:dio/dio.dart';

import 'package:marib/data/model/service_request_model.dart';
import 'package:marib/data/model/service_request_page.dart';
import 'package:marib/utils/api.dart';

class ServiceRequestRepository {
  Future<ServiceRequestModel> createRequest({
    required int serviceId,
    String? serviceUid,
    String? note,
    Map<String, dynamic>? customFields,
    Map<String, dynamic>? attachments,
  }) async {
    final String? normalizedUid =
        serviceUid != null && serviceUid.trim().isNotEmpty
            ? serviceUid.trim()
            : null;
    final String? normalizedNote =
        note != null && note.trim().isNotEmpty ? note.trim() : null;
    dynamic _cloneAttachmentValue(dynamic value) {
      if (value is MultipartFile) {
        return value.clone();
      }
      if (value is List) {
        return value.map(_cloneAttachmentValue).toList();
      }
      return value;
    }

    Map<String, dynamic> _buildPayload() {
      final map = <String, dynamic>{
        'service_id': serviceId,
      };

      if (normalizedUid != null) {
        map['service_uid'] = normalizedUid;
      }
      if (normalizedNote != null) {
        map['note'] = normalizedNote;
      }

      if (customFields != null && customFields.isNotEmpty) {
        customFields.forEach((rawKey, rawValue) {
          final key = rawKey?.toString().trim();
          if (key == null || key.isEmpty) {
            return;
          }
          if (rawValue == null) {
            return;
          }
          map[key] = rawValue;
        });
      }
      if (attachments != null && attachments!.isNotEmpty) {
        attachments!.forEach((rawKey, rawValue) {
          final key = rawKey?.toString().trim();
          if (key == null || key.isEmpty) {
            return;
          }
          if (rawValue == null) {
            return;
          }
          map[key] = _cloneAttachmentValue(rawValue);
        });
      }

      return map;
    }

    final endpoints = <String>[
      Api.serviceRequestsCreateApi,
      Api.serviceRequestsAlternativeCreateApi,
    ];

    ApiHttpException? lastHttpError;

    for (final endpoint in endpoints) {
      try {
        final response = await Api.post(
          url: endpoint,
          parameter: _buildPayload(),
        );
        return _parseResponse(response);
      } on ApiHttpException catch (e) {
        if (e.statusCode == 404 || e.statusCode == 405) {
          lastHttpError = e;
          continue;
        }

        rethrow;
      }
    }

    if (lastHttpError != null) {
      throw lastHttpError;
    }

    throw ApiException('invalid-response');
  }

  ServiceRequestModel _parseResponse(dynamic response) {
    dynamic data = response;
    const possibleKeys = [
      'data',
      'request',
      'service_request',
      'serviceRequest',
      'serviceRequests',
      'service',
      'result',
      'payload',
    ];

    Map<String, dynamic> _ensureStringKeyedMap(Map map) {
      if (map is Map<String, dynamic>) {
        return map;
      }
      return map.map((key, value) => MapEntry(key.toString(), value));
    }

    for (var depth = 0; depth < 6; depth++) {
      if (data is Map) {
        final map = _ensureStringKeyedMap(data);

        String? matchedKey;
        for (final key in possibleKeys) {
          if (map.containsKey(key) && map[key] != null) {
            matchedKey = key;
            break;
          }
        }

        if (matchedKey != null) {
          data = map[matchedKey];
          continue;
        }

        if (map.length == 1) {
          final value = map.values.first;
          if (value is Map || value is List) {
            data = value;
            continue;
          }
        }
      }
      break;
    }

    if (data is List && data.isNotEmpty) {
      data = data.first;
    }
    if (data is Map<String, dynamic>) {
      return ServiceRequestModel.fromJson(data);
    }
    if (data is Map) {
      return ServiceRequestModel.fromJson(
        data.map((key, value) => MapEntry(key.toString(), value)),
      );
    }

    throw ApiException('invalid-response');
  }

  Future<ServiceRequestPage> fetchRequests({
    String status = 'review',
    int page = 1,
    int? perPage,
    int? categoryId,
  }) async {
    final int normalizedPage = page <= 0 ? 1 : page;
    final Map<String, dynamic> query = <String, dynamic>{
      if (status.trim().isNotEmpty) 'status': status.trim(),
      if (categoryId != null) 'category_id': categoryId,
      Api.pageQuery: normalizedPage,
      if (perPage != null && perPage > 0) Api.perPageQuery: perPage,
    };

    final dynamic response = await Api.get(
      url: Api.serviceRequestsCreateApi,
      queryParameters: query,
    );

    final List<Map<String, dynamic>> rawRequests =
        _extractRequestList(response);
    final List<ServiceRequestModel> requests =
        rawRequests.map(ServiceRequestModel.fromJson).toList();

    final Map<String, dynamic> meta = _extractMeta(response);

    final int total = _parseInt(meta['total']) ?? requests.length;
    final int currentPage = _parseInt(meta['current_page']) ?? normalizedPage;
    final int? lastPageCandidate = _parseInt(meta['last_page']);
    final int? perPageFromMeta = _parseInt(meta['per_page']);

    final int resolvedLastPage =
        lastPageCandidate != null && lastPageCandidate >= 1
            ? lastPageCandidate
            : _inferLastPage(
                total: total,
                currentPage: currentPage,
                perPage: perPageFromMeta ?? perPage,
              );

    return ServiceRequestPage(
      requests: requests,
      meta: ServiceRequestPaginationMeta(
        total: total,
        currentPage: currentPage,
        lastPage: resolvedLastPage,
      ),
    );
  }

  List<Map<String, dynamic>> _extractRequestList(dynamic response) {
    final Queue<dynamic> queue = Queue<dynamic>();
    final Set<int> visited = <int>{};
    queue.add(response);

    Map<String, dynamic>? _asMap(dynamic source) {
      if (source is Map<String, dynamic>) {
        return source;
      }
      if (source is Map) {
        return source.map(
          (dynamic key, dynamic value) =>
              MapEntry<String, dynamic>(key.toString(), value),
        );
      }
      return null;
    }

    List<Map<String, dynamic>>? _asMapList(dynamic source) {
      if (source is List) {
        final List<Map<String, dynamic>> mapped = source
            .where((dynamic element) => element is Map)
            .map<Map<String, dynamic>>((dynamic element) {
          return element is Map<String, dynamic>
              ? element
              : Map<String, dynamic>.from(element as Map);
        }).toList();
        if (mapped.isNotEmpty) {
          return mapped;
        }
      }
      return null;
    }

    while (queue.isNotEmpty) {
      final dynamic current = queue.removeFirst();
      if (current == null) {
        continue;
      }
      final int identity = identityHashCode(current);
      if (!visited.add(identity)) {
        continue;
      }

      final List<Map<String, dynamic>>? mappedList = _asMapList(current);
      if (mappedList != null && mappedList.isNotEmpty) {
        return mappedList;
      }

      final Map<String, dynamic>? map = _asMap(current);
      if (map != null) {
        for (final String key in const <String>{
          'data',
          'requests',
          'service_requests',
          'serviceRequests',
          'items',
          'records',
          'results',
          'list',
          'payload',
          'response',
        }) {
          if (map.containsKey(key)) {
            final dynamic nested = map[key];
            final List<Map<String, dynamic>>? nestedList = _asMapList(nested);
            if (nestedList != null && nestedList.isNotEmpty) {
              return nestedList;
            }
            if (nested is Map || nested is List) {
              queue.add(nested);
            }
          }
        }

        for (final dynamic value in map.values) {
          if (value is Map || value is List) {
            queue.add(value);
          }
        }
      }
    }

    return <Map<String, dynamic>>[];
  }

  Map<String, dynamic> _extractMeta(dynamic response) {
    Map<String, dynamic>? _normalizeMap(dynamic value) {
      if (value is Map<String, dynamic>) {
        return value;
      }
      if (value is Map) {
        return value.map(
          (dynamic key, dynamic val) =>
              MapEntry<String, dynamic>(key.toString(), val),
        );
      }
      return null;
    }

    final Queue<dynamic> queue = Queue<dynamic>();
    final Set<int> visited = <int>{};
    queue.add(response);

    while (queue.isNotEmpty) {
      final dynamic current = queue.removeFirst();
      if (current == null) {
        continue;
      }
      final int identity = identityHashCode(current);
      if (!visited.add(identity)) {
        continue;
      }

      if (current is Map || current is Map<String, dynamic>) {
        final Map<String, dynamic>? map = _normalizeMap(current);
        if (map == null) {
          continue;
        }

        final List<dynamic> candidates = <dynamic>[
          map['meta'],
          map['pagination'],
          map['pager'],
          map['links'],
        ];

        for (final dynamic candidate in candidates) {
          final Map<String, dynamic>? normalized = _normalizeMap(candidate);
          if (normalized != null && normalized.isNotEmpty) {
            return normalized;
          }
        }

        final bool hasPaginationHints = map.containsKey('total') ||
            map.containsKey('current_page') ||
            map.containsKey('last_page');
        if (hasPaginationHints) {
          return map;
        }

        for (final dynamic value in map.values) {
          if (value is Map || value is List) {
            queue.add(value);
          }
        }
      } else if (current is List) {
        for (final dynamic value in current) {
          if (value is Map || value is List) {
            queue.add(value);
          }
        }
      }
    }

    return <String, dynamic>{};
  }

  int? _parseInt(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      final String trimmed = value.trim();
      if (trimmed.isEmpty) {
        return null;
      }
      return int.tryParse(trimmed);
    }
    return null;
  }

  int _inferLastPage({
    required int total,
    required int currentPage,
    int? perPage,
  }) {
    if (perPage != null && perPage > 0) {
      final double ratio = total / perPage;
      final int computed = ratio.ceil();
      if (computed >= 1) {
        return computed;
      }
    }
    if (total == 0 && currentPage > 1) {
      return currentPage;
    }
    return currentPage;
  }
}
