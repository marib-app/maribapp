import 'package:marib/utils/api.dart';

class StorefrontFollowRepository {
  const StorefrontFollowRepository();

  Future<bool> follow(int storeId) async {
    final Map<String, dynamic> response = await Api.post(
      url: Api.storefrontFollowApi(storeId),
      useBaseUrl: true,
    );
    return _parseFollowFlag(response, fallback: true);
  }

  Future<bool> unfollow(int storeId) async {
    final Map<String, dynamic> response = await Api.post(
      url: Api.storefrontUnfollowApi(storeId),
      useBaseUrl: true,
    );
    return _parseFollowFlag(response, fallback: false);
  }

  bool _parseFollowFlag(
    Map<String, dynamic> response, {
    required bool fallback,
  }) {
    final dynamic data = response['data'];
    if (data is Map<String, dynamic>) {
      final dynamic raw = data['is_following'] ??
          data['is_followed'] ??
          data['following'] ??
          data['followed'];
      if (raw is bool) return raw;
      if (raw is num) return raw != 0;
      if (raw is String) {
        final String normalized = raw.toLowerCase().trim();
        if (normalized == 'true' || normalized == '1') return true;
        if (normalized == 'false' || normalized == '0') return false;
      }
    }
    return fallback;
  }
}
