import 'package:collection/collection.dart';

class MarketNews {
  final int id;
  final String title;
  final String slug;
  final String? summary;
  final String status;
  final DateTime? publishAt;
  final DateTime? publishedAt;
  final List<String> tags;
  final String? imageUrl;
  final MarketNewsAsset? asset;
  final MarketNewsGovernorate? governorate;

  const MarketNews({
    required this.id,
    required this.title,
    required this.slug,
    required this.status,
    this.summary,
    this.publishAt,
    this.publishedAt,
    this.tags = const <String>[],
    this.imageUrl,
    this.asset,
    this.governorate,
  });

  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;

  String? get primaryTag => tags.firstOrNull;

  MarketNews copyWith({
    int? id,
    String? title,
    String? slug,
    String? summary,
    String? status,
    DateTime? publishAt,
    DateTime? publishedAt,
    List<String>? tags,
    String? imageUrl,
    MarketNewsAsset? asset,
    MarketNewsGovernorate? governorate,
  }) {
    return MarketNews(
      id: id ?? this.id,
      title: title ?? this.title,
      slug: slug ?? this.slug,
      summary: summary ?? this.summary,
      status: status ?? this.status,
      publishAt: publishAt ?? this.publishAt,
      publishedAt: publishedAt ?? this.publishedAt,
      tags: tags ?? this.tags,
      imageUrl: imageUrl ?? this.imageUrl,
      asset: asset ?? this.asset,
      governorate: governorate ?? this.governorate,
    );
  }

  factory MarketNews.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value == null) {
        return null;
      }
      if (value is DateTime) {
        return value;
      }
      final String candidate = value.toString();
      if (candidate.isEmpty) {
        return null;
      }
      return DateTime.tryParse(candidate);
    }

    return MarketNews(
      id: _asInt(json['id']),
      title: json['title']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      summary: json['summary']?.toString(),
      status: json['status']?.toString() ?? 'draft',
      publishAt: parseDate(json['publish_at']),
      publishedAt: parseDate(json['published_at']),
      tags: _parseTags(json['tags']),
      imageUrl: json['image_url']?.toString(),
      asset: MarketNewsAsset.fromJson(json['asset']),
      governorate: MarketNewsGovernorate.fromJson(json['governorate']),
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  static List<String> _parseTags(dynamic value) {
    if (value is List) {
      return value
          .where((element) => element != null)
          .map((element) => element.toString())
          .where((element) => element.isNotEmpty)
          .toList(growable: false);
    }
    return const <String>[];
  }
}

class MarketNewsAsset {
  final int? id;
  final String? name;
  final String? slug;
  final String? image;

  const MarketNewsAsset({
    this.id,
    this.name,
    this.slug,
    this.image,
  });

  factory MarketNewsAsset.fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) {
      return const MarketNewsAsset();
    }
    return MarketNewsAsset(
      id: MarketNews._asInt(json['id']),
      name: json['name']?.toString(),
      slug: json['slug']?.toString(),
      image: json['image']?.toString(),
    );
  }
}

class MarketNewsGovernorate {
  final int? id;
  final String? name;
  final String? code;

  const MarketNewsGovernorate({
    this.id,
    this.name,
    this.code,
  });

  factory MarketNewsGovernorate.fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) {
      return const MarketNewsGovernorate();
    }
    return MarketNewsGovernorate(
      id: MarketNews._asInt(json['id']),
      name: json['name']?.toString(),
      code: json['code']?.toString(),
    );
  }
}