import 'package:marib/data/model/currency_rates_bundle.dart';
import 'package:marib/utils/api.dart';

class CurrencyRepository {

  Future<CurrencyRatesBundle> getCurrencyRates({String? governorateCode}) async {

    try {
      final Map<String, dynamic> result = await Api.get(
        url: Api.getCurrencyRatesApi,
        queryParameters: governorateCode != null
            ? {'governorate_code': governorateCode}
            : null,
      );

      if (result['error'] == false && result['data'] is List<dynamic>) {
        return CurrencyRatesBundle.fromApi(
          result['data'] as List<dynamic>,
          result,
        );
      }

      return CurrencyRatesBundle(
        rates: const [],
        governorates: const [],
        requestedGovernorate: null,
        appliedGovernorate: null,
        usedFallback: false,
        requestedGovernorateCode: governorateCode,
      );
    } catch (e) {
      print('Error fetching currency rates: $e');
      return CurrencyRatesBundle(
        rates: const [],
        governorates: const [],
        requestedGovernorate: null,
        appliedGovernorate: null,
        usedFallback: false,
        requestedGovernorateCode: governorateCode,
      );
    }
  }
}
