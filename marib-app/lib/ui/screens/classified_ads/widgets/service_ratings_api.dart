// lib/new_code/data/service_ratings_api.dart
import 'package:flutter/foundation.dart';
import 'package:marib/utils/api.dart';
import 'package:marib/data/model/seller_ratings_model.dart' show Buyer, UserRatings;
import 'package:marib/utils/hive_utils.dart';

typedef _GetRequestHandler = Future<Map<String, dynamic>> Function({
  required String url,
  Map<String, dynamic>? queryParameters,
  bool? useBaseUrl,
  bool enableEtagCache,
});

class ServiceRatingsResult {
  final List<UserRatings> list;
  final bool hasMore;
  final int nextPage;
  final bool canReview;
  final double averageRating;
  final int totalReviews;
  final int serviceId;

  ServiceRatingsResult({
    required this.list,
    required this.hasMore,
    required this.nextPage,
    required this.canReview,
    required this.averageRating,
    required this.totalReviews,
    required this.serviceId,
  });
}

class ServiceRatingsApi {
  static final Map<String, _FallbackPageTracker> _fallbackTrackers = {};
  static _GetRequestHandler? _getOverride;

  static Future<Map<String, dynamic>> _performGet({
    required String url,
    Map<String, dynamic>? queryParameters,
    bool? useBaseUrl,
    bool enableEtagCache = false,
  }) {
    final handler = _getOverride;
    if (handler != null) {
      return handler(
        url: url,
        queryParameters: queryParameters,
        useBaseUrl: useBaseUrl,
        enableEtagCache: enableEtagCache,
      );
    }

    return Api.get(
      url: url,
      queryParameters: queryParameters,
      useBaseUrl: useBaseUrl,
      enableEtagCache: enableEtagCache,
    );
  }

  @visibleForTesting
  static void setGetOverride(_GetRequestHandler? handler) {
    _getOverride = handler;
  }

  @visibleForTesting
  static void resetGetOverride() {
    _getOverride = null;
  }

  // ط¬ظ„ط¨ ط§ظ„طھط¹ظ„ظٹظ‚ط§طھ/ط§ظ„طھظ‚ظٹظٹظ…ط§طھ ظ„ط®ط¯ظ…ط© ظ…ط¹ظٹظ‘ظ†ط©
  static Future<ServiceRatingsResult> fetchRatings({
    int? serviceId,
    int page = 1,
    int perPage = 20,
    String? sort, // "newest" | "highest" | "lowest" ...ط§ظ„ط® (ط§ط®طھظٹط§ط±ظٹ)
    String? serviceUid,
  }) async {
    final String? uid = _normalizeUid(serviceUid);

    final int resolvedServiceId = await _ensureServiceId(
      serviceId: serviceId,
      serviceUid: uid,
    );

    // اجلب تقييمي الشخصي أولاً لنضمن إدراجه حتى لو كانت القائمة الرئيسية فارغة
    UserRatings? myReview;
    try {
      myReview = await getMyReview(serviceId: resolvedServiceId, serviceUid: uid);
      if (kDebugMode) {
        // ignore: avoid_print
        print(
            '[ratings] preload myReview for fetch sid=$resolvedServiceId rating=${myReview?.ratings} review=${myReview?.review}');
      }
    } catch (_) {
      myReview = null;
    }

    // ظ†ط³طھط®ط¯ظ… getItemApi ظ„ط£ظ†ظ‡ ط§ظ„ط£ظƒط«ط± ط«ط¨ط§طھظ‹ط§ ظ„ط¯ظٹظƒظ…طŒ
    // ظˆظ†ظ…ط±ط± ظ…ظپط§طھظٹط­ ط´ط§ط¦ط¹ط© ظ„ظ„طھط±ظ‚ظٹظ…/ط§ظ„ظپط±ط² ظƒظٹ ظٹطھط¬ط§ظ‡ظ„ظ‡ط§ ط§ظ„ط¨ط§ظƒ ط¥ظ†ط¯ ط¥ظ† ظ„ظ… ظٹط¯ط¹ظ…ظ‡ط§.
    final Map<String, dynamic> resp = await _performGet(
      url: Api.serviceReviewsApi,
      queryParameters: {
        Api.page: page,
        'per_page': perPage,
        'service_id': resolvedServiceId,
        'item_id': resolvedServiceId,
        'department': 'services',
        'report_department': 'services',
        // مرر القيمتين المفرد والجمع لزيادة التوافق
        'type': 'services',
        'item_type': 'services',
        'type_alt': 'service',
        'item_type_alt': 'service',
        'status': 'all', // اطلب جميع الحالات لأصحاب الخدمة (سيتجاهلها السيرفر لغير المالك)
        if (uid != null) 'service_uid': uid,
        if (uid != null) 'uid': uid,
        if (sort != null) 'sort': sort,
      },
    );

    if (kDebugMode) {
      // ط§ط·ط¨ط¹ ظ…ظپطھط§ط­ظ‹ط§ ظˆط§ط­ط¯ظ‹ط§ طµط؛ظٹط±ظ‹ط§ ظ„ظ„طھط´ط®ظٹطµ ظپظ‚ط·
      // (ط¨ط¯ظˆظ† ط¥ط؛ط±ط§ظ‚ ط§ظ„ظ„ظˆط¬)
      // ignore: avoid_print
      print(
          '[ratings] got response keys: ${resp.keys.take(6).toList()} for serviceId=$resolvedServiceId');
    }

    List<Map<String, dynamic>> rows = _extractReviewRows(resp);
    if (kDebugMode) {
      // ignore: avoid_print
      final dataNode = resp['data'];
      final dataKeys =
          dataNode is Map ? dataNode.keys.take(8).toList() : dataNode?.runtimeType;
      print(
          '[ratings] fetchRatings sid=$resolvedServiceId uid=$uid rows=${rows.length} page=$page keys=${resp.keys.take(6).toList()} msg=${resp['message']} data_keys=$dataKeys');
      if (rows.isEmpty && dataNode is Map && page == 1) {
        // log content of reviews node to understand structure
        final rev = dataNode['reviews'];
        final revType = rev?.runtimeType;
        final revLen = rev is List ? rev.length : (rev is Map && rev['data'] is List ? (rev['data'] as List).length : null);
        print('[ratings] reviews node type=$revType len=$revLen raw=$rev');
      }
    }
    Map<String, dynamic> metaSource = resp;
    // لو رجع خالياً في الصفحة الأولى، جرب استدعاءً أبسط بدون معاملات إضافية
    if (page == 1 && rows.isEmpty) {
      try {
        final alt = await _performGet(
          url: Api.serviceReviewsApi,
          queryParameters: {
            'service_id': resolvedServiceId,
            'status': 'all',
            if (uid != null) 'service_uid': uid,
            if (uid != null) 'uid': uid,
          },
        );
        final altRows = _extractReviewRows(alt);
        if (altRows.isNotEmpty) {
          rows = altRows;
          metaSource = alt;
          if (kDebugMode) {
            // ignore: avoid_print
            print(
                '[ratings] fallback fetch succeeded sid=$resolvedServiceId rows=${rows.length} msg=${alt['message']}');
          }
        }
      } catch (_) {
        // ignore and keep original rows
      }
    }
    List<UserRatings> list =
        rows.map(_toUserRatings).whereType<UserRatings>().toList();

    // أضف تقييمي الشخصي إن وجد لأي حال (أعد الطلب إن كان null)
    if (myReview == null && page == 1) {
      try {
        myReview = await getMyReview(
          serviceId: resolvedServiceId,
          serviceUid: uid,
        );
        if (kDebugMode) {
          // ignore: avoid_print
          print('[ratings] late fetch myReview sid=$resolvedServiceId rating=${myReview?.ratings}');
        }
      } catch (_) {
        myReview = null;
      }
    }

    if (myReview != null) {
      final bool exists = list.any(
          (r) => r.id != null && myReview!.id != null && r.id == myReview!.id);
      if (!exists) {
        list.insert(0, myReview!);
        if (kDebugMode) {
          // ignore: avoid_print
          print('[ratings] appended myReview to list sid=$resolvedServiceId');
        }
      }
    }

    // إذا بقيت القائمة فارغة لكن لدينا تقييمي الشخصي، استخدمه كقائمة وحيدة
    if (list.isEmpty && myReview != null) {
      list.add(myReview!);
      if (kDebugMode) {
        // ignore: avoid_print
        print('[ratings] using only myReview as list sid=$resolvedServiceId');
      }
    }

    final String trackerKey = _paginationTrackerKey(
      serviceId: resolvedServiceId,
      uid: uid,
      sort: sort,
      perPage: perPage,
    );
    if (page <= 1) {
      _fallbackTrackers.remove(trackerKey);
    }

    // ط§ط³طھظ†طھط§ط¬ ط§ظ„طھط±ظ‚ظٹظ… ظ…ظ† ط§ظ„ط§ط³طھط¬ط§ط¨ط© ط¥ظ† ظˆظڈط¬ط¯
    final pg = _extractPagination(resp,
        fallbackPage: page,
        perPage: perPage,
        currentCount: list.length,
        rawRows: rows,
        trackerKey: trackerKey);

    double totalRatings = 0;
    for (final rating in list) {
      totalRatings += (rating.ratings ?? 0).toDouble();
    }
    final double fallbackAverage =
        list.isEmpty ? 0.0 : totalRatings / list.length;
    final double averageRating =
        _extractAverageRating(metaSource) ?? fallbackAverage;

    final int fallbackTotal = ((page - 1) * perPage) + list.length;
    final int? extractedTotal = _extractTotalReviews(metaSource);
    int totalReviews = extractedTotal != null
        ? (extractedTotal < fallbackTotal ? fallbackTotal : extractedTotal)
        : fallbackTotal;
    // إذا بقيت القائمة فارغة لكن لدينا تقييمي الشخصي، استخدمه كقائمة وحيدة
    if (list.isEmpty && myReview != null) {
      list = [myReview!];
      totalRatings = (myReview!.ratings ?? 0).toDouble();
      totalReviews = 1;
      if (kDebugMode) {
        // ignore: avoid_print
        print('[ratings] using only myReview as list sid=$resolvedServiceId');
      }
    }
    // إذا كنا نعرض تقييمي الشخصي فقط، لا تترك العدد صفراً
    if (totalReviews == 0 && list.isNotEmpty) {
      totalReviews = list.length;
    }

    if (kDebugMode) {
      // ignore: avoid_print
      final first = list.isNotEmpty ? list.first : null;
      print(
          '[ratings] final list len=${list.length} first_review=${first?.review} rating=${first?.ratings} status=${first?.buyerId}');
    }

    final int extractedServiceId =
        _extractServiceIdFromAny(metaSource, matchUid: uid) ??
            resolvedServiceId;

    return ServiceRatingsResult(
      list: list,
      hasMore: pg.hasMore,
      nextPage: pg.nextPage,
      canReview: _extractCanReview(metaSource),
      averageRating: averageRating,
      totalReviews: totalReviews,
      serviceId: extractedServiceId,
    );
  }

  /// ط¥ط¶ط§ظپط© طھظ‚ظٹظٹظ…/طھط¹ظ„ظٹظ‚ ط¬ط¯ظٹط¯
  static Future<bool> addRating({
    required int serviceId,
    required int stars, // 1..5
    String? comment,
    String? serviceUid,
  }) async {
    final text = (comment ?? '').trim();
    final String? uid = _normalizeUid(serviceUid);

    final int resolvedServiceId = await _ensureServiceId(
      serviceId: serviceId,
      serviceUid: uid,
    );

    final payload = <String, dynamic>{
      'service_id': resolvedServiceId,
      'item_id': resolvedServiceId,
      'rating': stars,
      'department': 'services',
      'report_department': 'services',
      'type': 'services',
      'item_type': 'services',
      'type_alt': 'service',
      'item_type_alt': 'service',
      if (text.isNotEmpty) 'review': text,
      if (uid != null) 'service_uid': uid,
      if (uid != null) 'uid': uid,
    };

    final resp =
        await Api.post(url: Api.addServiceReviewApi, parameter: payload);

    final messageValue = resp['message'];
    final messageString =
        messageValue is String ? messageValue.trim().toLowerCase() : null;

    final ok = (resp['success'] == true) ||
        (resp['status'] == 'ok') ||
        (resp['status'] == true) ||
        (resp['code'] == 200) ||
        (resp['error'] == false) ||
        (messageString == 'success');
    if (kDebugMode) {
      // ignore: avoid_print
      print('[ratings] addRating -> $ok, resp keys: ${resp.keys.toList()}');
    }

    if (!ok) {
      final dynamic rawMessage =
          resp['message'] ?? resp['msg'] ?? resp['error'];
      final String? serverMessage =
          rawMessage is String ? rawMessage.trim() : rawMessage?.toString();

      throw ApiException(
        (serverMessage != null && serverMessage.isNotEmpty)
            ? serverMessage
            : 'طھط¹ط°ط± ط¥ط±ط³ط§ظ„ ط§ظ„طھظ‚ظٹظٹظ…',
      );
    }

    return true;
  }

  // (ط§ط®طھظٹط§ط±ظٹ) ط¬ظ„ط¨ طھظ‚ظٹظٹظ… ط§ظ„ظ…ط³طھط®ط¯ظ… ط§ظ„ط­ط§ظ„ظٹ ظ„ظ‡ط°ظ‡ ط§ظ„ط®ط¯ظ…ط© â€” ظ„ظ…ظ†ط¹ ط§ظ„طھظƒط±ط§ط± ط£ظˆ ظ„ط¹ط±ط¶ ط²ط± "ط¹ط¯ظ„ طھظ‚ظٹظٹظ…ظƒ"

  static Future<UserRatings?> getMyReview({
    int? serviceId,
    String? serviceUid,
  }) async {
    final String? uid = _normalizeUid(serviceUid);

    final int resolvedServiceId = await _ensureServiceId(
      serviceId: serviceId,
      serviceUid: uid,
    );

    final resp = await _performGet(
      url: Api.myServiceReviewsApi,
      queryParameters: {
        'service_id': resolvedServiceId,
        'item_id': resolvedServiceId,
        'department': 'services',
        'report_department': 'services',
        'type': 'services',
        'item_type': 'services',
        'type_alt': 'service',
        'item_type_alt': 'service',
        if (uid != null) 'service_uid': uid,
        if (uid != null) 'uid': uid,
      },
    );
    if (kDebugMode) {
      // ignore: avoid_print
      final dn = resp['data'];
      final dType = dn?.runtimeType;
      final dLen = dn is List ? dn.length : (dn is Map ? dn.length : null);
      final first = dn is List && dn.isNotEmpty ? dn.first : null;
      print('[ratings] getMyReview sid=$resolvedServiceId uid=$uid keys=${resp.keys.take(6).toList()} msg=${resp['message']} data_type=$dType data_len=$dLen first=$first');
    }
    final row = _firstRow(resp);
    if (row != null) {
      final parsed = _toUserRatings(row, fillCurrentUserIfMissing: true) ??
          _fillBuyerFromHiveIfMissing(
              _bestEffortRating(row, resolvedServiceId),
              force: true);
      if (parsed != null) return parsed;
    }

    // قد يعود data كـ List مباشرة
    final dynamic dataNode = resp['data'];
    if (dataNode is List) {
      for (final item in dataNode) {
        if (item is Map) {
          final map = <String, dynamic>{};
          item.forEach((key, value) {
            map[key.toString()] = value;
          });
          final parsed = _toUserRatings(map, fillCurrentUserIfMissing: true) ??
              _fillBuyerFromHiveIfMissing(
                  _bestEffortRating(map, resolvedServiceId),
                  force: true);
          if (parsed != null) return parsed;
        }
      }
    }

    // قد يعود كائن مفرد بدلاً من قائمة
    if (resp is Map<String, dynamic>) {
      final dataNode = resp['data'];
      if (dataNode is Map<String, dynamic>) {
        final parsed = _toUserRatings(dataNode, fillCurrentUserIfMissing: true) ??
            _fillBuyerFromHiveIfMissing(
                _bestEffortRating(dataNode, resolvedServiceId),
                force: true);
        if (parsed != null) return parsed;
      }
      final parsed = _toUserRatings(resp, fillCurrentUserIfMissing: true) ??
          _fillBuyerFromHiveIfMissing(
              _bestEffortRating(resp, resolvedServiceId),
              force: true);
      if (parsed != null) return parsed;
    }

    return null;
  }

  /// (ط§ط®طھظٹط§ط±ظٹ) ط§ظ„ط¥ط¨ظ„ط§ط؛ ط¹ظ† طھط¹ظ„ظٹظ‚/طھظ‚ظٹظٹظ… ظ…ط¹ظٹظ‘ظ†
  static Future<bool> reportReview({
    required int reviewId,
    required int serviceId,
    String? reasonText,
    String? serviceUid,
  }) async {
    final String? uid = _normalizeUid(serviceUid);
    final String text = (reasonText ?? '').trim();

    final int resolvedServiceId = await _ensureServiceId(
      serviceId: serviceId,
      serviceUid: uid,
    );

    final payload = <String, dynamic>{
      'review_id': reviewId,
      'service_id': resolvedServiceId,
      if (text.isNotEmpty) Api.message: text,
      if (text.isNotEmpty) 'details': text,
      'type': 'service',
      if (uid != null) 'service_uid': uid,
      if (uid != null) 'uid': uid,
    };

    final resp =
        await Api.post(url: Api.addServiceReviewReportApi, parameter: payload);

    final ok = (resp['success'] == true) ||
        (resp['status'] == 'ok') ||
        (resp['code'] == 200) ||
        (resp['error'] == false);

    if (kDebugMode) {
      // ignore: avoid_print
      print('[ratings] reportReview -> $ok');
    }

    return ok;
  }

  // --------------------------------------------------------------------------
  // Helpers
  // --------------------------------------------------------------------------

  static Future<int> _ensureServiceId({
    int? serviceId,
    String? serviceUid,
  }) async {
    final int? direct = _asPositiveInt(serviceId);
    if (direct != null) {
      return direct;
    }

    final String? uid = _normalizeUid(serviceUid);
    if (uid == null) {
      throw ApiException('طھط¹ط°ط± ط§ظ„ط¹ط«ظˆط± ط¹ظ„ظ‰ ط§ظ„ط®ط¯ظ…ط© ط§ظ„ظ…ط·ظ„ظˆط¨ط©.');
    }

    try {
      final Map<String, dynamic> response = await _performGet(
        url: Api.getServicesApi,
        queryParameters: {
          'service_uid': uid,
          'uid': uid,
          'limit': 1,
        },
      );

      final int? extracted =
          _extractServiceIdFromAny(response, matchUid: uid) ??
              _extractServiceIdFromAny(response);
      if (extracted != null) {
        return extracted;
      }
    } on ApiException {
      rethrow;
    } catch (error) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('[ratings] resolve serviceId failed for uid=$uid -> $error');
      }
    }

    throw ApiException('طھط¹ط°ط± ط§ظ„ط¹ط«ظˆط± ط¹ظ„ظ‰ ط§ظ„ط®ط¯ظ…ط© ط§ظ„ظ…ط·ظ„ظˆط¨ط©.');
  }

  static String? _normalizeUid(String? value) {
    if (value == null) return null;
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static int? _asPositiveInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value > 0 ? value : null;
    if (value is num) {
      final int intValue = value.toInt();
      return intValue > 0 ? intValue : null;
    }
    if (value is String) {
      final int? parsed = int.tryParse(value.trim());
      if (parsed != null && parsed > 0) return parsed;
    }
    return null;
  }

  static String _paginationTrackerKey({
    required int serviceId,
    String? uid,
    String? sort,
    required int perPage,
  }) {
    final buffer = StringBuffer('srv:$serviceId|pp:$perPage');
    if (uid != null && uid.trim().isNotEmpty) {
      buffer.write('|uid:${uid.trim()}');
    }
    if (sort != null && sort.trim().isNotEmpty) {
      buffer.write('|sort:${sort.trim()}');
    }
    return buffer.toString();
  }

  static String _rowIdentityKey(Map<String, dynamic> row) {
    final dynamic id = row['id'] ??
        row['review_id'] ??
        row['rating_id'] ??
        row['ratingId'] ??
        row['comment_id'] ??
        row['uid'] ??
        row['uuid'] ??
        row['user_id'];
    if (id != null) {
      return 'id:$id';
    }

    final reviewText = (row['review'] ??
            row['comment'] ??
            row['message'] ??
            row['description'] ??
            row['body'] ??
            row['text'] ??
            '')
        .toString()
        .trim();
    final created = (row['created_at'] ??
            row['created'] ??
            row['date'] ??
            row['updated_at'] ??
            row['timestamp'] ??
            '')
        .toString()
        .trim();

    final reviewHash = reviewText.isEmpty ? reviewText : reviewText.hashCode;
    final createdHash = created.isEmpty ? created : created.hashCode;
    return 'c:$reviewHash|t:$createdHash';
  }

  static String _rowsSignature(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) return 'empty';
    final keys = rows.map(_rowIdentityKey).toList()..sort();
    return keys.join('||');
  }

  static int? _extractServiceIdFromAny(
    dynamic source, {
    String? matchUid,
  }) {
    if (source == null) return null;

    if (source is Map) {
      final Map<String, dynamic> map = <String, dynamic>{};
      source.forEach((key, value) {
        map[key.toString()] = value;
      });

      final int? directId = _asPositiveInt(
        map['service_id'] ?? map['id'] ?? map['item_id'] ?? map['items_id'],
      );
      final String? uidCandidate = _normalizeUid(
        map['service_uid'] ?? map['serviceUid'] ?? map['uid'],
      );

      if (directId != null) {
        if (matchUid == null) {
          return directId;
        }
        if (uidCandidate != null && uidCandidate == matchUid) {
          return directId;
        }
      }

      for (final value in map.values) {
        final int? nested = _extractServiceIdFromAny(value, matchUid: matchUid);
        if (nested != null) {
          return nested;
        }
      }

      return null;
    }

    if (source is Iterable) {
      for (final dynamic value in source) {
        final int? nested = _extractServiceIdFromAny(value, matchUid: matchUid);
        if (nested != null) {
          return nested;
        }
      }
    }

    return null;
  }

  static UserRatings _bestEffortRating(Map<String, dynamic> map, int serviceId) {
    final buyerMap = _extractBuyerMap(map);
    final rating = UserRatings(
      id: _asPositiveInt(map['id']),
      itemId: serviceId,
      ratings: (map['ratings'] ?? map['rating'] ?? map['stars']) is num
          ? (map['ratings'] ?? map['rating'] ?? map['stars']).toDouble()
          : null,
      review: (map['review'] ?? map['comment'] ?? '').toString(),
      createdAt: (map['created_at'] ?? map['created'] ?? '').toString(),
      updatedAt: (map['updated_at'] ?? map['updated'] ?? '').toString(),
      buyer: buyerMap != null ? Buyer.fromJson(buyerMap) : null,
      buyerId: buyerMap != null ? _asPositiveInt(buyerMap['id']) : null,
    );
    return rating;
  }

  static Map<String, dynamic>? _extractBuyerMap(Map<String, dynamic> map) {
    Map<String, dynamic>? take(dynamic value) {
      if (value is Map<String, dynamic>) return value;
      if (value is Map) {
        return value.map((k, v) => MapEntry(k.toString(), v));
      }
      return null;
    }

    final Map<String, dynamic>? directBuyer = take(map['buyer'] ??
        map['user'] ??
        map['customer'] ??
        map['client'] ??
        map['author']);
    Map<String, dynamic>? buyer = directBuyer != null
        ? Map<String, dynamic>.from(directBuyer)
        : <String, dynamic>{};

    final candidateId = _asPositiveInt(map['buyer_id'] ??
        map['user_id'] ??
        map['customer_id'] ??
        map['client_id'] ??
        map['author_id'] ??
        map['uid'] ??
        buyer['id']);
    if (candidateId != null) buyer['id'] = candidateId;

    final String? name = (map['buyer_name'] ??
            map['user_name'] ??
            map['customer_name'] ??
            map['author_name'] ??
            map['name'] ??
            buyer['name'])
        ?.toString();
    if (name != null && name.trim().isNotEmpty) {
      buyer['name'] = name.trim();
    }

    final String? avatar = (map['buyer_profile'] ??
            map['user_profile'] ??
            map['customer_profile'] ??
            map['author_profile'] ??
            map['profile'] ??
            map['avatar'] ??
            buyer['profile'])
        ?.toString();
    if (avatar != null && avatar.trim().isNotEmpty) {
      buyer['profile'] = avatar.trim();
    }

    if (buyer.isEmpty) return null;
    return buyer;
  }

  static UserRatings _fillBuyerFromHiveIfMissing(UserRatings rating,
      {bool force = false}) {
    try {
      final bool hasBuyer =
          rating.buyer != null && (rating.buyer!.name?.trim().isNotEmpty ?? false);
      final int? buyerId = rating.buyerId ?? rating.buyer?.id;
      final int? currentUserId = HiveUtils.getUserDetails().id;
      final bool isCurrentUser =
          currentUserId != null && buyerId != null && buyerId == currentUserId;

      if (!force && (hasBuyer || !isCurrentUser)) {
        return rating;
      }

      final user = HiveUtils.getUserDetails();
      final int? uid = user.id;
      final String? uname = user.name?.toString();
      final String? uprofile = user.profile?.toString();
      if (uid == null && (uname == null || uname.trim().isEmpty)) {
        return rating;
      }
      return rating.copyWith(
        buyerId: buyerId ?? uid,
        buyer: Buyer(
          id: buyerId ?? uid,
          name: uname ?? user.mobile ?? 'User',
          profile: uprofile,
        ),
      );
    } catch (_) {
      return rating;
    }
  }

  /// ظٹط­ط§ظˆظ„ ط§ط³طھط®ط±ط§ط¬ ظ…طµظپظˆظپط© ط§ظ„طھط¹ظ„ظٹظ‚ط§طھ/ط§ظ„طھظ‚ظٹظٹظ…ط§طھ ظ…ظ† ط£ظ†ظ…ط§ط· ط´ط§ط¦ط¹ط©
  static List<Map<String, dynamic>> _extractReviewRows(
      Map<String, dynamic> resp) {
    dynamic root = resp;


    final dynamic rootRows = resp['rows'];
    if (rootRows is List) {
      return rootRows
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
    }

    // ط´ط§ط¦ط¹: { data: {...} } ط£ظˆ { item: {...} }
    root = root[Api.data] ?? root['data'] ?? root;

    // ظپظٹ ط­ط§ظ„ ظƒط§ظ† ط§ظ„ط¬ط°ط± ظٹط­ظˆظٹ ظ…ط¨ط§ط´ط±ط© ط¹ظ„ظ‰ ظ‚ط§ط¦ظ…ط© ط¯ط§ط®ظ„ data
    if (root is Map) {
      final direct = root[Api.data] ?? root['data'];
      if (direct is List) {
        return direct
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList();
      }
    }

    root = root[Api.item] ?? root['item'] ?? root['service'] ?? root;

    // ط£ظ†ظ…ط§ط· ظƒط«ظٹط±ط©: reviews, ratings, comments, feedback, list, items, result
    for (final key in const [
      'reviews',
      'ratings',
      'comments',
      'feedback',
      'list',
      'items',
      'rows',
      'result',
    ]) {
      final v = (root is Map) ? root[key] : null;
      // Laravel paginator: { reviews: { data: [...] } }
      if (v is Map && v['data'] is List) {
        return (v['data'] as List)
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList();
      }
      if (v is List) {
        return v
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList();
      }
    }

    // ط£ط­ظٹط§ظ†ظ‹ط§ طھظƒظˆظ† ط§ظ„ظ…طµظپظˆظپط© ظ…ط¨ط§ط´ط±ط©
    if (root is List) {
      return root
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
    }

    // ظ„ط§ ط´ظٹط،
    return const <Map<String, dynamic>>[];
  }

  static Map<String, dynamic>? _firstRow(Map<String, dynamic> resp) {
    final rows = _extractReviewRows(resp);
    return rows.isNotEmpty ? rows.first : null;
  }

  /// طھط­ظˆظٹظ„ ظ…ط±ظ† ط¥ظ„ظ‰ UserRatings
  static UserRatings? _toUserRatings(Map<String, dynamic> m,
      {bool fillCurrentUserIfMissing = false}) {
    try {
      // ظˆظپظ‘ط± ظ…ظپط§طھظٹط­ ط§ظپطھط±ط§ط¶ظٹط© ظ„ظƒظٹ ظٹظ‚ط±ط£ظ‡ط§ ظ…ظˆط¯ظٹظ„ UserRatings ط¨ط³ظ„ط§ط³ط©
      final rating = m['ratings'] ?? m['rating'] ?? m['stars'] ?? 0;
      final review = (m['review'] ??
              m['comment'] ??
              m['message'] ??
              m['description'] ??
              '')
          .toString();
      final created = (m['created_at'] ??
              m['created'] ??
              m['date'] ??
              m['updated_at'] ??
              '')
          .toString();

      final mm = Map<String, dynamic>.from(m);
      final Map<String, dynamic>? buyerMap = _extractBuyerMap(mm);
      if (buyerMap != null) {
        mm['buyer'] = buyerMap;
        if (buyerMap['id'] != null) {
          mm.putIfAbsent('buyer_id', () => buyerMap['id']);
        }
      }
      mm.putIfAbsent('ratings', () => rating);
      mm.putIfAbsent('review', () => review);
      mm.putIfAbsent('created_at', () => created);

      final parsed = UserRatings.fromJson(mm);
      if (fillCurrentUserIfMissing) {
        return _fillBuyerFromHiveIfMissing(parsed, force: true);
      }
      return parsed;
    } catch (_) {
      return null;
    }
  }

  /// ط¥ط³طھظ†طھط§ط¬ ظ…ط¹ظ„ظˆظ…ط§طھ ط§ظ„طھط±ظ‚ظٹظ… ظ…ظ† ط£ظ†ظ…ط§ط· ط´ط§ط¦ط¹ط© ط£ظˆ ظ…ظ† ط·ظˆظ„ ط§ظ„ظ†طھط§ط¦ط¬
  static _Pager _extractPagination(
    Map<String, dynamic> resp, {
    required int fallbackPage,
    required int perPage,
    required int currentCount,
    required List<Map<String, dynamic>> rawRows,
    required String trackerKey,
  }) {


    int? parseInt(dynamic value) {
      if (value is int) {
        return value;
      }
      if (value is num) {
        return value.toInt();
      }
      if (value is String) {
        return int.tryParse(value);
      }
      return null;
    }

    final int? topCurrent = parseInt(resp['current_page']);
    final int? topLast = parseInt(resp['last_page']);
    final int? topPerPage = parseInt(resp['per_page']);
    final int? topTotal = parseInt(resp['total']);

    if (topCurrent != null && (topLast != null || (topPerPage != null && topPerPage > 0 && topTotal != null))) {
      final int lastPage = topLast ?? ((topTotal! + topPerPage! - 1) ~/ topPerPage);
      final bool hasMore = topCurrent < lastPage;
      _fallbackTrackers.remove(trackerKey);
      return _Pager(hasMore: hasMore, nextPage: topCurrent + 1);
    }


    // 1) Laravel pagination ط´ط§ط¦ط¹:
    // meta: { current_page, last_page, next_page_url, per_page }

    dynamic meta = resp['meta'];
    if (meta == null) {
      final root = resp[Api.data] ?? resp['data'];
      if (root is Map) {
        meta = root['meta'] ?? root['pagination'];
      }
    }

    if (meta is Map) {
      final int current = (meta['current_page'] is int)
          ? meta['current_page'] as int
          : int.tryParse('${meta['current_page'] ?? ''}') ?? fallbackPage;

      // ظ‚ط¯ طھظƒظˆظ† ظپظٹ meta.pagination.{...}
      final pagination = meta['pagination'];
      if (pagination is Map) {
        final int current2 = (pagination['current_page'] is int)
            ? pagination['current_page'] as int
            : int.tryParse('${pagination['current_page'] ?? ''}') ?? current;

        final int last = (pagination['last_page'] is int)
            ? pagination['last_page'] as int
            : int.tryParse('${pagination['last_page'] ?? ''}') ?? current2;

        final bool hasMore = current2 < last ||
            (pagination['next_page_url'] ?? pagination['next'] ?? '') != null;
        _fallbackTrackers.remove(trackerKey);
        return _Pager(hasMore: hasMore, nextPage: current2 + 1);
      }

      final int last = (meta['last_page'] is int)
          ? meta['last_page'] as int
          : int.tryParse('${meta['last_page'] ?? ''}') ?? fallbackPage;

      final bool hasMore = current < last ||
          (meta['next_page_url'] ?? meta['next'] ?? '') != null;
      _fallbackTrackers.remove(trackerKey);
      return _Pager(hasMore: hasMore, nextPage: current + 1);
    }

    // 2) reviews: { data: [...], current_page, last_page }
    final reviews = (resp['data'] ?? resp['item'] ?? resp)['reviews'];
    if (reviews is Map) {
      final int current =
          int.tryParse('${reviews['current_page'] ?? ''}') ?? fallbackPage;
      final int last = int.tryParse('${reviews['last_page'] ?? ''}') ?? current;
      final bool hasMore = current < last ||
          (reviews['next_page_url'] ?? reviews['next'] ?? '') != null;
      _fallbackTrackers.remove(trackerKey);
      return _Pager(hasMore: hasMore, nextPage: current + 1);
    }

    // 3) fallback: ط§ط³طھظ†طھط¬ ظ…ظ† ط·ظˆظ„ ط§ظ„ظ†طھط§ط¦ط¬
    final tracker =
        _fallbackTrackers.putIfAbsent(trackerKey, () => _FallbackPageTracker());
    final String signature = _rowsSignature(rawRows);
    final String? previousSignature = tracker.lastSignature;
    final int? previousCount = tracker.lastCount;

    final Set<String> currentKeys = rawRows.map(_rowIdentityKey).toSet();
    final int? previousUniqueCount = tracker.lastUniqueCount;
    tracker.lastUniqueCount = currentKeys.length;

    final Set<String> seenRowKeys = tracker.seenRowKeys;
    final int uniqueBefore = seenRowKeys.length;
    seenRowKeys.addAll(currentKeys);
    final bool aggregatedGrew = seenRowKeys.length > uniqueBefore;

    final int? reportedTotal = _extractTotalReviews(resp);
    final int? previousReportedTotal = tracker.lastReportedTotal;
    if (reportedTotal != null) {
      tracker.lastReportedTotal = reportedTotal;
    }

    // ظ„ظ… ظٹطھظ… ط§ظ„ط¹ط«ظˆط± ط¹ظ„ظ‰ ط£ظٹ ظ…ط¹ظ„ظˆظ…ط§طھ طھط±ظ‚ظٹظ… طµط±ظٹط­ط© ظپظٹ ط§ظ„ط§ط³طھط¬ط§ط¨ط©طŒ ظ„ط°ظ„ظƒ ظ†طھظˆظ‚ظپ ط¨ط¹ط¯
    // ظ‡ط°ظ‡ ط§ظ„ط¬ظˆظ„ط© ط­طھظ‰ ظ„ط§ ظ†ط¯ط®ظ„ ظپظٹ ط­ظ„ظ‚ط§طھ ظ„ط§ ظ†ظ‡ط§ط¦ظٹط© ط¹ظ†ط¯ طھظƒط±ط§ط± ظ†ظپط³ ط§ظ„ظ†طھط§ط¦ط¬.
    bool hasMore = false;

    final bool duplicateBySignature = previousSignature != null &&
        previousSignature == signature &&
        (previousCount == null || previousCount == currentCount);
    if (duplicateBySignature) {
      hasMore = false;
    }

    final bool totalsConfirmRepeat = reportedTotal != null &&
        previousReportedTotal != null &&
        reportedTotal == previousReportedTotal;

    final bool uniqueCountDidNotIncrease = previousUniqueCount != null &&
        currentKeys.length <= previousUniqueCount;

    if (!aggregatedGrew && tracker.lastPage != null) {
      final bool repeatConfirmed = reportedTotal != null
          ? totalsConfirmRepeat
          : uniqueCountDidNotIncrease;
      if (repeatConfirmed) {
        hasMore = false;
      }
    }

    tracker
      ..lastSignature = signature
      ..lastCount = currentCount
      ..lastPage = fallbackPage;

    if (!hasMore) {
      _fallbackTrackers.remove(trackerKey);
    }

    return _Pager(
      hasMore: hasMore,
      nextPage: hasMore ? fallbackPage + 1 : fallbackPage,
    );
  }

  static double? _extractAverageRating(Map<String, dynamic> resp) {
    double? parse(dynamic value) {
      if (value is num) {
        return value.toDouble();
      }
      if (value is String) {
        return double.tryParse(value);
      }
      return null;
    }

    double? walk(dynamic node, int depth, Set<int> seen) {
      if (node == null || depth > 6) return null;
      final identity = identityHashCode(node);
      if (!seen.add(identity)) return null;

      if (node is Map) {
        for (final key in const {
          'average_rating',
          'avg_rating',
          'rating_avg',
          'rating_average',
          'averageRating',
          'average',
        }) {
          final parsed = parse(node[key]);
          if (parsed != null) {
            return parsed;
          }
        }

        for (final value in node.values) {
          final result = walk(value, depth + 1, seen);
          if (result != null) return result;
        }
      } else if (node is Iterable) {
        for (final value in node) {
          final result = walk(value, depth + 1, seen);
          if (result != null) return result;
        }
      }

      return null;
    }

    return walk(resp, 0, <int>{});
  }

  static int? _extractTotalReviews(Map<String, dynamic> resp) {
    int? parse(dynamic value) {
      if (value is int) {
        return value;
      }
      if (value is num) {
        return value.toInt();
      }
      if (value is String) {
        return int.tryParse(value);
      }
      return null;
    }

    int? walk(dynamic node, int depth, Set<int> seen) {
      if (node == null || depth > 6) return null;
      final identity = identityHashCode(node);
      if (!seen.add(identity)) return null;

      if (node is Map) {
        for (final key in const {
          'total_reviews',
          'reviews_count',
          'totalReviews',
          'reviewsTotal',
          'reviews_total',
        }) {
          final parsed = parse(node[key]);
          if (parsed != null) {
            return parsed;
          }
        }

        if (node.containsKey('total')) {
          final dynamic iterable =
              node['data'] ?? node['rows'] ?? node['items'] ?? node['list'];
          if (iterable is List) {
            final parsed = parse(node['total']);
            if (parsed != null) {
              return parsed;
            }
          }
        }

        for (final value in node.values) {
          final result = walk(value, depth + 1, seen);
          if (result != null) return result;
        }
      } else if (node is Iterable) {
        for (final value in node) {
          final result = walk(value, depth + 1, seen);
          if (result != null) return result;
        }
      }

      return null;
    }

    return walk(resp, 0, <int>{});
  }

  static bool _extractCanReview(Map<String, dynamic> resp) {
    try {
      if (!HiveUtils.isUserAuthenticated()) {
        return false;
      }
    } catch (_) {
      return false;
    }

    bool foundCanReviewKey = false;

    bool? parseBool(dynamic value) {
      if (value is bool) return value;
      if (value is num) return value != 0;
      if (value is String) {
        final normalized = value.trim().toLowerCase();
        if (normalized.isEmpty) return null;
        if (const {
          'true',
          '1',
          'yes',
          'y',
          't',
          'allowed',
          'allow',
          'can',
          'enabled',
          'enable',
        }.contains(normalized)) {
          return true;
        }
        if (const {
          'false',
          '0',
          'no',
          'n',
          'f',
          'not_allowed',
          'forbidden',
          'disabled',
          'deny',
          'denied',
          'cannot',
          'cant',
        }.contains(normalized)) {
          return false;
        }
      }
      return null;
    }

    bool? parseGuestFlag(dynamic value) {
      if (value == null) return null;
      if (value is bool) return value;
      if (value is num) return value != 0;
      final String normalized = value.toString().trim().toLowerCase();
      if (normalized.isEmpty) return null;
      if (const {'guest', 'visitor', 'anonymous'}.contains(normalized)) {
        return true;
      }
      if (const {'user', 'member', 'authenticated'}.contains(normalized)) {
        return false;
      }
      return null;
    }

    bool? walk(dynamic node, int depth, Set<int> seen) {
      if (node == null || depth > 6) return null;
      final id = identityHashCode(node);
      if (!seen.add(id)) return null;

      if (node is Map) {
        if (node.containsKey('can_review') || node.containsKey('canReview')) {
          foundCanReviewKey = true;
        }

        final dynamic directRaw = node['can_review'] ?? node['canReview'];
        final direct = parseBool(directRaw);

        if (direct != null) return direct;

        final dynamic guestFlag = node['is_guest'] ??
            node['guest'] ??
            node['guest_user'] ??
            node['isGuest'];
        final bool? isGuest = parseGuestFlag(guestFlag);
        if (isGuest == true) return false;

        final dynamic userType = node['user_type'] ?? node['userType'];
        final bool? userTypeGuest = parseGuestFlag(userType);
        if (userTypeGuest == true) return false;

        for (final key in [
          Api.data,
          'data',
          'meta',
          Api.item,
          'item',
          'service',
          'attributes',
          'extra',
          'pagination',
          'permissions',
          'response',
        ]) {
          final result = walk(node[key], depth + 1, seen);
          if (result != null) return result;
        }
      } else if (node is Iterable) {
        for (final child in node) {
          final result = walk(child, depth + 1, seen);
          if (result != null) return result;
        }
      }

      return null;
    }

    final bool? extracted = walk(resp, 0, <int>{});
    if (!foundCanReviewKey) {
      return false;
    }
    return extracted ?? false;
  }
}

class _Pager {
  final bool hasMore;
  final int nextPage;

  _Pager({required this.hasMore, required this.nextPage});
}

class _FallbackPageTracker {
  String? lastSignature;
  int? lastCount;
  int? lastPage;
  int? lastUniqueCount;
  int? lastReportedTotal;
  final Set<String> seenRowKeys = <String>{};
}


