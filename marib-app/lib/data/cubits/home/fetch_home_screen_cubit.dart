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
  FetchHomeScreenCubit({
    String? defaultInterfaceType,
    String? defaultSlug,
    String? defaultRootIdentifier,
    bool enablePersistence = true,
    HomeRepository? homeRepository,
  })  : _homeRepository = homeRepository ?? HomeRepository(),
        _enablePersistence = enablePersistence,
        _defaultInterfaceType = _cleanInterfaceType(defaultInterfaceType),
        _defaultSlug = _cleanSlug(defaultSlug),
        _defaultRootIdentifier = _cleanRootIdentifier(defaultRootIdentifier),
        _currentInterfaceType = _cleanInterfaceType(defaultInterfaceType),
        _currentSlug = _cleanSlug(defaultSlug),
        _currentRootIdentifier = _cleanRootIdentifier(defaultRootIdentifier),
        super(FetchHomeScreenInitial());

  final HomeRepository _homeRepository;
  final String? _defaultSlug;
  final String? _defaultRootIdentifier;
  final bool _enablePersistence;
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

  static String _sanitizeStorageSegment(String value) {
    final String trimmed = value.trim().toLowerCase();
    final String collapsedWhitespace = trimmed.replaceAll(RegExp(r'\s+'), '-');
    final String sanitized = collapsedWhitespace
        .replaceAll(RegExp(r'[^a-z0-9\-_]+'), '-')
        .replaceAll(RegExp(r'-{2,}'), '-')
        .replaceAll(RegExp(r'^-+|-+\$'), '');

    return sanitized.isEmpty ? 'none' : sanitized;
  }

  @override
  String get id {
    if (!_enablePersistence) {
      return super.id;
    }

    final List<String> segments = <String>['fetch-home-screen'];
    final String interfaceSegment =
        _sanitizeStorageSegment(_defaultInterfaceType ?? 'default');
    segments.add(interfaceSegment);

    if (_defaultSlug != null && _defaultSlug!.isNotEmpty) {
      segments.add(_sanitizeStorageSegment('slug-${_defaultSlug!}'));
    }

    if (_defaultRootIdentifier != null && _defaultRootIdentifier!.isNotEmpty) {
      segments.add(
        _sanitizeStorageSegment('root-${_defaultRootIdentifier!}'),
      );
    }

    return segments.join('__');
  }

  String? get currentInterfaceType =>
      _currentInterfaceType ?? _defaultInterfaceType;

  String? get currentSlug => _currentSlug ?? _defaultSlug;

  String? get currentRootIdentifier =>
      _currentRootIdentifier ?? _defaultRootIdentifier;

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
          _cleanInterfaceType(interfaceType) ??
              _currentInterfaceType ??
              _defaultInterfaceType;
      final String? resolvedSlug =
          _cleanSlug(slug) ?? _currentSlug ?? _defaultSlug;
      final String? resolvedRootIdentifier =
          _cleanRootIdentifier(rootIdentifier) ??
              _currentRootIdentifier ??
              _defaultRootIdentifier;

      _currentInterfaceType = resolvedInterfaceType;
      _currentSlug = resolvedSlug;
      _currentRootIdentifier = resolvedRootIdentifier;

      final List<HomeScreenSection> homeScreenDataList =
          await _homeRepository.fetchHome(
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
    if (!_enablePersistence) {
      return null;
    }
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
            sections.add(HomeScreenSection.fromJson(
                Map<String, dynamic>.from(item as Map)));
          }
        }
      }

      final String? interfaceType =
          _cleanInterfaceType(json['interfaceType'] as String?) ??
              _defaultInterfaceType;
      final String? slug = _cleanSlug(json['slug'] as String?) ?? _defaultSlug;

      final String? rootIdentifier =
          _cleanRootIdentifier(json['rootIdentifier'] as String?) ??
              _defaultRootIdentifier;
      _currentInterfaceType = interfaceType ?? _defaultInterfaceType;
      _currentSlug = slug ?? _defaultSlug;
      _currentRootIdentifier = rootIdentifier ?? _defaultRootIdentifier;

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
    if (!_enablePersistence) {
      return null;
    }
    if (state is! FetchHomeScreenSuccess) {
      return null;
    }

    return <String, dynamic>{
      'type': 'success',
      'interfaceType': state.interfaceType,
      'slug': state.slug,
      'rootIdentifier': state.rootIdentifier,
      'sections': state.sections
          .map((HomeScreenSection section) => section.toJson())
          .toList(),
    };
  }
}
