import 'package:marib/data/model/merchant/merchant_dashboard_summary.dart';
import 'package:marib/utils/api.dart';

class MerchantRepository {
  const MerchantRepository();

  Future<MerchantDashboardSummary> fetchDashboardSummary() async {
    final response = await Api.get(url: Api.storeDashboardSummaryApi);
    return MerchantDashboardSummary.fromJson(response);
  }
}
