import 'package:marib/utils/api.dart';
import 'package:marib/data/model/item/item_model.dart';

class MapAdsRepository {
  final String endpoint; // Api.getItemApi
  MapAdsRepository({required this.endpoint});

  bool _isAbsoluteUrl(String u) {
    final s = u.toLowerCase();
    return s.startsWith('http://') || s.startsWith('https://');
  }

  Future<List<ItemModel>> fetchAllAds() async {
    final List<ItemModel> acc = [];

    Map<String, dynamic> resp = await Api.get(url: endpoint);
    _appendItems(resp, acc);

    String? nextUrl = _extractNext(resp);
    int? curr = _toInt(resp['data']?['current_page']);
    int? last = _toInt(resp['data']?['last_page']);
    final String? path = resp['data']?['path']?.toString();

    int safety = 0;
    while (true) {
      if (safety++ > 50) break;

      if (nextUrl != null && nextUrl.isNotEmpty) {
        final useBase = !_isAbsoluteUrl(nextUrl) ? true : false;
        resp = await Api.get(url: nextUrl, useBaseUrl: useBase);
        _appendItems(resp, acc);
        nextUrl = _extractNext(resp);
        curr = _toInt(resp['data']?['current_page']);
        last = _toInt(resp['data']?['last_page']);
        continue;
      }

      if (curr != null && last != null && curr < last) {
        final int nextPageNum = curr + 1;
        if (path != null && path.isNotEmpty) {
          final pageUrl = '$path?page=$nextPageNum';
          final useBase = !_isAbsoluteUrl(pageUrl) ? true : false;
          resp = await Api.get(url: pageUrl, useBaseUrl: useBase);
        } else {
          resp = await Api.get(
              url: endpoint, queryParameters: {'page': nextPageNum});
        }
        _appendItems(resp, acc);
        curr = _toInt(resp['data']?['current_page']);
        last = _toInt(resp['data']?['last_page']);
        nextUrl = _extractNext(resp);
        continue;
      }

      break;
    }

    return acc;
  }

  void _appendItems(Map<String, dynamic> r, List<ItemModel> acc) {
    final data = r['data'];
    List pageItems = const [];
    if (data is Map && data['data'] is List) {
      pageItems = data['data'];
    } else if (r['items'] is List) {
      pageItems = r['items'];
    }
    for (final e in pageItems) {
      if (e is Map<String, dynamic>) {
        acc.add(ItemModel.fromJson(e));
      } else if (e is Map) {
        acc.add(ItemModel.fromJson(Map<String, dynamic>.from(e)));
      }
    }
  }

  String? _extractNext(Map<String, dynamic> r) {
    final data = r['data'];
    if (data is Map &&
        data['next_page_url'] != null &&
        data['next_page_url'].toString().isNotEmpty) {
      return data['next_page_url'].toString();
    }
    if (r['next'] is String && (r['next'] as String).isNotEmpty) {
      return r['next'] as String;
    }
    return null;
  }

  int? _toInt(dynamic v) => v == null ? null : int.tryParse(v.toString());
}

/// تطبيع فئات بسيطة
String normalizeCategory(String? raw) {
  if (raw == null || raw.trim().isEmpty) return 'أخرى';
  final s = raw.trim().toLowerCase().replaceAll(RegExp(r'[\s\-_]+'), '');

  const map = {
    'سيارات': 'سيارات',
    'سيارة': 'سيارات',
    'cars': 'سيارات',
    'car': 'سيارات',
    'auto': 'سيارات',
    'عقارات': 'عقارات',
    'عقار': 'عقارات',
    'realestate': 'عقارات',
    'property': 'عقارات',
    'اجهزة': 'أجهزة',
    'أجهزة': 'أجهزة',
    'الكترونيات': 'أجهزة',
    'إلكترونيات': 'أجهزة',
    'electronics': 'أجهزة',
    'electronic': 'أجهزة',
  };

  if (map.containsKey(s)) return map[s]!;
  if (s.contains('car') || s.contains('auto')) return 'سيارات';
  if (s.contains('estate') || s.contains('real') || s.contains('property'))
    return 'عقارات';
  if (s.contains('electro') || s.contains('device')) return 'أجهزة';
  return 'أخرى';
}
