import 'package:dio/dio.dart';
import 'package:marib/utils/payment/bank_account.dart';

// ملاحظة: اضبط baseUrl من إعداداتك (AppSettings.baseUrl) حيث تُنشئ BankApi.
class BankApi {
  final Dio _dio;

  BankApi(String baseUrl)
      : _dio = Dio(BaseOptions(baseUrl: _normalizeBase(baseUrl)));

  static String _normalizeBase(String u) {
    if (u.endsWith('/api/')) return u;
    if (u.endsWith('/')) return '${u}api/';
    return '$u/api/';
  }

  Future<List<BankAccount>> fetchBanks() async {
    try {
      final r = await _dio.get('banks');
      // لوج تشخيصي
      // ignore: avoid_print
      print('GET /banks → ${r.statusCode} ${r.data.runtimeType}');
      final data = r.data;

      List list;
      if (data is List) {
        list = data;
      } else if (data is Map && data['data'] is List) {
        list = data['data'];
      } else if (data is Map && data['banks'] is List) {
        list = data['banks'];
      } else {
        list = const [];
      }

      return list
          .map<BankAccount>(
              (e) => BankAccount.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } on DioException catch (e) {
      // ignore: avoid_print
      print('Banks error: ${e.response?.statusCode} ${e.response?.data}');
      return [];
    } catch (e) {
      // ignore: avoid_print
      print('Banks error: $e');
      return [];
    }
  }
}
