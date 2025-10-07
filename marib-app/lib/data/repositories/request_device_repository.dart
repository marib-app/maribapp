import 'package:marib/utils/api.dart';

class RequestDeviceRepository {
  Future<Map<String, dynamic>> storeRequestDevice({
    required String phone,
    required String subject,
    required String message,
  }) async {
    Map<String, dynamic> parameters = {
      'phone': phone,
      'subject': subject,
      'message': message,
    };

    Map<String, dynamic> response = await Api.post(
      url: Api.requestDeviceApi,
      parameter: parameters,
      useBaseUrl: true,
    );

    return response;
  }
}
