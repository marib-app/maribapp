import 'package:marib/utils/api.dart';
import 'package:marib/data/model/item/item_model.dart';

import 'package:marib/data/model/category_model.dart';
import 'package:marib/data/model/item/item_model.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapAdsRepository {
  final String endpoint; // Api.getItemApi
  MapAdsRepository({required this.endpoint});

  Future<AdsPageResult> fetchAdsPage({
    int page = 1,
    LatLngBounds? bounds,
    int? perPage,
  }) async {
    final query = <String, dynamic>{
      'page': page,
    };

    if (perPage != null) {
      query['per_page'] = perPage;
    }

    if (bounds != null) {
      query
        ..['sw_lat'] = bounds.southwest.latitude
        ..['sw_lng'] = bounds.southwest.longitude
        ..['ne_lat'] = bounds.northeast.latitude
        ..['ne_lng'] = bounds.northeast.longitude;
    }

    final resp = await Api.get(url: endpoint, queryParameters: query);
    return _toAdsPageResult(resp, fallbackPage: page);

  }

  AdsPageResult _toAdsPageResult(Map<String, dynamic> resp, {required int fallbackPage}) {
    final List<ItemModel> items = [];

    Map<String, dynamic>? meta;
    if (resp['data'] is Map<String, dynamic>) {
      meta = Map<String, dynamic>.from(resp['data'] as Map);

    }
    final List<dynamic> payload;
    if (meta != null && meta['data'] is List) {
      payload = List<dynamic>.from(meta['data'] as List);
    } else if (resp['items'] is List) {
      payload = List<dynamic>.from(resp['items'] as List);
    } else {
      payload = const [];
    }
    for (final raw in payload) {
      if (raw is Map<String, dynamic>) {
        items.add(ItemModel.fromJson(raw));
      } else if (raw is Map) {
        items.add(ItemModel.fromJson(Map<String, dynamic>.from(raw)));
      }
    }
    final current = _toInt(meta?['current_page']) ?? fallbackPage;
    final last = _toInt(meta?['last_page']) ?? current;
    final perPage = _toInt(meta?['per_page']) ?? items.length;
    final total = _toInt(meta?['total']) ?? items.length;

    return AdsPageResult(
      items: items,
      currentPage: current,
      lastPage: last,
      perPage: perPage,
      total: total,
    );
  }

  int? _toInt(dynamic v) => v == null ? null : int.tryParse(v.toString());
}



class AdsPageResult {
  final List<ItemModel> items;
  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;

  const AdsPageResult({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
  });

  bool get hasMore => currentPage < lastPage;
}

/// تطبيع فئات بسيطة
String normalizeCategory(String? raw) {
  if (raw == null || raw.trim().isEmpty) return 'أخرى';
  final s = raw.trim().toLowerCase().replaceAll(RegExp(r'[\s\-_]+'), '');

  const map = {
    'سيارات': 'سيارات', 'سيارة': 'سيارات', 'cars': 'سيارات', 'car': 'سيارات', 'auto': 'سيارات',
    'عقارات': 'عقارات', 'عقار': 'عقارات', 'realestate': 'عقارات', 'property': 'عقارات',
    'اجهزة': 'أجهزة', 'أجهزة': 'أجهزة', 'الكترونيات': 'أجهزة', 'إلكترونيات': 'أجهزة',
    'electronics': 'أجهزة', 'electronic': 'أجهزة',
  };

  if (map.containsKey(s)) return map[s]!;
  if (s.contains('car') || s.contains('auto')) return 'سيارات';
  if (s.contains('estate') || s.contains('real') || s.contains('property')) return 'عقارات';
  if (s.contains('electro') || s.contains('device')) return 'أجهزة';
  return 'أخرى';
}
