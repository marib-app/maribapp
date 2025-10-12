import 'package:marib/data/model/currency_rate.dart';
import 'package:marib/data/model/governorate.dart';

class CurrencyRatesBundle {
  final List<CurrencyRate> rates;
  final List<Governorate> governorates;
  final Governorate? requestedGovernorate;
  final Governorate? appliedGovernorate;
  final bool usedFallback;
  final String? requestedGovernorateCode;

  const CurrencyRatesBundle({
    required this.rates,
    required this.governorates,
    this.requestedGovernorate,
    this.appliedGovernorate,
    required this.usedFallback,
    this.requestedGovernorateCode,
  });

  factory CurrencyRatesBundle.fromApi(
      List<dynamic> ratesData,
      Map<String, dynamic> payload,
      ) {
    final rates = ratesData
        .map((json) => CurrencyRate.fromJson(json as Map<String, dynamic>))
        .toList();

    final governorates = (payload['governorates'] as List<dynamic>? ?? [])
        .map((gov) => Governorate.fromJson(gov as Map<String, dynamic>))
        .toList();

    Governorate? parseGovernorate(dynamic json) {
      if (json is Map<String, dynamic>) {
        final code = json['code'];
        final name = json['name'];
        if (code != null && name != null) {
          return Governorate(
            code: code.toString(),
            name: name.toString(),
          );
        }
      }
      return null;
    }

    return CurrencyRatesBundle(
      rates: rates,
      governorates: governorates,
      requestedGovernorate: parseGovernorate(payload['requested_governorate']),
      appliedGovernorate: parseGovernorate(payload['applied_governorate']),
      usedFallback: payload['used_fallback'] == true,
      requestedGovernorateCode:
      payload['requested_governorate_code']?.toString(),
    );
  }
}