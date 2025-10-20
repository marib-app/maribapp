import 'package:dio/dio.dart';

import 'package:marib/data/model/service_request_model.dart';
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
}
