import 'package:marib/data/model/currency_rates_bundle.dart';
import 'package:marib/utils/api.dart';
import 'package:marib/data/model/currency_history.dart';

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



  Future<Map<int, CurrencyHistoryBundle>> getCurrencyHistory({
    required List<int> currencyIds,
    String? governorateCode,
  }) async {
    if (currencyIds.isEmpty) {
      return <int, CurrencyHistoryBundle>{};
    }

    final Map<String, dynamic> params = <String, dynamic>{
      'ids': currencyIds.join(','),
    };

    if (governorateCode != null && governorateCode.isNotEmpty) {
      params['governorate_code'] = governorateCode;
    }

    try {
      final Map<String, dynamic> result = await Api.get(
        url: Api.getCurrencyHistoryApi,
        queryParameters: params,
        enableEtagCache: true,
      );

      final Map<int, CurrencyHistoryBundle> histories = <int, CurrencyHistoryBundle>{};
      final dynamic data = result['data'] ?? result;
      final dynamic entries = data is Map ? data['currency_histories'] : null;

      if (entries is List) {
        for (final dynamic entry in entries) {
          if (entry is Map<String, dynamic>) {
            final CurrencyHistoryBundle bundle = CurrencyHistoryBundle.fromJson(entry);
            histories[bundle.currencyId] = bundle;
          }
        }
      }

      return histories;
    } catch (error) {
      print('Error fetching currency history: $error');
      return <int, CurrencyHistoryBundle>{};
    }
  }
}
