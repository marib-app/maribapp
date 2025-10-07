import 'package:marib/data/model/cart/cart_safety_tip.dart';
import 'package:marib/utils/api.dart';
import 'package:marib/utils/app_telemetry.dart';



class CartTipsRepository {
  const CartTipsRepository();

  Future<CartSafetyTipsPayload?> fetchTips({
    required String department,
    required int itemId,
  }) async {

    AppTelemetry.record('tips_called', <String, dynamic>{
      'department': department,
      'item_id': itemId,
    });


    final Map<String, dynamic> response = await Api.get(
      url: Api.getTipsApi,
      queryParameters: <String, dynamic>{
        'department': department,
        'item_id': itemId,
      },
    );

    final Map<String, dynamic> payload =
    _resolvePayload(response, department: department);

    final CartSafetyTipsPayload tipsPayload =
    CartSafetyTipsPayload.fromJson(payload).copyWith(raw: payload);
    if (!tipsPayload.hasDisplayableContent) {
      AppTelemetry.record('tips_empty', <String, dynamic>{
        'department': department,
        'item_id': itemId,
      });
    }

    return tipsPayload;
  }

  Map<String, dynamic> _resolvePayload(
      Map<String, dynamic>? source, {
        required String department,
      }) {
    final Map<String, dynamic> fallback = <String, dynamic>{
      'tips': const <dynamic>[],
      'actions': const <dynamic>[],
      'product_link': null,
      'presentation': 'modal',
      'department': <String, dynamic>{
        'key': department,
        'label': department,
      },
    };

    if (source == null) {
      return fallback;
    }

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


    List<dynamic> normalizeList(dynamic value) {
      if (value is List) {
        return List<dynamic>.from(value);
      }
      if (value is Iterable) {
        return value.map((dynamic e) => e).toList();
      }
      return <dynamic>[];
    }


    final Iterable<dynamic> candidates = <dynamic>[
      source?['data'],
      source?['payload'],
      source?['result'],
      source,
    ];

    for (final dynamic candidate in candidates) {
      final Map<String, dynamic>? map = normalize(candidate);
      if (map == null) continue;
      final Map<String, dynamic> sanitized = Map<String, dynamic>.from(fallback);
      sanitized.addAll(map);

      sanitized['presentation'] = sanitized['presentation'] ??
          sanitized['display'] ??
          sanitized['style'] ??
          fallback['presentation'];
      sanitized['tips'] = normalizeList(sanitized['tips']);
      sanitized['actions'] = normalizeList(sanitized['actions']);
      sanitized['product_link'] = sanitized.containsKey('product_link')
          ? sanitized['product_link']
          : fallback['product_link'];
      sanitized['department'] = normalize(sanitized['department']) ??
          fallback['department'];

      final List<dynamic> tips = sanitized['tips'] as List<dynamic>? ??
          fallback['tips'] as List<dynamic>;
      final List<dynamic> actions = sanitized['actions'] as List<dynamic>? ??
          fallback['actions'] as List<dynamic>;
      final bool hasFallbackText = () {
        const List<String> keys = <String>[
          'disclaimer',
          'default_description',
          'description',
          'message',
          'text',
          'note',
          'return_policy_text',
        ];
        for (final String key in keys) {
          final dynamic value = sanitized[key];
          if (value is String && value.trim().isNotEmpty) {
            return true;
          }
        }
        return false;
      }();

      final bool hasMeaningfulContent = tips.isNotEmpty ||
          actions.isNotEmpty ||
          sanitized['product_link'] != null ||
          hasFallbackText;

      if (hasMeaningfulContent) {
        sanitized.remove('display');
        sanitized.remove('style');
        return sanitized;
      }

    }
    return fallback;
  }
}