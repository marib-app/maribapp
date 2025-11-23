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
    Iterable<int> allowedCategoryIds = const <int>[],
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
          await Api.get(
            url: Api.getCategoriesApi,
            queryParameters: parameters,
            includeAuthHeader: false,
          );

      final CategoryModel? selfCategory =
          _parseSelfCategory(response, categoryId: categoryId);

      final _ParsedPaginatedData<CategoryModel> parsed =
          _parseCategoryResponse(response['data']);

      List<CategoryModel> items = List<CategoryModel>.from(parsed.items);

      if (selfCategory != null) {
        final int? targetId = selfCategory.id;
        if (targetId != null) {
          final int existingIndex =
              items.indexWhere((CategoryModel c) => c.id == targetId);
          if (existingIndex >= 0) {
            items[existingIndex] = selfCategory;
          } else {
            items = <CategoryModel>[selfCategory, ...items];
          }
        } else {
          items = <CategoryModel>[selfCategory, ...items];
        }
      }

      if (onlyAllowed) {
        final Set<int> required = _normalizeCategoryIds(ensureCategoryIds);
        final Set<int> allowed = _normalizeCategoryIds(allowedCategoryIds);
        allowed.addAll(required);
        items = _filterAllowedCategories(items, required, allowed);
      }

      return DataOutput(
        total: parsed.total,
        modelList: items,
        page: parsed.page ?? page,
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

      final Map<String, dynamic>? meta = data['meta'] is Map<String, dynamic>
          ? data['meta'] as Map<String, dynamic>
          : null;
      final Map<String, dynamic>? pagination =
          data['pagination'] is Map<String, dynamic>
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

  CategoryModel? _parseSelfCategory(Map<String, dynamic> response,
      {int? categoryId}) {
    final dynamic topLevel = response['self_category'];
    final dynamic nested = (response['data'] is Map<String, dynamic>)
        ? (response['data'] as Map<String, dynamic>)['self_category']
        : null;

    final dynamic raw = topLevel ?? nested;
    if (raw is! Map<String, dynamic>) {
      return null;
    }

    final CategoryModel candidate = CategoryModel.fromJson(raw);
    if (categoryId != null &&
        candidate.id != null &&
        candidate.id != categoryId) {
      // إذا أرجع الخادم فئة مختلفة بشكل غير متوقع، تجاهلها
      return null;
    }
    return candidate;
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
    Set<int> allowedCategoryIds,
  ) {
    final List<CategoryModel> filtered = <CategoryModel>[];
    final bool restrictByAllowed = allowedCategoryIds.isNotEmpty;

    for (final CategoryModel category in categories) {
      final List<CategoryModel> children = _filterAllowedCategories(
        category.children ?? const <CategoryModel>[],
        ensureCategoryIds,
        allowedCategoryIds,
      );

      final int? id = category.id;
      final bool isRequired = id != null && ensureCategoryIds.contains(id);
      final bool childRetained = children.isNotEmpty;
      final bool interfaceAllowed = _isInterfaceAllowed(category.interfaceType);
      final bool explicitlyAllowed =
          !restrictByAllowed || (id != null && allowedCategoryIds.contains(id));
      final bool isAllowed =
          interfaceAllowed || (restrictByAllowed && explicitlyAllowed);
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
