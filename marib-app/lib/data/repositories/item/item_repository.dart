import 'dart:io';

import 'package:dio/dio.dart';
import 'package:marib/data/model/item_filter_model.dart';
import 'package:marib/utils/api.dart';
import 'package:marib/data/model/data_output.dart';
import 'package:marib/data/model/item/item_model.dart';
import 'package:path/path.dart' as path;

/// ---------------------------------------------------------------------------
/// ItemRepository
/// المستودع الخاص بطلبات العناصر (إنشاء/تعديل/حذف/جلب/بحث/إحصاءات)
// يعتمد على Api (GET/POST) ويحوّل الردود إلى نماذج ItemModel/DataOutput
/// ---------------------------------------------------------------------------

class ItemRepository {
  /// -------------------------------------------------------------------------
  /// createItem
  /// إنشاء إعلان جديد مع صورة رئيسية (إلزامية) + صور إضافية (اختيارية)
  /// - itemDetails: الحقول النصية/الرقمية للإعلان
  /// - mainImage: ملف الصورة الرئيسية
  /// - otherImages: قائمة ملفات للمعرض (اختياري)
  /// يعيد: ItemModel الخاص بالإعلان الذي تم إنشاؤه
  /// -------------------------------------------------------------------------
  Future<ItemModel> createItem(
    Map<String, dynamic> itemDetails,
    File mainImage,
    List<File>? otherImages,
  ) async {
    try {
      final Map<String, dynamic> parameters = {};
      parameters.addAll(itemDetails);

      // تجهيز الصورة الرئيسية باسم ملف مناسب
      final MultipartFile image = await MultipartFile.fromFile(
        mainImage.path,
        filename: path.basename(mainImage.path),
      );

      // تجهيز صور المعرض (إن وُجدت)
      if (otherImages != null && otherImages.isNotEmpty) {
        final List<Future<MultipartFile>> futures =
            otherImages.map((imageFile) {
          return MultipartFile.fromFile(
            imageFile.path,
            filename: path.basename(imageFile.path),
          );
        }).toList();

        final List<MultipartFile> galleryImages = await Future.wait(futures);

        if (galleryImages.isNotEmpty) {
          parameters["gallery_images"] = galleryImages;
        }
      }

      // ضم الصورة الرئيسية وخيارات إضافية
      parameters.addAll({
        "image": image,
        "show_only_to_premium": 1,
      });

      // طلب الإنشاء
      final Map<String, dynamic> response = await Api.post(
        url: Api.addItemApi,
        parameter: parameters, /* useAuthToken: true*/
      );

      return ItemModel.fromJson(response['data'][0]);
    } catch (e) {
      rethrow;
    }
  }

  // -------------------------------------------------------------------------
  // fetchMyFeaturedItems
  // جلب إعلاناتي المميزة (featured) مع دعم التصفح بترقيم الصفحات
  // - page: رقم الصفحة
  // يعيد: DataOutput<ItemModel> يحتوي total + modelList
  // -------------------------------------------------------------------------

  Future<DataOutput<ItemSummary>> fetchItemSummariesFromCatId({
    required int categoryId,
    required int page,
    String? search,
    String? sortBy,
    ItemFilterModel? filter,
  }) async {
    final Map<String, dynamic> parameters = {
      Api.categoryId: categoryId,
      Api.page: page,
      'view': 'summary',
    };

    if (filter != null) {
      parameters.addAll(filter.toMap());

      if (filter.areaId == null) {
        parameters.remove('area_id');
      }
      parameters.remove('area');

      if (filter.customFields != null) {
        filter.customFields!.forEach((key, value) {
          if (value is List) {
            parameters[key] = value.map((v) => v.toString()).join(',');
          } else {
            parameters[key] = value.toString();
          }
        });
      }
    }

    if (search != null) parameters[Api.search] = search;
    if (sortBy != null) parameters[Api.sortBy] = sortBy;

    final Map<String, dynamic> response =
        await Api.get(url: Api.getItemApi, queryParameters: parameters);

    final List<ItemSummary> items = (response['data']['data'] as List)
        .whereType<Map<String, dynamic>>()
        .map(ItemSummary.fromJson)
        .toList();

    return DataOutput(
      total: response['data']['total'] ?? 0,
      modelList: items,
    );
  }

  Future<DataOutput<ItemModel>> fetchMyFeaturedItems({int? page}) async {
    try {
      final Map<String, dynamic> parameters = {
        "status": "featured",
        "page": page,
      };

      final Map<String, dynamic> response = await Api.get(
        url: Api.getMyItemApi,
        queryParameters: parameters, /*useAuthToken: true*/
      );

      final List<ItemModel> itemList = (response['data']['data'] as List)
          .map((element) => ItemModel.fromJson(element))
          .toList();

      return DataOutput(
        total: response['data']['total'] ?? 0,
        modelList: itemList,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// -------------------------------------------------------------------------
  /// fetchMyItems
  /// جلب إعلاناتي (كلها أو حسب حالة معينة: pending/approved/... إلخ)
  /// - getItemsWithStatus: فلترة بالحالة
  /// - page: رقم الصفحة
  /// يعيد: DataOutput<ItemModel>
  /// -------------------------------------------------------------------------
  Future<DataOutput<ItemModel>> fetchMyItems({
    String? getItemsWithStatus,
    int? page,
  }) async {
    try {
      final Map<String, dynamic> parameters = {
        if (getItemsWithStatus != null) "status": getItemsWithStatus,
        if (page != null) Api.page: page,
      };

      // لو ستاتس فاضي تُحذف
      if (parameters['status'] == "") parameters.remove('status');

      final Map<String, dynamic> response = await Api.get(
        url: Api.getMyItemApi,
        queryParameters: parameters, /*useAuthToken: true*/
      );

      final List<ItemModel> itemList = (response['data']['data'] as List)
          .map((element) => ItemModel.fromJson(element))
          .toList();

      return DataOutput(
        total: response['data']['total'] ?? 0,
        modelList: itemList,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// -------------------------------------------------------------------------
  /// fetchItemFromItemId
  /// جلب عنصر (أو عناصر) بحسب المعرّف Id
  /// يعيد: DataOutput<ItemModel> (عادة عنصر واحد)
  /// -------------------------------------------------------------------------
  Future<DataOutput<ItemModel>> fetchItemFromItemId(int id) async {
    final Map<String, dynamic> parameters = {Api.id: id};

    final Map<String, dynamic> response = await Api.get(
      url: Api.getItemApi,
      queryParameters: parameters,
    );

    final List<ItemModel> modelList =
        (response['data'] as List).map((e) => ItemModel.fromJson(e)).toList();

    return DataOutput(total: modelList.length, modelList: modelList);
  }

  /// -------------------------------------------------------------------------
  /// fetchItemFromItemSlug
  /// جلب عنصر من خلال الـ slug
  /// يعيد: DataOutput<ItemModel> من البينات الراجعة (data.data)
  /// -------------------------------------------------------------------------
  Future<DataOutput<ItemModel>> fetchItemFromItemSlug(String slug) async {
    final Map<String, dynamic> parameters = {"slug": slug};

    final Map<String, dynamic> response = await Api.get(
      url: Api.getItemApi,
      queryParameters: parameters,
    );

    final List<ItemModel> modelList = (response['data']['data'] as List)
        .map((e) => ItemModel.fromJson(e))
        .toList();

    return DataOutput(total: modelList.length, modelList: modelList);
  }

  /// -------------------------------------------------------------------------
  /// changeMyItemStatus
  /// تغيير حالة إعلان مِلكي (مثل: sold/active/hidden .. إلخ)
  /// - itemId: معرّف العنصر
  /// - status: الحالة الجديدة
  /// - userId: (اختيارية) المشتري عند وضع Sold مثلاً
  /// يعيد: الخريطة الخام من الرد
  /// -------------------------------------------------------------------------
  Future<Map> changeMyItemStatus({
    required int itemId,
    required String status,
    int? userId,
  }) async {
    final Map response = await Api.post(
      url: Api.updateItemStatusApi,
      parameter: {Api.status: status, Api.itemId: itemId, Api.soldTo: userId},
    );
    return response;
  }

  /// -------------------------------------------------------------------------
  /// createFeaturedAds
  /// ترقية إعلان إلى إعلان مميز
  /// - itemId: المعرّف
  /// يعيد: الرد الخام (Map)
  /// -------------------------------------------------------------------------
  Future<Map> createFeaturedAds({required int itemId}) async {
    final Map response = await Api.post(
      url: Api.makeItemFeaturedApi,
      parameter: {"item_id": itemId},
    );
    return response;
  }

  /// -------------------------------------------------------------------------
  /// fetchItemFromCatId
  /// جلب عناصر حسب تصنيف معيّن مع دعم:
  /// - البحث
  /// - الفرز
  /// - الموقع (من خلال filter.toMap + customFields)
  /// - التصفح بترقيم الصفحات
  /// يعيد: DataOutput<ItemModel>
  /// -------------------------------------------------------------------------
  Future<DataOutput<ItemModel>> fetchItemFromCatId({
    required int categoryId,
    required int page,
    String? search,
    String? sortBy,
    String? country,
    String? state,
    String? city,
    int? areaId,
    ItemFilterModel? filter,
  }) async {
    final Map<String, dynamic> parameters = {
      Api.categoryId: categoryId,
      Api.page: page,
    };

    // تطبيق الفلاتر (إن وُجدت)
    if (filter != null) {
      parameters.addAll(filter.toMap());

      // تنظيف بعض المفاتيح حسب شروطك:
      if (filter.areaId == null) {
        parameters.remove('area_id');
      }
      parameters.remove('area');

      // تحويل الحقول المخصصة customFields إلى شكل مناسب في الاستعلام
      if (filter.customFields != null) {
        filter.customFields!.forEach((key, value) {
          if (value is List) {
            parameters[key] = value.map((v) => v.toString()).join(',');
          } else {
            parameters[key] = value.toString();
          }
        });
      }
    }

    if (search != null) parameters[Api.search] = search;
    if (sortBy != null) parameters[Api.sortBy] = sortBy;

    final Map<String, dynamic> response =
        await Api.get(url: Api.getItemApi, queryParameters: parameters);

    final List<ItemModel> items = (response['data']['data'] as List)
        .map((e) => ItemModel.fromJson(e))
        .toList();

    return DataOutput(
      total: response['data']['total'] ?? 0,
      modelList: items,
    );
  }

  /// -------------------------------------------------------------------------
  /// fetchMyItemFromItemId
  /// جلب إعلان مِلكي بالمعرّف حتى لو كان Pending/Rejection
  /// يعتمد على my-items (يتطلّب التوكن) لضمان رؤية كل الحالات
  /// يعيد: DataOutput<ItemModel>
  /// -------------------------------------------------------------------------
  Future<DataOutput<ItemModel>> fetchMyItemFromItemId(int id) async {
    final Map<String, dynamic> response = await Api.get(
      url: Api.getMyItemApi,
      queryParameters: {Api.id: id},
    );

    final dynamic data = response['data'];

    Iterable<dynamic> rawItems = const [];
    if (data is List) {
      rawItems = data;
    } else if (data is Map<String, dynamic>) {
      final dynamic innerData = data['data'] ?? data['items'] ?? data['item'];
      if (innerData is List) {
        rawItems = innerData;
      } else if (innerData is Map<String, dynamic>) {
        rawItems = [innerData];
      } else if (data.containsKey('id')) {
        rawItems = [data];
      }
    }

    final List<ItemModel> modelList = rawItems
        .whereType<Map<String, dynamic>>()
        .map(ItemModel.fromJson)
        .toList();

    int total = modelList.length;
    if (data is Map<String, dynamic>) {
      final dynamic totalValue = data['total'];
      if (totalValue is int) {
        total = totalValue;
      } else if (totalValue is String) {
        total = int.tryParse(totalValue) ?? total;
      }
    }

    return DataOutput(total: total, modelList: modelList);
  }

  /*  النسخة السابقة (مرجعية) احتفظت بها عندك بالتعليق لو احتجت ترجع
  Future<DataOutput<ItemModel>> fetchItemFromCatId(...) async { ... }
  */

  /// -------------------------------------------------------------------------
  /// fetchPopularItems
  /// جلب عناصر شعبية/أحدث... إلخ حسب مفتاح الفرز مع الصفحة
  /// - sortBy: مفتاح الفرز (مثلاً: popular, latest)
  /// - page: رقم الصفحة
  /// يعيد: DataOutput<ItemModel>
  /// -------------------------------------------------------------------------
  Future<DataOutput<ItemModel>> fetchPopularItems({
    required String sortBy,
    required int page,
  }) async {
    final Map<String, dynamic> parameters = {
      Api.sortBy: sortBy,
      Api.page: page
    };

    final Map<String, dynamic> response =
        await Api.get(url: Api.getItemApi, queryParameters: parameters);

    final List<ItemModel> items = (response['data']['data'] as List)
        .map((e) => ItemModel.fromJson(e))
        .toList();

    return DataOutput(
      total: response['data']['total'] ?? 0,
      modelList: items,
    );
  }

  /// -------------------------------------------------------------------------
  /// editItem
  /// تعديل إعلان:
  /// - itemDetails: الحقول النصية/الرقمية
  /// - mainImage: صورة رئيسية جديدة (اختياري)
  /// - otherImages: صور معرض جديدة (اختياري)
  /// يعيد: ItemModel بعد التعديل
  /// -------------------------------------------------------------------------
  Future<ItemModel> editItem(
    Map<String, dynamic> itemDetails,
    File? mainImage,
    List<File>? otherImages,
  ) async {
    final Map<String, dynamic> parameters = {};
    parameters.addAll(itemDetails);

    // صورة رئيسية (إن وُجدت)
    if (mainImage != null) {
      final MultipartFile image = await MultipartFile.fromFile(
        mainImage.path,
        filename: path.basename(mainImage.path),
      );
      parameters['image'] = image;
    }

    // صور المعرض (إن وُجدت)
    if (otherImages != null && otherImages.isNotEmpty) {
      final List<Future<MultipartFile>> futures = otherImages.map((imageFile) {
        return MultipartFile.fromFile(
          imageFile.path,
          filename: path.basename(imageFile.path),
        );
      }).toList();

      final List<MultipartFile> galleryImages = await Future.wait(futures);

      if (galleryImages.isNotEmpty) {
        parameters["gallery_images"] = galleryImages;
      }
    }

    final Map<String, dynamic> response = await Api.post(
      url: Api.updateItemApi,
      parameter: parameters, /* useAuthToken: true*/
    );

    return ItemModel.fromJson(response['data'][0]);
  }

  /// -------------------------------------------------------------------------
  /// deleteItem
  /// حذف إعلان بالمعرّف
  /// -------------------------------------------------------------------------
  Future<void> deleteItem(int id) async {
    await Api.post(
      url: Api.deleteItemApi,
      parameter: {Api.id: id}, /* useAuthToken: true*/
    );
  }

  /// -------------------------------------------------------------------------
  /// itemTotalClick
  /// إرسال نقرة/زيارة للإعلان (زيادة عدّاد النقرات)
  /// -------------------------------------------------------------------------
  Future<void> itemTotalClick(int id) async {
    await Api.post(
      url: Api.setItemTotalClickApi,
      parameter: {Api.itemId: id},
    );
  }

  /// -------------------------------------------------------------------------
  /// makeAnOfferItem
  /// إرسال عرض سعر على إعلان
  /// - amount: إن لم يمرّر سيُرسل فقط itemId
  /// يعيد: الرد الخام (Map)
  /// -------------------------------------------------------------------------
  Future<Map> makeAnOfferItem(int id, double? amount) async {
    final Map response = await Api.post(
      url: Api.itemOfferApi,
      parameter: {
        Api.itemId: id,
        if (amount != null) Api.amount: amount,
      },
    );
    return response;
  }

  /// -------------------------------------------------------------------------
  /// searchItem
  /// البحث عن إعلانات بنص + فلاتر + صفحة
  /// - query: نص البحث
  /// - filter: فلاتر البحث (areaId, customFields, ...)
  /// - page: رقم الصفحة
  /// يعيد: DataOutput<ItemModel>
  /// -------------------------------------------------------------------------
  Future<DataOutput<ItemModel>> searchItem(
    String query,
    ItemFilterModel? filter, {
    required int page,
  }) async {
    final Map<String, dynamic> parameters = {
      Api.search: query,
      Api.page: page,
      if (filter != null) ...filter.toMap(),
    };

    if (filter != null) {
      // تنظيف area_id لو غير موجود
      if (filter.areaId == null) {
        parameters.remove('area_id');
      }
      // إزالة 'area' (يبدو أنها لا تُستخدم في الاستعلام)
      parameters.remove('area');

      // الحقول المخصصة إن وجدت تُضاف كما هي
      if (filter.customFields != null) {
        parameters.addAll(filter.customFields!);
      }
    }

    final Map<String, dynamic> response =
        await Api.get(url: Api.getItemApi, queryParameters: parameters);

    final List<ItemModel> items = (response['data']['data'] as List)
        .map((e) => ItemModel.fromJson(e))
        .toList();

    return DataOutput(
      total: response['data']['total'] ?? 0,
      modelList: items,
    );
  }

  /// -------------------------------------------------------------------------
  /// _fileToMultipartFileList
  /// أداة مساعدة لتحويل قائمة Files إلى MultipartFiles (للرفع)
  /// -------------------------------------------------------------------------
  Future<List<MultipartFile>> _fileToMultipartFileList(
    List<File> files,
  ) async {
    final List<MultipartFile> multipartFileList = [];
    for (final File file in files) {
      multipartFileList.add(await MultipartFile.fromFile(file.path));
    }
    return multipartFileList;
  }
}
