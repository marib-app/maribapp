import 'package:marib/data/model/data_output.dart';
import 'package:marib/data/model/wallet/wallet_withdrawal.dart';
import 'package:marib/data/model/wallet/wallet_operation_options.dart';
import 'package:marib/utils/api.dart';
import 'package:marib/utils/constant.dart';
import 'package:marib/utils/payment/manual_payment.dart';
import 'package:marib/data/model/wallet/manual_payment_requests_summary.dart';

class WalletOperationsRepository {
  Future<WalletWithdrawalsResult> fetchWithdrawals({
    int page = 1,
    int? perPage,
    Map<String, dynamic>? filters,
    bool includeOptions = true,
  }) async {
    final query = <String, dynamic>{
      Api.pageQuery: page,
      Api.perPageQuery: perPage ?? Constant.loadLimit,
      if (filters != null) ...filters,
      if (!includeOptions) 'include_options': '0',
    };

    final response = await Api.get(
      url: Api.walletWithdrawalsApi,
      queryParameters: query,
    );

    final rows = _unwrapList(response, const [
      'withdrawals',
      'data',
      'items',
      'results',
      'rows',
      'payload',
    ]);

    final responseCurrency = _unwrapCurrency(response);

    final withdrawals = rows
        .map((row) {
      final map = Map<String, dynamic>.from(row);
      final existing = map['currency'] ?? map['currency_code'];
      final hasCurrency = existing != null && existing.toString().trim().isNotEmpty;
      if (!hasCurrency && responseCurrency != null) {
        map['currency'] = responseCurrency;
      }
      return WalletWithdrawal.fromJson(map);
    })
        .toList();

    final metaMap = _unwrapMeta(response);
    final currentPage = _parseInt(metaMap['current_page']) ?? page;
    final lastPage = _parseInt(metaMap['last_page']);
    final perPageValue = _parseInt(metaMap['per_page']) ?? (perPage ?? Constant.loadLimit);
    final total = _parseInt(metaMap['total']) ?? withdrawals.length;
    final hasMore = _resolveHasMore(metaMap, currentPage, lastPage, perPageValue, withdrawals.length);

    final optionsMap = _unwrapOptions(response);
    final options = optionsMap != null ? WalletOperationOptions.fromMap(optionsMap) : null;

    return WalletWithdrawalsResult(
      data: DataOutput<WalletWithdrawal>(
        total: total,
        modelList: withdrawals,
        page: currentPage,
        extraData: ExtraData(
          data: WalletWithdrawalsMeta(
            currentPage: currentPage,
            lastPage: lastPage,
            hasMore: hasMore,
            perPage: perPageValue,
          ),
        ),
      ),
      options: options,
    );
  }

  Future<WalletOperationOptions?> fetchWithdrawalOptions({String? clientTag}) async {
    final response = await Api.get(
      url: Api.walletWithdrawalOptionsApi,
      queryParameters: {
        if (clientTag != null && clientTag.isNotEmpty) 'client_tag': clientTag,
      },
    );

    final optionsMap = _unwrapOptions(response) ?? response;
    if (optionsMap.isEmpty) {
      return null;
    }
    return WalletOperationOptions.fromMap(optionsMap);
  }

  Future<WalletWithdrawal> submitWithdrawal({
    required Map<String, dynamic> payload,
  }) async {
    final response = await Api.post(
      url: Api.walletWithdrawalsApi,
      parameter: payload,
      extraHeaders: <String, dynamic>{
        'Idempotency-Key': Api.generateIdempotencyKey(),
      },
    );

    final map = _unwrapSingle(response, const [
      'withdrawal',
      'data',
      'item',
      'result',
      'payload',
    ]);

    return WalletWithdrawal.fromJson(map);
  }

  Future<Map<String, dynamic>> submitTransfer({
    required Map<String, dynamic> payload,
  }) async {
    final response = await Api.post(
      url: Api.walletTransfersApi,
      parameter: payload,
    );

    return Map<String, dynamic>.from(response);
  }

  Future<DataOutput<ManualPayment>> fetchManualPaymentRequests({
    int page = 1,
    int? perPage,
    Map<String, dynamic>? filters,
  }) async {
    final query = <String, dynamic>{
      Api.pageQuery: page,
      Api.perPageQuery: perPage ?? Constant.loadLimit,
      if (filters != null) ...filters,
    };

    final response = await Api.get(
      url: Api.manualPaymentRequestsApi,
      queryParameters: query,
    );

    final rows = _unwrapList(response, const [
      'manual_payment_requests',
      'payment_transactions',
      'transactions',
      'data',
      'items',
      'results',
    ]);

    final requests = <ManualPayment>[];
    for (final row in rows) {
      try {
        requests.add(ManualPayment.fromJson(row));
      } catch (_) {}
    }

    final metaMap = _unwrapMeta(response);
    final currentPage = _parseInt(metaMap['current_page']) ?? page;
    final lastPage = _parseInt(metaMap['last_page']);
    final perPageValue = _parseInt(metaMap['per_page']) ?? (perPage ?? Constant.loadLimit);
    final total = _parseInt(metaMap['total']) ?? requests.length;
    final hasMore = _resolveHasMore(metaMap, currentPage, lastPage, perPageValue, requests.length);


    final statsMap = _unwrapStats(response);
    ManualPaymentRequestsSummary? summary;
    if (statsMap != null && statsMap.isNotEmpty) {
      summary = ManualPaymentRequestsSummary.fromJson(statsMap);
    }

    final meta = WalletWithdrawalsMeta(
      currentPage: currentPage,
      lastPage: lastPage,
      hasMore: hasMore,
      perPage: perPageValue,
    );

    return DataOutput<ManualPayment>(
      total: total,
      modelList: requests,
      page: currentPage,
      extraData: ExtraData(
        data: ManualPaymentRequestsExtraData(
          meta: meta,
          summary: summary,
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _unwrapList(
      Map<String, dynamic> response,
      List<String> candidates,
      ) {
    dynamic payload = response;
    if (payload is Map && payload.containsKey('data')) {
      payload = payload['data'];
    }
    if (payload is List) {
      return payload
          .whereType<dynamic>()
          .map((e) => e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e as Map))
          .toList();
    }
    if (payload is Map) {
      final map = Map<String, dynamic>.from(payload);
      for (final key in candidates) {
        final value = map[key];
        if (value is List) {
          return value
              .whereType<dynamic>()
              .map((e) => e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e as Map))
              .toList();
        }
        if (value is Map) {
          payload = value;
          return _unwrapList(payload as Map<String, dynamic>, candidates);
        }
      }
    }
    return const [];
  }

  Map<String, dynamic>? _unwrapOptions(Map<String, dynamic> response) {
    final candidates = [
      response['options'],
      response['withdrawal_options'],
      response['meta'] is Map ? (response['meta'] as Map)['options'] : null,
    ];

    for (final candidate in candidates) {
      if (candidate is Map<String, dynamic>) {
        return Map<String, dynamic>.from(candidate);
      }
      if (candidate is Map) {
        return candidate.map((key, value) => MapEntry(key.toString(), value));
      }
    }
    return null;
  }


  String? _unwrapCurrency(Map<String, dynamic> response) {
    String? normalize(dynamic value) {
      if (value == null) return null;
      final text = value.toString().trim();
      return text.isEmpty ? null : text;
    }

    final direct = normalize(response['currency']);
    if (direct != null) return direct;

    final data = response['data'];
    if (data is Map<String, dynamic>) {
      final nested = normalize(data['currency'] ?? data['currency_code']);
      if (nested != null) return nested;
    } else if (data is Map) {
      final map = data.map((key, value) => MapEntry(key.toString(), value));
      final nested = normalize(map['currency'] ?? map['currency_code']);
      if (nested != null) return nested;
    }

    final meta = response['meta'];
    if (meta is Map<String, dynamic>) {
      final nested = normalize(meta['currency'] ?? meta['currency_code']);
      if (nested != null) return nested;
    } else if (meta is Map) {
      final map = meta.map((key, value) => MapEntry(key.toString(), value));
      final nested = normalize(map['currency'] ?? map['currency_code']);
      if (nested != null) return nested;
    }

    return null;
  }

  Map<String, dynamic> _unwrapMeta(Map<String, dynamic> response) {
    final candidates = [
      response['meta'],
      response['pagination'],
      response['pager'],
      response['links'],
    ];

    for (final candidate in candidates) {
      if (candidate is Map<String, dynamic>) {
        return Map<String, dynamic>.from(candidate);
      }
      if (candidate is Map) {
        return candidate.map((key, value) => MapEntry(key.toString(), value));
      }
    }

    return const {};
  }


  Map<String, dynamic>? _unwrapStats(dynamic response) {
    if (response is Map<String, dynamic>) {
      final stats = response['stats'];
      if (stats is Map<String, dynamic>) {
        return Map<String, dynamic>.from(stats);
      }
      if (stats is Map) {
        return stats.map((key, value) => MapEntry(key.toString(), value));
      }
      for (final key in const ['data', 'meta']) {
        if (response.containsKey(key)) {
          final nested = _unwrapStats(response[key]);
          if (nested != null) {
            return nested;
          }
        }
      }
      return null;
    }
    if (response is Map) {
      final map = response.map((key, value) => MapEntry(key.toString(), value));
      return _unwrapStats(map);
    }
    return null;
  }


  Map<String, dynamic> _unwrapSingle(
      Map<String, dynamic> response,
      List<String> candidates,
      ) {
    dynamic payload = response;
    for (var depth = 0; depth < 5; depth++) {
      if (payload is Map<String, dynamic>) {
        for (final key in candidates) {
          if (payload.containsKey(key) && payload[key] is Map) {
            payload = payload[key];
            break;
          }
        }
        if (payload is Map<String, dynamic>) {
          return payload;
        }
      } else if (payload is Map) {
        payload = payload.map((key, value) => MapEntry(key.toString(), value));
      } else {
        break;
      }
    }

    if (payload is Map<String, dynamic>) {
      return payload;
    }
    if (payload is Map) {
      return payload.map((key, value) => MapEntry(key.toString(), value));
    }
    throw ApiException('invalid-response');
  }

  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String && value.isNotEmpty) {
      return int.tryParse(value);
    }
    return null;
  }

  bool _resolveHasMore(
      Map<String, dynamic> meta,
      int currentPage,
      int? lastPage,
      int perPage,
      int count,
      ) {
    if (meta['has_more'] is bool) {
      return meta['has_more'] as bool;
    }
    if (meta['has_more'] is String) {
      final value = meta['has_more'] as String;
      if (value == '1' || value.toLowerCase() == 'true') {
        return true;
      }
      if (value == '0' || value.toLowerCase() == 'false') {
        return false;
      }
    }
    if (lastPage != null) {
      return currentPage < lastPage;
    }
    if (meta['next_page'] != null) {
      final nextPage = _parseInt(meta['next_page']);
      if (nextPage != null) {
        return nextPage > currentPage;
      }
    }
    return count >= perPage;
  }
}

class WalletWithdrawalsResult {
  WalletWithdrawalsResult({
    required this.data,
    this.options,
  });

  final DataOutput<WalletWithdrawal> data;
  final WalletOperationOptions? options;
}

class WalletWithdrawalsMeta {
  const WalletWithdrawalsMeta({
    this.currentPage = 1,
    this.lastPage,
    this.hasMore = false,
    this.perPage,
  });

  final int currentPage;
  final int? lastPage;
  final bool hasMore;
  final int? perPage;

  WalletWithdrawalsMeta copyWith({
    int? currentPage,
    int? lastPage,
    bool? hasMore,
    int? perPage,
  }) {
    return WalletWithdrawalsMeta(
      currentPage: currentPage ?? this.currentPage,
      lastPage: lastPage ?? this.lastPage,
      hasMore: hasMore ?? this.hasMore,
      perPage: perPage ?? this.perPage,
    );
  }
}

class ManualPaymentRequestsExtraData {
  const ManualPaymentRequestsExtraData({
    required this.meta,
    this.summary,
  });

  final WalletWithdrawalsMeta meta;
  final ManualPaymentRequestsSummary? summary;
}