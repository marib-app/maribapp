import 'package:marib/utils/api.dart';

class SystemRepository {
  static const int _defaultPerPage = 50;
  static const int _maxPaginationLoops = 25;

  Future<Map> fetchSystemSettings() async {
    final Map<String, dynamic> baseParameters = <String, dynamic>{
      'per_page': _defaultPerPage,
    };


    final Map<String, dynamic> firstResponse = await Api.get(
      queryParameters: baseParameters,
      url: Api.getSystemSettingsApi,
    );


    final Map<String, dynamic> aggregatedValues = <String, dynamic>{};
    Map<String, dynamic>? aggregatedExtras;

    _SettingsPage page = _parseSettingsResponse(firstResponse);
    aggregatedValues.addAll(page.items);
    if (page.extras != null && page.extras!.isNotEmpty) {
      aggregatedExtras = Map<String, dynamic>.from(page.extras!);
    }

    Map<String, dynamic>? meta = page.meta;
    int? currentPage = _asInt(meta?['current_page']) ?? _asInt(firstResponse['current_page']);
    int? lastPage = _asInt(meta?['last_page']) ?? _asInt(firstResponse['last_page']);

    int loop = 0;
    while (meta != null && currentPage != null && lastPage != null && currentPage < lastPage && loop < _maxPaginationLoops) {
      currentPage += 1;
      final Map<String, dynamic> parameters = Map<String, dynamic>.from(baseParameters)
        ..['page'] = currentPage;

      final Map<String, dynamic> response = await Api.get(
        queryParameters: parameters,
        url: Api.getSystemSettingsApi,
      );

      page = _parseSettingsResponse(response);
      aggregatedValues.addAll(page.items);

      if (page.extras != null && page.extras!.isNotEmpty) {
        aggregatedExtras ??= <String, dynamic>{};
        aggregatedExtras.addAll(page.extras!);
      }

      meta = page.meta;
      currentPage = _asInt(meta?['current_page']) ?? currentPage;
      lastPage = _asInt(meta?['last_page']) ?? lastPage;
      loop += 1;
    }

    if (aggregatedExtras != null && aggregatedExtras.isNotEmpty) {
      aggregatedValues.addAll(aggregatedExtras);
    }

    final Map<String, dynamic> normalizedResponse = Map<String, dynamic>.from(firstResponse);
    normalizedResponse['data'] = aggregatedValues;
    if (aggregatedExtras != null && aggregatedExtras.isNotEmpty) {
      normalizedResponse['extras'] = aggregatedExtras;
    }

    return normalizedResponse;
  }

  _SettingsPage _parseSettingsResponse(Map<String, dynamic> response) {
    final Map<String, dynamic> items = normalizeSettingsPayload(response);

    Map<String, dynamic>? meta;
    Map<String, dynamic>? extras = _mapify(response['extras']);

    final Map<String, dynamic>? dataMap = _mapify(response['data']);
    if (dataMap != null) {
      meta = _mapify(dataMap['meta']);
      meta ??= _mapify(dataMap['pagination']);
      meta ??= _extractPaginationMeta(dataMap);
      extras ??= _mapify(dataMap['extras']);
    }

    meta ??= _mapify(response['meta']);
    meta ??= _mapify(response['pagination']);

    return _SettingsPage(
      items: items,
      meta: meta,
      extras: extras,
    );
  }

  Map<String, dynamic>? _extractPaginationMeta(Map<String, dynamic> source) {
    const Set<String> keys = <String>{
      'current_page',
      'per_page',
      'from',
      'to',
      'last_page',
      'total',
      'first_page_url',
      'last_page_url',
      'next_page_url',
      'prev_page_url',
      'path',
      'has_more_pages',
    };

    final Map<String, dynamic> meta = <String, dynamic>{};

    for (final String key in keys) {
      if (source.containsKey(key)) {
        meta[key] = source[key];
      }
    }

    final dynamic links = source['links'];
    if (links != null) {
      meta['links'] = links;
    }

    if (meta.isEmpty) {
      return null;
    }

    return meta;
  }


  static Map<String, dynamic> normalizeSettingsPayload(dynamic payload) {
    final Map<String, dynamic> values = <String, dynamic>{};
    final Set<int> visitedNodes = <int>{};

    void inspect(dynamic node) {
      if (node == null) {
        return;
      }

      if (node is Map || node is Iterable) {
        final int identity = identityHashCode(node);
        if (!visitedNodes.add(identity)) {
          return;
        }
      }

      if (node is Iterable) {
        for (final element in node) {
          inspect(element);
        }
        return;
      }

      if (node is Map) {
        final Map<String, dynamic> map = <String, dynamic>{};
        node.forEach((dynamic key, dynamic value) {
          if (key == null) {
            return;
          }
          map[key.toString()] = value;
        });

        final dynamic rawName = map['name'];
        if (rawName != null) {
          final String name = rawName.toString();
          if (name.isNotEmpty && map.containsKey('value')) {
            values[name] = map['value'];
          }

        }
        const Set<String> containerKeys = <String>{
          'data',
          'items',
          'values',
          'records',
          'list',
          'payload',
          'extras',
          'settings',
        };

        const Set<String> skipKeys = <String>{
          'name',
          'value',
          'type',
          'meta',
          'links',
          'error',
          'message',
          'code',
          'per_page',
          'current_page',
          'last_page',
          'has_more_pages',
          'total',
          'from',
          'to',
          'first_page_url',
          'last_page_url',
          'next_page_url',
          'prev_page_url',
          'path',
          'pagination',
        };

        for (final MapEntry<String, dynamic> entry in map.entries) {
          final String key = entry.key;
          final dynamic value = entry.value;

          if (containerKeys.contains(key)) {
            inspect(value);
            continue;
          }

          if (skipKeys.contains(key)) {
            if ((value is Map || value is Iterable) && key != 'links') {
              inspect(value);
            }
            continue;
          }

          if (!values.containsKey(key)) {

            values[key] = value;
          }

          if (value is Map || value is Iterable) {
            inspect(value);
          }
        }

        return;

      }

    }

    inspect(payload);


    return values;
  }

  int? _asInt(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    if (value is double) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  Map<String, dynamic>? _mapify(dynamic source) {
    if (source is Map<String, dynamic>) {
      return source;
    }
    if (source is Map) {
      return Map<String, dynamic>.from(source as Map);
    }
    return null;
  }


}

class _SettingsPage {
  const _SettingsPage({
    required this.items,
    this.meta,
    this.extras,
  });

  final Map<String, dynamic> items;
  final Map<String, dynamic>? meta;
  final Map<String, dynamic>? extras;
}