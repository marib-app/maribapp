import 'package:flutter/material.dart';
import 'package:marib/data/model/user_model.dart';
import 'package:marib/settings.dart';
import 'package:marib/ui/screens/home_screen/section/section_screen/section_screen.dart';
import 'package:marib/utils/constant.dart';
import 'package:marib/utils/seller_category_utils.dart'
    as seller_category_utils;
import 'package:marib/utils/ui_utils.dart';

class SellerCard extends StatelessWidget {
  const SellerCard({super.key, required this.seller});

  final UserModel seller;

  static const String _defaultStoreName = '\u0645\u062a\u062c\u0631';
  static const String _categoryName =
      '\u0627\u0644\u0645\u062a\u062c\u0631 \u0627\u0644\u0625\u0644\u0643\u062a\u0631\u0648\u0646\u064a';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final int? id = seller.id;
    final Map<String, dynamic> store = _resolveStoreMap(seller);

    final String displayName =
        (_pick(store, 'name') ?? seller.name ?? _defaultStoreName).toString();

    final String logo = _normalizeImage(_pickFirst(store, [
          'logo_path',
          'logoPath',
          'logo',
          'logo_url',
          'logoUrl',
          'business_logo',
          'office_logo',
          'profile',
          'image',
        ]) ??
        seller.profile);

    final String cover = _normalizeImage(_pickFirst(store, [
          'cover_path',
          'coverPath',
          'banner_path',
          'bannerPath',
          'cover',
          'cover_url',
          'coverUrl',
          'cover_image',
          'banner',
          'banner_url',
          'bannerUrl',
          'banner_image',
          'bannerImage',
          'image',
          'profile',
        ]) ??
        seller.profile);

    final _StoreAvailabilityStatus availability =
        _resolveStoreAvailabilityStatus(store);

    final sellerCategories =
        seller_category_utils.extractSellerCategoryIdentifiers(
      seller_category_utils.extractContactInfo(seller.additionalInfo),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: GestureDetector(
        onTap: () {
          if (id == null) return;

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => Section_screen(
                categoryId: Constant.storeRootCategoryIdAsString,
                categoryName: _categoryName,
                storefrontSnapshot: store.isNotEmpty ? store : null,
                categoryIds: <String>[Constant.storeRootCategoryIdAsString],
                interfaceType: 'e_store',
                sellerId: id,
                sellerCategoryIds: sellerCategories.numericIds.isNotEmpty
                    ? sellerCategories.numericIds
                    : null,
              ),
            ),
          );
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Container(
            height: 150,
            decoration: BoxDecoration(color: colors.surfaceVariant),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (cover.isNotEmpty)
                        UiUtils.getImage(cover, fit: BoxFit.cover),
                      Container(
                        color: colors.background.withOpacity(0.35),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: colors.surface.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      availability.primaryLabel,
                      style: TextStyle(
                        color: availability.isOpenNow
                            ? colors.primary
                            : colors.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: colors.surface,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: colors.onSurface.withOpacity(0.08),
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: logo.isNotEmpty
                            ? UiUtils.getImage(logo, fit: BoxFit.cover)
                            : Icon(
                                Icons.store_mall_directory_rounded,
                                color: colors.onSurface.withOpacity(0.5),
                              ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              displayName.isEmpty
                                  ? _defaultStoreName
                                  : displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: colors.onSurface,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                _statChip(
                                  colors,
                                  Icons.people_outline_rounded,
                                  _intValue(store['followers_count']),
                                  '\u0645\u062a\u0627\u0628\u0639',
                                ),
                                _statChip(
                                  colors,
                                  Icons.inventory_2_outlined,
                                  _intValue(store['items_count']),
                                  '\u0645\u0646\u062a\u062c',
                                ),
                                _statChip(
                                  colors,
                                  Icons.star_rate_rounded,
                                  _doubleValue(store['ratings_avg']),
                                  '\u062a\u0642\u064a\u064a\u0645',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Map<String, dynamic> _resolveStoreMap(UserModel seller) {
    final Map<String, dynamic> store = <String, dynamic>{};

    void merge(Map<dynamic, dynamic> source) {
      source.forEach((dynamic rawKey, dynamic rawValue) {
        if (rawKey == null) return;
        final String key = rawKey.toString();
        final dynamic current = store[key];
        if (_isEmptyValue(rawValue)) return;
        if (_isEmptyValue(current)) {
          store[key] = rawValue;
          return;
        }
        final String currentString = current.toString().trim();
        if (currentString.isEmpty || currentString == '-') {
          store[key] = rawValue;
        }
      });
    }

    if (seller.store is Map<String, dynamic>) {
      merge(seller.store as Map<String, dynamic>);
    } else if (seller.store is Map) {
      merge((seller.store as Map)
          .map((key, value) => MapEntry(key.toString(), value)));
    }

    final Map<String, dynamic>? info =
        seller_category_utils.coerceAdditionalInfo(seller.additionalInfo);
    if (info != null) {
      if (info['contact_info'] is Map) {
        merge(Map<String, dynamic>.from(info['contact_info'] as Map));
      }
      if (info['store'] is Map) {
        merge(Map<String, dynamic>.from(info['store'] as Map));
      }
      if (info['store_media'] is Map) {
        merge(Map<String, dynamic>.from(info['store_media'] as Map));
      } else if (info['store_media'] is List &&
          (info['store_media'] as List).isNotEmpty) {
        final dynamic first = (info['store_media'] as List).first;
        if (first is Map) merge(Map<String, dynamic>.from(first));
      }
      if (info['media'] is Map) {
        merge(Map<String, dynamic>.from(info['media'] as Map));
      }
    }

    if (store['media'] is Map) {
      merge(Map<String, dynamic>.from(store['media'] as Map));
    }

    return store;
  }

  _StoreAvailabilityStatus _resolveStoreAvailabilityStatus(
      Map<String, dynamic> store) {
    final String? opening = _stringValue(store['opening_time']);
    final String? closing = _stringValue(store['closing_time']);
    final String status = (store['status'] ?? store['store_status'] ?? '')
        .toString()
        .toLowerCase();
    final bool isOpen = status == 'open' ||
        status == 'opened' ||
        status == '1' ||
        status == '\u0645\u0641\u062a\u0648\u062d' ||
        status == 'open_now';

    final String primary;
    if (isOpen && opening != null && closing != null) {
      primary = '\u0645\u0641\u062a\u0648\u062d $opening - $closing';
    } else if (isOpen) {
      primary = '\u0645\u0641\u062a\u0648\u062d \u0627\u0644\u0622\u0646';
    } else {
      primary = '\u0645\u063a\u0644\u0642';
    }

    return _StoreAvailabilityStatus(
      isOpenNow: isOpen,
      primaryLabel: primary,
      secondaryLabel:
          (opening != null && closing != null) ? '$opening - $closing' : null,
    );
  }

  String _normalizeImage(dynamic value) {
    var path = (value ?? '').toString().trim();
    if (path.isEmpty) return '';
    final String lower = path.toLowerCase();
    if (lower == '-' || lower == 'null' || lower == 'placeholder') return '';
    if (path.startsWith('http')) return path;
    if (path.startsWith('//')) return 'https:$path';
    if (!path.startsWith('/')) path = '/$path';

    String? tryBuild(String base) {
      try {
        final uri = Uri.parse(base);
        if (uri.scheme.isNotEmpty && uri.host.isNotEmpty) {
          final origin =
              '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
          return origin + path;
        }
      } catch (_) {}
      return null;
    }

    final String baseWithoutApi =
        Constant.baseUrl.replaceFirst(RegExp(r'/api/?$'), '');
    final List<String> rawBases = <String>[
      baseWithoutApi,
      ...Constant.apiBaseUrlCandidates
          .map((b) => b.replaceFirst(RegExp(r'/api/?$'), '')),
      Constant.baseUrl,
      ...Constant.apiBaseUrlCandidates,
      ...AppSettings.hostUrlCandidates,
      'https://marib.app',
      'http://marib.app',
      'https://maribsrv.com',
      'http://maribsrv.com',
    ];

    final List<String> bases = <String>[];
    for (final base in rawBases) {
      final normalized = base.trim().replaceFirst(RegExp(r'/$'), '');
      if (normalized.isEmpty) continue;
      if (!bases.contains(normalized)) {
        bases.add(normalized);
        if (normalized.startsWith('http://')) {
          final secure = normalized.replaceFirst('http://', 'https://');
          if (!bases.contains(secure)) {
            bases.add(secure);
          }
        }
      }
    }

    for (final base in bases) {
      final resolved = tryBuild(base);
      if (resolved != null && resolved.isNotEmpty) return resolved;
    }

    return path;
  }

  String? _pick(Map<String, dynamic> store, String key) {
    final List<String> candidates = <String>[
      key,
      '${key}_url',
      '${key}Url',
      '${key}_path',
      '${key}Path',
      '${key}_image',
      '${key}Image',
      '${key}_link',
      '${key}Link',
    ];
    for (final candidate in candidates) {
      final dynamic v = store[candidate];
      if (_isEmptyValue(v)) continue;
      final String s = v.toString().trim();
      if (s.isNotEmpty) return s;
    }
    return null;
  }

  String? _pickFirst(Map<String, dynamic> store, List<String> keys) {
    for (final key in keys) {
      final String? value = _pick(store, key);
      if (value != null) return value;
    }
    return null;
  }

  bool _isEmptyValue(dynamic v) {
    if (v == null) return true;
    final String s = v.toString().trim();
    if (s.isEmpty) return true;
    final String lower = s.toLowerCase();
    return lower == 'null' || lower == '-' || lower == 'placeholder';
  }

  String? _stringValue(dynamic v) {
    if (_isEmptyValue(v)) return null;
    return v.toString().trim();
  }

  int? _intValue(dynamic v) {
    if (_isEmptyValue(v)) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  double? _doubleValue(dynamic v) {
    if (_isEmptyValue(v)) return null;
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  Widget _statChip(
    ColorScheme colors,
    IconData icon,
    num? value,
    String label,
  ) {
    final String display;
    if (value != null) {
      display = value >= 1000
          ? '${(value / 1000).toStringAsFixed(1)}k'
          : value.toString();
    } else {
      display = '-';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.surface.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: colors.primary),
          const SizedBox(width: 4),
          Text(
            '$display $label',
            style: TextStyle(color: colors.onSurface, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _StoreAvailabilityStatus {
  const _StoreAvailabilityStatus({
    required this.isOpenNow,
    required this.primaryLabel,
    this.secondaryLabel,
  });

  final bool isOpenNow;
  final String primaryLabel;
  final String? secondaryLabel;
}
