import 'package:marib/data/model/data_output.dart';
import 'package:marib/data/model/market_news.dart';
import 'package:marib/utils/api.dart';

class MarketNewsRepository {
  Future<DataOutput<MarketNews>> fetchNews({
    int page = 1,
    int perPage = 10,
    int? itemId,
    int? governorateId,
    String? tag,
    String? search,
  }) async {
    final Map<String, dynamic> parameters = <String, dynamic>{
      Api.pageQuery: page,
      Api.perPageQuery: perPage,
    };

    if (itemId != null) {
      parameters[Api.itemIdQuery] = itemId;
    }
    if (governorateId != null) {
      parameters[Api.governorateIdQuery] = governorateId;
    }
    if (tag != null && tag.isNotEmpty) {
      parameters[Api.tagQuery] = tag;
    }
    if (search != null && search.isNotEmpty) {
      parameters[Api.searchQuery] = search;
    }

    final Map<String, dynamic> response =
    await Api.get(url: Api.marketNewsApi, queryParameters: parameters);

    final Map<String, dynamic> payload =
    Map<String, dynamic>.from(response['data'] as Map? ?? <String, dynamic>{});

    final List<dynamic> items = List<dynamic>.from(
      (payload['data'] as List?) ?? const <dynamic>[],
    );

    final Map<String, dynamic> meta =
    Map<String, dynamic>.from(payload['meta'] as Map? ?? <String, dynamic>{});

    final int total = _readInt(meta['total']) ?? items.length;
    final int currentPage = _readInt(meta['current_page']) ?? page;

    final List<MarketNews> news = items
        .map((dynamic element) =>
        MarketNews.fromJson(Map<String, dynamic>.from(element as Map? ?? {})))
        .toList(growable: false);

    return DataOutput<MarketNews>(
      total: total,
      modelList: news,
      page: currentPage,
    );
  }

  Future<MarketNews> fetchDetail(String slug) async {
    final Map<String, dynamic> response =
    await Api.get(url: Api.marketNewsDetailApi(slug));

    final Map<String, dynamic> payload =
    Map<String, dynamic>.from(response['data'] as Map? ?? <String, dynamic>{});

    return MarketNews.fromJson(payload);
  }

  int? _readInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }
}