import 'package:marib/data/model/home/home_screen_section.dart';
import 'package:marib/utils/api.dart';
import 'package:marib/data/model/data_output.dart';
import 'package:marib/data/model/item/item_model.dart';
import 'package:marib/utils/slider_interface_mapper.dart';

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
    } catch (e) {
      print('Error in fetchHome: $e');
      print('Response structure might be unexpected');
      rethrow;
    }
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
      Map<String, dynamic> parameters = {
        "page": page,
        // Remove location filtering to show all items regardless of location
        // if (radius == null) ...{
        //   if (city != null && city != "") 'city': city,
        //   if (areaId != null && areaId != "") 'area_id': areaId,
        //   if (country != null && country != "") 'country': country,
        //   if (state != null && state != "") 'state': state,
        // },
        // if (radius != null && radius != "") 'radius': radius,
        // if (latitude != null && latitude != "") 'latitude': latitude,
        // if (longitude != null && longitude != "") 'longitude': longitude,
        "sort_by": "new-to-old"
      };

      Map<String, dynamic> response =
          await Api.get(url: Api.getItemApi, queryParameters: parameters);
      List<ItemModel> items = (response['data']['data'] as List)
          .map((e) => ItemModel.fromJson(e))
          .toList();

      return DataOutput(
          total: response['data']['total'] ?? 0, modelList: items);
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
      Map<String, dynamic> parameters = {
        "page": page,
        "featured_section_id": sectionId,
        // Remove location filtering to show all section items regardless of location
        // if (city != null && city != "") 'city': city,
        // if (areaId != null && areaId != "") 'area_id': areaId,
        // if (country != null && country != "") 'country': country,
        // if (state != null && state != "") 'state': state,
      };

      Map<String, dynamic> response =
          await Api.get(url: Api.getItemApi, queryParameters: parameters);
      List<ItemModel> items = (response['data']['data'] as List)
          .map((e) => ItemModel.fromJson(e))
          .toList();

      return DataOutput(
          total: response['data']['total'] ?? 0, modelList: items);
    } catch (error) {
      rethrow;
    }
  }
}
