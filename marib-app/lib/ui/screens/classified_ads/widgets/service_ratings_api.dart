// lib/new_code/data/service_ratings_api.dart
import 'package:flutter/foundation.dart';
import 'package:marib/utils/api.dart';
import 'package:marib/data/model/seller_ratings_model.dart' show UserRatings;

class ServiceRatingsResult {
  final List<UserRatings> list;
  final bool hasMore;
  final int nextPage;
  final bool canReview;
  final double averageRating;
  final int totalReviews;


  ServiceRatingsResult({
    required this.list,
    required this.hasMore,
    required this.nextPage,
    required this.canReview,
    required this.averageRating,
    required this.totalReviews,

  });
}

class ServiceRatingsApi {
  /// جلب التعليقات/التقييمات لخدمة معيّنة
  static Future<ServiceRatingsResult> fetchRatings({
    required int itemId,
    int page = 1,
    int perPage = 20,
    String? sort, // "newest" | "highest" | "lowest" ...الخ (اختياري)
    String? serviceUid,

  }) async {
    final uid = serviceUid?.trim();

    // نستخدم getItemApi لأنه الأكثر ثباتًا لديكم،
    // ونمرر مفاتيح شائعة للترقيم/الفرز كي يتجاهلها الباك إند إن لم يدعمها.
    final Map<String, dynamic> resp = await Api.get(
      url: Api.serviceReviewsApi,
      queryParameters: {

        Api.page: page,

        'per_page': perPage,
        'service_id': itemId,
        if (uid != null && uid.isNotEmpty) 'service_uid': uid,
        if (uid != null && uid.isNotEmpty) 'uid': uid,

        if (sort != null) 'sort': sort,
      },
    );

    if (kDebugMode) {
      // اطبع مفتاحًا واحدًا صغيرًا للتشخيص فقط
      // (بدون إغراق اللوج)
      // ignore: avoid_print
      print('[ratings] got response keys: ${resp.keys.take(6).toList()}');
    }

    final rows = _extractReviewRows(resp);
    final list = rows.map(_toUserRatings).whereType<UserRatings>().toList();

    // استنتاج الترقيم من الاستجابة إن وُجد
    final pg = _extractPagination(resp,
        fallbackPage: page, perPage: perPage, currentCount: list.length);

    double totalRatings = 0;
    for (final rating in list) {
      totalRatings += (rating.ratings ?? 0).toDouble();
    }
    final double fallbackAverage = list.isEmpty ? 0.0 : totalRatings / list.length;
    final double averageRating = _extractAverageRating(resp) ?? fallbackAverage;

    final int fallbackTotal = ((page - 1) * perPage) + list.length;
    final int? extractedTotal = _extractTotalReviews(resp);
    final int totalReviews = extractedTotal != null
        ? (extractedTotal < fallbackTotal ? fallbackTotal : extractedTotal)
        : fallbackTotal;


    return ServiceRatingsResult(
      list: list,
      hasMore: pg.hasMore,
      nextPage: pg.nextPage,
      canReview: _extractCanReview(resp),
      averageRating: averageRating,
      totalReviews: totalReviews,
    );
  }

  /// إضافة تقييم/تعليق جديد
  static Future<bool> addRating({
    required int itemId,
    required int stars, // 1..5
    String? comment,
    String? serviceUid,

  }) async {
    final text = (comment ?? '').trim();
    final uid = serviceUid?.trim();

    final payload = <String, dynamic>{
      'service_id': itemId,
      'rating': stars,
      if (text.isNotEmpty) 'review': text,
      if (uid != null && uid.isNotEmpty) 'service_uid': uid,
      if (uid != null && uid.isNotEmpty) 'uid': uid,
    };

    final resp = await Api.post(url: Api.addServiceReviewApi, parameter: payload);

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
      final dynamic rawMessage = resp['message'] ?? resp['msg'] ?? resp['error'];
      final String? serverMessage =
      rawMessage is String ? rawMessage.trim() : rawMessage?.toString();

      throw ApiException(
        (serverMessage != null && serverMessage.isNotEmpty)
            ? serverMessage
            : 'تعذر إرسال التقييم',
      );
    }

    return true;
  }

  // (اختياري) جلب تقييم المستخدم الحالي لهذه الخدمة — لمنع التكرار أو لعرض زر "عدل تقييمك"

  static Future<UserRatings?> getMyReview({
    required int itemId,
    String? serviceUid,
  }) async {
    final uid = serviceUid?.trim();

    final resp = await Api.get(
      url: Api.myServiceReviewsApi,
      queryParameters: {
        'service_id': itemId,
        if (uid != null && uid.isNotEmpty) 'service_uid': uid,
        if (uid != null && uid.isNotEmpty) 'uid': uid,
      },
    );
    final row = _firstRow(resp);
    return row == null ? null : _toUserRatings(row);
  }

  /// (اختياري) الإبلاغ عن تعليق/تقييم معيّن
  static Future<bool> reportReview({
    required int reviewId,
    String? reasonText,
    String? serviceUid,

  }) async {
    final text = (reasonText ?? '').trim();
    final uid = serviceUid?.trim();

    final payload = <String, dynamic>{
      'review_id': reviewId,
      if (text.isNotEmpty) Api.message: text,
      if (text.isNotEmpty) 'details': text,
      'type': 'service',
      if (uid != null && uid.isNotEmpty) 'service_uid': uid,
      if (uid != null && uid.isNotEmpty) 'uid': uid,
    };

    final resp = await Api.post(url: Api.addServiceReviewReportApi, parameter: payload);

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

  /// يحاول استخراج مصفوفة التعليقات/التقييمات من أنماط شائعة
  static List<Map<String, dynamic>> _extractReviewRows(Map<String, dynamic> resp) {
    dynamic root = resp;

    // شائع: { data: {...} } أو { item: {...} }
    root = root[Api.data] ?? root['data'] ?? root;




    // في حال كان الجذر يحوي مباشرة على قائمة داخل data
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

    // أنماط كثيرة: reviews, ratings, comments, feedback, list, items, result
    for (final key in const [
      'reviews',
      'ratings',
      'comments',
      'feedback',
      'list',
      'items',
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
        return v.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
      }
    }

    // أحيانًا تكون المصفوفة مباشرة
    if (root is List) {
      return root.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    }

    // لا شيء
    return const <Map<String, dynamic>>[];
  }

  static Map<String, dynamic>? _firstRow(Map<String, dynamic> resp) {
    final rows = _extractReviewRows(resp);
    return rows.isNotEmpty ? rows.first : null;
  }

  /// تحويل مرن إلى UserRatings
  static UserRatings? _toUserRatings(Map<String, dynamic> m) {
    try {
      // وفّر مفاتيح افتراضية لكي يقرأها موديل UserRatings بسلاسة
      final rating = m['ratings'] ?? m['rating'] ?? m['stars'] ?? 0;
      final review = (m['review'] ?? m['comment'] ?? m['message'] ?? m['description'] ?? '').toString();
      final created = (m['created_at'] ?? m['created'] ?? m['date'] ?? m['updated_at'] ?? '').toString();

      final mm = Map<String, dynamic>.from(m);
      mm.putIfAbsent('ratings', () => rating);
      mm.putIfAbsent('review', () => review);
      mm.putIfAbsent('created_at', () => created);

      return UserRatings.fromJson(mm);
    } catch (_) {
      return null;
    }
  }

  /// إستنتاج معلومات الترقيم من أنماط شائعة أو من طول النتائج
  static _Pager _extractPagination(
      Map<String, dynamic> resp, {
        required int fallbackPage,
        required int perPage,
        required int currentCount,
      }) {
    // 1) Laravel pagination شائع:
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

      // قد تكون في meta.pagination.{...}
      final pagination = meta['pagination'];
      if (pagination is Map) {
        final int current2 = (pagination['current_page'] is int)
            ? pagination['current_page'] as int
            : int.tryParse('${pagination['current_page'] ?? ''}') ?? current;

        final int last = (pagination['last_page'] is int)
            ? pagination['last_page'] as int
            : int.tryParse('${pagination['last_page'] ?? ''}') ?? current2;

        final bool hasMore = current2 < last || (pagination['next_page_url'] ?? pagination['next'] ?? '') != null;
        return _Pager(hasMore: hasMore, nextPage: current2 + 1);
      }

      final int last = (meta['last_page'] is int)
          ? meta['last_page'] as int
          : int.tryParse('${meta['last_page'] ?? ''}') ?? fallbackPage;

      final bool hasMore = current < last || (meta['next_page_url'] ?? meta['next'] ?? '') != null;
      return _Pager(hasMore: hasMore, nextPage: current + 1);
    }

    // 2) reviews: { data: [...], current_page, last_page }
    final reviews = (resp['data'] ?? resp['item'] ?? resp)['reviews'];
    if (reviews is Map) {
      final int current = int.tryParse('${reviews['current_page'] ?? ''}') ?? fallbackPage;
      final int last = int.tryParse('${reviews['last_page'] ?? ''}') ?? current;
      final bool hasMore = current < last || (reviews['next_page_url'] ?? reviews['next'] ?? '') != null;
      return _Pager(hasMore: hasMore, nextPage: current + 1);
    }

    // 3) fallback: استنتج من طول النتائج
    final hasMore = currentCount >= perPage;
    return _Pager(hasMore: hasMore, nextPage: fallbackPage + 1);
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

        if (node.containsKey('total') && node['data'] is List) {
          final parsed = parse(node['total']);
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


  static bool _extractCanReview(Map<String, dynamic> resp) {
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

    bool? walk(dynamic node, int depth, Set<int> seen) {
      if (node == null || depth > 6) return null;
      final id = identityHashCode(node);
      if (!seen.add(id)) return null;

      if (node is Map) {
        final direct = parseBool(node['can_review']);
        if (direct != null) return direct;

        for (final key in  [
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

    return walk(resp, 0, <int>{}) ?? true;
  }




}

class _Pager {
  final bool hasMore;
  final int nextPage;
  _Pager({required this.hasMore, required this.nextPage});
}
