import 'package:marib/data/model/classified_model.dart';
import 'package:marib/utils/api.dart';

class ServiceRepository {
  Future<Map<String, dynamic>> fetchServices(
      Map<String, dynamic> parameters) async {
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

      return {
        'services': summaryList,
        'total': result['total'] ?? summaryList.length,
      };
    } catch (e) {
      throw e.toString();
    }
  }
}
