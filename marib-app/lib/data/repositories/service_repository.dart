import 'package:marib/data/model/classified_model.dart';
import 'package:marib/utils/api.dart';

class ServiceRepository {
  Future<Map<String, dynamic>> fetchServices(Map<String, dynamic> parameters) async {
    try {
      // نستخدم GET (زي ما هو في كودك الأصلي)
      final Map<String, dynamic> result =
      await Api.get(url: Api.getServicesApi, queryParameters: parameters);

      // الـ API يرجع البيانات في المفتاح 'data'
      final List rawList = result['data'] as List? ?? const [];

      // نكوّن قائمة ClassifiedSummary (خفيفة للقائمة)
      final List<ClassifiedSummary> summaryList = rawList.map((element) {
        return ClassifiedSummary.fromJson(Map<String, dynamic>.from(element));
      }).toList();



      int? _asInt(dynamic value) {
        if (value == null) return null;
        if (value is int) return value;
        if (value is double) return value.toInt();
        if (value is String) return int.tryParse(value);
        return null;
      }

      int? total = _asInt(result['total']);
      final meta = result['meta'];
      if (meta is Map) {
        total ??= _asInt(meta['total']);
      }

      return {
        'services': summaryList,
        'total': total ?? summaryList.length,

      };
    } catch (e) {
      throw e.toString();
    }
  }
}
