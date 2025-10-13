import 'package:marib/data/model/currency_rate.dart';
import 'package:marib/data/model/governorate.dart';
import 'package:marib/data/model/preference_option.dart';
import 'package:marib/data/model/user_preferences.dart';



class CurrencyRatesBundle {
  final List<CurrencyRate> rates;
  final List<Governorate> governorates;
  final Governorate? requestedGovernorate;
  final Governorate? appliedGovernorate;
  final bool usedFallback;
  final String? requestedGovernorateCode;
  final UserPreferences? preferences;
  final List<PreferenceOption> notificationOptions;


  const CurrencyRatesBundle({
    required this.rates,
    required this.governorates,
    this.requestedGovernorate,
    this.appliedGovernorate,
    required this.usedFallback,
    this.requestedGovernorateCode,
    this.preferences,
    this.notificationOptions = const <PreferenceOption>[],

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



    final dynamic preferencesJson = payload['preferences'];
    final UserPreferences? preferences =
    preferencesJson is Map<String, dynamic>
        ? UserPreferences.fromJson(preferencesJson)
        : null;

    final List<PreferenceOption> notificationOptions = <PreferenceOption>[];
    final dynamic preferenceOptions = payload['preference_options'];
    if (preferenceOptions is Map<String, dynamic>) {
      final dynamic frequencies =
      preferenceOptions['notification_frequencies'];
      if (frequencies is List) {
        notificationOptions.addAll(
          frequencies
              .whereType<Map>()
              .map((dynamic entry) => PreferenceOption.fromJson(
            Map<String, dynamic>.from(entry as Map<dynamic, dynamic>),
          ))
              .toList(),
        );
      }
    }


    return CurrencyRatesBundle(
      rates: rates,
      governorates: governorates,
      requestedGovernorate: parseGovernorate(payload['requested_governorate']),
      appliedGovernorate: parseGovernorate(payload['applied_governorate']),
      usedFallback: payload['used_fallback'] == true,
      requestedGovernorateCode:
      payload['requested_governorate_code']?.toString(),
      preferences: preferences,
      notificationOptions: notificationOptions,
    );
  }
}