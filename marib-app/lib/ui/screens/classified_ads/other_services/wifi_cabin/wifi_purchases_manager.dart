import 'package:flutter/foundation.dart';

import 'package:marib/data/model/wifi/wifi_purchase.dart';
import 'package:marib/data/wifi/wifi_repository.dart';
import 'package:marib/utils/api.dart';

class WifiPurchasesManager {
  WifiPurchasesManager(this._repository);

  final WifiRepository _repository;

  final ValueNotifier<List<WifiPurchase>> purchases =
  ValueNotifier<List<WifiPurchase>>(const <WifiPurchase>[]);
  final ValueNotifier<bool> loading = ValueNotifier<bool>(false);
  final ValueNotifier<String?> error = ValueNotifier<String?>(null);

  bool _hasLoaded = false;

  Future<void> fetch({bool force = false}) async {
    if (loading.value) return;
    if (!force && _hasLoaded) return;
    _hasLoaded = true;
    loading.value = true;
    error.value = null;
    try {
      final results = await _repository.fetchPurchases();
      purchases.value = results;
    } catch (err) {
      error.value = _describeError(err);
    } finally {
      loading.value = false;
    }
  }

  Future<void> refresh() => fetch(force: true);

  void register(WifiPurchase purchase) {
    final WifiPurchase sanitized = purchase.withoutCodes();

    final int index = current.indexWhere((element) => element.id == sanitized.id);

    final int index = current.indexWhere((element) => element.id == purchase.id);
    if (index >= 0) {
      current[index] = sanitized;

    } else {
      current.insert(0, sanitized);

    }
    purchases.value = current;
    error.value = null;
    _hasLoaded = true;
  }

  void dispose() {
    purchases.dispose();
    loading.dispose();
    error.dispose();
  }

  String _describeError(Object error) {
    if (error is ApiHttpException) {
      final Map<String, dynamic> payload =
      error.payload is Map<String, dynamic>
          ? Map<String, dynamic>.from(error.payload as Map)
          : error.payload is Map
          ? Map<String, dynamic>.from(error.payload as Map)
          : <String, dynamic>{};
      final String? base = _stringify(
        payload['message'] ?? payload['error'] ?? payload['detail'],
      );
      final List<String> details = _flattenErrors(payload['errors']);
      final List<String> parts = <String>[
        if (base != null && base.isNotEmpty) base,
        if (details.isNotEmpty) details.join('\n'),
      ];
      if (parts.isEmpty) {
        return error.toString();
      }
      return parts.join('\n');
    }
    if (error is ApiException) {
      return error.toString();
    }
    return error.toString();
  }

  String? _stringify(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      return value.trim().isEmpty ? null : value.trim();
    }
    return value.toString();
  }

  List<String> _flattenErrors(dynamic value) {
    if (value == null) return const <String>[];
    if (value is List) {
      return value
          .map((dynamic element) => _stringify(element))
          .whereType<String>()
          .where((element) => element.isNotEmpty)
          .toList();
    }
    if (value is Map) {
      final List<String> results = <String>[];
      value.forEach((_, dynamic element) {
        final List<String> nested = _flattenErrors(element);
        if (nested.isEmpty) {
          final String? candidate = _stringify(element);
          if (candidate != null && candidate.isNotEmpty) {
            results.add(candidate);
          }
        } else {
          results.addAll(nested);
        }
      });
      return results;
    }
    final String? single = _stringify(value);
    if (single == null || single.isEmpty) {
      return const <String>[];
    }
    return <String>[single];
  }
}