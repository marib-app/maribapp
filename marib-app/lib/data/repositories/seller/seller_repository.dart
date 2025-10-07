import 'package:marib/utils/api.dart';
import 'package:marib/data/model/user_model.dart'; // Assuming UserModel can be reused or adapted

class SellerRepository {
  Future<List<UserModel>> fetchSellers(
      {required int accountType, int? page}) async {
    try {
      Map<String, String> params = {
        "account_type": accountType.toString(),
      };
      if (page != null) {
        params["page"] = page.toString();
      }

      final response = await Api.get(
        url: Api.usersByAccountTypeApi,
        queryParameters: params,
      );

      if (response['error'] == false) {
        final dynamic responseData = response['data'];
        List<dynamic> sellersData = [];

        if (responseData is List) {
          sellersData = responseData;
        } else if (responseData is Map<String, dynamic>) {
          final dynamic paginatedData = responseData['data'];
          if (paginatedData is List) {
            sellersData = paginatedData;
          } else {
            throw ApiException('Invalid data format received from server');
          }
        } else {
          throw ApiException('Unexpected data format received from server');
        }

        return sellersData.map((e) => UserModel.fromJson(e)).toList();
      } else {
        final dynamic errorCode = response['code'];
        final dynamic errorMessage =
            response['message'] ?? 'Unknown error occurred';
        final String formattedMessage = errorCode != null
            ? 'Error $errorCode: $errorMessage'
            : errorMessage.toString();

        throw ApiException(formattedMessage);
      }
    } catch (e) {
      throw ApiException(e.toString());
    }
  }
}
