import 'dart:math';

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
class AdPublishingService {
  Future<void> saveDraft(Map<String, dynamic> payload) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    // In production this would POST to the draft endpoint. Here we simply log.
    // ignore: avoid_print
    print('Draft saved with payload: $payload');
  }

  Future<void> publish(Map<String, dynamic> payload) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    // ignore: avoid_print
    print('Ad published with payload: $payload');
  }
}