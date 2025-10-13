import 'dart:math';
import 'package:dio/dio.dart';
import 'package:marib/data/model/ad_draft_model.dart';
import 'package:marib/data/repositories/item/ad_draft_local_store.dart';
import 'package:marib/data/repositories/item/ad_draft_repository.dart';

import '../models/custom_field_schema.dart';

/// A lightweight mock of the category/inventory service used by the wizard.
///
/// The real application fetches the schema from the backend. For the purposes
/// of the sample wizard we simulate that behaviour with static payloads to keep
/// the UI flow functional while remaining offline-friendly.
class CategoryInventoryService {
  CategoryInventoryService();

  final Map<String, List<CustomFieldSchema>> _cache = <String, List<CustomFieldSchema>>{};

  Future<List<CustomFieldSchema>> fetchCustomFieldSchema({
    required String interfaceType,
    required int categoryId,
  }) async {
    final String cacheKey = '$interfaceType-$categoryId';
    final List<CustomFieldSchema>? cached = _cache[cacheKey];
    if (cached != null) {
      return cached;
    }

    // Simulate latency to mimic the network request to the category/inventory
    // service on the production backend.
    await Future<void>.delayed(Duration(milliseconds: 250 + Random().nextInt(250)));

    final List<Map<String, dynamic>>? rawSchema = _mockedSchemas[cacheKey] ??
        _mockedSchemas['$interfaceType-*'] ??
        _mockedSchemas['*-*'];

    final List<CustomFieldSchema> parsed = rawSchema
        ?.map((Map<String, dynamic> field) => CustomFieldSchema.fromMap(field))
        .toList(growable: false) ??
        const <CustomFieldSchema>[];

    _cache[cacheKey] = parsed;
    return parsed;
  }
}

/// Example payloads emulating the backend response.
final Map<String, List<Map<String, dynamic>>> _mockedSchemas = <String, List<Map<String, dynamic>>>{
  'public_ads-101': <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 'color',
      'label': 'اللون',
      'type': 'dropdown',
      'required': true,
      'options': <Map<String, String>>[
        <String, String>{'value': 'red', 'label': 'أحمر'},
        <String, String>{'value': 'blue', 'label': 'أزرق'},
        <String, String>{'value': 'white', 'label': 'أبيض'},
      ],
    },
    <String, dynamic>{
      'id': 'condition',
      'label': 'الحالة',
      'type': 'select',
      'required': true,
      'options': <String>['جديد', 'مستعمل', 'مجدّد'],
    },
    <String, dynamic>{
      'id': 'extras',
      'label': 'مزايا إضافية',
      'type': 'multi',
      'options': <String>['ضمان', 'توصيل مجاني', 'إرجاع خلال 7 أيام'],
    },
  ],
  'public_ads-102': <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 'furnished',
      'label': 'مفروش',
      'type': 'radio',
      'required': true,
      'options': <String>['نعم', 'لا'],
    },
    <String, dynamic>{
      'id': 'rooms',
      'label': 'عدد الغرف',
      'type': 'text',
      'required': true,
    },
    <String, dynamic>{
      'id': 'amenities',
      'label': 'الخدمات المتاحة',
      'type': 'multi_select',
      'options': <Map<String, String>>[
        <String, String>{'value': 'parking', 'label': 'موقف سيارات'},
        <String, String>{'value': 'elevator', 'label': 'مصعد'},
        <String, String>{'value': 'security', 'label': 'أمن'},
        <String, String>{'value': 'gym', 'label': 'نادي رياضي'},
      ],
    },
  ],
  'services-201': <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 'experience',
      'label': 'سنوات الخبرة',
      'type': 'textbox',
      'required': true,
    },
    <String, dynamic>{
      'id': 'service_area',
      'label': 'نطاق الخدمة',
      'type': 'checkbox',
      'options': <String>['داخل المدينة', 'خارج المدينة', 'دولي'],
    },
  ],
  '*-*': <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 'notes',
      'label': 'ملاحظات إضافية',
      'type': 'textarea',
      'required': false,
    },
  ],
};

/// Simple service to simulate saving or publishing an advertisement.

class DraftSaveOfflineException implements Exception {
  DraftSaveOfflineException(this.cause);

  final DioException cause;

  @override
  String toString() =>
      'DraftSaveOfflineException(${cause.message ?? cause.error ?? 'unknown'})';
}

/// Service responsible for synchronising draft data with the backend.

class AdPublishingService {
  AdPublishingService({
    AdDraftRepository? draftRepository,
    AdDraftLocalStore? localStore,
  })  : _draftRepository = draftRepository ?? AdDraftRepository(),
        _localStore = localStore ?? AdDraftLocalStore();

  final AdDraftRepository _draftRepository;
  final AdDraftLocalStore _localStore;

  Future<AdDraftModel> saveDraft({
    String? draftId,
    required Map<String, dynamic> payload,
    required Map<String, dynamic> stepPayload,
    required Map<String, dynamic> temporaryMedia,
    required String currentStep,
    required String cacheKey,
  }) async {
    try {
      final AdDraftModel draft = await _draftRepository.saveDraft(
        draftId: draftId,
        payload: payload,
        currentStep: currentStep,
        stepPayload: stepPayload,
        temporaryMedia: temporaryMedia,
      );
      await _localStore.saveSnapshot(cacheKey, draft);
      await _localStore.clearPending(cacheKey);
      return draft;
    } on DioException catch (error) {
      if (_isConnectivityError(error)) {
        await _localStore.savePending(cacheKey, <String, dynamic>{
          'draft_id': draftId,
          'current_step': currentStep,
          'payload': payload,
          'step_payload': stepPayload,
          'temporary_media': temporaryMedia,
        });
        throw DraftSaveOfflineException(error);
      }
      rethrow;
    }
  }

  Future<AdDraftModel> fetchDraft(String draftId) {
    return _draftRepository.fetchDraft(draftId);
  }

  Future<AdDraftModel?> syncPending({
    required String cacheKey,
    String? fallbackDraftId,
  }) async {
    final Map<String, dynamic>? pending = await _localStore.readPending(cacheKey);
    if (pending == null) {
      return null;
    }

    final Map<String, dynamic> payload = _mapOf(pending['payload']);
    if (payload.isEmpty) {
      await _localStore.clearPending(cacheKey);
      return null;
    }

    final Map<String, dynamic> stepPayload = _mapOf(pending['step_payload']);
    final Map<String, dynamic> temporaryMedia = _mapOf(pending['temporary_media']);
    final String currentStep = _stringOrNull(pending['current_step']) ?? 'review';
    final String? draftId =
        _stringOrNull(pending['draft_id']) ?? _stringOrNull(fallbackDraftId);

    try {
      final AdDraftModel draft = await _draftRepository.saveDraft(
        draftId: draftId,
        payload: payload,
        currentStep: currentStep,
        stepPayload: stepPayload,
        temporaryMedia: temporaryMedia,
      );
      await _localStore.saveSnapshot(cacheKey, draft);
      await _localStore.clearPending(cacheKey);
      return draft;
    } on DioException catch (error) {
      if (_isConnectivityError(error)) {
        return null;
      }
      rethrow;
    }
  }

  Future<AdDraftModel?> readCachedDraft(String cacheKey) {
    return _localStore.readSnapshot(cacheKey);
  }

  Future<Map<String, dynamic>?> readPending(String cacheKey) {
    return _localStore.readPending(cacheKey);
  }

  Future<void> rememberDraft(String cacheKey, AdDraftModel draft) {
    return _localStore.saveSnapshot(cacheKey, draft);
  }

  Future<void> migrateCache({required String from, required String to}) {
    return _localStore.migrate(from: from, to: to);
  }

  Future<void> publish(Map<String, dynamic> payload) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    // ignore: avoid_print
    print('Ad published with payload: $payload');
  }


  bool _isConnectivityError(DioException error) {
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return true;
    }
    final Object? underlying = error.error;
    return underlying is Exception &&
        underlying.toString().toLowerCase().contains('socket');
  }

  Map<String, dynamic> _mapOf(dynamic value) {
    if (value is Map<String, dynamic>) {
      return Map<String, dynamic>.from(value);
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value as Map);
    }
    return <String, dynamic>{};
  }

  String? _stringOrNull(dynamic value) {
    if (value == null) {
      return null;
    }
    final String candidate = value.toString();
    return candidate.isEmpty ? null : candidate;
  }

}