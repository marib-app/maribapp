import 'package:marib/data/model/merchant/storefront_model.dart';
import 'package:marib/utils/api.dart';
import 'package:marib/utils/hive_utils.dart';

class StorefrontRepository {
  const StorefrontRepository();

  Future<StorefrontDetails> fetchStore(String identifier) async {
    final String? viewerIdRaw = HiveUtils.getUserId();
    final String? viewerId = viewerIdRaw != null && viewerIdRaw.trim().isNotEmpty
        ? viewerIdRaw.trim()
        : null;
    final Map<String, dynamic> response = await Api.get(
      url: Api.storefrontShowApi(identifier),
      queryParameters: viewerId != null
          ? <String, dynamic>{
              'viewer_id': viewerId,
              'user_id': viewerId,
            }
          : null,
    );

    final Map<String, dynamic> data =
        (response['data'] as Map<String, dynamic>?) ??
            <String, dynamic>{};

    return StorefrontDetails.fromJson(data);
  }
}
