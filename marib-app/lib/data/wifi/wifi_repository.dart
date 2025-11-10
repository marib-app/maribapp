import 'package:marib/data/model/wifi/wifi_network.dart';
import 'package:marib/utils/api.dart';
import 'package:marib/data/model/wifi/wifi_payment_gateway.dart';
import 'package:marib/data/model/wifi/wifi_plan.dart';
import 'package:marib/data/model/wifi/wifi_purchase.dart';
import 'package:marib/data/model/wifi/wifi_purchase_result.dart';
import 'dart:collection';
import 'package:dio/dio.dart';

class WifiRepository {
  const WifiRepository();

  static const int _maxBatchUploadSizeBytes = 5 * 1024 * 1024;
  static const List<String> _allowedBatchExtensions = <String>[
    'csv',
    'txt',
    'xls',
    'xlsx'
  ];

  Map<String, dynamic> _mapify(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value as Map);
    }
    return <String, dynamic>{};
  }

  List<dynamic> _listify(dynamic value) {
    if (value is List) {
      return value;
    }
    if (value is Map) {
      final map = _mapify(value);
      final dynamic dataCandidate = map['data'] ??
          map['items'] ??
          map['results'] ??
          map['purchases'] ??
          map['plans'] ??
          map['wifi_plans'];
      if (dataCandidate != null && !identical(dataCandidate, value)) {
        final list = _listify(dataCandidate);
        if (list.isNotEmpty) {
          return list;
        }
      }
    }
    return const <dynamic>[];
  }

  String? _stringify(dynamic value) {
    if (value == null) return null;
    if (value is String) return value.trim().isEmpty ? null : value.trim();
    return value.toString();
  }

  int? _intify(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  Future<List<WifiNetwork>> fetchOwnerNetworks({
    String? query,
    int perPage = 60,
  }) async {
    final int normalizedPerPage = perPage.clamp(1, 100).toInt();
    final String normalizedQuery = query?.trim() ?? '';

    final response = await Api.get(
      url: Api.ownerWifiNetworksApi,
      queryParameters: <String, dynamic>{'per_page': normalizedPerPage},
    );

    final List<dynamic> rawList = _extractNetworksList(response);

    final List<WifiNetwork> networks = rawList
        .map((dynamic element) {
          if (element is Map<String, dynamic>) {
            return WifiNetwork.fromJson(element);
          }
          if (element is Map) {
            return WifiNetwork.fromJson(
              Map<String, dynamic>.from(element as Map),
            );
          }
          return null;
        })
        .whereType<WifiNetwork>()
        .toList();

    if (normalizedQuery.isEmpty) {
      return networks;
    }

    final String needle = normalizedQuery.toLowerCase();
    return networks.where((network) {
      final String haystack = <String?>[
        network.name,
        network.slug,
        network.address,
      ].whereType<String>().map((value) => value.toLowerCase()).join(' ');
      return haystack.contains(needle);
    }).toList();
  }

  Future<List<WifiNetwork>> fetchNetworks({
    String? query,
    int perPage = 30,
    int? ownerId,
    bool includePlans = false,
  }) async {
    final int normalizedPerPage = perPage.clamp(1, 100).toInt();
    final String normalizedQuery = query?.trim() ?? '';

    final Map<String, dynamic> queryParameters = <String, dynamic>{
      'per_page': normalizedPerPage,
      if (normalizedQuery.isNotEmpty) 'q': normalizedQuery,
      if (ownerId != null) 'owner_id': ownerId,
      if (includePlans) 'with_plans': true,
    };

    final response = await Api.get(
      url: Api.wifiNetworksApi,
      queryParameters: queryParameters,
    );

    final List<dynamic> rawList = _extractNetworksList(response);

    final List<WifiNetwork> networks = rawList
        .map((dynamic element) {
          if (element is Map<String, dynamic>) {
            return WifiNetwork.fromJson(element);
          }
          if (element is Map) {
            return WifiNetwork.fromJson(
              Map<String, dynamic>.from(element as Map),
            );
          }
          return null;
        })
        .whereType<WifiNetwork>()
        .toList();

    if (normalizedQuery.isEmpty) {
      return networks;
    }

    final String needle = normalizedQuery.toLowerCase();
    return networks.where((network) {
      final String haystack = <String?>[
        network.name,
        network.slug,
        network.address,
      ].whereType<String>().map((value) => value.toLowerCase()).join(' ');
      return haystack.contains(needle);
    }).toList();
  }

  List<dynamic> _extractNetworksList(dynamic payload) {
    if (payload is List) {
      return payload;
    }
    if (payload is Map<String, dynamic>) {
      final dynamic data = payload['data'] ?? payload['networks'];
      if (data is List) {
        return data;
      }
      if (data is Map<String, dynamic>) {
        final dynamic nested = data['data'] ?? data['networks'];
        if (nested is List) {
          return nested;
        }
      }
    }
    if (payload is Map) {
      return _extractNetworksList(Map<String, dynamic>.from(payload));
    }
    return const [];
  }

  Future<WifiNetwork> submitOwnerNetworkRequest({
    required String name,
    String? slug,
    double? latitude,
    double? longitude,
    double? coverageRadiusKm,
    String? address,
    String? description,
    String? notes,
    List<Map<String, String>> contacts = const <Map<String, String>>[],
    List<String> currencies = const <String>['YER'],
    MultipartFile? logo,
    MultipartFile? loginScreenshot,
  }) async {
    final Map<String, dynamic> metaPayload = <String, dynamic>{
      'source': 'mobile_app',
      'request_type': 'owner_network',
    };

    final Map<String, dynamic> formPayload = <String, dynamic>{
      'name': name,
      if (slug != null && slug.isNotEmpty) 'slug': slug,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (coverageRadiusKm != null) 'coverage_radius_km': coverageRadiusKm,
      if (address != null && address.isNotEmpty) 'address': address,
      if (description != null && description.isNotEmpty)
        'description': description,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      'meta': metaPayload,
    }..removeWhere((key, value) {
        if (value == null) return true;
        if (value is String && value.trim().isEmpty) {
          return true;
        }
        if (value is Iterable && value.isEmpty) {
          return true;
        }
        if (value is Map && value.isEmpty) {
          return true;
        }
        return false;
      });

    for (int i = 0; i < currencies.length; i++) {
      final String normalized = currencies[i].trim();
      if (normalized.isEmpty) {
        continue;
      }
      formPayload['currencies[$i]'] = normalized.toUpperCase();
    }

    for (int i = 0; i < contacts.length; i++) {
      final Map<String, String> contact = contacts[i];
      final String? type = contact['type'];
      final String? value = contact['value'];
      if (type == null || type.isEmpty || value == null || value.isEmpty) {
        continue;
      }
      formPayload['contacts[$i][type]'] = type;
      formPayload['contacts[$i][value]'] = value;
    }

    if (logo != null) {
      formPayload['logo'] = logo;
    }
    if (loginScreenshot != null) {
      formPayload['login_screenshot'] = loginScreenshot;
    }

    final Map<String, dynamic> response = await Api.post(
      url: Api.ownerWifiNetworksApi,
      parameter: FormData.fromMap(
        formPayload,
        ListFormat.multiCompatible,
      ),
    );

    final Map<String, dynamic> data =
        _mapify(response['data'] ?? response['network'] ?? response);

    return WifiNetwork.fromJson(data);
  }

  Future<List<WifiPlan>> fetchNetworkPlans(int networkId,
      {int perPage = 50}) async {
    final int normalizedPerPage = perPage.clamp(1, 100).toInt();

    final response = await Api.get(
      url: Api.wifiPlansApi,
      queryParameters: <String, dynamic>{
        'network_id': networkId,
        'per_page': normalizedPerPage,
      },
    );

    final dynamic container = response['data'] ??
        response['plans'] ??
        response['wifi_plans'] ??
        response['items'];

    final List<dynamic> plansRaw = List<dynamic>.from(_listify(container));

    if (plansRaw.isEmpty && container is List) {
      plansRaw.addAll(container);
    }

    final List<WifiPlan> plans = plansRaw
        .map((dynamic element) => _mapify(element))
        .where((map) => map.isNotEmpty)
        .map(WifiPlan.fromJson)
        .toList();

    return plans;
  }

  Future<List<WifiPlan>> fetchManagedPlans({
    int? networkId,
    int perPage = 50,
  }) async {
    final int normalizedPerPage = perPage.clamp(1, 50).toInt();

    final Map<String, dynamic> queryParameters = <String, dynamic>{
      'owner_only': true,
      'per_page': normalizedPerPage,
      if (networkId != null) 'network': networkId,
    };

    final Map<String, dynamic> response;

    try {
      response = await Api.get(
        url: Api.wifiPlansApi,
        queryParameters: queryParameters,
      );
    } on ApiHttpException catch (error) {
      if (error.statusCode == 403) {
        return const <WifiPlan>[];
      }
      rethrow;
    }

    final dynamic container = response['data'] ??
        response['plans'] ??
        response['wifi_plans'] ??
        response['items'];

    final List<dynamic> primaryList = List<dynamic>.from(_listify(container));
    if (primaryList.isEmpty && container is List) {
      primaryList.addAll(container);
    }

    final List<dynamic> includedRaw = _extractIncludedPlans(response);

    final List<Map<String, dynamic>> planMaps = <Map<String, dynamic>>[];
    final Map<int, int> indexById = <int, int>{};

    void addPlan(dynamic element) {
      final Map<String, dynamic> map = _mapify(element);
      if (map.isEmpty) {
        return;
      }

      final int? id = _intify(map['id']);
      if (id != null) {
        final int? existingIndex = indexById[id];
        if (existingIndex != null) {
          planMaps[existingIndex] = <String, dynamic>{
            ...planMaps[existingIndex],
            ...map,
          };
          return;
        }
        indexById[id] = planMaps.length;
      }

      planMaps.add(map);
    }

    for (final dynamic element in primaryList) {
      addPlan(element);
    }

    for (final dynamic element in includedRaw) {
      addPlan(element);
    }

    return planMaps.map(WifiPlan.fromJson).toList();
  }

  List<dynamic> _extractIncludedPlans(dynamic payload) {
    if (payload is Map<String, dynamic>) {
      final dynamic included = payload['included'];

      if (included is List) {
        final List<dynamic> list = _listify(included);
        return list.isEmpty ? const [] : List<dynamic>.from(list);
      }

      if (included is Map<String, dynamic>) {
        final dynamic container = included['plans'] ??
            included['wifi_plans'] ??
            included['data'] ??
            included['items'];

        final List<dynamic> list = _listify(container);
        return list.isEmpty ? const [] : List<dynamic>.from(list);
      }

      if (included is Map) {
        return _extractIncludedPlans(
          <String, dynamic>{
            'included': Map<String, dynamic>.from(included as Map),
          },
        );
      }

      return const [];
    }

    if (payload is Map) {
      return _extractIncludedPlans(Map<String, dynamic>.from(payload as Map));
    }

    return const [];
  }

  Future<List<WifiPaymentGateway>> fetchPaymentGateways() async {
    final response = await Api.get(url: Api.wifiPaymentGatewaysApi);
    final dynamic container = response['data'] ??
        response['gateways'] ??
        response['payment_gateways'] ??
        response['items'];

    final List<dynamic> gatewaysRaw = List<dynamic>.from(_listify(container));
    if (gatewaysRaw.isEmpty && container is List) {
      gatewaysRaw.addAll(container);
    }

    final List<WifiPaymentGateway> gateways = gatewaysRaw
        .map((dynamic element) => _mapify(element))
        .where((map) => map.isNotEmpty)
        .map(WifiPaymentGateway.fromJson)
        .toList();

    if (gateways.isEmpty) {
      return const <WifiPaymentGateway>[
        WifiPaymentGateway(id: 'wallet', name: 'المحفظة', isWallet: true),
      ];
    }

    return gateways;
  }

  Future<Map<String, dynamic>> uploadBatch({
    required String name,
    required String contact,
    required MultipartFile logo,
    required MultipartFile loginScreenshot,
    String? notes,
  }) async {
    final payload = <String, dynamic>{
      'name': name,
      'contacts': <String>[contact],
      'notes': notes,
      'logo': logo,
      'login_screenshot': loginScreenshot,
    }..removeWhere((key, value) {
        if (value == null) return true;
        if (value is String && value.trim().isEmpty) {
          return true;
        }
        if (value is Iterable && value.isEmpty) {
          return true;
        }
        return false;
      });

    return Api.post(
      url: Api.wifiNetworksApi,
      parameter: payload,
    );
  }

  Future<Map<String, dynamic>> createOwnerRequest({
    required String name,
    required String contact,
    required MultipartFile logo,
    required MultipartFile loginScreenshot,
    String? notes,
  }) async {
    const bool isActive = false;
    final int isActiveFlag = isActive ? 1 : 0;

    final payload = <String, dynamic>{
      'name': name,
      'contacts': <String>[contact],
      'notes': notes,
      'is_active': isActiveFlag,
      'meta': <String, dynamic>{
        'source': 'mobile_app',
        'request_type': 'owner_network',
      },
      'logo': logo,
      'login_screenshot': loginScreenshot,
    }..removeWhere((key, value) {
        if (value == null) return true;
        if (value is String && value.trim().isEmpty) {
          return true;
        }
        if (value is Iterable && value.isEmpty) {
          return true;
        }
        return false;
      });

    return Api.post(
      url: Api.wifiNetworksApi,
      parameter: payload,
    );
  }

  Future<WifiPlan> createNetworkPlan({
    required int networkId,
    required String name,
    String? description,
    required int durationDays,
    required num price,
    required String currency,
    double? dataCapGb,
    bool? isUnlimited,
    num? speedMbps,
    num? commissionRateOverride,
    bool? isActive,
    Map<String, dynamic>? meta,
    String? notes,
  }) async {
    if (networkId <= 0) {
      throw ArgumentError.value(networkId, 'networkId', 'must be positive');
    }
    if (durationDays <= 0) {
      throw ArgumentError.value(
        durationDays,
        'durationDays',
        'must be greater than zero',
      );
    }
    if (price <= 0) {
      throw ArgumentError.value(price, 'price', 'must be greater than zero');
    }

    final Map<String, dynamic> metaPayload = <String, dynamic>{
      if (meta != null) ...meta,
      if (speedMbps != null) 'speed_mbps': speedMbps,
      if (commissionRateOverride != null)
        'commission_rate_override': commissionRateOverride,
      if (isActive != null) 'is_active_requested': isActive,
    }..removeWhere((key, value) => value == null);

    final Map<String, dynamic> payload = <String, dynamic>{
      'name': name,
      'description': description,
      'duration_days': durationDays,
      'data_cap_gb': dataCapGb,
      'is_unlimited': isUnlimited,
      'price': price,
      'currency': currency,
      'notes': notes,
      if (metaPayload.isNotEmpty) 'meta': metaPayload,
    }..removeWhere((key, value) {
        if (value == null) return true;
        if (value is String && value.trim().isEmpty) {
          return true;
        }
        if (value is Iterable && value.isEmpty) {
          return true;
        }
        if (value is Map && value.isEmpty) {
          return true;
        }
        if (value is num && value.isNaN) {
          return true;
        }
        return false;
      });

    final Map<String, dynamic> response = await Api.post(
      url: Api.ownerWifiNetworkPlansApi(networkId),
      parameter: payload,
    );

    final Map<String, dynamic> data =
        _mapify(response['data'] ?? response['plan'] ?? response);

    return WifiPlan.fromJson(data);
  }

  Future<void> createPlanBatch({
    required int planId,
    required MultipartFile sourceFile,
    required String label,
    String? notes,
    int? totalCodes,
    int? availableCodes,
    Map<String, dynamic>? meta,
  }) async {
    if (planId <= 0) {
      throw ArgumentError.value(planId, 'planId', 'must be positive');
    }

    final String fileName = sourceFile.filename ?? '';
    final String extension =
        fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
    if (!_allowedBatchExtensions.contains(extension)) {
      throw ArgumentError(
        'Unsupported voucher file type "$extension". Allowed extensions: '
        '${_allowedBatchExtensions.join(', ')}.',
      );
    }

    final int? length = sourceFile.length;
    if (length != null && length > _maxBatchUploadSizeBytes) {
      throw ArgumentError(
        'Voucher file exceeds the maximum size of 5 MB.',
      );
    }

    final Map<String, dynamic> metaPayload = <String, dynamic>{
      if (meta != null) ...meta,
    }..removeWhere((key, value) => value == null);

    final Map<String, dynamic> payload = <String, dynamic>{
      'label': label,
      'source_file': sourceFile,
      'notes': notes,
      'total_codes': totalCodes,
      'available_codes': availableCodes,
      if (metaPayload.isNotEmpty) 'meta': metaPayload,
    }..removeWhere((key, value) {
        if (value == null) return true;
        if (value is String && value.trim().isEmpty) {
          return true;
        }
        if (value is Iterable && value.isEmpty) {
          return true;
        }
        if (value is Map && value.isEmpty) {
          return true;
        }
        return false;
      });

    await Api.post(
      url: Api.ownerWifiPlanBatchesApi(planId),
      parameter: FormData.fromMap(
        payload,
        ListFormat.multiCompatible,
      ),
    );
  }

  Future<void> deleteOwnerNetwork(int networkId) async {
    if (networkId <= 0) {
      throw ArgumentError.value(networkId, 'networkId', 'must be positive');
    }
    await Api.delete(
      url: Api.ownerWifiNetworkApi(networkId),
    );
  }

  Future<void> deleteNetworkPlan(int planId) async {
    if (planId <= 0) {
      throw ArgumentError.value(planId, 'planId', 'must be positive');
    }
    await Api.delete(
      url: Api.ownerWifiPlanApi(planId),
    );
  }

  Future<List<WifiPurchase>> fetchPurchases({int? page}) async {
    final query = page != null ? <String, dynamic>{'page': page} : null;
    final response = await Api.get(
      url: Api.wifiPurchasesApi,
      queryParameters: query,
    );

    final dynamic container = response['data'] ??
        response['purchases'] ??
        response['items'] ??
        response['orders'];

    final List<dynamic> rawList = List<dynamic>.from(_listify(container));

    if (rawList.isEmpty && container is List) {
      rawList.addAll(container);
    }

    final List<WifiPurchase> purchases = rawList
        .map((dynamic element) => _mapify(element))
        .where((map) => map.isNotEmpty)
        .map(WifiPurchase.fromJson)
        .toList();

    if (purchases.isNotEmpty) {
      purchases.sort(
        (a, b) {
          final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bDate.compareTo(aDate);
        },
      );
    }

    return purchases;
  }

  WifiPurchaseResult _buildPurchaseResult(Map<String, dynamic> response) {
    Map<String, dynamic> makeCopy(Map<String, dynamic> map) =>
        Map<String, dynamic>.from(map);

    final Map<String, dynamic> normalized = makeCopy(response);
    final Map<String, dynamic> payload = _mapify(
      normalized['data'] ??
          normalized['purchase'] ??
          normalized['order'] ??
          normalized['transaction'] ??
          normalized['payload'] ??
          normalized['result'],
    );

    WifiPurchase? purchase =
        payload.isEmpty ? null : WifiPurchase.fromJson(payload);

    if (purchase != null) {
      final Map<String, dynamic> wifiCode = _mapify(payload['wifi_code']);
      final List<Map<String, dynamic>> wifiCodes =
          _listify(payload['wifi_codes']).map(_mapify).toList();

      final List<String> extractedCodes = <String>[...purchase.codes];
      final Set<int> extractedIds = <int>{
        if (purchase.id != 0) purchase.id,
      };

      void appendCode(Map<String, dynamic> source) {
        final String? codeValue = _stringify(source['code']);
        if (codeValue != null && codeValue.isNotEmpty) {
          extractedCodes.add(codeValue);
        }
        final int? codeId = _intify(source['id'] ?? source['code_id']);
        if (codeId != null) {
          extractedIds.add(codeId);
        }
      }

      if (wifiCode.isNotEmpty) {
        appendCode(wifiCode);
      }

      for (final Map<String, dynamic> codeMap in wifiCodes) {
        appendCode(codeMap);
      }

      final List<String> normalizedCodes = extractedCodes
          .map((code) => code.trim())
          .where((code) => code.isNotEmpty)
          .toSet()
          .toList();

      final int resolvedId =
          extractedIds.isNotEmpty ? extractedIds.first : purchase.id;

      purchase = purchase.copyWith(
        id: resolvedId,
        codes: normalizedCodes,
      );
    }

    final String? topMessage = _stringify(
      normalized['message'] ??
          normalized['note'] ??
          normalized['status_message'] ??
          payload['message'],
    );

    String resolveStatus() {
      final List<dynamic> candidates = <dynamic>[
        normalized['status'],
        normalized['state'],
        normalized['purchase_status'],
        normalized['payment_status'],
        normalized['result'],
        payload['status'],
        payload['state'],
        payload['purchase_status'],
        payload['payment_status'],
        purchase?.status,
      ];

      for (final dynamic candidate in candidates) {
        final String? value = _stringify(candidate);
        if (value != null && value.isNotEmpty) {
          return value;
        }
      }

      if (normalized['pending'] == true) {
        return 'pending';
      }
      if (normalized['success'] == true) {
        return 'success';
      }
      if (payload['pending'] == true) {
        return 'pending';
      }
      return 'unknown';
    }

    bool isPendingStatus(String status) {
      final String value = status.toLowerCase();
      const Set<String> pendingStates = <String>{
        'pending',
        'processing',
        'awaiting',
        'awaiting_payment',
        'initiated',
        'created',
        'in_progress',
      };
      if (pendingStates.contains(value)) {
        return true;
      }
      final int? code = _intify(
            normalized['status_code'] ??
                normalized['code'] ??
                normalized['http_status'],
          ) ??
          _intify(payload['status_code'] ?? payload['code']);
      if (code == 202) {
        return true;
      }
      if (normalized['awaiting_webhook'] == true ||
          normalized['requires_webhook'] == true ||
          payload['awaiting_webhook'] == true) {
        return true;
      }
      return false;
    }

    final String status = resolveStatus();
    final bool pending = isPendingStatus(status);

    Uri? resolveRedirect() {
      final dynamic urlCandidate = normalized['redirect_url'] ??
          normalized['payment_url'] ??
          normalized['authorization_url'] ??
          payload['redirect_url'] ??
          payload['payment_url'];
      if (urlCandidate == null) {
        return null;
      }
      final String? url = _stringify(urlCandidate);
      if (url == null || url.isEmpty) {
        return null;
      }
      return Uri.tryParse(url);
    }

    final Uri? redirect = resolveRedirect();
    final bool requiresAction = normalized['requires_action'] == true ||
        normalized['requires_redirect'] == true ||
        payload['requires_action'] == true ||
        redirect != null;

    return WifiPurchaseResult(
      status: status,
      isPending: pending,
      requiresAction: requiresAction,
      purchase: purchase,
      message: topMessage,
      redirectUrl: redirect,
      raw: normalized,
    );
  }

  String? _collectErrorMessage(Map<String, dynamic> payload) {
    final List<String> pieces = <String>[];
    final String? baseMessage = _stringify(
      payload['message'] ??
          payload['error'] ??
          payload['detail'] ??
          payload['status_message'],
    );
    if (baseMessage != null && baseMessage.isNotEmpty) {
      pieces.add(baseMessage);
    }

    List<String> flatten(dynamic value) {
      if (value == null) return const <String>[];
      if (value is List) {
        return value
            .map((dynamic element) => _stringify(element))
            .whereType<String>()
            .where((element) => element.isNotEmpty)
            .toList();
      }
      if (value is Map) {
        final List<String> buffer = <String>[];
        value.forEach((key, dynamic element) {
          final List<String> nested = flatten(element);
          if (nested.isEmpty) {
            final String? asString = _stringify(element);
            if (asString != null && asString.isNotEmpty) {
              buffer.add(asString);
            }
          } else {
            buffer.addAll(nested);
          }
        });
        return buffer;
      }
      final String? single = _stringify(value);
      if (single == null || single.isEmpty) {
        return const <String>[];
      }
      return <String>[single];
    }

    final List<String> detailedErrors = flatten(payload['errors']);
    if (detailedErrors.isNotEmpty) {
      pieces.addAll(detailedErrors);
    }

    if (pieces.isEmpty) {
      return null;
    }

    final LinkedHashSet<String> unique = LinkedHashSet<String>.from(pieces);
    return unique.join('\n');
  }

  Future<WifiPurchaseResult> purchasePlan({
    required int planId,
    int quantity = 1,
    String paymentGateway = 'wallet',
    required bool termsAcknowledged,
  }) async {
    final Map<String, dynamic> payload = <String, dynamic>{
      'quantity': quantity,
      'payment_gateway': paymentGateway,
      'terms_acknowledged': termsAcknowledged,
    };

    final Map<String, dynamic> response = await Api.postJson(
      url: Api.wifiPlanPurchaseApi(planId),
      data: payload,
    );

    final bool hasErrorFlag = response['error'] == true ||
        response['success'] == false ||
        (_stringify(response['status'])?.toLowerCase() == 'error');

    if (hasErrorFlag) {
      final String? errorMessage = _collectErrorMessage(response);
      throw ApiException(
        errorMessage ?? 'تعذّر إتمام عملية الشراء في الوقت الحالي.',
      );
    }

    return _buildPurchaseResult(response);
  }

  Future<WifiPurchase?> revealTransactionCode(int transactionId) async {
    if (transactionId <= 0) {
      return null;
    }

    final Map<String, dynamic> response = await Api.get(
      url: Api.wifiOrderCodeApi(transactionId),
    );

    final Map<String, dynamic> data = _mapify(
      response['data'] ?? response['payload'] ?? response['result'],
    );

    if (data.isEmpty) {
      return null;
    }

    final Map<String, dynamic> codeMap = _mapify(data['code']);
    final Map<String, dynamic> planMap = _mapify(data['plan']);
    final Map<String, dynamic> networkMap = _mapify(data['network']);
    final Map<String, dynamic> transactionMap = _mapify(data['transaction']);

    final List<String> codes = <String>[];
    final String? primaryCode = _stringify(codeMap['code']);
    if (primaryCode != null && primaryCode.isNotEmpty) {
      codes.add(primaryCode);
    }

    if (codes.isEmpty) {
      return null;
    }

    final Map<String, dynamic> payload = <String, dynamic>{
      'id': codeMap['id'] ?? data['code_id'] ?? transactionId,
      'plan': planMap,
      'network': networkMap,
      'codes': codes,
      'status': codeMap['status'] ?? transactionMap['payment_status'],
      'payment_status': transactionMap['payment_status'],
      'payment_status_label': transactionMap['payment_status_label'],
      'payment_gateway': transactionMap['payment_gateway'],
      'transaction_id': transactionMap['id'] ?? transactionId,
      'meta': <String, dynamic>{
        ..._mapify(transactionMap['meta']),
        'transaction_id': transactionMap['id'] ?? transactionId,
        'payment_status': transactionMap['payment_status'],
        'payment_status_label': transactionMap['payment_status_label'],
        'payment_gateway': transactionMap['payment_gateway'],
        'reveal_count': codeMap['reveal_count'],
        'revealed_at': codeMap['revealed_at'],
        'code_id': codeMap['id'],
      },
      'created_at': transactionMap['completed_at'] ??
          transactionMap['updated_at'] ??
          transactionMap['created_at'],
      'reference': transactionMap['reference'],
    };

    return WifiPurchase.fromJson(payload);
  }

  Future<void> logCodeEvent({
    required int codeId,
    required String action,
    Map<String, dynamic>? metadata,
  }) async {
    if (codeId <= 0) {
      return;
    }

    final Map<String, dynamic> payload = <String, dynamic>{
      'action': action,
      if (metadata != null && metadata.isNotEmpty) 'meta': metadata,
    };

    await Api.postJson(
      url: Api.wifiCodeEventsApi(codeId),
      data: payload,
    );
  }
}
