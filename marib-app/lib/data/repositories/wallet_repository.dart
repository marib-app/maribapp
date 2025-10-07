import 'package:marib/data/model/data_output.dart';
import 'package:marib/data/model/wallet/wallet_filter.dart';
import 'package:marib/data/model/wallet/wallet_summary.dart';
import 'package:marib/data/model/wallet/wallet_transaction.dart';
import 'package:marib/utils/api.dart';
import 'package:marib/utils/constant.dart';

class WalletRepository {
  Future<WalletSummary> fetchSummary({String? filter}) async {
    final response = await Api.get(
      url: Api.walletSummaryApi,
      queryParameters: {
        if (filter != null && filter.isNotEmpty) Api.filterQuery: filter,
      },
    );

    final summaryPayload = _unwrapSummary(response);
    final summary = WalletSummary.fromJson(summaryPayload);

    final filters = WalletFilter.fromResponse(
      response['filters'] ?? response['available_filters'] ?? summaryPayload['filters'],
    );

    return summary.copyWith(availableFilters: summary.availableFilters.isEmpty ? filters : summary.availableFilters);
  }

  Future<DataOutput<WalletTransaction>> fetchTransactions({
    int page = 1,
    int? perPage,
    String? filter,
  }) async {
    final query = <String, dynamic>{
      Api.pageQuery: page,
      Api.perPageQuery: perPage ?? Constant.loadLimit,
      if (filter != null && filter.isNotEmpty) Api.filterQuery: filter,
    };

    final response = await Api.get(
      url: Api.walletTransactionsApi,
      queryParameters: query,
    );

    final rows = _unwrapTransactions(response);
    final transactions = rows.map(WalletTransaction.fromJson).toList();

    final metaMap = _unwrapMeta(response);
    final filters = WalletFilter.fromResponse(
      response['filters'] ?? response['available_filters'] ?? metaMap['filters'],
    );

    final meta = WalletTransactionsMeta(
      currentPage: _tryParseInt(metaMap['current_page']) ?? page,
      lastPage: _tryParseInt(metaMap['last_page']),
      hasMore: _parseHasMore(metaMap, page, rows.length),
      availableFilters: filters,
    );

    final total = _tryParseInt(metaMap['total']) ?? rows.length;

    return DataOutput<WalletTransaction>(
      total: total,
      modelList: transactions,
      extraData: ExtraData(data: meta),
      page: meta.currentPage,
    );
  }

  Map<String, dynamic> _unwrapSummary(Map<String, dynamic> response) {
    if (response.containsKey('data') && response['data'] is Map) {
      return Map<String, dynamic>.from(response['data'] as Map);
    }
    if (response.containsKey('summary') && response['summary'] is Map) {
      return Map<String, dynamic>.from(response['summary'] as Map);
    }
    return Map<String, dynamic>.from(response);
  }

  List<Map<String, dynamic>> _unwrapTransactions(Map<String, dynamic> response) {
    final candidates = [
      response['data'],
      response['transactions'],
      response['items'],
      response['results'],
      response['rows'],
      response['payload'],
    ];

    for (final candidate in candidates) {
      if (candidate is List) {
        return candidate
            .whereType<dynamic>()
            .map((e) => e is Map<String, dynamic>
            ? e
            : Map<String, dynamic>.from(e as Map))
            .toList();
      }
      if (candidate is Map) {
        final map = Map<String, dynamic>.from(candidate as Map);
        final nested = map['data'] ?? map['items'];
        if (nested is List) {
          return nested
              .whereType<dynamic>()
              .map((e) => e is Map<String, dynamic>
              ? e
              : Map<String, dynamic>.from(e as Map))
              .toList();
        }
      }
    }

    return const [];
  }

  Map<String, dynamic> _unwrapMeta(Map<String, dynamic> response) {
    final metaCandidates = [
      response['meta'],
      response['pagination'],
      response['links'],
      response['pager'],
    ];

    for (final meta in metaCandidates) {
      if (meta is Map) {
        return Map<String, dynamic>.from(meta as Map);
      }
    }

    final total = response['total'];
    if (total != null) {
      return {'total': total, 'current_page': response['page'] ?? 1};
    }

    return const {};
  }

  bool _parseHasMore(Map<String, dynamic> meta, int page, int rowCount) {
    final bool? explicit = _tryParseBool(meta['has_more']);
    if (explicit != null) {
      return explicit;
    }

    final lastPage = _tryParseInt(meta['last_page']);
    if (lastPage != null) {
      return page < lastPage;
    }

    final int? perPage = _tryParseInt(meta['per_page']);
    if (perPage != null) {
      return rowCount >= perPage;
    }

    final nextPage = _tryParseInt(meta['next_page']) ?? _tryParseInt(meta['next']);
    if (nextPage != null) {
      return nextPage > page;
    }

    return false;
  }

  int? _tryParseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String && value.isNotEmpty) {
      return int.tryParse(value);
    }
    return null;
  }

  bool? _tryParseBool(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      switch (value.toLowerCase()) {
        case 'true':
        case '1':
        case 'yes':
          return true;
        case 'false':
        case '0':
        case 'no':
          return false;
      }
    }
    return null;
  }
}