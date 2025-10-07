import 'dart:convert';

import 'package:marib/data/model/service_request_model.dart';
import 'package:marib/utils/api.dart';

class ServiceRequestRepository {
  Future<List<ServiceRequestModel>> fetchRequests({
    required String status,
    int? categoryId,
  }) async {
    try {
      final response = await Api.get(
        url: Api.serviceRequestsIndexApi,
        queryParameters: {
          'status': status,
          if (categoryId != null) 'category_id': categoryId.toString(),
        },
      );

      dynamic data = response['data'] ?? response['requests'] ?? response;
      if (data is Map && data.containsKey('data')) {
        data = data['data'];
      }

      final List list = data is List
          ? data
          : data is Map
          ? data.values.whereType<List>().expand((e) => e).toList()
          : const [];

      return list
          .whereType<Map>()
          .map((e) => ServiceRequestModel.fromJson(e.cast<String, dynamic>()))
          .toList();
    } on ApiHttpException catch (e) {
      if (e.statusCode == 404 || e.statusCode == 405) {
        return const <ServiceRequestModel>[];
      }
      rethrow;
    } catch (e) {
      rethrow;
    }
  }

  Future<ServiceRequestModel> createRequest({
    required int serviceId,
    String? serviceUid,
    String? note,

    Map<String, dynamic>? customFields,
    Map<String, dynamic>? attachments,
  }) async {

    String? _encodeCustomFields(Map<String, dynamic>? fields) {
      if (fields == null || fields.isEmpty) {
        return null;
      }
      final normalized = <String, dynamic>{};
      fields.forEach((key, value) {
        normalized[key.toString()] = value;
      });
      return jsonEncode(normalized);
    }

    final String? normalizedUid =
    serviceUid != null && serviceUid.trim().isNotEmpty ? serviceUid.trim() : null;
    final String? normalizedNote =
    note != null && note.trim().isNotEmpty ? note.trim() : null;
    final String? encodedCustomFields = _encodeCustomFields(customFields);

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

      if (encodedCustomFields != null) {
        map['custom_fields'] = encodedCustomFields;
      }
      if (attachments != null && attachments!.isNotEmpty) {
        map.addAll(attachments!);
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