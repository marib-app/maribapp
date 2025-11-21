import 'dart:math';

import 'package:marib/data/model/action_request.dart';
import 'package:marib/utils/api.dart';

class ActionRequestRepository {
  Future<ActionRequestModel> fetchRequest({
    required String requestId,
    required String token,
  }) async {
    final Map<String, dynamic> response = await Api.get(
      url: Api.actionRequestApi(requestId),
      queryParameters: <String, dynamic>{'token': token},
    );

    final dynamic data = response['data'] ?? response['action_request'];
    if (data is Map<String, dynamic>) {
      return ActionRequestModel.fromJson(data);
    }
    throw ApiHttpException(
      statusCode: 404,
      errorMessage: 'action_request_not_found',
    );
  }

  Future<ActionRequestModel> perform({
    required String requestId,
    required String token,
    String? idempotencyKey,
  }) async {
    final String key = idempotencyKey ?? _generateIdempotencyKey();
    final String targetUrl =
        '${Api.actionRequestPerformApi(requestId)}?token=${Uri.encodeQueryComponent(token)}';

    final Map<String, dynamic> response = await Api.postJson(
      url: targetUrl,
      data: const <String, dynamic>{},
      extraHeaders: <String, dynamic>{'Idempotency-Key': key},
    );

    final dynamic data = response['data'] ?? response['action_request'];
    if (data is Map<String, dynamic>) {
      return ActionRequestModel.fromJson(data);
    }

    throw ApiHttpException(
      statusCode: 422,
      errorMessage: response['error']?.toString() ?? 'action_request_failed',
    );
  }

  String _generateIdempotencyKey() {
    final Random random = Random();
    final List<int> values = List<int>.generate(16, (_) => random.nextInt(256));
    return values.map((int v) => v.toRadixString(16).padLeft(2, '0')).join();
  }
}
