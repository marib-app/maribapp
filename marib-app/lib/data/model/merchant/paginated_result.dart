class PaginatedResult<T> {
  const PaginatedResult({
    required this.data,
    required this.currentPage,
    required this.hasMore,
    required this.nextPage,
  });

  final List<T> data;
  final int currentPage;
  final bool hasMore;
  final int nextPage;
}

PaginatedResult<T> parsePaginatedResult<T>({
  required Map<String, dynamic> json,
  required T Function(Map<String, dynamic>) fromJson,
}) {
  final List<dynamic> rawData = json['data'] as List<dynamic>? ?? const [];
  final Map<String, dynamic> meta =
      json['meta'] as Map<String, dynamic>? ?? const {};

  final int current = _asInt(meta['current_page'], fallback: 1);
  final bool hasMore = meta['has_more'] == true;
  final int nextPage = hasMore ? current + 1 : current;

  final List<T> items = rawData
      .whereType<Map<String, dynamic>>()
      .map(fromJson)
      .toList(growable: false);

  return PaginatedResult<T>(
    data: items,
    currentPage: current,
    hasMore: hasMore,
    nextPage: nextPage,
  );
}

int _asInt(dynamic value, {int fallback = 1}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}
