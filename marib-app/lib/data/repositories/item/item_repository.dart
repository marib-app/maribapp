import 'dart:io';

import 'package:dio/dio.dart';
import 'package:marib/data/model/item_filter_model.dart';
import 'package:marib/utils/api.dart';
import 'package:marib/data/model/data_output.dart';
import 'package:marib/data/model/item/item_model.dart';
import 'package:path/path.dart' as path;
import 'package:meta/meta.dart';
import 'package:marib/utils/logger.dart';
import 'package:marib/utils/constant.dart';

/// ---------------------------------------------------------------------------
/// ItemRepository
/// المستودع الخاص بطلبات العناصر (إنشاء/تعديل/حذف/جلب/بحث/إحصاءات)
// يعتمد على Api (GET/POST) ويحوّل الردود إلى نماذج ItemModel/DataOutput
/// ---------------------------------------------------------------------------

class ItemRepository {
  ItemRepository({
    Future<Map<String, dynamic>> Function({
      required String url,
      Map<String, dynamic>? queryParameters,
      bool? useBaseUrl,
      bool enableEtagCache,
    })? getRequest,
  }) : _getRequest = getRequest ?? Api.get;

  final Future<Map<String, dynamic>> Function({
    required String url,
    Map<String, dynamic>? queryParameters,
    bool? useBaseUrl,
    bool enableEtagCache,
  }) _getRequest;

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
    String? country,
    String? state,
    String? city,
    int? areaId,
    int perPage = Constant.loadLimit,
  }) async {
    final Map<String, dynamic> parameters = {
      Api.categoryId: categoryId,
      Api.page: page,
      'view': 'summary',
      Api.perPageQuery: perPage,
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
    if (country?.isNotEmpty ?? false) parameters['country'] = country;
    if (state?.isNotEmpty ?? false) parameters['state'] = state;
    if (city?.isNotEmpty ?? false) parameters['city'] = city;
    if (areaId != null) parameters['area_id'] = areaId;

    final Map<String, dynamic> response = await _getRequest(
      url: Api.getItemApi,
      queryParameters: parameters,
      enableEtagCache: false,
    );

    final Iterable<dynamic> rawItems =
        ItemRepository._extractItemsOrData(response);

    final List<ItemSummary> items = ItemRepository._mapJsonListToModels(
      rawItems,
      ItemSummary.fromJson,
      ItemRepository._itemSummaryExpectedFields,
      'fetchItemSummariesFromCatId',
    );

    final int total = ItemRepository.resolveTotalCount(
      response,
      items.length,
    );

    return DataOutput(
      total: total,
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

      final Iterable<Map<String, dynamic>> itemMaps =
          ItemRepository._resolveItemsFromResponse(response);

      final List<ItemModel> itemList =
          itemMaps.map(ItemModel.fromJson).toList();

      final int total = ItemRepository.resolveTotalCount(
        response,
        itemList.length,
      );

      return DataOutput(
        total: total,
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

      final Iterable<Map<String, dynamic>> itemMaps =
          ItemRepository._resolveItemsFromResponse(response);

      final List<ItemModel> itemList =
          itemMaps.map(ItemModel.fromJson).toList();

      final int total = ItemRepository.resolveTotalCount(
        response,
        itemList.length,
      );

      return DataOutput(
        total: total,
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
    final Map<String, dynamic> parameters = {
      Api.id: id,
      'view': 'detail',
    };

    final Map<String, dynamic> response = await _getRequest(
      url: Api.getItemApi,
      queryParameters: parameters,
      enableEtagCache: false,
    );

    final Iterable<Map<String, dynamic>> itemMaps =
        ItemRepository._extractItemMaps(response);

    final List<ItemModel> modelList =
        itemMaps.map(ItemModel.fromJson).toList(growable: false);

    final int total =
        ItemRepository.resolveTotalCount(response, modelList.length);

    return DataOutput(total: total, modelList: modelList);
  }

  /// -------------------------------------------------------------------------
  /// fetchItemFromItemSlug
  /// جلب عنصر من خلال الـ slug
  /// يعيد: DataOutput<ItemModel> من البينات الراجعة (data.data)
  /// -------------------------------------------------------------------------
  Future<DataOutput<ItemModel>> fetchItemFromItemSlug(String slug) async {
    final Map<String, dynamic> parameters = {
      'slug': slug,
      'view': 'detail',
    };

    final Map<String, dynamic> response = await _getRequest(
      url: Api.getItemApi,
      queryParameters: parameters,
      enableEtagCache: false,
    );

    final Iterable<Map<String, dynamic>> itemMaps =
        ItemRepository._extractItemMaps(response);

    final List<ItemModel> modelList =
        itemMaps.map(ItemModel.fromJson).toList(growable: false);

    final int total =
        ItemRepository.resolveTotalCount(response, modelList.length);

    return DataOutput(total: total, modelList: modelList);
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
  Future<DataOutput<ItemSummary>> fetchItemFromCatId({
    required int categoryId,
    required int page,
    String? search,
    String? sortBy,
    String? country,
    String? state,
    String? city,
    int? areaId,
    ItemFilterModel? filter,
  }) {
    return fetchItemSummariesFromCatId(
      categoryId: categoryId,
      page: page,
      search: search,
      sortBy: sortBy,
      filter: filter,
      country: country,
      state: state,
      city: city,
      areaId: areaId,
    );
  }

  @visibleForTesting
  static const List<String> _itemSummaryExpectedFields = <String>['id', 'name'];

  static Iterable<dynamic> _extractItemsOrData(
    Map<String, dynamic> response,
  ) {
    final dynamic itemsSection = response['items'];
    if (itemsSection != null) {
      final Iterable<dynamic> extracted = _extractIterable(itemsSection);
      if (extracted.isNotEmpty || _isExplicitCollection(itemsSection)) {
        return extracted;
      }
    }

    final dynamic dataSection = response['data'];
    if (dataSection != null) {
      final Iterable<dynamic> extracted = _extractIterable(dataSection);
      if (extracted.isNotEmpty || _isExplicitCollection(dataSection)) {
        return extracted;
      }
    }

    final dynamic resultsSection = response['results'];
    if (resultsSection != null) {
      final Iterable<dynamic> extracted = _extractIterable(resultsSection);
      if (extracted.isNotEmpty || _isExplicitCollection(resultsSection)) {
        return extracted;
      }
    }

    return const Iterable<dynamic>.empty();
  }

  static List<T> _mapJsonListToModels<T>(
    Iterable<dynamic> rawItems,
    T Function(Map<String, dynamic>) factory,
    List<String> expectedFields,
    String context,
  ) {
    final List<T> models = <T>[];
    for (final dynamic rawItem in rawItems) {
      if (rawItem is! Map<String, dynamic>) {
        Logger.debug(
          '[WARNING][$context] Expected Map<String, dynamic> but received ${rawItem.runtimeType}',
          name: 'ItemRepository',
        );
        continue;
      }

      final Iterable<String> missingFields = expectedFields.where(
        (String key) => !rawItem.containsKey(key),
      );

      if (missingFields.isNotEmpty) {
        Logger.debug(
          '[WARNING][$context] Missing fields: ${missingFields.join(', ')}',
          name: 'ItemRepository',
        );
      }

      models.add(factory(rawItem));
    }

    return models;
  }

  @visibleForTesting
  static Iterable<Map<String, dynamic>> resolvePaginatedMapList(
    Map<String, dynamic> response,
  ) {
    final Iterable<dynamic> dataItems = _extractIterable(response['data']);
    if (dataItems.isNotEmpty || _isExplicitCollection(response['data'])) {
      return dataItems.whereType<Map<String, dynamic>>();
    }

    final Iterable<dynamic> items = _extractIterable(response['items']);
    if (items.isNotEmpty || _isExplicitCollection(response['items'])) {
      return items.whereType<Map<String, dynamic>>();
    }

    final Iterable<dynamic> results = _extractIterable(response['results']);
    if (results.isNotEmpty || _isExplicitCollection(response['results'])) {
      return results.whereType<Map<String, dynamic>>();
    }

    return const Iterable<Map<String, dynamic>>.empty();
  }

  static Iterable<Map<String, dynamic>> _resolveItemsFromResponse(
    Map<String, dynamic> response,
  ) {
    final Iterable<Map<String, dynamic>> dataItems =
        _extractItemMapsFromSection(response['data']);
    if (dataItems.isNotEmpty) {
      return dataItems;
    }

    final Iterable<Map<String, dynamic>> fallback =
        ItemRepository.resolvePaginatedMapList(response);
    if (fallback.isNotEmpty) {
      return fallback;
    }

    return const Iterable<Map<String, dynamic>>.empty();
  }

  @visibleForTesting
  static Iterable<Map<String, dynamic>> _extractItemMaps(
    Map<String, dynamic> response,
  ) {
    final Iterable<Map<String, dynamic>> fromItems =
        _extractItemMapsFromSection(response['items']);
    if (fromItems.isNotEmpty) {
      return fromItems;
    }

    final Iterable<Map<String, dynamic>> fromData =
        _extractItemMapsFromSection(response['data']);
    if (fromData.isNotEmpty) {
      return fromData;
    }

    final Iterable<Map<String, dynamic>> fromResults =
        _extractItemMapsFromSection(response['results']);
    if (fromResults.isNotEmpty) {
      return fromResults;
    }

    return _extractItemMapsFromSection(response);
  }

  static Iterable<Map<String, dynamic>> _extractItemMapsFromSection(
    dynamic section,
  ) {
    if (section == null) {
      return const Iterable<Map<String, dynamic>>.empty();
    }

    if (section is Iterable) {
      return section.whereType<Map<String, dynamic>>();
    }

    if (section is Map<String, dynamic>) {
      for (final String key in const <String>{
        'items',
        'data',
        'results',
        'item'
      }) {
        if (!section.containsKey(key)) {
          continue;
        }

        final dynamic nested = section[key];

        if (nested is Iterable) {
          return nested.whereType<Map<String, dynamic>>();
        }

        if (nested is Map<String, dynamic>) {
          return <Map<String, dynamic>>[nested];
        }
      }

      if (section.containsKey('id')) {
        return <Map<String, dynamic>>[section];
      }
    }

    return const Iterable<Map<String, dynamic>>.empty();
  }

  @visibleForTesting
  static int resolveTotalCount(
    Map<String, dynamic> response,
    int fallbackCount,
  ) {
    final int? totalFromData = _parseTotal(response['data']);
    if (totalFromData != null) {
      return totalFromData;
    }

    final int? totalFromItems = _parseTotal(response['items']);
    if (totalFromItems != null) {
      return totalFromItems;
    }

    final int? totalFromRoot = _parseTotal(response);
    return totalFromRoot ?? fallbackCount;
  }

  static Iterable<dynamic> _extractIterable(dynamic value) {
    if (value == null) {
      return const Iterable<dynamic>.empty();
    }
    if (value is Iterable<dynamic>) {
      return value;
    }
    if (value is Map<String, dynamic>) {
      if (value.containsKey('data')) {
        final dynamic nested = value['data'];
        final Iterable<dynamic> nestedIterable = _extractIterable(nested);
        if (nestedIterable.isNotEmpty || _isExplicitCollection(nested)) {
          return nestedIterable;
        }
      }
      if (value.containsKey('items')) {
        final dynamic nested = value['items'];
        final Iterable<dynamic> nestedIterable = _extractIterable(nested);
        if (nestedIterable.isNotEmpty || _isExplicitCollection(nested)) {
          return nestedIterable;
        }
      }
      if (value.containsKey('results')) {
        final dynamic nested = value['results'];
        final Iterable<dynamic> nestedIterable = _extractIterable(nested);
        if (nestedIterable.isNotEmpty || _isExplicitCollection(nested)) {
          return nestedIterable;
        }
      }
      if (value.containsKey('item')) {
        final dynamic nested = value['item'];
        final Iterable<dynamic> nestedIterable = _extractIterable(nested);
        if (nestedIterable.isNotEmpty || _isExplicitCollection(nested)) {
          return nestedIterable;
        }
      }
      return <Map<String, dynamic>>[value];
    }
    return const Iterable<dynamic>.empty();
  }

  static bool _isExplicitCollection(dynamic value) {
    if (value == null) {
      return false;
    }
    if (value is Iterable<dynamic>) {
      return true;
    }
    if (value is Map<String, dynamic>) {
      return value.containsKey('data') ||
          value.containsKey('items') ||
          value.containsKey('results') ||
          value.containsKey('item');
    }
    return false;
  }

  static int? _parseTotal(dynamic value) {
    if (value is Map<String, dynamic>) {
      for (final String key in const <String>{
        'total',
        'total_count',
        'totalItems',
        'total_items',
        'count',
      }) {
        final int? parsed = _tryParseInt(value[key]);
        if (parsed != null) {
          return parsed;
        }
      }

      final int? paginationTotal = _parseTotal(value['pagination']);
      if (paginationTotal != null) {
        return paginationTotal;
      }

      final int? metaTotal = _parseTotal(value['meta']);
      if (metaTotal != null) {
        return metaTotal;
      }
    }
    return null;
  }

  static int? _tryParseInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
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

    final Iterable<Map<String, dynamic>> itemMaps =
        ItemRepository._resolveItemsFromResponse(response);

    final List<ItemModel> items = itemMaps.map(ItemModel.fromJson).toList();

    final int total = ItemRepository.resolveTotalCount(
      response,
      items.length,
    );

    return DataOutput(
      total: total,
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

    final Iterable<Map<String, dynamic>> itemMaps =
        ItemRepository._resolveItemsFromResponse(response);

    final List<ItemModel> items = itemMaps.map(ItemModel.fromJson).toList();

    final int total = ItemRepository.resolveTotalCount(
      response,
      items.length,
    );

    return DataOutput(
      total: total,
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
