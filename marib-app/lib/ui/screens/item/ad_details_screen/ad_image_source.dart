import 'package:cached_network_image/cached_network_image.dart';

const int kAdDetailImageMaxEdge = 720;

class AdImageSource {
  const AdImageSource._({
    required this.detailUrl,
    required this.originalUrl,
  });

  factory AdImageSource.from({
    String? detailUrl,
    String? fallbackUrl,
  }) {
    final String normalizedDetail = _normalize(detailUrl);
    final String normalizedFallback = _normalize(fallbackUrl);

    final String resolvedOriginal =
    normalizedFallback.isNotEmpty ? normalizedFallback : normalizedDetail;
    final String resolvedDetail =
    normalizedDetail.isNotEmpty ? normalizedDetail : resolvedOriginal;

    if (resolvedDetail.isEmpty) {
      throw ArgumentError('At least one non-empty URL is required.');
    }

    return AdImageSource._(
      detailUrl: resolvedDetail,
      originalUrl: resolvedOriginal.isNotEmpty ? resolvedOriginal : resolvedDetail,
    );
  }

  final String detailUrl;
  final String originalUrl;

  bool get hasOptimizedVariant => detailUrl != originalUrl;

  String get displayUrl => detailUrl;

  String get fallbackDisplayUrl => originalUrl;

  CachedNetworkImageProvider buildFullScreenProvider() {
    return CachedNetworkImageProvider(
      displayUrl,
      maxWidth: hasOptimizedVariant ? kAdDetailImageMaxEdge : null,
      maxHeight: hasOptimizedVariant ? kAdDetailImageMaxEdge : null,
    );
  }

  static String _normalize(String? value) {
    if (value == null) {
      return '';
    }
    final String trimmed = value.trim();
    return trimmed.isEmpty ? '' : trimmed;
  }
}