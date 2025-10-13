import 'package:marib/data/model/metal_rates_bundle.dart';
import 'package:marib/utils/api.dart';

class MetalRepository {
  Future<MetalRatesBundle> getMetalRates() async {
    try {
      final Map<String, dynamic> result = await Api.get(
        url: Api.getMetalRatesApi,
      );

      if (result['error'] == false) {
        return MetalRatesBundle.fromApi(result);
      }
    } catch (e) {
      print('Error fetching metal rates: $e');
    }

    return const MetalRatesBundle(rates: [], lastUpdatedAt: null);
  }
}