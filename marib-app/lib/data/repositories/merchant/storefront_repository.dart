import 'package:marib/data/model/merchant/storefront_model.dart';
import 'package:marib/utils/api.dart';

class StorefrontRepository {
  const StorefrontRepository();

  Future<StorefrontDetails> fetchStore(String identifier) async {
    final Map<String, dynamic> response = await Api.get(
      url: Api.storefrontShowApi(identifier),
    );

    final Map<String, dynamic> data =
        (response['data'] as Map<String, dynamic>?) ??
            <String, dynamic>{};

    return StorefrontDetails.fromJson(data);
  }
}
