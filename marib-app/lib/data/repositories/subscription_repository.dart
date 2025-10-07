import 'dart:io';

import 'package:marib/data/model/data_output.dart';
import 'package:marib/data/model/subscription_pacakage_model.dart';
import 'package:marib/utils/api.dart';
import 'package:marib/data/model/subscription_status.dart';



class SubscriptionRepository {
  Future<DataOutput<SubscriptionPackageModel>> getSubscriptionPacakges(
      {required String type}) async {
    Map<String, dynamic> response = await Api.get(
        url: Api.getPackageApi,
        queryParameters: {if (Platform.isIOS) "platform": "ios", "type": type});

    List<SubscriptionPackageModel> modelList = (response['data'] as List)
        .map((element) => SubscriptionPackageModel.fromJson(element))
        .toList();
    List<SubscriptionPackageModel> combineList = [];
    List<SubscriptionPackageModel> activeModelList =
        modelList.where((item) => item.isActive == true).toList();
    combineList.addAll(activeModelList);
    List<SubscriptionPackageModel> inactiveModelList =
        modelList.where((item) => item.isActive == false).toList();
    combineList.addAll(inactiveModelList);

    return DataOutput(total: combineList.length, modelList: combineList);
  }

  Future<void> subscribeToPackage(
      int packageId, bool isPackageAvailable) async {
    try {
      final Map<String, dynamic> parameters = <String, dynamic>{
        Api.packageId: packageId,
        if (isPackageAvailable) 'flag': 1,
      };
      // if (isPackageAvailable) {
      //   parameters['flag'] = 1;
      // }

      await Api.post(url: Api.userPurchasePackageApi, parameter: parameters);
    } on ApiHttpException catch (error) {
      throw _propagateError(error);
    } on ApiException {
      rethrow;
    } catch (error) {
      throw ApiException(error.toString());
    }
  }

  Future<SubscriptionStatus> fetchStatus() async {
    try {
      final Map<String, dynamic> response = await Api.get(
        url: Api.premiumSubscriptionStatusApi,
        queryParameters: const <String, dynamic>{
          'package_type': 'advertisement',
        },
      );



      final Map<String, dynamic> root = _unwrapMap(response);
      final Map<String, dynamic> container = _firstNonEmptyMap(<dynamic>[
        root['data'],
        root['result'],
        root['payload'],
        root,
      ]);

      final Map<String, dynamic> statusSource = _firstNonEmptyMap(<dynamic>[
        container['subscription'],
        container['subscription_status'],
        container['status'],
        container['plan'],
        container['premium'],
        container['data'],
        root['subscription'],
        root['status'],
        root,
      ]);

      final Map<String, dynamic> normalized =
      Map<String, dynamic>.from(statusSource);

      void ensureKey(String key, dynamic value) {
        if (value == null) {
          return;
        }
        if (!normalized.containsKey(key) || normalized[key] == null) {
          normalized[key] = value;
          return;
        }

        final dynamic existing = normalized[key];
        if (existing is num && value is num) {
          if (existing == 0 && value != 0) {
            normalized[key] = value;
          }
        } else if (existing is String && value is String) {
          if (existing.trim().isEmpty && value.trim().isNotEmpty) {
            normalized[key] = value;
          }

        }
      }


      final Map<String, dynamic> meta = _firstNonEmptyMap(<dynamic>[
        container['meta'],
        container['summary'],
        container['stats'],
        statusSource['meta'],
        statusSource['summary'],
      ]);

      if (meta.isNotEmpty) {
        for (final MapEntry<String, dynamic> entry in meta.entries) {
          ensureKey(entry.key, entry.value);
        }
      }

      final Map<String, dynamic> advertisement = _firstNonEmptyMap(<dynamic>[
        container['advertisement'],
        container['ad'],
        container['item'],
        container['listing'],
        container['current_ad'],
        container['currentAd'],
        statusSource['advertisement'],
        statusSource['ad'],
      ]);

      if (advertisement.isNotEmpty) {
        ensureKey(
          'is_featured',
          advertisement['is_featured'] ??
              advertisement['isFeatured'] ??
              advertisement['featured'],
        );
        ensureKey(
          'can_pause',
          advertisement['can_pause'] ??
              advertisement['canPause'] ??
              advertisement['allow_pause'] ??
              advertisement['pausable'],
        );

        final int? adCount = _extractFeaturedCount(advertisement);
        if (adCount != null) {
          ensureKey('featured_count', adCount);
          ensureKey('count', adCount);
        }
      }

      final Map<String, dynamic> limits = _firstNonEmptyMap(<dynamic>[
        statusSource['limits'],
        statusSource['limit'],
        container['limits'],
        container['limit'],
        meta['limits'],
        root['limits'],

      ]);

      final int? limitCount = _extractFeaturedCount(limits);
      if (limitCount != null) {
        ensureKey('featured_count', limitCount);
        ensureKey('count', limitCount);
        ensureKey('remaining', limitCount);
      }

      final dynamic allowedCandidate = normalized['allowed'] ??
          normalized['allow'] ??
          limits['allowed'] ??
          limits['allow'] ??
          container['allowed'] ??
          container['allow'] ??
          meta['allowed'] ??
          meta['allow'] ??
          root['allowed'] ??
          root['allow'];
      ensureKey('allowed', allowedCandidate);

      final dynamic totalCandidate = normalized['total'] ??
          normalized['total_allowed'] ??
          limits['total'] ??
          limits['total_allowed'] ??
          container['total'] ??
          container['total_allowed'] ??
          meta['total'] ??
          meta['total_allowed'] ??
          root['total'] ??
          root['total_allowed'];
      ensureKey('total', totalCandidate);

      final dynamic remainingCandidate = normalized['remaining'] ??
          normalized['left'] ??
          limits['remaining'] ??
          limits['left'] ??
          container['remaining'] ??
          container['left'] ??
          meta['remaining'] ??
          meta['left'] ??
          root['remaining'] ??
          root['left'];
      ensureKey('remaining', remainingCandidate);

      final dynamic expiresCandidate = normalized['expires_at'] ??
          normalized['expiresAt'] ??
          limits['expires_at'] ??
          limits['expiresAt'] ??
          container['expires_at'] ??
          container['expiresAt'] ??
          meta['expires_at'] ??
          meta['expiresAt'] ??
          root['expires_at'] ??
          root['expiresAt'];
      ensureKey('expires_at', expiresCandidate);
      ensureKey('expiresAt', expiresCandidate);

      if (!normalized.containsKey('has_active') ||
          normalized['has_active'] == null) {
        ensureKey('has_active', allowedCandidate);


      }

      final dynamic activeCandidate =
          normalized['has_active'] ??
              normalized['hasActive'] ??
              normalized['active'] ??
              container['has_active'] ??
              container['hasActive'] ??
              container['active'] ??
              meta['has_active'] ??
              meta['hasActive'] ??
              meta['active'] ??
              root['has_active'] ??
              root['hasActive'] ??
              root['active'];
      ensureKey('has_active', activeCandidate);

      final dynamic balanceCandidate =
          normalized['availableBalance'] ??
              normalized['available_balance'] ??
              normalized['balance'] ??
              container['availableBalance'] ??
              container['available_balance'] ??
              container['balance'] ??
              meta['availableBalance'] ??
              meta['available_balance'] ??
              meta['balance'] ??
              root['availableBalance'] ??
              root['available_balance'] ??
              root['balance'];
      ensureKey('available_balance', balanceCandidate);

      final dynamic isFeaturedCandidate =
          normalized['is_featured'] ??
              normalized['isFeatured'] ??
              container['is_featured'] ??
              container['isFeatured'] ??
              container['featured'] ??
              meta['is_featured'] ??
              meta['isFeatured'];
      ensureKey('is_featured', isFeaturedCandidate);

      final dynamic canPauseCandidate =
          normalized['can_pause'] ??
              normalized['canPause'] ??
              container['can_pause'] ??
              container['canPause'] ??
              meta['can_pause'] ??
              meta['canPause'];
      ensureKey('can_pause', canPauseCandidate);

      if (normalized.isEmpty) {
        normalized['has_active'] = false;
      }



      SubscriptionStatus status =
      SubscriptionStatus.fromJson(_unwrapMap(normalized));

      if (status.featuredCount == null) {
        final Map<String, dynamic> countResponse =
        await Api.get(url: Api.adsFeaturedCountApi);
        final int? featuredCount = _extractFeaturedCount(countResponse);
        status = status.copyWith(featuredCount: featuredCount);
      }

      return status;
    } on ApiHttpException catch (error) {
      throw _propagateError(error);
    }
  }

  Future<Map<String, dynamic>> featureAd(int adId) async {
    try {
      return await Api.post(
        url: Api.makeItemFeaturedApi,
        parameter: <String, dynamic>{'item_id': adId},
      );
    } on ApiHttpException catch (error) {
      throw _propagateError(error);
    }
  }

  Future<Map<String, dynamic>> unfeatureAd(int adId) async {


    try {
      return await Api.post(
        url: Api.unfeatureAdApi(adId),
        parameter: const <String, dynamic>{},
      );
    } on ApiHttpException catch (error) {



      throw _propagateError(error);
    }
  }

  Map<String, dynamic> _unwrapMap(dynamic payload) {
    if (payload is Map<String, dynamic>) {
      return payload;
    }
    if (payload is Map) {
      return Map<String, dynamic>.from(payload as Map);
    }
    return <String, dynamic>{};
  }

  Map<String, dynamic> _firstNonEmptyMap(Iterable<dynamic> sources) {
    for (final dynamic source in sources) {
      final Map<String, dynamic> map = _unwrapMap(source);
      if (map.isNotEmpty) {
        return map;
      }
    }
    return <String, dynamic>{};
  }

  int? _extractFeaturedCount(dynamic payload) {
    if (payload == null) {
      return null;
    }
    if (payload is Map) {
      final Map<String, dynamic> map = payload is Map<String, dynamic>
          ? payload
          : Map<String, dynamic>.from(payload as Map);

      final int? direct = _parseCount(
        map['featuredCount'] ??
            map['featured_count'] ??
            map['count'] ??
            map['remaining'],
      );
      if (direct != null) {
        return direct;
      }

      final List<dynamic> candidates = <dynamic>[
        map['data'],
        map['result'],
        map['subscription'],
        map['limits'],
        map['limit'],
        map['featured'],
      ];
      for (final dynamic candidate in candidates) {
        final int? nested = _extractFeaturedCount(candidate);
        if (nested != null) {
          return nested;
        }
      }

      for (final dynamic value in map.values) {
        final int? nested = _extractFeaturedCount(value);
        if (nested != null) {
          return nested;
        }
      }
      return null;
    }

    if (payload is Iterable) {
      for (final dynamic element in payload) {
        final int? parsed = _extractFeaturedCount(element);
        if (parsed != null) {
          return parsed;
        }
      }
      return null;
    }

    return _parseCount(payload);
  }

  int? _parseCount(dynamic value) {
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
      return int.tryParse(value.trim());
    }
    if (value is Map) {
      return _extractFeaturedCount(value);

    }
    if (value is Iterable) {
      for (final dynamic element in value) {
        final int? parsed = _parseCount(element);
        if (parsed != null) {
          return parsed;
        }
      }
    }
    return null;
  }

  ApiHttpException _propagateError(ApiHttpException error) {
    final String? message =
        _extractErrorMessage(error.payload) ?? _stringify(error.errorMessage);

    return ApiHttpException(
      errorMessage: message ?? error.errorMessage,
      statusCode: error.statusCode,
      payload: error.payload,
      cause: error.cause,
    );
  }

  String? _extractErrorMessage(dynamic payload) {
    if (payload == null) {
      return null;
    }
    if (payload is String) {
      final String trimmed = payload.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    if (payload is Map) {
      final Map<String, dynamic> map = payload is Map<String, dynamic>
          ? payload
          : Map<String, dynamic>.from(payload as Map);
      final String? direct = _extractErrorMessage(
        map['message'] ?? map['error'] ?? map['msg'],
      );
      if (direct != null) {
        return direct;
      }
      for (final dynamic value in map.values) {
        final String? nested = _extractErrorMessage(value);
        if (nested != null) {
          return nested;
        }
      }
      return null;
    }
    if (payload is Iterable) {
      for (final dynamic element in payload) {
        final String? nested = _extractErrorMessage(element);
        if (nested != null) {
          return nested;
        }
      }
    }
    return null;
  }

  String? _stringify(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is String) {
      return value;
    }
    return value.toString();
  }

}
