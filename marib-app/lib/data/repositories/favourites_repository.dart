import 'package:marib/data/model/data_output.dart';
import 'package:marib/data/model/item/item_model.dart';
import 'package:marib/utils/api.dart';

class FavoriteRepository {
  Future<void> manageFavorites(int id) async {
    final parameters = {Api.itemId: id};

    await Api.post(
      url: Api.manageFavouriteApi,
      parameter: parameters,
      useBaseUrl: true,
    );
  }

  // ===== Helpers (داخل نفس الملف) =====
  List<Map<String, dynamic>> _onlyMaps(dynamic v) {
    if (v is List) {
      return v
          .where((e) => e is Map<String, dynamic>)
          .cast<Map<String, dynamic>>()
          .toList();
    }
    return const <Map<String, dynamic>>[];
  }

  Map<String, dynamic> _sanitizeItemMap(Map<String, dynamic> m) {
    // نسخة قابلة للتعديل
    final map = Map<String, dynamic>.from(m);

    // قوائم قد تحتوي عناصر ليست خرائط
    map['custom_fields'] = _onlyMaps(map['custom_fields']);
    map['gallery_images'] = _onlyMaps(map['gallery_images']);
    map['favourites'] = _onlyMaps(map['favourites']);
    map['featured_items'] = _onlyMaps(map['featured_items']);

    // ضبط بعض الحقول الشائعة داخل custom_fields
    final cfs = (map['custom_fields'] as List<Map<String, dynamic>>);
    for (final cf in cfs) {
      final rawValues = cf['values'];
      if (rawValues != null && rawValues is! List) {
        cf['values'] = [rawValues];
      }
      final rawValue = cf['value'];
      if (rawValue != null && rawValue is! List) {
        cf['value'] = [rawValue];
      }
      if (cf['custom_field_value'] is Map) {
        final cfv = cf['custom_field_value'] as Map<String, dynamic>;
        final v = cfv['value'];
        if (v != null && v is! List) {
          cfv['value'] = [v];
        }
      }
    }

    return map;
  }

  Future<DataOutput<ItemModel>> fetchFavorites({required int page}) async {
    print("🌐 إرسال طلب جلب المفضلة - الصفحة: $page");

    final parameters = {Api.page: page};

    print("📤 المعاملات المُرسلة: $parameters");
    print("🔗 الرابط: ${Api.getFavoriteItemApi}");

    final response = await Api.get(
      url: Api.getFavoriteItemApi,
      queryParameters: parameters,
      useBaseUrl: true,
    );

    final data = response['data'] as Map<String, dynamic>?;

    print("📥 الاستجابة من الخادم:");
    print("   - نوع البيانات: ${data.runtimeType}");
    print("   - محتوى البيانات: $data");

    final rows = (data?['data'] as List?) ?? const [];

    // ✅ تنقية كل عنصر قبل تحويله للموديل
    final List<ItemModel> modelList = rows
        .map<ItemModel?>((e) {
          if (e is Map) {
            final sanitized = _sanitizeItemMap(Map<String, dynamic>.from(e));
            return ItemModel.fromJson(sanitized);
          }
          // نتجاهل أي عنصر ليس خريطة
          return null;
        })
        .whereType<ItemModel>()
        .toList();

    print("🔄 تم تحويل ${modelList.length} عنصر بنجاح");

    final total = (data?['total'] as int?) ?? modelList.length;

    return DataOutput<ItemModel>(
      total: total,
      modelList: modelList,
    );
  }
}
