import 'package:marib/data/model/home/home_screen_section.dart';
import 'package:marib/data/model/item/item_model.dart';
import 'package:marib/data/repositories/home/home_repository.dart';
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
  final Map<String, int> _sectionPage = <String, int>{};
  final Set<String> _loadingSections = <String>{};

  static String _normalizeItemKeyPart(String? value) {
    if (value == null) return '';
    return value.trim().toLowerCase();
  }

  static List<ItemModel> _dedupeItems(Iterable<ItemModel> items) {
    final Set<int> seenIds = <int>{};
    final Set<String> seenKeys = <String>{};
    final List<ItemModel> result = <ItemModel>[];

    for (final ItemModel item in items) {
      final int? rawId = item.id;
      final int? id = (rawId != null && rawId > 0) ? rawId : null;

      if (id != null) {
        if (!seenIds.add(id)) continue;
        result.add(item);
        continue;
      }

      final String slug = _normalizeItemKeyPart(item.slug);
      if (slug.isNotEmpty) {
        final String key = 'slug:$slug';
        if (!seenKeys.add(key)) continue;
        result.add(item);
        continue;
      }

      final String name = _normalizeItemKeyPart(item.name);
      final String image = _normalizeItemKeyPart(
        item.thumbnailUrl ??
            item.thumbnailFallbackUrl ??
            item.detailImageUrl ??
            item.detailImageFallbackUrl ??
            item.image,
      );
      final String price = item.price?.toString() ?? '';

      final String key = 'misc:$name|$price|$image';
      if (key != 'misc:||') {
        if (!seenKeys.add(key)) continue;
      }

      result.add(item);
    }

    return result;
  }

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
    String? orderMode,
    String? styleKey,
    int? rootCategoryId,
  }) async {
    await fetch(
      interfaceType: interfaceType,
      slug: slug,
      rootIdentifier: rootIdentifier,
      orderMode: orderMode,
      styleKey: styleKey,
      rootCategoryId: rootCategoryId,
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
    String? orderMode,
    String? styleKey,
    int? rootCategoryId,
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
        orderMode: orderMode,
        styleKey: styleKey,
          rootCategoryId: rootCategoryId,
          page: 1,
        );

      final List<HomeScreenSection> normalizedSections = homeScreenDataList
          .map((HomeScreenSection section) {
            final List<ItemModel>? items = section.sectionData;
            if (items == null || items.isEmpty) {
              return section;
            }
            final List<ItemModel> uniqueItems = _dedupeItems(items);
            if (uniqueItems.length == items.length) {
              return section;
            }
            return section.copyWith(sectionData: uniqueItems);
          })
          .toList(growable: false);

      _sectionPage.clear();
      for (final HomeScreenSection section in normalizedSections) {
        _sectionPage[_sectionKey(section)] = 1;
      }

      emit(
        FetchHomeScreenSuccess(
          normalizedSections,
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

  String _sectionKey(HomeScreenSection section) {
    final String type = (section.sectionType ?? '').trim().toLowerCase();
    final String key = (section.filter ??
            section.slug ??
            section.sectionId?.toString() ??
            '')
        .trim()
        .toLowerCase();
    return '$type::$key';
  }

  HomeScreenSection? _findMatchingSection(
    List<HomeScreenSection> sections,
    HomeScreenSection target,
  ) {
    final String wantedKey = _sectionKey(target);
    for (final HomeScreenSection element in sections) {
      if (_sectionKey(element) == wantedKey) {
        return element;
      }
    }
    return null;
  }

  Future<void> loadMoreSection(HomeScreenSection section) async {
    if (!(section.hasMore ?? false)) return;
    final FetchHomeScreenState currentState = state;
    if (currentState is! FetchHomeScreenSuccess) return;

    final String key = _sectionKey(section);
    if (_loadingSections.contains(key)) return;

    _loadingSections.add(key);
    try {
      final int currentPage = _sectionPage[key] ?? 1;
      final int nextPage = currentPage + 1;

      final List<HomeScreenSection> response =
          await _homeRepository.fetchHome(
        interfaceType: currentState.interfaceType ?? _currentInterfaceType,
        slug: currentState.slug ?? _currentSlug,
        rootIdentifier: currentState.rootIdentifier ?? _currentRootIdentifier,
        orderMode: section.filter,
        styleKey: section.style,
        rootCategoryId: null,
          page: nextPage,
        );

      final HomeScreenSection fetched = (() {
        final HomeScreenSection? match = _findMatchingSection(response, section);
        if (match == null) {
          return section.copyWith(hasMore: false, sectionData: const []);
        }
        if (match.sectionData == null || match.sectionData!.isEmpty) {
          return match.copyWith(hasMore: false, sectionData: const []);
        }
        return match;
      })();

      final List<HomeScreenSection> updatedSections = <HomeScreenSection>[];
      for (final HomeScreenSection existing in currentState.sections) {
        if (_sectionKey(existing) != key) {
          updatedSections.add(existing);
          continue;
        }

        final List<ItemModel> uniqueExisting =
            _dedupeItems(existing.sectionData ?? const <ItemModel>[]);
        final List<ItemModel> combined = _dedupeItems(<ItemModel>[
          ...uniqueExisting,
          ...?fetched.sectionData,
        ]);
        final bool addedNewItems = combined.length > uniqueExisting.length;

        double? _minPrice(Iterable<double?> values) {
          double? result;
          for (final double? v in values) {
            if (v == null) continue;
            result = result == null ? v : (v < result ? v : result);
          }
          return result;
        }

        double? _maxPrice(Iterable<double?> values) {
          double? result;
          for (final double? v in values) {
            if (v == null) continue;
            result = result == null ? v : (v > result ? v : result);
          }
          return result;
        }

        updatedSections.add(
          existing.copyWith(
            sectionData: combined,
            totalData: combined.length,
            minPrice: _minPrice(
              <double?>[
                existing.minPrice,
                fetched.minPrice,
                ...combined.map((e) => e.price),
              ],
            ),
            maxPrice: _maxPrice(
              <double?>[
                existing.maxPrice,
                fetched.maxPrice,
                ...combined.map((e) => e.price),
              ],
            ),
            hasMore: (fetched.hasMore ?? false) && addedNewItems,
          ),
        );
      }

      _sectionPage[key] = nextPage;

      emit(
        FetchHomeScreenSuccess(
          updatedSections,
          interfaceType: currentState.interfaceType,
          slug: currentState.slug,
          rootIdentifier: currentState.rootIdentifier,
        ),
      );
    } catch (e) {
      // ignore load more errors to avoid breaking main state
    } finally {
      _loadingSections.remove(key);
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
                Map<String, dynamic>.from(item)));
          }
        }
      }
      final List<HomeScreenSection> normalizedSections = sections
          .map((HomeScreenSection section) {
            final List<ItemModel>? items = section.sectionData;
            if (items == null || items.isEmpty) {
              return section;
            }
            final List<ItemModel> uniqueItems = _dedupeItems(items);
            if (uniqueItems.length == items.length) {
              return section;
            }
            return section.copyWith(sectionData: uniqueItems);
          })
          .toList(growable: false);

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

      _sectionPage.clear();
      final Map<String, dynamic>? rawPages =
          json['sectionPage'] as Map<String, dynamic>?;
      if (rawPages != null) {
        rawPages.forEach((key, value) {
          final int? page = value is int
              ? value
              : value is num
                  ? value.toInt()
                  : int.tryParse(value.toString());
          if (page != null && page > 0) {
            _sectionPage[key] = page;
          }
        });
      } else {
        for (final HomeScreenSection section in normalizedSections) {
          _sectionPage[_sectionKey(section)] = 1;
        }
      }

      return FetchHomeScreenSuccess(
        normalizedSections,
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
      'sectionPage': _sectionPage,
      'sections': state.sections
          .map((HomeScreenSection section) => section.toJson())
          .toList(),
    };
  }
}

