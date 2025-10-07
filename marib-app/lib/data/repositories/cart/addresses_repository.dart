import 'dart:async';
import 'package:dio/dio.dart';

import 'package:marib/data/repositories/cart/checkout_repository.dart';
import 'package:marib/data/services/cart_shipping_quote_service.dart';
import 'package:marib/utils/api.dart';


typedef _ApiPostHandler = Future<Map<String, dynamic>> Function({
required String url,
dynamic parameter,
Options? options,
bool? useBaseUrl,
Map<String, dynamic>? extraHeaders,
});

typedef _ApiGetHandler = Future<Map<String, dynamic>> Function({
required String url,
Map<String, dynamic>? queryParameters,
bool? useBaseUrl,
});

typedef _ApiDeleteHandler = Future<Map<String, dynamic>> Function({
required String url,
Map<String, dynamic>? queryParameters,
bool? useBaseUrl,
});

typedef _ApiJsonRequestHandler = Future<Map<String, dynamic>> Function({
required String url,
String method,
Map<String, dynamic>? data,
Options? options,
bool? useBaseUrl,
Map<String, dynamic>? extraHeaders,
});



class AddressesRepository {
  AddressesRepository({
    CartShippingQuoteService? shippingQuoteService,
    CheckoutRepository? checkoutRepository,

    _ApiPostHandler? apiPostHandler,
    _ApiGetHandler? apiGetHandler,
    _ApiDeleteHandler? apiDeleteHandler,
    _ApiJsonRequestHandler? apiJsonRequestHandler,

    Future<void> Function()? onAddressesMutated,



  })  : _shippingQuoteService =
      shippingQuoteService ?? CartShippingQuoteService.shared,
        _checkoutRepository = checkoutRepository ??
            CheckoutRepository(
              shippingQuoteService:
              shippingQuoteService ?? CartShippingQuoteService.shared,
            ),
        _apiPostHandler = apiPostHandler ?? Api.post,
        _apiGetHandler = apiGetHandler ?? Api.get,
        _apiDeleteHandler = apiDeleteHandler ?? Api.delete,
        _apiJsonRequestHandler = apiJsonRequestHandler ?? Api.requestJson,

      _onAddressesMutated = onAddressesMutated;

  final CartShippingQuoteService _shippingQuoteService;
  final CheckoutRepository _checkoutRepository;
  final _ApiPostHandler _apiPostHandler;
  final _ApiGetHandler _apiGetHandler;
  final _ApiDeleteHandler _apiDeleteHandler;
  final Future<void> Function()? _onAddressesMutated;
  final _ApiJsonRequestHandler _apiJsonRequestHandler;



  Future<List<Map<String, dynamic>>> fetchAddresses() async {
    final Map<String, dynamic> response = await _apiGetHandler(
      url: _addressesEndpoint,
      useBaseUrl: true,
    );
    return _parseAddresses(response);
  }

  Future<List<Map<String, dynamic>>> createAddress(
      Map<String, dynamic> payload) {
    final Map<String, dynamic> sanitized = _preparePayload(payload);
    return _mutate(() => _requestAddress(
      endpoint: _addressesEndpoint,
      method: 'POST',
      payload: sanitized,
    ));
  }

  Future<List<Map<String, dynamic>>> updateAddress(
      int id,
      Map<String, dynamic> payload,
      ) {
    final Map<String, dynamic> sanitized = _preparePayload(payload);
    return _mutate(() => _requestAddress(
      endpoint: '$_addressesEndpoint/$id',
      method: 'PATCH',
      payload: sanitized,
      allowPutFallback: true,
    ));
  }

  Future<List<Map<String, dynamic>>> deleteAddress(int id) {
    return _mutate(() => _apiDeleteHandler(
      url: '$_addressesEndpoint/$id',
      useBaseUrl: true,
    ));
  }

  Future<List<Map<String, dynamic>>> markDefault(int id) {
    return _mutate(() => _requestAddress(
      endpoint: '$_addressesEndpoint/$id/default',
      method: 'PATCH',
      payload: const <String, dynamic>{},
      allowPutFallback: true,
    ));
  }

  Future<List<Map<String, dynamic>>> _mutate(
      Future<void> Function() mutation) async {
    await mutation();

    final List<Map<String, dynamic>> addresses = await fetchAddresses();
    _notifyAddressMutation();
    return addresses;
  }

  void _notifyAddressMutation() {
    _shippingQuoteService.invalidateCache();

    final Future<void> Function()? callback = _onAddressesMutated;
    if (callback != null) {
      unawaited(callback().catchError((_) {}));
    }

    unawaited(_checkoutRepository.fetchCheckout().catchError((_) {}));
  }

  Map<String, dynamic> _preparePayload(Map<String, dynamic> payload) {
    final Map<String, dynamic> source = <String, dynamic>{};

    void merge(dynamic value) {
      final Map<String, dynamic>? map = _mapify(value);
      if (map == null) {
        return;
      }
      map.forEach((String key, dynamic entry) {
        if (entry == null) {
          return;
        }
        source.putIfAbsent(key, () => entry);
      });

    }

    merge(payload);
    merge(payload['location']);
    merge(payload['coordinates']);
    merge(payload['geo']);

    String? resolveString(List<String> keys, {int? maxLength}) {
      for (final String key in keys) {
        final String? value = _asString(source[key]);
        if (value != null) {
          if (maxLength != null && value.length > maxLength) {
            return value.substring(0, maxLength);
          }
          return value;
        }
      }
      return null;
    }

    double? resolveDouble(List<String> keys) {
      for (final String key in keys) {
        final double? value = _asDouble(source[key]);
        if (value != null) {
          return value;
        }
      }
      return null;
    }


    bool? resolveBool(List<String> keys) {
      for (final String key in keys) {
        final bool? value = _asBool(source[key]);
        if (value != null) {
          return value;
        }
      }
      return null;
    }
    double _resolveDistanceKm() {
      for (final String key in const <String>['distance_km', 'distanceKm', 'distance', 'radius']) {
        final double? candidate = _roundDistance(source[key]);
        if (candidate != null) {
          return candidate < 0 ? 0.0 : candidate;
        }
      }
      return 0.0;
    }

    final Map<String, dynamic> sanitized = <String, dynamic>{};

    final String? label = resolveString(
      const <String>['label', 'address', 'full_address', 'fullAddress', 'street', 'title'],
      maxLength: 100,
    );
    if (label != null) {
      sanitized['label'] = label;
    }

    final String? phone = resolveString(
      const <String>['phone', 'phone_number', 'mobile', 'contact_phone', 'contactPhone'],
      maxLength: 50,
    );
    if (phone != null) {
      sanitized['phone'] = phone;
    }

    final String? name = resolveString(
      const <String>['name', 'contact_name', 'contactName', 'recipient_name'],
      maxLength: 100,
    );
    if (name != null) {
      sanitized['name'] = name;
    }
    final double? latitude = resolveDouble(
      const <String>['latitude', 'lat', 'geo_lat', 'geoLat'],
    );
    if (latitude != null) {
      sanitized['latitude'] = latitude;
    }

    final double? longitude = resolveDouble(
      const <String>['longitude', 'lng', 'geo_lng', 'geoLng'],
    );
    if (longitude != null) {
      sanitized['longitude'] = longitude;
    }
    sanitized['distance_km'] = _resolveDistanceKm();




    final int? areaId = () {
      final dynamic direct = source['area_id'] ?? source['areaId'] ?? source['areaID'];
      final int? parsedDirect = _asInt(direct);
      if (parsedDirect != null) {
        return parsedDirect;
      }
      final Map<String, dynamic>? directMap = _mapify(direct);
      if (directMap != null) {
        final int? fromMap = _asInt(
          directMap['id'] ?? directMap['area_id'] ?? directMap['areaId'],
        );
        if (fromMap != null) {
          return fromMap;
        }
      }
      final Map<String, dynamic>? areaMap =
          _mapify(source['area']) ?? _mapify(source['district']);
      if (areaMap != null) {
        return _asInt(areaMap['id'] ?? areaMap['area_id'] ?? areaMap['areaId']);
      }
      return null;
    }();
    if (areaId != null) {
      sanitized['area_id'] = areaId;
    }
    final String? street = resolveString(
      const <String>['street', 'street_name', 'streetName', 'address_line_1', 'addressLine1'],
      maxLength: 150,
    );
    if (street != null) {
      sanitized['street'] = street;
    }


    final String? building = resolveString(
      const <String>['building', 'building_name', 'buildingName', 'details'],
      maxLength: 150,
    );
    if (building != null) {
      sanitized['building'] = building;
    }

    final String? note = resolveString(
      const <String>['note', 'notes', 'description', 'instructions'],
      maxLength: 255,
    );
    if (note != null) {
      sanitized['note'] = note;
    }

    final bool? isDefault = resolveBool(
      const <String>['is_default', 'isDefault', 'default'],
    );
    if (isDefault != null) {
      sanitized['is_default'] = isDefault;
    }

    return sanitized;

  }

  Future<void> _requestAddress({
    required String endpoint,
    required String method,
    required Map<String, dynamic> payload,
    bool allowPutFallback = false,
  }) async {

    try {
      await _apiJsonRequestHandler(
        url: endpoint,
        method: method,
        data: payload,
        useBaseUrl: true,
      );
      return;
    } on ApiHttpException catch (error) {
      if (allowPutFallback && (error.statusCode == 405 || error.statusCode == 404)) {
        await _requestAddress(
          endpoint: endpoint,
          method: 'PUT',
          payload: payload,
          allowPutFallback: false,
        );
        return;
      }
      if (error.statusCode == 415) {
        await _sendMultipartRequest(
          endpoint: endpoint,
          method: method,
          payload: payload,
          allowPutFallback: allowPutFallback,
        );
        return;
      }
      throw error;
    }
  }


  Future<void> _sendMultipartRequest({
    required String endpoint,
    required String method,
    required Map<String, dynamic> payload,
    bool allowPutFallback = false,
  }) async {
    final Map<String, dynamic> formPayload = Map<String, dynamic>.from(payload);
    if (method != 'POST') {
      formPayload['_method'] = method;
    }

    try {
      await _apiPostHandler(
        url: endpoint,
        parameter: formPayload,
        useBaseUrl: true,
      );
    } on ApiHttpException catch (error) {
      if (allowPutFallback &&
          method == 'PATCH' &&
          (error.statusCode == 405 || error.statusCode == 404)) {
        final Map<String, dynamic> putPayload = Map<String, dynamic>.from(payload)
          ..['_method'] = 'PUT';
        await _apiPostHandler(
          url: endpoint,
          parameter: putPayload,
          useBaseUrl: true,
        );
        return;
      }
      throw error;
    }
  }

  List<Map<String, dynamic>> _parseAddresses(Map<String, dynamic> response) {
    final List<dynamic>? rawAddresses = _extractAddressList(response);
    if (rawAddresses == null) {
      return <Map<String, dynamic>>[];
    }

    return rawAddresses
        .map<Map<String, dynamic>>((dynamic item) {
      if (item is Map<String, dynamic>) {
        return _normaliseAddress(item);
      }
      if (item is Map) {
        return _normaliseAddress(Map<String, dynamic>.from(item));
      }
      return _normaliseAddress(<String, dynamic>{'label': item});
    })
        .where((Map<String, dynamic> element) => element.isNotEmpty)
        .toList();
  }

  List<dynamic>? _extractAddressList(
      dynamic payload, {
        Set<int>? visited,
        String? keyHint,
      }) {
    final Set<int> seen = visited ?? <int>{};

    if (payload == null) {
      return null;
    }    if (payload is List<dynamic>) {
      if (_isAddressListCandidate(payload, keyHint: keyHint)) {
        return payload;
      }
      for (final dynamic element in payload) {
        final List<dynamic>? nested = _extractAddressList(
          element,
          visited: seen,
          keyHint: keyHint,
        );
        if (nested != null) {
          return nested;
        }
      }
      return null;
    }

    if (payload is Map || payload is Map<String, dynamic>) {
      final int identity = identityHashCode(payload);
      if (seen.contains(identity)) {
        return null;
      }
      seen.add(identity);


      final Map<String, dynamic> map = payload is Map<String, dynamic>
          ? payload
          : Map<String, dynamic>.from(payload as Map);

      for (final List<String> path in _preferredAddressPaths) {
        final dynamic value = _walk(map, path);
        if (value == null) {
          continue;
        }
        final List<dynamic>? resolved = _extractAddressList(
          value,
          visited: seen,
          keyHint: path.isNotEmpty ? path.last : keyHint,
        );
        if (resolved != null) {
          return resolved;
        }
      }

      if (_looksLikeAddress(map)) {
        return <Map<String, dynamic>>[map];
      }

      for (final MapEntry<String, dynamic> entry in map.entries) {
        final dynamic value = entry.value;
        if (value == null) {
          continue;
        }

        final List<dynamic>? resolved = _extractAddressList(
          value,
          visited: seen,
          keyHint: entry.key,
        );
        if (resolved != null) {
          return resolved;
        }
      }
    }
    return null;
  }

  bool _isAddressListCandidate(
      List<dynamic> list, {
        String? keyHint,
      }) {
    if (list.isEmpty) {
      return keyHint == null || _isAddressishKey(keyHint);
    }

    int inspected = 0;
    for (final dynamic item in list) {
      if (item == null) {
        continue;
      }
      inspected++;
      if (item is Map<String, dynamic>) {
        if (_looksLikeAddress(item)) {
          return true;
        }
      } else if (item is Map) {
        final Map<String, dynamic> converted = Map<String, dynamic>.from(item);
        if (_looksLikeAddress(converted)) {
          return true;
        }
      } else if (item is String) {
        if (keyHint != null && _isAddressishKey(keyHint)) {
          return true;
        }
      }
      if (inspected >= 5) {
        break;
      }
    }
    return false;
  }

  bool _isAddressishKey(String key) {
    final String lower = key.toLowerCase();
    return lower.contains('address') ||
        lower == 'data' ||
        lower == 'result' ||
        lower == 'payload' ||
        lower == 'response';


  }

  dynamic _walk(Map<String, dynamic> map, List<String> path) {
    dynamic current = map;
    for (final String key in path) {
      if (current is Map<String, dynamic>) {
        current = current[key];
      } else if (current is Map) {
        current = (current as Map)[key];
      } else {
        return null;
      }
    }
    return current;
  }

  bool _looksLikeAddress(Map<String, dynamic> payload) {
    return payload.containsKey('id') ||
        payload.containsKey('address') ||
        payload.containsKey('label') ||
        payload.containsKey('title');

  }

  Map<String, dynamic> _normaliseAddress(Map<String, dynamic> raw) {
    final Map<String, dynamic> normalized = <String, dynamic>{};

    final int? id = _asInt(raw['id'] ?? raw['address_id'] ?? raw['addressId']);
    if (id != null) {
      normalized['id'] = id;
      normalized['address_id'] = id;
    }

    final String? name = _asString(raw['name'] ?? raw['contact_name']);
    if (name != null) {
      normalized['name'] = name;
    }

    final String? phone = _asString(
      raw['phone'] ?? raw['phone_number'] ?? raw['contact_phone'],
    );
    if (phone != null) {
      normalized['phone'] = phone;
    }

    final String? label = _asString(
      raw['label'] ??
          raw['address'] ??
          raw['street'] ??
          raw['full_address'] ??
          raw['title'] ??
          raw['name_ar'] ??
          raw['title_ar'],
    );
    if (label != null) {
      normalized['label'] = label;
      normalized['address'] = label;
    }

    double? latitude =
    _asDouble(raw['latitude'] ?? raw['lat'] ?? raw['geo_lat']);
    double? longitude =
    _asDouble(raw['longitude'] ?? raw['lng'] ?? raw['geo_lng']);

    if (latitude == null || longitude == null) {
      final Map<String, dynamic>? coordinatesMap =
          _mapify(raw['coordinates']) ??
              _mapify(raw['location']) ??
              _mapify(raw['geo']);
      if (coordinatesMap != null) {
        latitude ??=
            _asDouble(coordinatesMap['latitude'] ?? coordinatesMap['lat']);
        longitude ??=
            _asDouble(coordinatesMap['longitude'] ?? coordinatesMap['lng']);
      }
    }
    if (latitude != null) {
      normalized['latitude'] = latitude;
      normalized['lat'] = latitude;
    }
    if (longitude != null) {
      normalized['longitude'] = longitude;
      normalized['lng'] = longitude;
    }

    for (final String key in const <String>['area', 'city', 'state', 'country']) {
      final String? value = _asString(raw[key]);
      if (value != null) {
        normalized[key] = value;
      }
    }

    final bool? isDefault = _asBool(
      raw['is_default'] ?? raw['default'] ?? raw['isDefault'] ?? raw['default_address'],
    );
    if (isDefault != null) {
      normalized['is_default'] = isDefault;
      normalized['default'] = isDefault;
      normalized['isDefault'] = isDefault;
    }

    final double? distance = _roundDistance(
      raw['distance'] ?? raw['distance_km'] ?? raw['distanceKm'],
    );
    if (distance != null) {
      normalized['distance'] = distance;
      normalized['distance_km'] = distance;
      normalized['distanceKm'] = distance;
    }

    final Map<String, dynamic> copy = Map<String, dynamic>.from(raw);
    for (final MapEntry<String, dynamic> entry in copy.entries) {
      if (entry.value == null) {
        continue;
      }
      normalized.putIfAbsent(entry.key, () => entry.value);
    }

    return normalized;
  }

  int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  double? _asDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  String? _asString(dynamic value) {
    if (value == null) return null;
    final String stringValue = value.toString().trim();
    return stringValue.isEmpty ? null : stringValue;
  }

  bool? _asBool(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is num) return value != 0;
    final String lower = value.toString().toLowerCase().trim();
    if (lower == 'true' || lower == 'yes' || lower == '1') return true;
    if (lower == 'false' || lower == 'no' || lower == '0') return false;
    return null;
  }

  double? _roundDistance(dynamic value) {
    final double? distance = _asDouble(value);
    if (distance == null) {
      return null;
    }
    return double.parse(distance.toStringAsFixed(3));
  }



  Map<String, dynamic>? _mapify(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value as Map);
    }
    return null;
  }


  static const String _addressesEndpoint = 'addresses';
  static const List<List<String>> _preferredAddressPaths = <List<String>>[
    <String>['data', 'addresses'],
    <String>['data', 'data'],
    <String>['data', 'result'],
    <String>['data', 'address'],
    <String>['data'],
    <String>['addresses'],
    <String>['address'],
    <String>['result', 'addresses'],
    <String>['result', 'data'],
    <String>['result', 'address'],
    <String>['result'],
    <String>['payload', 'addresses'],
    <String>['payload', 'address'],
    <String>['payload'],
    <String>['response', 'addresses'],
    <String>['response', 'address'],
    <String>['response'],
  ];
}