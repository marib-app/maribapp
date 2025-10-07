import 'package:marib/data/model/system_settings_model.dart';
import 'package:marib/data/repositories/system_repository.dart';
import 'package:marib/settings.dart';
import 'package:marib/utils/constant.dart';
import 'package:marib/utils/network/networkAvailability.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:convert';
import 'package:marib/data/model/social_link_model.dart';



abstract class FetchSystemSettingsState {}

class FetchSystemSettingsInitial extends FetchSystemSettingsState {}

class FetchSystemSettingsInProgress extends FetchSystemSettingsState {}

class FetchSystemSettingsSuccess extends FetchSystemSettingsState {
  final Map settings;


  final String? usageGuide;
  final List<SocialLink> socialLinks;

  FetchSystemSettingsSuccess({
    required this.settings,

    this.usageGuide,
    List<SocialLink> socialLinks = const [],
  }) : socialLinks = List.unmodifiable(socialLinks);

  Map<String, dynamic> toMap() {
    return {
      'settings': settings,
      'usageGuide': usageGuide,
      'socialLinks': socialLinks.map((link) => link.toMap()).toList(),
    };
  }

  factory FetchSystemSettingsSuccess.fromMap(Map<String, dynamic> map) {
    final dynamic rawLinks = map['socialLinks'];
    final List<SocialLink> parsedLinks = <SocialLink>[];
    if (rawLinks is List) {
      for (final element in rawLinks) {
        if (element is Map) {
          final SocialLink? link = SocialLink.fromDynamic(element);
          if (link != null) {
            parsedLinks.add(link);
          }
        }
      }
    }
    return FetchSystemSettingsSuccess(
      settings: map['settings'] as Map,
      usageGuide: map['usageGuide'] as String?,
      socialLinks: parsedLinks,
    );
  }
}

class FetchSystemSettingsFailure extends FetchSystemSettingsState {
  final String errorMessage;

  FetchSystemSettingsFailure(this.errorMessage);
}

class FetchSystemSettingsCubit extends Cubit<FetchSystemSettingsState> {
  FetchSystemSettingsCubit() : super(FetchSystemSettingsInitial());
  final SystemRepository _systemRepository = SystemRepository();

  Future<void> fetchSettings({bool? forceRefresh}) async {
    try {
      if (forceRefresh != true) {
        if (state is FetchSystemSettingsSuccess) {
          await Future.delayed(
              const Duration(seconds: AppSettings.hiddenAPIProcessDelay));
        } else {
          emit(FetchSystemSettingsInProgress());
        }
      } else {
        emit(FetchSystemSettingsInProgress());
      }

      if (forceRefresh == true) {
        Map settings = await _systemRepository.fetchSystemSettings();
        emit(_processFetchedSettings(settings));

      } else {
        if (state is! FetchSystemSettingsSuccess) {
          Map settings = await _systemRepository.fetchSystemSettings();
          emit(_processFetchedSettings(settings));

        } else {
          await CheckInternet.check(
            onInternet: () async {
              Map settings = await _systemRepository.fetchSystemSettings();

              emit(_processFetchedSettings(settings));

            },
            onNoInternet: () {
              final current = state as FetchSystemSettingsSuccess;

              emit(FetchSystemSettingsSuccess(
                settings: current.settings,
                usageGuide: current.usageGuide,
                socialLinks: current.socialLinks,
              ));

              },
          );
        }
      }
    } catch (e, st) {
      emit(FetchSystemSettingsFailure(st.toString()));
    }
  }

  dynamic getSetting(SystemSetting selected) {
    if (selected == SystemSetting.socialLinks) {
      if (state is FetchSystemSettingsSuccess) {
        return (state as FetchSystemSettingsSuccess).socialLinks;
      }
      return Constant.socialLinks;
    }

    if (selected == SystemSetting.usageGuide) {
      if (state is FetchSystemSettingsSuccess) {
        return (state as FetchSystemSettingsSuccess).usageGuide;
      }
      return Constant.usageGuide;
    }

    if (state is FetchSystemSettingsSuccess) {
      final successState = state as FetchSystemSettingsSuccess;
      final dynamic rawData = successState.settings['data'];
      if (rawData is! Map) {
        return null;
      }

      Map settings = rawData;
      if (selected == SystemSetting.subscription) {
        //check if we have subscribed to any package if true then return this data otherwise return empty list
        if (settings['subscription'] == true) {
          return settings['package']['user_purchased_package'] as List;
        } else {
          return [];
        }
      }

      if (selected == SystemSetting.language) {
        return settings['languages'];
      }

      if (selected == SystemSetting.demoMode) {
        if (settings.containsKey("demo_mode")) {
          return settings['demo_mode'];
        } else {
          return false;
        }
      }

      /// where selected is equals to type
      final String? key = Constant.systemSettingKeys[selected];
      if (key == null || key.isEmpty) {
        return null;
      }

      var selectedSettingData = settings[key];

      return selectedSettingData;
    }
  }

  Map getRawSettings() {
    if (state is FetchSystemSettingsSuccess) {
      final dynamic rawData =
      (state as FetchSystemSettingsSuccess).settings['data'];
      if (rawData is Map) {
        return rawData;
      }
    }
    return {};
  }


  void _cacheDelegateSettings(Map settings) {
    if (settings['data'] is! Map) {
      Constant.delegatesShein = [];
      Constant.delegatesComputer = [];
      return;
    }

    final Map data = settings['data'] as Map;
    Constant.delegatesShein = _parseDelegateList(data['delegates_shein']);
    Constant.delegatesComputer =
        _parseDelegateList(data['delegates_computer']);
  }

  List<int> _parseDelegateList(dynamic raw) {
    final Set<int> values = <int>{};

    void addValue(dynamic candidate) {
      final parsed = _parseDelegateId(candidate);
      if (parsed != null) {
        values.add(parsed);
      }
    }

    if (raw == null) {
      return values.toList();
    }

    if (raw is List) {
      for (final element in raw) {
        addValue(element);
      }
      return values.toList();
    }

    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) {
        return values.toList();
      }

      try {
        final decoded = json.decode(trimmed);
        if (decoded is List) {
          for (final element in decoded) {
            addValue(element);
          }
          return values.toList();
        }
      } catch (_) {}

      for (final segment in trimmed.split(RegExp(r'[\s,]+'))) {
        if (segment.trim().isEmpty) {
          continue;
        }
        addValue(segment);
      }
      return values.toList();
    }

    addValue(raw);
    return values.toList();
  }

  int? _parseDelegateId(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    final parsed = int.tryParse(value.toString().trim());
    return parsed;
  }



  FetchSystemSettingsSuccess _processFetchedSettings(Map settings) {
    Constant.currencySymbol = _getSettingString(
      settings,
      SystemSetting.currencySymbol,
      fallback: Constant.currencySymbol,
    );
    Constant.maintenanceMode = _getSettingString(
      settings,
      SystemSetting.maintenanceMode,
      fallback: Constant.maintenanceMode,
    );
    Constant.isGoogleBannerAdsEnabled = _getSettingString(
      settings,
      SystemSetting.bannerAdStatus,
      fallback: Constant.isGoogleBannerAdsEnabled,
    );
    Constant.isGoogleInterstitialAdsEnabled = _getSettingString(
      settings,
      SystemSetting.interstitialAdStatus,
      fallback: Constant.isGoogleInterstitialAdsEnabled,
    );
    Constant.isGoogleNativeAdsEnabled = _getSettingString(
      settings,
      SystemSetting.nativeAdStatus,
      fallback: Constant.isGoogleNativeAdsEnabled,
    );
    Constant.bannerAdIdAndroid = _getSettingString(
      settings,
      SystemSetting.bannerAdAndroidAd,
      fallback: Constant.bannerAdIdAndroid,
    );
    Constant.bannerAdIdIOS = _getSettingString(
      settings,
      SystemSetting.bannerAdiOSAd,
      fallback: Constant.bannerAdIdIOS,
    );
    Constant.interstitialAdIdAndroid = _getSettingString(
      settings,
      SystemSetting.interstitialAdAndroidAd,
      fallback: Constant.interstitialAdIdAndroid,
    );
    Constant.interstitialAdIdIOS = _getSettingString(
      settings,
      SystemSetting.interstitialAdiOSAd,
      fallback: Constant.interstitialAdIdIOS,
    );
    Constant.nativeAdIdAndroid = _getSettingString(
      settings,
      SystemSetting.nativeAndroidAd,
      fallback: Constant.nativeAdIdAndroid,
    );
    Constant.nativeAdIdIOS = _getSettingString(
      settings,
      SystemSetting.nativeAdiOSAd,
      fallback: Constant.nativeAdIdIOS,
    );
    Constant.defaultLatitude = _getSettingString(
      settings,
      SystemSetting.defaultLatitude,
      fallback: Constant.defaultLatitude,
    );
    Constant.defaultLongitude = _getSettingString(
      settings,
      SystemSetting.defaultLongitude,
      fallback: Constant.defaultLongitude,
    );

    final String playStoreLink = _getSettingString(
      settings,
      SystemSetting.playStoreLink,
      fallback: Constant.playstoreURLAndroid,
    );
    Constant.playstoreURLAndroid = playStoreLink;

    final String appStoreLink = _getSettingString(
      settings,
      SystemSetting.appStoreLink,
      fallback: Constant.appstoreURLios,
    );
    Constant.appstoreURLios = appStoreLink;
    Constant.iOSAppId = appStoreLink.split('/').last;

    Constant.mobileAuthentication = _getSettingString(
      settings,
      SystemSetting.mobileAuthentication,
      fallback: Constant.mobileAuthentication.isEmpty
          ? "0"
          : Constant.mobileAuthentication,
    );
    Constant.googleAuthentication = _getSettingString(
      settings,
      SystemSetting.googleAuthentication,
      fallback: Constant.googleAuthentication.isEmpty
          ? "0"
          : Constant.googleAuthentication,
    );
    Constant.appleAuthentication = _getSettingString(
      settings,
      SystemSetting.appleAuthentication,
      fallback: Constant.appleAuthentication.isEmpty
          ? "0"
          : Constant.appleAuthentication,
    );
    Constant.emailAuthentication = _getSettingString(
      settings,
      SystemSetting.emailAuthentication,
      fallback: Constant.emailAuthentication.isEmpty
          ? "0"
          : Constant.emailAuthentication,
    );

    final String? usageGuide = _parseUsageGuide(settings);
    final List<SocialLink> socialLinks = _parseSocialLinks(settings);
    Constant.usageGuide = usageGuide ?? Constant.usageGuide;
    Constant.socialLinks = List.unmodifiable(socialLinks);

    _cacheDelegateSettings(settings);

    return FetchSystemSettingsSuccess(
      settings: settings,
      usageGuide: usageGuide,
      socialLinks: socialLinks,
    );
  }



  dynamic _getSetting(Map settings, SystemSetting selected) {
    final dynamic data = settings['data'];
    if (data is! Map) {
      return null;
    }

    final String? key = Constant.systemSettingKeys[selected];
    if (key == null || key.isEmpty) {
      return null;
    }

    return data[key];
  }

  String _getSettingString(
      Map settings,
      SystemSetting selected, {
        String? fallback,
      }) {
    final dynamic value = _getSetting(settings, selected);
    if (value == null) {
      return fallback ?? '';
    }
    return value.toString();
  }

  String? _parseUsageGuide(Map settings) {
    final dynamic raw = _getSetting(settings, SystemSetting.usageGuide);
    if (raw == null) {
      return null;
    }
    if (raw is String) {
      return raw;
    }
    return raw.toString();
  }

  List<SocialLink> _parseSocialLinks(Map settings) {
    final List<SocialLink> links = <SocialLink>[];
    final dynamic raw = _getSetting(settings, SystemSetting.socialLinks);

    void addLink(dynamic candidate) {
      final SocialLink? link = SocialLink.fromDynamic(candidate);
      if (link == null) {
        return;
      }
      if (link.url.trim().isEmpty) {
        return;
      }
      links.add(link);
    }

    void consume(dynamic value, {String? label}) {
      if (value == null) {
        return;
      }

      if (value is List) {
        for (final element in value) {
          consume(element, label: label);
        }
        return;
      }

      if (value is Map) {
        final bool isLinkMap = value.containsKey('url') ||
            value.containsKey('link') ||
            value.containsKey('value') ||
            value.containsKey('href');

        if (isLinkMap) {
          if (label != null && label.isNotEmpty) {
            final Map<dynamic, dynamic> enriched = Map<dynamic, dynamic>.from(value);
            enriched.putIfAbsent('label', () => label);
            addLink(enriched);
          } else {
            addLink(value);
          }
          return;
        }

        value.forEach((key, nested) {
          consume(nested, label: key?.toString());
        });
        return;
      }

      if (label != null && label.isNotEmpty) {
        final String resolvedUrl = value.toString().trim();
        if (resolvedUrl.isEmpty) {
          return;
        }
        addLink(SocialLink(label: label, url: resolvedUrl));
        return;
      }

      addLink(value);
    }

    if (raw == null) {
      return links;
    }

    if (raw is String) {
      final String trimmed = raw.trim();
      if (trimmed.isEmpty) {
        return links;
      }

      dynamic decoded;
      try {
        decoded = json.decode(trimmed);
      } catch (_) {}

      if (decoded != null && (decoded is List || decoded is Map)) {
        consume(decoded);
        return links;
      }

      for (final segment in trimmed.split(RegExp(r'[\n;,]+'))) {
        final part = segment.trim();
        if (part.isEmpty) {
          continue;
        }

        final RegExp delimiter = RegExp(r'[:=|-]');
        final Match? match = delimiter.firstMatch(part);
        if (match != null) {
          final String key = part.substring(0, match.start).trim();
          final String value = part.substring(match.end).trim();
          if (value.isEmpty) {
            continue;
          }
          consume(value, label: key);
        } else {
          addLink(part);
        }
      }

      return links;
    }


    consume(raw);
    return links;
  }

/*  @override
  FetchSystemSettingsState? fromJson(Map<String, dynamic> json) {
    try {
      if (json['cubit_state'] == "FetchSystemSettingsSuccess") {
        FetchSystemSettingsSuccess fetchSystemSettingsSuccess =
            FetchSystemSettingsSuccess.fromMap(json);

        return fetchSystemSettingsSuccess;
      }
    } catch (e) {}
    return null;
  }

  @override
  Map<String, dynamic>? toJson(FetchSystemSettingsState state) {
    try {
      if (state is FetchSystemSettingsSuccess) {
        Map<String, dynamic> mapped = state.toMap();
        mapped['cubit_state'] = "FetchSystemSettingsSuccess";
        return mapped;
      }
    } catch (e) {}

    return null;
    }
  */
}
