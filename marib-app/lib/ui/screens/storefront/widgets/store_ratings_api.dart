import 'package:flutter/foundation.dart';
import 'package:marib/data/model/seller_ratings_model.dart' show UserRatings;
import 'package:marib/utils/api.dart';
import 'package:marib/utils/hive_utils.dart';

class StoreRatingsResult {
  final List<UserRatings> list;
  final bool hasMore;
  final int nextPage;
  final bool canReview;
  final double averageRating;
  final int totalReviews;
  final int storeId;
  final String? storeSlug;
  final UserRatings? myReview;
  final Map<int, int> distribution;

  StoreRatingsResult({
    required this.list,
    required this.hasMore,
    required this.nextPage,
    required this.canReview,
    required this.averageRating,
    required this.totalReviews,
    required this.storeId,
    required this.storeSlug,
    required this.myReview,
    required this.distribution,
  });
}

class StoreRatingsApi {
  static Future<StoreRatingsResult> fetchRatings({
    required int storeId,
    String? storeSlug,
    int page = 1,
    int perPage = 20,
    String? sort,
  }) async {
    final bool hasSlug = storeSlug != null && storeSlug.isNotEmpty;
    if (storeId <= 0 && !hasSlug) {
      throw Exception('Store id is missing');
    }
    final storeKey = storeId > 0
        ? storeId.toString()
        : Uri.encodeComponent(storeSlug!.trim());

    final resp = await Api.get(
      url: 'storefront/stores/$storeKey/reviews',
      queryParameters: {
        Api.page: page,
        'per_page': perPage,
        if (sort != null && sort.isNotEmpty) 'sort': sort,
      },
    );

    final List<Map<String, dynamic>> rows = _extractRows(resp);
    final list = rows.map(_toUserRatings).whereType<UserRatings>().toList();

    final meta = resp['meta'] as Map?;
    final currentPage = (meta?['current_page'] as num?)?.toInt() ?? page;
    final lastPage = (meta?['last_page'] as num?)?.toInt() ?? currentPage;
    final hasMore = currentPage < lastPage;
    final nextPage = hasMore ? currentPage + 1 : currentPage;

    final summary = (resp['summary'] as Map?) ?? const {};
    final averageRating =
        (summary['average_rating'] is num) ? (summary['average_rating'] as num).toDouble() : 0.0;
    final totalReviews = (summary['total_reviews'] as num?)?.toInt() ?? list.length;
    final bool canReview = summary['can_review'] == true && HiveUtils.isUserAuthenticated();
    final distribution = _parseDistribution(summary['distribution']);

    final myRaw = summary['my_review'];
    final myReview = myRaw is Map<String, dynamic> ? _toUserRatings(myRaw) : null;
    if (myReview != null && !list.any((r) => r.id != null && r.id == myReview.id)) {
      list.insert(0, myReview);
    }

    return StoreRatingsResult(
      list: list,
      hasMore: hasMore,
      nextPage: nextPage,
      canReview: canReview,
      averageRating: averageRating,
      totalReviews: totalReviews,
      storeId: storeId,
      storeSlug: storeSlug,
      myReview: myReview,
      distribution: distribution,
    );
  }

  static Future<bool> addRating({
    required int storeId,
    String? storeSlug,
    required int stars,
    String? comment,
  }) async {
    final bool hasSlug = storeSlug != null && storeSlug.isNotEmpty;
    if (storeId <= 0 && !hasSlug) {
      throw Exception('Store id is missing');
    }
    final storeKey = storeId > 0
        ? storeId.toString()
        : Uri.encodeComponent(storeSlug!.trim());
    final text = (comment ?? '').trim();
    final payload = <String, dynamic>{
      'rating': stars,
      if (text.isNotEmpty) 'comment': text,
    };

    final resp = await Api.post(
      url: 'storefront/stores/$storeKey/reviews',
      parameter: payload,
    );

    return resp['data'] != null || resp['status'] == true || resp['success'] == true;
  }

  static Future<bool> updateRating({
    required int storeId,
    String? storeSlug,
    required int stars,
    String? comment,
  }) async {
    final bool hasSlug = storeSlug != null && storeSlug.isNotEmpty;
    if (storeId <= 0 && !hasSlug) {
      throw Exception('Store id is missing');
    }
    final text = (comment ?? '').trim();
    final storeKey = storeId > 0
        ? storeId.toString()
        : Uri.encodeComponent(storeSlug!.trim());
    final payload = <String, dynamic>{
      'rating': stars,
      if (text.isNotEmpty) 'comment': text,
    };

    final resp = await Api.requestJson(
      url: 'storefront/stores/$storeKey/reviews',
      method: 'PUT',
      data: payload,
    );

    return resp['data'] != null || resp['status'] == true || resp['success'] == true;
  }

  static Future<bool> deleteRating({required int storeId, String? storeSlug}) async {
    final bool hasSlug = storeSlug != null && storeSlug.isNotEmpty;
    if (storeId <= 0 && !hasSlug) {
      throw Exception('Store id is missing');
    }
    final storeKey = storeId > 0
        ? storeId.toString()
        : Uri.encodeComponent(storeSlug!.trim());
    final resp = await Api.delete(url: 'storefront/stores/$storeKey/reviews');
    return resp['status'] == true || resp['success'] == true || resp['data'] != null;
  }

  static List<Map<String, dynamic>> _extractRows(Map<String, dynamic> resp) {
    final data = resp['data'];
    if (data is List) {
      return data.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    }
    if (data is Map && data['data'] is List) {
      return (data['data'] as List)
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
    }
    return const <Map<String, dynamic>>[];
  }

  static UserRatings? _toUserRatings(Map<String, dynamic> json) {
    try {
      final normalized = <String, dynamic>{...json};
      normalized['ratings'] ??= json['rating'];
      normalized['review'] ??= json['comment'];
      normalized['buyer'] ??= _mapUser(json['user']);
      normalized['item_id'] ??= json['store_id'];
      return UserRatings.fromJson(normalized);
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('StoreRatingsApi: parse error $e for $json');
      }
      return null;
    }
  }

  static Map<String, dynamic>? _mapUser(dynamic user) {
    if (user is Map) {
      return {
        'id': user['id'],
        'name': user['name'],
        'profile': user['profile'] ?? user['profile_photo_url'] ?? user['avatar'],
      };
    }
    return null;
  }

  static Map<int, int> _parseDistribution(dynamic value) {
    final Map<int, int> dist = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
    if (value is Map) {
      value.forEach((key, val) {
        final int? k = key is int ? key : int.tryParse(key.toString());
        final int? v = val is int ? val : (val is num ? val.toInt() : int.tryParse('$val'));
        if (k != null && k >= 1 && k <= 5 && v != null) {
          dist[k] = v;
        }
      });
    }
    return dist;
  }
}
