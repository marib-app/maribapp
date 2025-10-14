// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';
import 'package:marib/data/helper/custom_exception.dart';
import 'package:marib/data/model/home_slider.dart';
import 'package:marib/settings.dart';
import 'package:marib/utils/api.dart';
import 'package:marib/utils/network/networkAvailability.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';
import 'dart:collection';
import 'package:marib/utils/slider_interface_mapper.dart';




abstract class SliderState {}

class SliderInitial extends SliderState {}

class SliderFetchInProgress extends SliderState {}

class SliderFetchInInternalProgress extends SliderState {}

class SliderFallbackState extends SliderState {
  SliderFallbackState({
    required this.display,
    this.image,
  });

  final String display;
  final String? image;
}


class SliderFetchSuccess extends SliderState {
  List<HomeSlider> sliderlist = [];

  SliderFetchSuccess(this.sliderlist);

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'sliderlist': sliderlist.map((x) => x.toJson()).toList(),
    };
  }

  factory SliderFetchSuccess.fromMap(Map<String, dynamic> map) {
    return SliderFetchSuccess(
      List<HomeSlider>.from(
        (map['sliderlist']).map<HomeSlider>(
          (x) => HomeSlider.fromJson(x as Map<String, dynamic>),
        ),
      ),
    );
  }

  String toJson() => json.encode(toMap());

  factory SliderFetchSuccess.fromJson(String source) =>
      SliderFetchSuccess.fromMap(json.decode(source) as Map<String, dynamic>);
}

class SliderFetchFailure extends SliderState {
  final String errorMessage;
  final bool isUserDeactivated;
  SliderFetchFailure(
      this.errorMessage, this.isUserDeactivated); //, this.isUserDeactivated
}

class SliderCubit extends Cubit<SliderState> {
  SliderCubit() : super(SliderInitial());


  static const String _defaultInterfaceKey = '_default';
  final Map<String, List<HomeSlider>> _interfaceCache = {};

  String _normalizeInterfaceKey(String? interfaceType) {
    final String? normalized =
        SliderInterfaceMapper.normalize(interfaceType) ?? interfaceType?.trim();
    return (normalized == null || normalized.isEmpty)


        ? _defaultInterfaceKey
        : normalized;
  }

  void _emitSliderSuccess(
      List<HomeSlider> sliders, {
        required String? interfaceType,
      }) {
    if (isClosed) return;

    final String key = _normalizeInterfaceKey(interfaceType);

    if (key == _defaultInterfaceKey) {
      _interfaceCache[_defaultInterfaceKey] = sliders;

    } else {
      _interfaceCache[key] = sliders;
      _interfaceCache.putIfAbsent(_defaultInterfaceKey, () => <HomeSlider>[]);
    }

    final LinkedHashMap<String, HomeSlider> mergedMap =
    LinkedHashMap<String, HomeSlider>();

    for (final List<HomeSlider> sliderGroup in _interfaceCache.values) {
      for (final HomeSlider slider in sliderGroup) {
        mergedMap.putIfAbsent(_sliderIdentity(slider), () => slider);
      }
    }

    final List<HomeSlider> merged =
    List<HomeSlider>.unmodifiable(mergedMap.values);

    emit(SliderFetchSuccess(merged));
  }

  String _sliderIdentity(HomeSlider slider) {
    final int? id = slider.id;
    if (id != null) {
      return 'id:' + id.toString();
    }

    final String? sequence = slider.sequence?.trim();
    if (sequence != null && sequence.isNotEmpty) {
      return 'sequence:' + sequence;
    }

    final String? image = slider.image;
    if (image != null && image.isNotEmpty) {
      return 'image:' + image;
    }

    return json.encode(slider.toJson());
  }

  Future<void> fetchSlider(
      BuildContext context, {
        bool? forceRefresh,
        bool? loadWithoutDelay,
        String? interfaceType,
      }) async {


    if (forceRefresh != true) {
      if (state is SliderFetchSuccess) {
        await Future.delayed(Duration(
            seconds: loadWithoutDelay == true
                ? 0
                : AppSettings.hiddenAPIProcessDelay));
      } else {
        emit(SliderFetchInProgress());
      }
    } else {
      emit(SliderFetchInProgress());
    }


    final String? normalizedInterfaceType =
        SliderInterfaceMapper.normalize(interfaceType) ??
            interfaceType?.trim();

    Future<void> handleFailure(Object error) async {
      if (isClosed) return;
      final String message = error.toString();
      final bool isUserActive =
          message != "your account has been deactivate! please contact admin";
      emit(SliderFetchFailure(message, isUserActive));
    }

    Future<void> loadSlider() async {
      try {
        final SliderFetchPayload value = await fetchSliderFromDb(
          context,
          sendCityName: true,
          interfaceType: normalizedInterfaceType,

        );
        processFetchResult(
          value,
          interfaceType: normalizedInterfaceType,
        );
      } catch (error) {
        await handleFailure(error);
      }
    }

    if (forceRefresh == true) {
      await loadSlider();
      return;
    }

    if (state is! SliderFetchSuccess) {
      await loadSlider();
      return;
    }

    final List<HomeSlider> cachedSliders =
    List<HomeSlider>.from((state as SliderFetchSuccess).sliderlist);

    await CheckInternet.check(
      onInternet: () async {
        await loadSlider();
      },
      onNoInternet: () {
        if (isClosed) return;
        emit(SliderFetchSuccess(cachedSliders));
      },
    );
  }

  Future<SliderFetchPayload> fetchSliderFromDb(
      BuildContext context, {
        required bool sendCityName,
        String? interfaceType,
      }) async {


    Map<String, String> body = {};


    final String? cleanedInterfaceType =
        SliderInterfaceMapper.normalize(interfaceType) ?? interfaceType?.trim();

    if (cleanedInterfaceType != null && cleanedInterfaceType.isNotEmpty) {
      body['interface_type'] = cleanedInterfaceType;
    }
    var response = await Api.get(url: Api.getSliderApi, queryParameters: body);

    if (response[Api.error]) {

      throw CustomException(response[Api.message]);
    }

    return parseSliderPayload(response['data']);
  }

  @visibleForTesting
  void processFetchResult(
      SliderFetchPayload result, {
        required String? interfaceType,
      }) {
    if (isClosed) return;

    if (result.hasFallback) {
      emit(SliderFallbackState(
        display: result.fallbackDisplay!,
        image: result.fallbackImage,
      ));
      return;
    }

    _emitSliderSuccess(
      result.sliders,
      interfaceType: interfaceType,
    );
  }

  @override
  SliderState? fromJson(Map<String, dynamic> json) {
    try {
      var state = json['cubit_state'];

      if (state == "SliderFetchSuccess") {
        return SliderFetchSuccess.fromMap(json);
      }
    } catch (e) {}

    return null;
  }

  @override
  Map<String, dynamic>? toJson(SliderState state) {
    if (state is SliderFetchSuccess) {
      Map<String, dynamic> map = state.toMap();
      map['cubit_state'] = "SliderFetchSuccess";
      return map;
    }
    return null;
  }
}



class SliderFetchPayload {
  const SliderFetchPayload({
    required this.sliders,
    this.fallbackDisplay,
    this.fallbackImage,

  });

  final List<HomeSlider> sliders;
  final String? fallbackDisplay;
  final String? fallbackImage;

  bool get hasFallback => fallbackDisplay != null;
}

SliderFetchPayload parseSliderPayload(dynamic raw) {
  try {
    dynamic normalized = raw;

    if (raw is Map) {
      final Map<String, dynamic> map = raw.map(
            (key, value) => MapEntry(key.toString(), value),
      );

      if (_parseBool(map['fallback'])) {
        final String? display = _parseDisplayValue(map['display']);
        final String? image = _parseImageValue(map['image']);
        final String resolvedDisplay = (display == null || display.isEmpty)
            ? (image != null ? 'image' : 'shimmer')
            : display;

        return SliderFetchPayload(
          sliders: const <HomeSlider>[],
          fallbackDisplay: resolvedDisplay,
          fallbackImage: image,
        );
      }

      if (_isDisplayManuallyDisabled(map['display'])) {
        return const SliderFetchPayload(
          sliders: <HomeSlider>[],
          fallbackDisplay: 'shimmer',
        );
      }

      if (map['data'] != null) {
        normalized = map['data'];
      } else if (map['slider'] != null) {
        normalized = map['slider'];
      } else if (map['sliders'] != null) {
        normalized = map['sliders'];
      } else if (_looksLikeSliderMap(map)) {
        normalized = map;
      } else {
        normalized = null;
      }
    }

    final List<HomeSlider> sliders = _buildSliderList(normalized);

    return SliderFetchPayload(
      sliders: sliders,
    );
  } catch (_) {
    return const SliderFetchPayload(
      sliders: <HomeSlider>[],
      fallbackDisplay: 'shimmer',
    );
  }
}

List<HomeSlider> _buildSliderList(dynamic data) {
  if (data == null) {
    return <HomeSlider>[];
  }

  if (data is List) {
    return data
        .map<HomeSlider?>((dynamic entry) {
      if (entry is Map<String, dynamic>) {
        return HomeSlider.fromJson(entry);
      }
      if (entry is Map) {
        return HomeSlider.fromJson(
          entry.map((key, value) => MapEntry(key.toString(), value)),
        );
      }
      return null;
    })
        .whereType<HomeSlider>()
        .toList(growable: false);
  }

  if (data is Map<String, dynamic>) {
    return <HomeSlider>[HomeSlider.fromJson(data)];
  }

  if (data is Map) {
    final Map<String, dynamic> mapped = data.map(
          (key, value) => MapEntry(key.toString(), value),
    );
    return <HomeSlider>[HomeSlider.fromJson(mapped)];
  }

  return <HomeSlider>[];
}




String? _parseDisplayValue(dynamic raw) {
  if (raw == null) {
    return null;
  }
  if (raw is String) {
    final String value = raw.trim();
    if (value.isEmpty) {
      return null;
    }
    return value.toLowerCase();
  }
  if (raw is bool) {
    return raw ? 'image' : 'shimmer';
  }
  if (raw is num) {
    return raw != 0 ? 'image' : 'shimmer';
  }
  return raw.toString().trim().toLowerCase();
}

String? _parseImageValue(dynamic raw) {
  if (raw == null) {
    return null;
  }
  final String value = raw.toString().trim();
  if (value.isEmpty) {
    return null;
  }
  return value;
}




bool _parseBool(dynamic raw) {
  if (raw is bool) {
    return raw;
  }
  if (raw is num) {
    return raw != 0;
  }
  if (raw is String) {
    final String normalized = raw.trim().toLowerCase();
    if (normalized.isEmpty) return false;

    const Set<String> truthyValues = <String>{
      'true',
      '1',
      'yes',
      'on',
      'image',
      'video',
      'shimmer',
    };
    if (truthyValues.contains(normalized)) {
      return true;
    }

    const Set<String> falsyValues = <String>{'false', '0', 'no'};
    if (falsyValues.contains(normalized)) {
      return false;
    }
    return true;
  }
  return false;
}


bool _isDisplayManuallyDisabled(dynamic raw) {
  if (raw == null) {
    return false;
  }
  if (raw is bool) {
    return raw == false;
  }
  if (raw is num) {
    return raw == 0;
  }
  if (raw is String) {
    final String normalized = raw.trim().toLowerCase();
    if (normalized.isEmpty) {
      return true;
    }
    const Set<String> falsyValues = <String>{'false', '0', 'no'};
    return falsyValues.contains(normalized);
  }
  return false;
}



bool _looksLikeSliderMap(Map<String, dynamic> map) {
  const Set<String> sliderKeys = <String>{
    'id',
    'image',
    'sequence',
    'third_party_link',
    'model_type',
    'model_id',
    'interface_type',
  };

  return map.keys.any(sliderKeys.contains);
}