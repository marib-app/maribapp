import 'package:marib/data/model/item/purchase_options.dart';
import 'package:marib/utils/api.dart';

class ItemPurchaseOptionsRepository {
  Future<ItemPurchaseOptions> fetch(int itemId) async {
    final Map<String, dynamic> response = await Api.get(
      url: Api.productPurchaseOptionsApi(itemId),
    );

    final dynamic data = response['data'];
    if (data is Map<String, dynamic>) {
      return ItemPurchaseOptions.fromJson(data);
    }

    if (data is Map) {
      return ItemPurchaseOptions.fromJson(
        data.map((dynamic key, dynamic value) => MapEntry(key.toString(), value)),
      );
    }

    throw Exception('unexpected-response');
  }
}