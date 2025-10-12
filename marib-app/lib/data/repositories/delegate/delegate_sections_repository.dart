import 'dart:convert';

import 'package:marib/utils/api.dart';
import 'package:marib/utils/hive_utils.dart';

class DelegateSections {
   DelegateSections({
    required Set<String> permittedSections,
    required Set<String> blockedSections,
  })  : permittedSections = Set.unmodifiable(permittedSections),
        blockedSections = Set.unmodifiable(blockedSections);

  final Set<String> permittedSections;
  final Set<String> blockedSections;

  bool get isEmpty =>
      permittedSections.isEmpty && blockedSections.isEmpty;
}

typedef DelegateSectionsFetcher = Future<Map<String, dynamic>> Function();

class DelegateSectionsRepository {
  DelegateSectionsRepository({DelegateSectionsFetcher? fetcher})
      : _fetcher = fetcher ?? _defaultFetcher;

  final DelegateSectionsFetcher _fetcher;

  static Future<Map<String, dynamic>> _defaultFetcher() {
    return Api.get(url: Api.delegateSectionsApi);
  }

  Future<DelegateSections> refreshPermissions() async {
    final Map<String, dynamic> response = await _fetcher();
    final Set<String> permitted = _parseSections(response['permitted_sections']);
    final Set<String> blocked =
    _parseSections(response['blocked_sections'])..removeWhere(permitted.contains);

    await HiveUtils.cacheDelegateSections(
      permitted: permitted,
      blocked: blocked,
    );

    return DelegateSections(
      permittedSections: permitted,
      blockedSections: blocked,
    );
  }

  Set<String> _parseSections(dynamic raw) {
    final Set<String> sections = <String>{};

    void consume(dynamic value) {
      if (value == null) {
        return;
      }
      final String normalized = value.toString().trim().toLowerCase();
      if (normalized.isEmpty) {
        return;
      }
      sections.add(normalized);
    }

    if (raw == null) {
      return sections;
    }

    if (raw is Iterable) {
      for (final element in raw) {
        consume(element);
      }
      return sections;
    }

    if (raw is String) {
      final String trimmed = raw.trim();
      if (trimmed.isEmpty) {
        return sections;
      }

      dynamic decoded;
      try {
        decoded = jsonDecode(trimmed);
      } catch (_) {
        decoded = null;
      }

      if (decoded is Iterable || decoded is Map) {
        return _parseSections(decoded);
      }

      for (final String segment in trimmed.split(RegExp(r'[\s,]+'))) {
        consume(segment);
      }
      return sections;
    }

    if (raw is Map) {
      for (final dynamic value in raw.values) {
        consume(value);
      }
      return sections;
    }

    consume(raw);
    return sections;
  }
}