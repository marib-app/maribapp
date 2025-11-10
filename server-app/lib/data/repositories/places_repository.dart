import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../core/exceptions/app_exception.dart';
import '../../core/network/api_result.dart';
import '../../services/api_client.dart';
import '../models/public_space.dart';

final placesRepositoryProvider = Provider<PlacesRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return PlacesRepository(client);
});

class PlacesRepository {
  const PlacesRepository(this._client);

  final ApiClient _client;

  Future<ApiResult<List<PublicSpace>>> fetchSpaces() async {
    try {
      final response = await _client.get<dynamic>('/spaces');
      final payload = response.data;
      final list = payload is List
          ? payload
          : (payload is Map<String, dynamic> ? payload['data'] as List<dynamic>? : null);
      final spaces = (list ?? [])
          .whereType<Map<String, dynamic>>()
          .map(PublicSpace.fromJson)
          .toList();
      return ApiSuccess(spaces);
    } on AppException catch (error) {
      return ApiFailure(error);
    }
  }

  Future<ApiResult<PublicSpace>> toggleAvailability(int id, bool enabled) async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        '/spaces/$id/toggle',
        data: {'enabled': enabled},
      );
      return ApiSuccess(PublicSpace.fromJson(response.data ?? {}));
    } on AppException catch (error) {
      return ApiFailure(error);
    }
  }
}
