import 'package:marib/data/model/category_model.dart';
import 'package:marib/data/model/data_output.dart';
import 'package:marib/utils/api.dart';
import 'dart:collection';
import 'package:marib/utils/hive_utils.dart';



class CategoryRepository {
  Future<DataOutput<CategoryModel>> fetchCategories({
    required int page,
    int? categoryId,
    String? interfaceType,
    List<int>? categoryIds,
    bool onlyAllowed = false,
    Iterable<int> ensureCategoryIds = const <int>[],
  }) async {
    try {
      Map<String, dynamic> parameters = {
        Api.page: page,
      };

      if (categoryId != null) {
        parameters[Api.categoryId] = categoryId;
      }
      if (categoryIds != null && categoryIds.isNotEmpty) {
        parameters[Api.categoryIds] = categoryIds.join(',');
      }
      if (interfaceType != null && interfaceType.trim().isNotEmpty) {
        parameters[Api.interfaceType] = interfaceType.trim();
      }
      Map<String, dynamic> response =
          await Api.get(url: Api.getCategoriesApi, queryParameters: parameters);

      final _ParsedPaginatedData<CategoryModel> parsed =
      _parseCategoryResponse(response['data']);

      List<CategoryModel> items = parsed.items;
      if (onlyAllowed) {
        final Set<int> required = _normalizeCategoryIds(ensureCategoryIds);
        items = _filterAllowedCategories(items, required);
      }

      return DataOutput(
        total: items.length,
        modelList: items,
        page: parsed.page,
      );
      // return (total: response['total'] ?? 0, modelList: modelList);
    } catch (e) {
      rethrow;
    }
  }


  _ParsedPaginatedData<CategoryModel> _parseCategoryResponse(dynamic data) {
    if (data == null) {
      throw ApiException('Invalid categories payload');
    }

    List<Map<String, dynamic>> rawItems = const <Map<String, dynamic>>[];
    int total = 0;
    int? page;

    if (data is List) {
      rawItems = data.whereType<Map<String, dynamic>>().toList();
      total = rawItems.length;
    } else if (data is Map<String, dynamic>) {
      final dynamic candidateItems =
          data['items'] ?? data['data'] ?? data['records'] ?? data['results'];
      rawItems = (candidateItems is List ? candidateItems : const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .toList();

      final Map<String, dynamic>? meta =
      data['meta'] is Map<String, dynamic>
          ? data['meta'] as Map<String, dynamic>
          : null;
      final Map<String, dynamic>? pagination = data['pagination']
      is Map<String, dynamic>
          ? data['pagination'] as Map<String, dynamic>
          : null;

      total = _parseTotal(data['total']) ??
          _parseTotal(meta?['total']) ??
          _parseTotal(pagination?['total']) ??
          rawItems.length;

      page = _parseTotal(data['page']) ??
          _parseTotal(meta?['current_page']) ??
          _parseTotal(pagination?['current_page']) ??
          _parseTotal(data['current_page']);
    } else {
      throw ApiException('Invalid categories payload');
    }

    final List<CategoryModel> modelList =
    rawItems.map(CategoryModel.fromJson).toList();

    return _ParsedPaginatedData<CategoryModel>(
      items: modelList,
      total: total,
      page: page,
    );
  }


  int? _parseTotal(dynamic source) {
    if (source == null) {
      return null;
    }

    if (source is int) {
      return source;
    }

    if (source is String) {
      return int.tryParse(source);
    }

    return null;
  }
  Set<int> _normalizeCategoryIds(Iterable<int> rawIds) {
    final LinkedHashSet<int> normalized = LinkedHashSet<int>();
    for (final int id in rawIds) {
      if (id <= 0) {
        continue;
      }
      normalized.add(id);
    }
    return normalized;
  }

  List<CategoryModel> _filterAllowedCategories(
      Iterable<CategoryModel> categories,
      Set<int> ensureCategoryIds,
      ) {
    final List<CategoryModel> filtered = <CategoryModel>[];

    for (final CategoryModel category in categories) {
      final List<CategoryModel> children = _filterAllowedCategories(
        category.children ?? const <CategoryModel>[],
        ensureCategoryIds,
      );

      final int? id = category.id;
      final bool isRequired = id != null && ensureCategoryIds.contains(id);
      final bool childRetained = children.isNotEmpty;
      final bool isAllowed = _isInterfaceAllowed(category.interfaceType);

      if (!(isAllowed || isRequired || childRetained)) {
        continue;
      }

      filtered.add(
        CategoryModel(
          id: category.id,
          name: category.name,
          url: category.url,
          description: category.description,
          interfaceType: category.interfaceType,
          subcategoriesCount: children.length,
          children: children,
        ),
      );
    }

    return filtered;
  }

  bool _isInterfaceAllowed(String? interfaceType) {
    final String normalized = (interfaceType ?? '').trim().toLowerCase();
    if (normalized.isEmpty) {
      return true;
    }
    final String? section = _interfaceToDelegateSection[normalized];
    if (section == null) {
      return true;
    }
    return HiveUtils.hasDelegateAccess(section);
  }
}

const Map<String, String> _interfaceToDelegateSection = <String, String>{
  'shein_products': 'shein',
  'shein': 'shein',
  'computer_section': 'computer',
  'computer_products': 'computer',
  'computer': 'computer',
  'store_products': 'store',
  'store': 'store',
};

class _ParsedPaginatedData<T> {
  final List<T> items;
  final int total;
  final int? page;

  const _ParsedPaginatedData({
    required this.items,
    required this.total,
    this.page,
  });
}