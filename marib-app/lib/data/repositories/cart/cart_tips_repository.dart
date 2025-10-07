import 'package:marib/data/model/cart/cart_safety_tip.dart';
import 'package:marib/utils/api.dart';

class CartTipsRepository {
  const CartTipsRepository();

  Future<CartSafetyTipsPayload?> fetchTips({
    required String department,
    required int itemId,
  }) async {
    final Map<String, dynamic> response = await Api.get(
      url: Api.getTipsApi,
      queryParameters: <String, dynamic>{
        'department': department,
        'item_id': itemId,
      },
    );

    final Map<String, dynamic>? payload = _extractPayload(response);
    if (payload == null) {
      return null;
    }

    final CartSafetyTipsPayload tipsPayload =
        CartSafetyTipsPayload.fromJson(payload).copyWith(raw: payload);
    if (!tipsPayload.hasTips) {
      return null;
    }

    return tipsPayload;
  }

  Map<String, dynamic>? _extractPayload(Map<String, dynamic>? source) {
    if (source == null) return null;

    Map<String, dynamic>? normalize(dynamic value) {
      if (value == null) return null;
      if (value is Map<String, dynamic>) return value;
      if (value is Map) {
        return value.map(
          (dynamic key, dynamic value) => MapEntry(key.toString(), value),
        );
      }
      return null;
    }

    final Iterable<dynamic> candidates = <dynamic>[
      source,
      source['data'],
      source['payload'],
      source['result'],
      source['tips'],
    ];

    for (final dynamic candidate in candidates) {
      final Map<String, dynamic>? map = normalize(candidate);
      if (map == null) continue;
      final List<dynamic>? tipsList = _extractTipsList(map);
      if (tipsList != null && tipsList.isNotEmpty) {
        return <String, dynamic>{
          'tips': tipsList,
          'presentation': map['presentation'] ?? map['display'] ?? map['style'],
          'raw': map,
        };
      }
    }

    return null;
  }

  List<dynamic>? _extractTipsList(Map<String, dynamic> map) {
    final List<String> keys = <String>[
      'tips',
      'data',
      'items',
      'records',
      'rows',
      'entries',
    ];

    for (final String key in keys) {
      final dynamic value = map[key];
      if (value is List) {
        return value;
      }
      if (value is Map) {
        final Map<String, dynamic>? inner = value.map(
          (dynamic key, dynamic value) => MapEntry(key.toString(), value),
        );
        if (inner == null) continue;
        final List<dynamic>? nested = _extractTipsList(inner);
        if (nested != null && nested.isNotEmpty) {
          return nested;
        }
      }
    }

    return null;
  }
}
