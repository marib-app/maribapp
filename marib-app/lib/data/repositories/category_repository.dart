import 'package:marib/data/model/category_model.dart';
import 'package:marib/data/model/data_output.dart';
import 'package:marib/utils/api.dart';

class CategoryRepository {
  Future<DataOutput<CategoryModel>> fetchCategories({
    required int page,
    int? categoryId,
  }) async {
    try {
      Map<String, dynamic> parameters = {
        Api.page: page,
      };

      if (categoryId != null) {
        parameters[Api.categoryId] = categoryId;
      }
      Map<String, dynamic> response =
          await Api.get(url: Api.getCategoriesApi, queryParameters: parameters);

      final _ParsedPaginatedData<CategoryModel> parsed =
      _parseCategoryResponse(response['data']);

      return DataOutput(
        total: parsed.total,
        modelList: parsed.items,
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
}
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