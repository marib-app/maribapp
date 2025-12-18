import 'package:marib/utils/api.dart';

class StorefrontFollowResult {
  const StorefrontFollowResult({
    required this.isFollowing,
    this.followersCount,
  });

  final bool isFollowing;
  final int? followersCount;
}

class StorefrontFollowRepository {
  const StorefrontFollowRepository();

  Future<StorefrontFollowResult> follow(dynamic storeIdentifier) async {
    final Map<String, dynamic> response = await Api.post(
      url: Api.storefrontFollowApi(storeIdentifier),
      useBaseUrl: true,
    );
    return _parseResponse(response, fallback: true);
  }

  Future<StorefrontFollowResult> unfollow(dynamic storeIdentifier) async {
    final Map<String, dynamic> response = await Api.post(
      url: Api.storefrontUnfollowApi(storeIdentifier),
      useBaseUrl: true,
    );
    return _parseResponse(response, fallback: false);
  }

  StorefrontFollowResult _parseResponse(
    Map<String, dynamic> response, {
    required bool fallback,
  }) {
    final dynamic data = response['data'];
    bool flag = fallback;
    int? count;

    if (data is Map<String, dynamic>) {
      flag = _parseFollowFlag(data, fallback: fallback);
      final dynamic rawCount = data['followers_count'] ?? data['followersCount'];
      if (rawCount is num) {
        count = rawCount.toInt();
      } else if (rawCount is String) {
        final int? parsed = int.tryParse(rawCount);
        if (parsed != null) count = parsed;
      }
    }

    return StorefrontFollowResult(
      isFollowing: flag,
      followersCount: count,
    );
  }

  bool _parseFollowFlag(
    Map<String, dynamic> map, {
    required bool fallback,
  }) {
    final dynamic raw = map['is_following'] ??
        map['is_followed'] ??
        map['following'] ??
        map['followed'];
    if (raw is bool) return raw;
    if (raw is num) return raw != 0;
    if (raw is String) {
      final String normalized = raw.toLowerCase().trim();
      if (normalized == 'true' || normalized == '1') return true;
      if (normalized == 'false' || normalized == '0') return false;
    }
    return fallback;
  }
}
