import 'package:marib/data/model/data_output.dart';
import 'package:marib/data/model/safety_tips_model.dart';
import 'package:marib/utils/api.dart';

class SafetyTipsRepository {
  Future<DataOutput<SafetyTipsModel>> fetchTipsList({
    required String department,
    required int itemId,
  }) async {

    try {
      Map<String, dynamic> response = await Api.get(
        url: Api.getTipsApi,
        queryParameters: <String, dynamic>{
          'department': department,
          'item_id': itemId,
        },
      );

      final Map<String, dynamic> data = _normalizeMap(response['data']);
      final SafetyTipsDepartment? departmentModel =
      SafetyTipsDepartment.fromNullableJson(data['department']);
      final String? productLink = _stringOrNull(data['product_link']);
      final List<SafetyTipAction> actions =
      SafetyTipAction.parseList(data['actions']);

      final List<SafetyTipsModel> list = _normalizeList(data['tips'])
          .map(
            (tip) => SafetyTipsModel.fromJson(
          tip,
          department: departmentModel,
          productLink: productLink,
          sharedActions: actions,
        ),
      )
          .toList();

      return DataOutput(total: list.length, modelList: list);
    } catch (e) {
      rethrow;
    }
  }
}
Map<String, dynamic> _normalizeMap(dynamic source) {
  if (source is Map<String, dynamic>) {
    return Map<String, dynamic>.from(source);
  }
  if (source is Map) {
    return source.map(
          (dynamic key, dynamic value) => MapEntry(key.toString(), value),
    );
  }
  return <String, dynamic>{};
}

List<Map<String, dynamic>> _normalizeList(dynamic source) {
  if (source is List) {
    return source
        .whereType<Map>()
        .map(
          (Map<dynamic, dynamic> value) => value.map(
            (dynamic key, dynamic value) => MapEntry(key.toString(), value),
      ),
    )
        .map((map) => Map<String, dynamic>.from(map))
        .toList();
  }
  return const <Map<String, dynamic>>[];
}

String? _stringOrNull(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is String) {
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
  return value.toString();
}