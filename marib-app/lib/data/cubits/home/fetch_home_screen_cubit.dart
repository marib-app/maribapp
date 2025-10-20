import 'package:marib/data/model/home/home_screen_section.dart';
import 'package:marib/data/repositories/home/home_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marib/utils/slider_interface_mapper.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';

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

class FetchHomeScreenCubit extends HydratedCubit<FetchHomeScreenState> {
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
    try {
      final String? type = json['type'] as String?;
      if (type != 'success') {
        return null;
      }

      final List<dynamic>? sectionsJson = json['sections'] as List<dynamic>?;
      final List<HomeScreenSection> sections = <HomeScreenSection>[];
      if (sectionsJson != null) {
        for (final dynamic item in sectionsJson) {
          if (item is Map<String, dynamic>) {
            sections.add(HomeScreenSection.fromJson(item));
          } else if (item is Map) {
            sections
                .add(HomeScreenSection.fromJson(Map<String, dynamic>.from(item as Map)));
          }
        }
      }

      final String? interfaceType =
      _cleanInterfaceType(json['interfaceType'] as String?);
      final String? slug = _cleanSlug(json['slug'] as String?);
      final String? rootIdentifier =
      _cleanRootIdentifier(json['rootIdentifier'] as String?);

      _currentInterfaceType = interfaceType ?? _defaultInterfaceType;
      _currentSlug = slug;
      _currentRootIdentifier = rootIdentifier;

      return FetchHomeScreenSuccess(
        sections,
        interfaceType: interfaceType,
        slug: slug,
        rootIdentifier: rootIdentifier,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Map<String, dynamic>? toJson(FetchHomeScreenState state) {
    if (state is! FetchHomeScreenSuccess) {
      return null;
    }

    return <String, dynamic>{
      'type': 'success',
      'interfaceType': state.interfaceType,
      'slug': state.slug,
      'rootIdentifier': state.rootIdentifier,
      'sections': state.sections.map((HomeScreenSection section) => section.toJson()).toList(),
    };
  }
}
