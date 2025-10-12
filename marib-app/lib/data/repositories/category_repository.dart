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

      final dynamic data = response['data'];

      late final List<CategoryModel> modelList;
      int total = 0;

      if (data is List) {
        modelList = data
            .whereType<Map<String, dynamic>>()
            .map(CategoryModel.fromJson)
            .toList();

        final dynamic meta = response['meta'];
        if (meta is Map<String, dynamic>) {
          total = _parseTotal(meta['total']) ??
              _parseTotal(meta['last_page']) ??
              modelList.length;
        } else {
          total = modelList.length;
        }
      } else if (data is Map<String, dynamic>) {
        final dynamic rawList = data['data'];
        modelList = (rawList is List ? rawList : const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(CategoryModel.fromJson)
            .toList();

        total = _parseTotal(data['total']) ?? modelList.length;

        if (total == modelList.length) {
          final dynamic meta = data['meta'];
          if (meta is Map<String, dynamic>) {
            total = _parseTotal(meta['total']) ?? total;
          }
        }
      } else {
        throw ApiException('Invalid categories payload');
      }

      return DataOutput(total: total, modelList: modelList);
      // return (total: response['total'] ?? 0, modelList: modelList);
    } catch (e) {
      rethrow;
    }
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
