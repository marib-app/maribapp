import 'package:marib/data/model/data_output.dart';
import 'package:marib/data/model/report_item/reason_model.dart';
import 'package:marib/utils/api.dart';

class ReportItemRepository {
  Future<DataOutput<ReportReason>> fetchReportReasonsList() async {
    try {
      Map<String, dynamic> response = await Api.get(
        url: Api.getReportReasonsApi,
        queryParameters: {},
      );

      List<dynamic> _pickFirstList(dynamic source) {
        if (source is List) return source;
        if (source is Map) {
          if (source['data'] is List) return source['data'] as List;
          if (source['reasons'] is List) return source['reasons'] as List;
          for (final entry in source.values) {
            if (entry is List) return entry;
            if (entry is Map && entry['data'] is List) return entry['data'] as List;
          }
        }
        return <dynamic>[];
      }

      final List<dynamic> root = _pickFirstList(response);
      final List<dynamic> nested = _pickFirstList(response['data']);
      final List<dynamic> payloadList =
          root.isNotEmpty ? root : nested;

      final List<dynamic> sourceList =
          payloadList.isNotEmpty ? payloadList : root;

      final List<ReportReason> list = sourceList.map((e) {
        final Map entry = e as Map;
        final String reasonText = (entry['reason'] ??
                entry['title'] ??
                entry['name'] ??
                '')
            .toString();
        return ReportReason(id: entry["id"], reason: reasonText);
      }).toList();

      final dynamic rawTotal =
          (response['total'] ?? (response['data'] is Map ? response['data']['total'] : null));
      final int total = rawTotal is int ? rawTotal : list.length;

      return DataOutput(total: total, modelList: list);
    } catch (e) {
      rethrow;
    }
  }

  Future<Map> reportItem(
      {required int reasonId, required int itemId, String? message}) async {
    try {
      Map response = await Api.post(
        url: Api.addReportsApi,
        parameter: {
          if (reasonId != -10) "report_reason_id": reasonId,
          "item_id": itemId,
          if (reasonId == -10 && (message?.trim().isNotEmpty ?? false))
            "other_message": message!.trim(),
        },
      );

      return response;
    } catch (e) {
      rethrow;
    }
  }
}
