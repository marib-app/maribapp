import 'package:flutter/material.dart';
import 'package:marib/data/model/seller_ratings_model.dart' show UserRatings;
import 'package:marib/ui/screens/storefront/widgets/store_ratings_api.dart';
import 'package:marib/app/routes.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:timeago/timeago.dart' as timeago;

class StoreCommentsList extends StatefulWidget {
  final int? storeId;
  final String? storeSlug;
  final EdgeInsetsGeometry? padding;
  final ValueChanged<bool>? onCanReviewChanged;
  final ValueChanged<int?>? onStoreIdResolved;
  final ValueChanged<List<UserRatings>>? onRatingsUpdated;

  const StoreCommentsList({
    super.key,
    this.storeId,
    this.storeSlug,
    this.onCanReviewChanged,
    this.onStoreIdResolved,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.onRatingsUpdated,
  });

  @override
  State<StoreCommentsList> createState() => StoreCommentsListState();
}

class StoreCommentsListState extends State<StoreCommentsList> {
  static final Map<String, List<UserRatings>> _localCache = {};
  final _scroll = ScrollController();

  final List<UserRatings> _items = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  String? _sort; // 'default' | 'recent' | 'top'
  int? _storeId;
  bool _paginationEnded = false;
  bool _endOfListNotified = false;

  static String? _cacheKeyFor(int? storeId, String? storeSlug) {
    final slug = storeSlug?.trim();
    if (slug != null && slug.isNotEmpty) return 'slug:$slug';
    if (storeId != null && storeId > 0) return 'id:$storeId';
    return null;
  }

  static List<UserRatings> cachedRatings({
    int? storeId,
    String? storeSlug,
  }) {
    final key = _cacheKeyFor(storeId, storeSlug);
    if (key == null) return const [];
    return List<UserRatings>.from(_localCache[key] ?? const <UserRatings>[]);
  }

  @override
  void initState() {
    super.initState();
    try {
      timeago.setLocaleMessages('ar', timeago.ArMessages());
    } catch (_) {}
    _storeId = widget.storeId;
    _restoreCachedLocal();
    _loadFirst();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant StoreCommentsList oldWidget) {
    super.didUpdateWidget(oldWidget);
    bool changed = false;
    if (widget.storeId != null &&
        widget.storeId != oldWidget.storeId &&
        widget.storeId != _storeId) {
      _storeId = widget.storeId;
      changed = true;
    }
    if ((widget.storeSlug ?? '') != (oldWidget.storeSlug ?? '')) {
      changed = true;
    }
    if (changed) {
      _loadFirst();
    }
  }

  Future<void> reload({String? sort}) async {
    _sort = sort ?? _sort;
    await _loadFirst();
  }

  void addLocalRating({required double stars, required String review}) {
    final now = DateTime.now().toIso8601String();
    _storeId ??= widget.storeId;
    final key = _cacheKey;
    final rating = UserRatings(
      id: DateTime.now().millisecondsSinceEpoch,
      itemId: _storeId,
      ratings: stars,
      review: review,
      createdAt: now,
      updatedAt: now,
    );
    if (key != null) {
      final list = _localCache.putIfAbsent(key, () => []);
      list.insert(0, rating);
    }
    setState(() {
      _loading = false;
      _items.insert(0, rating);
    });
    _emitUpdated();
  }

  String? get _cacheKey {
    return _cacheKeyFor(_storeId ?? widget.storeId, widget.storeSlug);
  }

  void _restoreCachedLocal() {
    final key = _cacheKey;
    if (key != null && _localCache.containsKey(key)) {
      final cached = _localCache[key]!;
      if (cached.isNotEmpty) {
        _items.insertAll(0, cached);
        _loading = false;
        _emitUpdated();
      }
    }
  }

  void _addIfMissing(UserRatings rating) {
    final key = _ratingKey(rating);
    final int? userId = rating.buyer?.id;
    final bool exists = _items.any((e) {
      final sameKey = _ratingKey(e) == key;
      final int? eu = e.buyer?.id;
      final bool sameUser =
          userId != null && eu != null && userId == eu && (e.itemId == rating.itemId);
      return sameKey || sameUser;
    });
    if (!exists) {
      _items.insert(0, rating);
    }
  }

  Future<void> _loadFirst() async {
    final List<UserRatings> preserved = List<UserRatings>.from(_items);
    setState(() {
      _loading = true;
      _items.clear();
      _page = 1;
      _hasMore = true;
      _paginationEnded = false;
      _endOfListNotified = false;
    });
    bool anyAdded = false;
    try {
      final res = await StoreRatingsApi.fetchRatings(
        storeId: _storeId ?? widget.storeId ?? 0,
        storeSlug: widget.storeSlug,
        page: _page,
        perPage: 20,
        sort: _sort,
      );
      final uniqueFirst = _collectUniqueRatings(
        res.list,
        _items.map(_ratingKey).toSet(),
        _items.map((r) => r.id).whereType<int>().toSet(),
      );
      if (uniqueFirst.isNotEmpty) {
        _items.addAll(uniqueFirst);
        anyAdded = true;
      } else if (res.list.isEmpty && preserved.isNotEmpty) {
        // إذا لم يُرجع الخادم شيئاً نعيد إظهار المحفوظات المحلية فقط
        for (final r in preserved) {
          _addIfMissing(r);
        }
      }
      final bool duplicateResponse = res.list.isNotEmpty && uniqueFirst.isEmpty;
      final bool emptyResponse = res.list.isEmpty;

      _hasMore = res.hasMore && !duplicateResponse && !emptyResponse;
      _paginationEnded = (!_hasMore || duplicateResponse || emptyResponse) &&
          _items.isNotEmpty;

      _page = res.nextPage;
      widget.onCanReviewChanged?.call(res.canReview);
      _storeId = res.storeId;
      widget.onStoreIdResolved?.call(_storeId);

      if (_paginationEnded) {
        _notifyPaginationEndOnce();
      }
    } catch (_) {
      for (final r in preserved) {
        _addIfMissing(r);
      }
    } finally {
      _cacheCurrent();
      _emitUpdated();
      if (mounted) {
        setState(() {
          _loading = false;
          if (!anyAdded && _items.isNotEmpty) {
            _paginationEnded = true;
          }
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final res = await StoreRatingsApi.fetchRatings(
        storeId: _storeId ?? widget.storeId ?? 0,
        storeSlug: widget.storeSlug,
        page: _page,
        perPage: 20,
        sort: _sort,
      );

      final existingKeys = _items.map(_ratingKey).toSet();
      final existingIds = _items.map((r) => r.id).whereType<int>().toSet();
      final unique = _collectUniqueRatings(res.list, existingKeys, existingIds);

      if (unique.isNotEmpty) {
        _items.addAll(unique);
      }

      _hasMore = res.hasMore && unique.isNotEmpty;
      _page = res.nextPage;

      if (!_hasMore) {
        _paginationEnded = true;
        _notifyPaginationEndOnce();
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _loadingMore = false);
        _cacheCurrent();
        _emitUpdated();
      }
    }
  }

  void _cacheCurrent() {
    final key = _cacheKey;
    if (key != null) {
      _localCache[key] = List<UserRatings>.from(_items);
    }
  }

  void _emitUpdated() {
    widget.onRatingsUpdated?.call(List<UserRatings>.from(_items));
  }

  void _onScroll() {
    if (_scroll.position.pixels >
        _scroll.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
          child: Padding(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator()));
    }

    final bool isRtl = Directionality.of(context) == TextDirection.rtl;

    if (_items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Text(
            isRtl ? 'لا توجد تقييمات بعد' : 'No reviews yet',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    return ListView.separated(
      controller: _scroll,
      shrinkWrap: true,
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _items.length + (_hasMore ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (_hasMore && index == _items.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: CircularProgressIndicator(),
            ),
          );
        }
        final rating = _items[index];
        return _CommentTile(rating: rating);
      },
    );
  }

  void _notifyPaginationEndOnce() {
    if (_endOfListNotified || !_paginationEnded) return;
    _endOfListNotified = true;
    // يمكن إضافة توست أو سناك بار هنا عند الحاجة
  }
}

String _ratingKey(UserRatings rating) =>
    '${rating.id ?? rating.itemId ?? rating.createdAt}-${rating.ratings}-${rating.review}';

List<UserRatings> _collectUniqueRatings(
  List<UserRatings> list,
  Set<String> existingKeys,
  Set<int> existingIds,
) {
  final Set<String> seenKeys = <String>{...existingKeys};
  final Set<int> seenIds = <int>{...existingIds};
  final List<UserRatings> result = [];
  for (final r in list) {
    final key = _ratingKey(r);
    final id = r.id;
    if (seenKeys.add(key)) {
      if (id == null || seenIds.add(id)) {
        result.add(r);
      }
    }
  }
  return result;
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.rating});
  final UserRatings rating;

  void _openProfile(BuildContext context, {required String displayName}) {
    final int? userId = rating.buyer?.id;
    final String? avatar = rating.buyer?.profile;
    if (userId == null) return;
    HelperUtils.goToNextPage(
      Routes.showProfile,
      context,
      false,
      args: {
        'from': 'store_rating_comment',
        'type': null,
        'popToCurrent': false,
        'extraData': {
          'id': userId,
          'name': displayName,
          'image': avatar,
        },
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.color;
    final buyer = rating.buyer;
    final bool isRtl = Directionality.of(context) == TextDirection.rtl;
    final name = buyer?.name ?? (isRtl ? 'مستخدم' : 'User');
    final created = rating.createdAt ?? '';
    final stars = (rating.ratings ?? 0).round().clamp(1, 5);

    DateTime? createdDt;
    try {
      createdDt = DateTime.tryParse(created)?.toLocal();
    } catch (_) {}
    final String timeLabel;
    if (createdDt != null) {
      final duration = DateTime.now().difference(createdDt);
      if (duration.inHours < 24) {
        timeLabel = timeago.format(createdDt, locale: isRtl ? 'ar' : 'en_short');
      } else {
        timeLabel = createdDt.toString().split(' ').first;
      }
    } else {
      timeLabel = created.split('T').first;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black12.withValues(alpha: 0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundImage:
                    buyer?.profile != null ? NetworkImage(buyer!.profile!) : null,
                child: buyer?.profile == null ? const Icon(Icons.person) : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: () => _openProfile(context, displayName: name),
                      child: Text(
                        name,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: colors.territoryColor,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: List.generate(
                        5,
                        (index) => Icon(
                          index < stars ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Text(timeLabel, style: theme.textTheme.bodySmall),
            ],
          ),
          if ((rating.review ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              rating.review ?? '',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }
}
