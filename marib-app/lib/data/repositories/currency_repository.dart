import 'package:marib/data/model/currency_rate.dart';
import 'package:marib/utils/api.dart';

class CurrencyRepository {
  Future<List<CurrencyRate>> getCurrencyRates() async {
    try {
      Map<String, dynamic> result = await Api.get(url: Api.getCurrencyRatesApi);

      if (result['error'] == false && result['data'] != null) {
        final List<dynamic> currencyData = result['data'];
        return currencyData.map((json) => CurrencyRate.fromJson(json)).toList();
      }

      return [];
    } catch (e) {
      print('Error fetching currency rates: $e');
      return [];
    }
  }
}
