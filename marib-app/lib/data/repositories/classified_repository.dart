import 'package:marib/data/model/classified_model.dart';
import 'package:marib/data/model/data_output.dart';
import 'package:marib/utils/api.dart';

class ClassifiedRepository {
  Future<DataOutput<ClassifiedModel>> fetchclassified(
      {required int page}) async {
    Map<String, dynamic> parameters = {
      Api.page: page,
    };

    Map<String, dynamic> result =
        await Api.get(url: Api.getBlogApi, queryParameters: parameters);

    List<ClassifiedModel> modelList = (result['data']['data'] as List)
        .map((element) => ClassifiedModel.fromJson(element))
        .toList();

    return DataOutput<ClassifiedModel>(
        total: result['data']['total'] ?? 0, modelList: modelList);
  }
}
