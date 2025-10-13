import 'package:dio/dio.dart';
import 'package:marib/data/model/ad_draft_model.dart';
import 'package:marib/utils/api.dart';

class AdDraftRepository {
  Future<AdDraftModel> saveDraft({
    String? draftId,
    required Map<String, dynamic> payload,
    required String currentStep,
    Map<String, dynamic>? stepPayload,
    Map<String, dynamic>? temporaryMedia,
  }) async {
    final Map<String, dynamic> body = <String, dynamic>{
      'current_step': currentStep,
      'payload': payload,
      if (stepPayload != null && stepPayload.isNotEmpty) 'step_payload': stepPayload,
      if (temporaryMedia != null && temporaryMedia.isNotEmpty)
        'temporary_media': temporaryMedia,
    };

    final Map<String, dynamic> response = await Api.requestJson(
      url: draftId == null ? Api.adDraftsApi : '${Api.adDraftsApi}/$draftId',
      method: draftId == null ? 'POST' : 'PUT',
      data: body,
    );

    final dynamic data = response['data'];
    if (data is Map<String, dynamic>) {
      return AdDraftModel.fromJson(data);
    }
    throw DioException(
      requestOptions: RequestOptions(path: Api.adDraftsApi),
      error: 'invalid-draft-response',
    );
  }

  Future<AdDraftModel> fetchDraft(String draftId) async {
    final Map<String, dynamic> response = await Api.get(
      url: '${Api.adDraftsApi}/$draftId',
    );
    final dynamic data = response['data'];
    if (data is Map<String, dynamic>) {
      return AdDraftModel.fromJson(data);
    }
    throw DioException(
      requestOptions: RequestOptions(path: '${Api.adDraftsApi}/$draftId'),
      error: 'invalid-draft-response',
    );
  }


  Future<Map<String, dynamic>> publishDraft({
    String? draftId,
    required Map<String, dynamic> payload,
  }) {
    final Map<String, dynamic> body = <String, dynamic>{
      'payload': payload,
      if (draftId != null && draftId.isNotEmpty)
        'draft_id': int.tryParse(draftId) ?? draftId,
    };
    return Api.requestJson(
      url: '${Api.adDraftsApi}/publish',
      method: 'POST',
      data: body,
    );
  }
}