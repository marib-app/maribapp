import 'package:marib/utils/api.dart';

class RequestSupportRepository {
  Future<Map<String, dynamic>> storeRequestSupport({
    required String name,
    required String phone,
    required String subject,
    required String message,
  }) async {
    Map<String, dynamic> parameters = {
      'name': name,
      'email': phone,
      'subject': subject,
      'message': message,
    };

    Map<String, dynamic> response = await Api.post(
      url: Api.requestSupportApi,
      parameter: parameters,
      useBaseUrl: true,
    );

    return response;
  }
}