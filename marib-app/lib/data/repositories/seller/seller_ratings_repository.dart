import 'package:marib/utils/api.dart';
import 'package:marib/data/model/data_output.dart';
import 'package:marib/data/model/seller_ratings_model.dart';

class SellerRatingsRepository {
  Future<DataOutput<UserRatings>> fetchSellerRatingsAllRatings(
      {required int sellerId, required int page}) async {
    try {
      Map<String, dynamic> parameters = {"id": sellerId, "page": page};

      Map<String, dynamic> response =
          await Api.get(url: Api.getSellerApi, queryParameters: parameters);

      // Deserialize response into SellerRatingsModel
      SellerRatingsModel sellerRatingsModel =
          SellerRatingsModel.fromJson(response["data"]);

      // Ensure ratings and userRatings are not null
      int totalRatings = sellerRatingsModel.ratings?.total ?? 0;
      List<UserRatings> userRatings =
          sellerRatingsModel.ratings?.userRatings ?? [];

      // Handle the possibility of seller being null
      var seller = sellerRatingsModel.seller;

      return DataOutput(
        total: totalRatings,
        modelList: userRatings,
        extraData: ExtraData(
          data: seller, // Pass the seller as extraData, which can be null
        ),
      );
    } catch (error) {
      // Handle or log the error appropriately
      rethrow;
    }
  }
}
