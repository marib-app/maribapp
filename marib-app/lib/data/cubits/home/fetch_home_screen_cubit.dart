import 'package:marib/data/model/home/home_screen_section.dart';
import 'package:marib/data/repositories/home/home_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marib/utils/slider_interface_mapper.dart';

abstract class FetchHomeScreenState {}

class FetchHomeScreenInitial extends FetchHomeScreenState {}

class FetchHomeScreenInProgress extends FetchHomeScreenState {}

class FetchHomeScreenSuccess extends FetchHomeScreenState {
  final List<HomeScreenSection> sections;

  final String? interfaceType;
  final String? slug;

  final String? rootIdentifier;

  FetchHomeScreenSuccess(
      this.sections, {
        this.interfaceType,
        this.slug,
        this.rootIdentifier,
      });
}

class FetchHomeScreenFail extends FetchHomeScreenState {
  final dynamic error;

  FetchHomeScreenFail(this.error);
}

class FetchHomeScreenCubit extends Cubit<FetchHomeScreenState> {
  FetchHomeScreenCubit({String? defaultInterfaceType, HomeRepository? homeRepository})
      : _homeRepository = homeRepository ?? HomeRepository(),
        _defaultInterfaceType = _cleanInterfaceType(defaultInterfaceType),
        _currentInterfaceType = _cleanInterfaceType(defaultInterfaceType),
        _currentSlug = null,
        _currentRootIdentifier = null,

      super(FetchHomeScreenInitial());


  final HomeRepository _homeRepository;

  final String? _defaultInterfaceType;
  String? _currentInterfaceType;
  String? _currentSlug;
  String? _currentRootIdentifier;



  static String? _cleanInterfaceType(String? value) {
    final String? normalized = SliderInterfaceMapper.normalize(value);
    if (normalized != null && normalized.isNotEmpty) {
      return normalized;
    }
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }


  static String? _cleanSlug(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static String? _cleanRootIdentifier(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String? get currentInterfaceType => _currentInterfaceType ?? _defaultInterfaceType;
  String? get currentSlug => _currentSlug;
  String? get currentRootIdentifier => _currentRootIdentifier;

  Future<void> loadFeaturedSections({
    required String interfaceType,
    String? slug,
    String? rootIdentifier,

  }) async {
    await fetch(
      interfaceType: interfaceType,
      slug: slug,
      rootIdentifier: rootIdentifier,
    );

  }

  Future<void> fetch({


    String? country,
    String? state,
    String? city,
    int? areaId,
    String? interfaceType,
    String? slug,
    String? rootIdentifier,

  }) async {


    try {
      emit(FetchHomeScreenInProgress());

      final String? resolvedInterfaceType =
          _cleanInterfaceType(interfaceType) ?? _currentInterfaceType ?? _defaultInterfaceType;
      final String? resolvedSlug = _cleanSlug(slug);
      final String? resolvedRootIdentifier = _cleanRootIdentifier(rootIdentifier);

      _currentInterfaceType = resolvedInterfaceType;
      _currentSlug = resolvedSlug;
      _currentRootIdentifier = resolvedRootIdentifier;

      final List<HomeScreenSection> homeScreenDataList = await _homeRepository.fetchHome(

        interfaceType: resolvedInterfaceType,
        country: country,
        state: state,
        city: city,
        areaId: areaId,
        slug: resolvedSlug,
        rootIdentifier: resolvedRootIdentifier,

      );



      emit(
        FetchHomeScreenSuccess(
          homeScreenDataList,
          interfaceType: resolvedInterfaceType,
          slug: resolvedSlug,
          rootIdentifier: resolvedRootIdentifier,

        ),
      );
    } catch (e) {
      print('Issue while loading home screen $e');
      emit(FetchHomeScreenFail(e));
    }
  }

  @override
  FetchHomeScreenState? fromJson(Map<String, dynamic> json) {
    // TODO: implement fromJson
    return null;
  }

  @override
  Map<String, dynamic>? toJson(FetchHomeScreenState state) {
    // TODO: implement toJson
    return null;
  }
}
