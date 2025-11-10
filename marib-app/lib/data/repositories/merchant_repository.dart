import 'package:marib/data/model/merchant/merchant_dashboard_summary.dart';
import 'package:marib/data/model/merchant/merchant_manual_payment.dart';
import 'package:marib/data/model/merchant/merchant_order.dart';
import 'package:marib/data/model/merchant/merchant_store_snapshot.dart';
import 'package:marib/data/model/merchant/paginated_result.dart';
import 'package:marib/utils/api.dart';

class MerchantRepository {
  const MerchantRepository();

  Future<MerchantDashboardSummary> fetchDashboardSummary() async {
    final response = await Api.get(url: Api.storeDashboardSummaryApi);
    return MerchantDashboardSummary.fromJson(response);
  }

  Future<PaginatedResult<MerchantOrder>> fetchOrders({
    String? status,
    int page = 1,
    int perPage = 15,
  }) async {
    final response = await Api.get(
      url: 'store/orders',
      queryParameters: {
        'page': page,
        'per_page': perPage,
        if (status != null && status.isNotEmpty) 'status': status,
      },
    );

    return parsePaginatedResult(
      json: response,
      fromJson: (json) => MerchantOrder.fromJson(json),
    );
  }

  Future<PaginatedResult<MerchantManualPayment>> fetchManualPayments({
    String? status,
    int page = 1,
    int perPage = 15,
  }) async {
    final response = await Api.get(
      url: 'store/manual-payments',
      queryParameters: {
        'page': page,
        'per_page': perPage,
        if (status != null && status.isNotEmpty) 'status': status,
      },
    );

    return parsePaginatedResult(
      json: response,
      fromJson: (json) => MerchantManualPayment.fromJson(json),
    );
  }

  Future<void> decideManualPayment({
    required int manualPaymentId,
    required String decision,
    String? note,
    bool notifyCustomer = true,
  }) async {
    await Api.post(
      url: 'store/manual-payments/$manualPaymentId/decision',
      parameter: {
        'decision': decision,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
        'notify_customer': notifyCustomer ? 1 : 0,
      },
    );
  }

  Future<MerchantStoreSnapshot?> fetchStoreProfile() async {
    final Map<String, dynamic> response =
        await Api.get(url: Api.storeOnboardingApi);
    final dynamic rawStore = response['data'];
    if (rawStore is Map<String, dynamic>) {
      return MerchantStoreSnapshot.fromMap(rawStore);
    }
    if (rawStore is Map) {
      return MerchantStoreSnapshot.fromMap(
        rawStore.map(
          (dynamic key, dynamic value) => MapEntry(
            key.toString(),
            value,
          ),
        ),
      );
    }
    return null;
  }
}
