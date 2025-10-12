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
    final Map<String, dynamic> items = <String, dynamic>{};

    Map<String, dynamic>? meta;
    Map<String, dynamic>? extras = _mapify(response['extras']);

    void mergeItems(dynamic source) {
      if (source is Iterable) {
        for (final element in source) {
          mergeItems(element);
        }
        return;
      }

      final Map<String, dynamic>? map = _mapify(source);
      if (map == null) {
        return;
      }

      final String? name = _stringify(map['name']);
      if (name != null && name.isNotEmpty) {
        items[name] = map['value'];
      } else {
        const ignoredKeys = <String>{'items', 'meta', 'links', 'extras'};
        for (final entry in map.entries) {
          final String key = entry.key.toString();
          if (ignoredKeys.contains(key)) {
            continue;
          }
          items.putIfAbsent(key, () => entry.value);
        }
      }
    }

    final dynamic dataNode = response['data'];
    if (dataNode is Map || dataNode is Iterable) {
      final Map<String, dynamic>? dataMap = _mapify(dataNode);
      if (dataMap != null) {
        final dynamic nestedItems = dataMap['items'];
        if (nestedItems != null) {
          mergeItems(nestedItems);
        } else {
          mergeItems(dataMap);
        }

        meta = _mapify(dataMap['meta']);
        extras ??= _mapify(dataMap['extras']);
      } else if (dataNode is Iterable) {
        mergeItems(dataNode);
      }
    } else if (dataNode != null) {
      mergeItems(dataNode);
    }

    meta ??= _mapify(response['meta']);

    return _SettingsPage(
      items: items,
      meta: meta,
      extras: extras,
    );
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

  String? _stringify(dynamic value) {
    if (value is String) {
      return value;
    }
    if (value == null) {
      return null;
    }
    return value.toString();
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