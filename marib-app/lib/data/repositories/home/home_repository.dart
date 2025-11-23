import 'package:marib/data/model/home/home_screen_section.dart';
import 'package:marib/utils/api.dart';
import 'package:marib/data/model/data_output.dart';
import 'package:marib/data/model/item/item_model.dart';
import 'package:marib/utils/slider_interface_mapper.dart';
import 'package:marib/settings.dart';
import 'package:marib/utils/hive_utils.dart';

class HomeRepository {
  Future<List<HomeScreenSection>> fetchHome({
    String? interfaceType,
    String? country,
    String? state,
    String? city,
    String? slug,
    String? rootIdentifier,
    int? areaId,
  }) async {
    try {
      return await _fetchSections(
        interfaceType: interfaceType,
        country: country,
        state: state,
        city: city,
        slug: slug,
        rootIdentifier: rootIdentifier,
        areaId: areaId,
      );
    } on ApiHttpException catch (e) {
      final bool unauthorized = e.statusCode == 401 || e.statusCode == 403;
      final bool hadAuthSession =
          HiveUtils.isUserAuthenticated() || HiveUtils.isUserBasicallyAuthenticated();


      if (unauthorized && hadAuthSession) {
        await HiveUtils.clear();
        return await _fetchSections(
          interfaceType: interfaceType,
          country: country,
          state: state,
          city: city,
          slug: slug,
          rootIdentifier: rootIdentifier,
          areaId: areaId,
        );
      }

      rethrow;
    } catch (e) {
      print('Error in fetchHome: $e');
      print('Response structure might be unexpected');
      rethrow;
    }
  }

  Future<List<HomeScreenSection>> _fetchSections({
    String? interfaceType,
    String? country,
    String? state,
    String? city,
    String? slug,
    String? rootIdentifier,
    int? areaId,
  }) async {
    final String? trimmedSlug = slug?.trim();
    final String? trimmedRootIdentifier = rootIdentifier?.trim();

    final String? normalizedInterfaceType =
        SliderInterfaceMapper.normalize(interfaceType) ??
            interfaceType?.trim();

    final Map<String, dynamic> parameters = {
      if (normalizedInterfaceType != null &&
          normalizedInterfaceType.isNotEmpty) ...{
        'section_type': normalizedInterfaceType,
        'interface_type': normalizedInterfaceType,
      },
      if (trimmedSlug != null && trimmedSlug.isNotEmpty) 'slug': trimmedSlug,
      if (trimmedRootIdentifier != null && trimmedRootIdentifier.isNotEmpty)
        'root_identifier': trimmedRootIdentifier,
      // Location filters kept for future use (currently disabled)
      // if (city != null && city.isNotEmpty) 'city': city,
      // if (areaId != null) 'area_id': areaId,
      // if (country != null && country.isNotEmpty) 'country': country,
      // if (state != null && state.isNotEmpty) 'state': state,
    };

    Map<String, dynamic> response = await Api.get(
      url: Api.getFeaturedSectionApi,
      queryParameters: parameters,
      enableEtagCache: true,
    );

    final dynamic raw = response['data'] ?? response;

    List<HomeScreenSection> parseSections(dynamic source) {
      if (source is List) {
        return source.whereType<Map>().map<HomeScreenSection>((element) {
          final map = Map<String, dynamic>.from(element);
          return HomeScreenSection.fromJson(map);
        }).toList();
      }
      if (source is Map) {
        final map = Map<String, dynamic>.from(source);

        if (map['sections'] is List) {
          return parseSections(map['sections']);
        }

        if (map['data'] is List) {
          return parseSections(map['data']);
        }

        if (map.isNotEmpty) {
          return [HomeScreenSection.fromJson(map)];
        }
      }

      return <HomeScreenSection>[];

    }
    return parseSections(raw);

  }

  Future<DataOutput<ItemModel>> fetchHomeAllItems(
      {required int page,
      String? country,
      String? state,
      String? city,
      double? latitude,
      double? longitude,
      int? areaId,
      int? radius}) async {
    try {
      final Map<String, dynamic> parameters = <String, dynamic>{
        'page': page,
        'view': 'summary',
        Api.perPageQuery: AppSettings.apiDataLoadLimit,
        'sort_by': 'new-to-old',
      };

      final Map<String, dynamic> response = await Api.get(
        url: Api.getItemApi,
        queryParameters: parameters,
        enableEtagCache: true,
      );

      final dynamic data = response['data'] ?? response;
      final List<Map<String, dynamic>> rawItems = _extractItemsPayload(data);
      final List<ItemModel> items = rawItems
          .map(ItemSummary.fromJson)
          .map((summary) => summary.toItemModelSkeleton())
          .toList(growable: false);

      final int total = _resolveSummaryTotal(data, items.length);

      return DataOutput(total: total, modelList: items);
    } catch (error) {
      rethrow;
    }
  }

  Future<DataOutput<ItemModel>> fetchSectionItems(
      {required int page,
      required int sectionId,
      String? country,
      String? state,
      String? city,
      int? areaId}) async {
    try {
      final Map<String, dynamic> parameters = <String, dynamic>{
        'page': page,
        'view': 'summary',
        Api.perPageQuery: AppSettings.sectionItemsPageSize,
        'featured_section_id': sectionId,
      };

      final Map<String, dynamic> response = await Api.get(
        url: Api.getItemApi,
        queryParameters: parameters,
        enableEtagCache: true,
      );

      final dynamic data = response['data'] ?? response;
      final List<Map<String, dynamic>> rawItems = _extractItemsPayload(data);
      final List<ItemModel> items = rawItems
          .map(ItemSummary.fromJson)
          .map((summary) => summary.toItemModelSkeleton())
          .toList(growable: false);

      final int total = _resolveSummaryTotal(data, items.length);

      return DataOutput(total: total, modelList: items);
    } catch (error) {
      rethrow;
    }
  }

  List<Map<String, dynamic>> _extractItemsPayload(dynamic payload) {
    if (payload is Map<String, dynamic>) {
      final dynamic items = payload['items'];
      if (items is List) {
        return items
            .whereType<Map>()
            .map((entry) => Map<String, dynamic>.from(entry))
            .toList(growable: false);
      }

      final dynamic dataField = payload['data'];
      if (dataField is List) {
        return dataField
            .whereType<Map>()
            .map((entry) => Map<String, dynamic>.from(entry))
            .toList(growable: false);
      }

      if (dataField is Map<String, dynamic>) {
        return _extractItemsPayload(dataField);
      }
    }

    if (payload is List) {
      return payload
          .whereType<Map>()
          .map((entry) => Map<String, dynamic>.from(entry))
          .toList(growable: false);
    }

    return const <Map<String, dynamic>>[];
  }

  int _resolveSummaryTotal(dynamic payload, int fallback) {
    int? _coerceToInt(dynamic value) {
      if (value is int) {
        return value;
      }
      if (value is num) {
        return value.toInt();
      }
      if (value is String) {
        return int.tryParse(value);
      }
      return null;
    }

    if (payload is Map<String, dynamic>) {
      final dynamic meta = payload['meta'];
      if (meta is Map<String, dynamic>) {
        final int? totalFromMeta = _coerceToInt(meta['total']);
        if (totalFromMeta != null) {
          return totalFromMeta;
        }
      }

      final int? directTotal = _coerceToInt(payload['total']);
      if (directTotal != null) {
        return directTotal;
      }

      if (payload.containsKey('data')) {
        return _resolveSummaryTotal(payload['data'], fallback);
      }
    }

    return fallback;
  }
}
