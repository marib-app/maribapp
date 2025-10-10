import 'package:marib/data/model/item/purchase_options.dart';
import 'package:marib/utils/api.dart';


class PurchaseOptionsUpdateResult {
  const PurchaseOptionsUpdateResult({
    required this.options,
    required this.message,
    this.finalPrice,
  });

  final ItemPurchaseOptions options;
  final String message;
  final double? finalPrice;
}


class ItemPurchaseOptionsRepository {
  Future<ItemPurchaseOptions> fetch(int itemId) async {
    final Map<String, dynamic> response = await Api.get(
      url: Api.productPurchaseOptionsApi(itemId),
    );

    final dynamic data = response['data'];
    if (data is Map<String, dynamic>) {
      return ItemPurchaseOptions.fromJson(data);
    }

    if (data is Map) {
      return ItemPurchaseOptions.fromJson(
        data.map((dynamic key, dynamic value) => MapEntry(key.toString(), value)),
      );
    }

    throw Exception('unexpected-response');
  }



  Future<PurchaseOptionsUpdateResult> saveAttributes({
    required int itemId,
    required Map<String, dynamic> selectedValues,
    required Map<String, String> textValues,
  }) async {
    final Map<String, dynamic> response = await Api.post(
      url: Api.itemAttributesApi(itemId),
      parameter: <String, dynamic>{
        'selected_values': selectedValues,
        'text_values': textValues,
      },
    );

    return _parseUpdateResponse(response);
  }

  Future<PurchaseOptionsUpdateResult> saveStock({
    required int itemId,
    required List<Map<String, dynamic>> rows,
  }) async {
    final Map<String, dynamic> response = await Api.post(
      url: Api.itemStockBulkSetApi(itemId),
      parameter: <String, dynamic>{'rows': rows},
    );

    return _parseUpdateResponse(response);
  }

  Future<PurchaseOptionsUpdateResult> saveDiscount({
    required int itemId,
    required Map<String, dynamic> payload,
  }) async {
    final Map<String, dynamic> response = await Api.requestJson(

      url: Api.itemDiscountApi(itemId),
      method: 'PATCH',
      data: payload,
    );

    return _parseUpdateResponse(response);
  }

  PurchaseOptionsUpdateResult _parseUpdateResponse(
      Map<String, dynamic> response,) {
    final Map<String, dynamic>? data =
    response['data'] is Map ? Map<String, dynamic>.from(response['data']) : null;

    final String message = response['message']?.toString() ?? 'تم الحفظ بنجاح';

    if (data == null) {
      throw Exception('unexpected-response');
    }

    final dynamic optionsRaw = data['purchase_options'];
    if (optionsRaw is! Map<String, dynamic>) {
      throw Exception('unexpected-response');
    }

    final ItemPurchaseOptions options =
    ItemPurchaseOptions.fromJson(optionsRaw as Map<String, dynamic>);

    final double? finalPrice = data['final_price'] is num
        ? (data['final_price'] as num).toDouble()
        : double.tryParse(data['final_price']?.toString() ?? '');

    return PurchaseOptionsUpdateResult(
      options: options,
      message: message,
      finalPrice: finalPrice,
    );
  }



}