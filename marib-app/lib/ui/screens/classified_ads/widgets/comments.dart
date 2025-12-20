import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:marib/data/model/seller_ratings_model.dart' show UserRatings;
import 'package:marib/utils/helper_utils.dart';
import 'package:marib/utils/hive_utils.dart';
import 'package:marib/app/routes.dart';
import 'service_ratings_api.dart';
import 'package:flutter/foundation.dart';

class ItemCommentsList extends StatefulWidget {
  final int? serviceId;
  final EdgeInsetsGeometry? padding;
  final ValueChanged<bool>? onCanReviewChanged;
  final ValueChanged<int?>? onServiceIdResolved;
  final String? serviceUid;
  final ValueChanged<List<UserRatings>>? onRatingsUpdated;

  const ItemCommentsList({
    super.key,
    this.serviceId,
    this.onCanReviewChanged,
    this.onServiceIdResolved,
    this.serviceUid,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.onRatingsUpdated,
  });

  @override
  State<ItemCommentsList> createState() => ItemCommentsListState();
}

class ItemCommentsListState extends State<ItemCommentsList> {
  static final Map<String, List<UserRatings>> _localCache = {};
  static String? _lastViewerKey;
  final _scroll = ScrollController();

  final List<UserRatings> _items = [];
  UserRatings? _myReview;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  String? _sort; // 'default' | 'recent' | 'top'
  int? _serviceId;
  bool _paginationEnded = false;
  bool _endOfListNotified = false;

  static String? _cacheKeyFor(int? serviceId, String? serviceUid) {
    final uid = serviceUid?.trim();
    final String viewer = HiveUtils.getUserId()?.toString().trim().isNotEmpty == true
        ? HiveUtils.getUserId()!.toString()
        : 'guest';
    if (uid != null && uid.isNotEmpty) return 'uid:$uid|v:$viewer';
    if (serviceId != null && serviceId > 0) return 'id:$serviceId|v:$viewer';
    return null;
  }

  static List<UserRatings> cachedRatings({
    int? serviceId,
    String? serviceUid,
  }) {
    final key = _cacheKeyFor(serviceId, serviceUid);
    if (key == null) return const [];
    return List<UserRatings>.from(_localCache[key] ?? const <UserRatings>[]);
  }

  @override
  void initState() {
    super.initState();
    try {
      timeago.setLocaleMessages('ar', timeago.ArMessages());
    } catch (_) {}
    _serviceId = widget.serviceId;
    _resetCacheIfViewerChanged();
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
  void didUpdateWidget(covariant ItemCommentsList oldWidget) {
    super.didUpdateWidget(oldWidget);
    bool changed = false;
    if (widget.serviceId != null &&
        widget.serviceId != oldWidget.serviceId &&
        widget.serviceId != _serviceId) {
      _serviceId = widget.serviceId;
      changed = true;
    }
    if ((widget.serviceUid ?? '') != (oldWidget.serviceUid ?? '')) {
      changed = true;
    }
    if (changed) {
      _resetCacheIfViewerChanged();
      _loadFirst();
    }
  }

  /// ط¥ط¹ط§ط¯ط© ط§ظ„طھط­ظ…ظٹظ„ ظ…ط¹ ط§ط®طھظٹط§ط± ط§ظ„طھط±طھظٹط¨
  Future<void> reload({String? sort}) async {
    _resetCacheIfViewerChanged();
    _sort = sort ?? _sort;
    await _loadFirst();
  }

  void addLocalRating({required double stars, required String review}) {
    final now = DateTime.now().toIso8601String();
    _serviceId ??= widget.serviceId;
    final key = _cacheKey;
    final rating = UserRatings(
      id: DateTime.now().millisecondsSinceEpoch,
      itemId: _serviceId,
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
    return _cacheKeyFor(_serviceId ?? widget.serviceId, widget.serviceUid);
  }

  void _resetCacheIfViewerChanged() {
    final String viewer = HiveUtils.getUserId()?.toString().trim().isNotEmpty == true
        ? HiveUtils.getUserId()!.toString()
        : 'guest';
    if (_lastViewerKey != viewer) {
      _localCache.clear();
      _lastViewerKey = viewer;
    }
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
    if (!_items.any((e) => _ratingKey(e) == key)) {
      _items.insert(0, rating);
    }
  }

  Future<void> _loadFirst() async {
    _resetCacheIfViewerChanged();
    final List<UserRatings> preserved = List<UserRatings>.from(_items);
    setState(() {
      _loading = true;
      _items.clear();
      _myReview = null;
      _page = 1;
      _hasMore = true;
      _paginationEnded = false;
      _endOfListNotified = false;
    });
    bool anyAdded = false;
    UserRatings? myReview;
    try {
      final res = await ServiceRatingsApi.fetchRatings(
        serviceId: _serviceId,
        page: _page,
        perPage: 20,
        sort: _sort,
        serviceUid: widget.serviceUid,
      );
      final uniqueFirst = _collectUniqueRatings(
        res.list,
        _items.map(_ratingKey).toSet(),
        _items.map((r) => r.id).whereType<int>().toSet(),
      );
      if (uniqueFirst.isNotEmpty) {
        _items.addAll(uniqueFirst);
        anyAdded = true;
      }
      for (final r in preserved) {
        _addIfMissing(r);
      }
      final bool duplicateResponse = res.list.isNotEmpty && uniqueFirst.isEmpty;
      final bool emptyResponse = res.list.isEmpty;

      _hasMore = res.hasMore && !duplicateResponse && !emptyResponse;
      _paginationEnded = (!_hasMore || duplicateResponse || emptyResponse) &&
          _items.isNotEmpty;

      _page = res.nextPage;
      widget.onCanReviewChanged?.call(res.canReview);
      _serviceId = res.serviceId;
      widget.onServiceIdResolved?.call(_serviceId);

      // اجلب تقييمي الشخصي بعد حل معرف الخدمة لضمان ظهوره حتى لو كان قيد المراجعة
      try {
        final my = await ServiceRatingsApi.getMyReview(
          serviceId: _serviceId ?? widget.serviceId,
          serviceUid: widget.serviceUid,
        );
        myReview = my;
        if (myReview != null) {
          _addIfMissing(myReview);
          anyAdded = true;
          _hasMore = false;
          _paginationEnded = true;
        }
        if (_items.isEmpty && my != null) {
          _items.add(my);
          anyAdded = true;
        }
      } catch (_) {}
      if (_paginationEnded) {
        _notifyPaginationEndOnce();
      }
    } catch (_) {
      for (final r in preserved) {
        _addIfMissing(r);
      }
      try {
        final my = await ServiceRatingsApi.getMyReview(
          serviceId: _serviceId ?? widget.serviceId,
          serviceUid: widget.serviceUid,
        );
        myReview = my;
        if (myReview != null) {
          _addIfMissing(myReview);
          anyAdded = true;
        }
        if (_items.isEmpty && myReview != null) {
          _items.add(myReview!);
          anyAdded = true;
        }
      } catch (_) {}
      _hasMore = false;
      _paginationEnded = _items.isNotEmpty;
    } finally {
      // تأكد من إظهار تقييمي الشخصي حتى لو بقيت القائمة فارغة لأي سبب
      if (_items.isEmpty && myReview != null) {
        _items.add(myReview!);
        anyAdded = true;
        _hasMore = false;
        _paginationEnded = true;
      }
      final key = _cacheKey;
      if (key != null) {
        _localCache[key] = List<UserRatings>.from(_items);
      }
      _myReview = myReview ?? _myReview;
      if (_paginationEnded && !_endOfListNotified && _items.isNotEmpty) {
        _notifyPaginationEndOnce();
      }
      if (mounted) {
        setState(() => _loading = false);
        if (anyAdded || _items.isNotEmpty) {
          _emitUpdated();
        }
      }
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final res = await ServiceRatingsApi.fetchRatings(
        serviceId: _serviceId,
        page: _page,
        perPage: 20,
        sort: _sort,
        serviceUid: widget.serviceUid,
      );
      final List<UserRatings> unique = _collectUniqueRatings(
        res.list,
        _items.map(_ratingKey).toSet(),
        _items.map((r) => r.id).whereType<int>().toSet(),
      );

      if (unique.isNotEmpty) {
        _items.addAll(unique);
      }

      final bool duplicateResponse = res.list.isNotEmpty && unique.isEmpty;
      final bool emptyResponse = res.list.isEmpty;
      _hasMore = res.hasMore && !duplicateResponse && !emptyResponse;
      _paginationEnded = (!_hasMore || duplicateResponse || emptyResponse) &&
          _items.isNotEmpty;

      _page = res.nextPage;
      widget.onCanReviewChanged?.call(res.canReview);
      _serviceId = res.serviceId;
      widget.onServiceIdResolved?.call(_serviceId);
      if (_paginationEnded) {
        _notifyPaginationEndOnce();
      }
    } catch (_) {
      // ignore
    } finally {
      if (mounted) {
        setState(() => _loadingMore = false);
        _emitUpdated();
      }
    }
  }

  void _onScroll() {
    if (!_scroll.hasClients || _loading || _loadingMore || !_hasMore) return;
    final pos = _scroll.position;
    if (pos.pixels >= pos.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  void _notifyPaginationEndOnce() {
    if (_endOfListNotified || !mounted || _items.isEmpty) {
      return;
    }
    _endOfListNotified = true;
    Future.microtask(() {
      if (!mounted) return;
      HelperUtils.showSnackBarMessage(
        context,
        'تم عرض جميع التعليقات.',
        isFloating: true,
      );
    });
  }

  void _emitUpdated() {
    widget.onRatingsUpdated?.call(List<UserRatings>.unmodifiable(_items));
  }

  String _ratingKey(UserRatings rating) {
    final int? id = rating.id;
    if (id != null && id > 0) {
      return 'id:$id';
    }
    final String created =
        (rating.createdAt ?? rating.updatedAt ?? '').toString().trim();
    final String reviewText = (rating.review ?? '').toString().trim();
    final int? buyer = rating.buyerId;
    final double? stars = rating.ratings;
    return 'meta:${buyer ?? 0}|t:$created|r:$reviewText|s:${stars ?? 0}';
  }

  @visibleForTesting
  List<UserRatings> collectUniqueRatingsForTesting(
    Iterable<UserRatings> ratings,
    Set<String> knownKeys,
    Set<int> knownIds,
  ) {
    return _collectUniqueRatings(ratings, knownKeys, knownIds);
  }

  List<UserRatings> _collectUniqueRatings(
    Iterable<UserRatings> ratings,
    Set<String> knownKeys,
    Set<int> knownIds,
  ) {
    final List<UserRatings> unique = [];
    final Set<int> seenIds = Set<int>.from(knownIds);
    for (final rating in ratings) {
      final int? id = rating.id;
      if (id != null && id > 0 && !seenIds.add(id)) {
        continue;
      }
      final key = _ratingKey(rating);
      if (knownKeys.add(key)) {
        unique.add(rating);
      }
    }
    return unique;
  }

  Widget _buildEndOfListMessage(BuildContext context) {
    final theme = Theme.of(context);
    final Color textColor =
        theme.textTheme.bodySmall?.color?.withOpacity(0.7) ?? theme.hintColor;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Text(
          'تم عرض جميع التعليقات.',
          style: TextStyle(color: textColor, fontSize: 12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<UserRatings> items = _items.isNotEmpty
        ? _items
        : (_myReview != null ? <UserRatings>[_myReview!] : _items);

    if (_loading) {
      return const Center(
        child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (items.isEmpty) {
      final isRtl = Directionality.of(context) == TextDirection.rtl;
      String _t(String ar, String en) => isRtl ? ar : en;
      return Center(child: Text(_t('لا توجد تعليقات بعد', 'No comments yet')));
    }

    return RefreshIndicator(
      onRefresh: () => reload(),
      child: ListView.separated(
        controller: _scroll,
        padding: widget.padding ?? EdgeInsets.zero,
        itemCount: items.length +
            (_loadingMore ? 1 : 0) +
            (_paginationEnded && _items.isNotEmpty ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (ctx, i) {
          final int loaderIndex = items.length;
          final int footerIndex = loaderIndex + (_loadingMore ? 1 : 0);
          if (_loadingMore && i >= loaderIndex && i < footerIndex) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Center(
                child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            );
          }
          if (_paginationEnded && _items.isNotEmpty && i >= footerIndex) {
            return _buildEndOfListMessage(context);
          }
          final r = items[i];
          return _CommentTile(rating: r);
        },
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final UserRatings rating;

  const _CommentTile({required this.rating});

  void _openProfile(BuildContext context) {
    final int? userId = rating.buyerId ?? rating.buyer?.id;
    if (userId == null) return;
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final String fallbackName = isRtl ? 'مستخدم' : 'User';
    final String name = (rating.buyer?.name ?? '').trim().isEmpty
        ? fallbackName
        : rating.buyer!.name!.trim();
    final String avatar = HelperUtils.absoluteImage(
      rating.buyer?.profile ?? '',
    );
    if (userId == null && name.isEmpty) return;
    HelperUtils.goToNextPage(
      Routes.showProfile,
      context,
      false,
      args: {
        'from': 'service_rating_comment',
        'type': null,
        'extraData': {
          'id': userId,
          'name': name,
          'profile': avatar,
        },
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final card = Theme.of(context).cardColor;
    final txt = context.color.textColorDark;

    final double stars = (rating.ratings ?? 0).toDouble();
    final String reviewText = (rating.review ?? '').toString().trim();
    final String timeText = _formatWhen(rating);
    final String avatar =
        HelperUtils.absoluteImage(rating.buyer?.profile ?? '').trim();
    final String name = (rating.buyer?.name ?? '').trim().isEmpty
        ? (Directionality.of(context) == TextDirection.rtl
            ? 'مستخدم'
            : 'User')
        : rating.buyer!.name!.trim();

    return Container(
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => _openProfile(context),
            borderRadius: BorderRadius.circular(12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: context.color.primaryColor.withOpacity(0.12),
                  backgroundImage:
                      avatar.isNotEmpty ? NetworkImage(avatar) : null,
                  child: avatar.isEmpty
                      ? Icon(Icons.person,
                          color: context.color.primaryColor, size: 18)
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          color: txt,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (timeText.isNotEmpty)
                        Text(
                          timeText,
                          style: TextStyle(
                            fontSize: 12,
                            color: txt.withOpacity(0.65),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _StarsRow(value: stars),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (reviewText.isNotEmpty)
            Text(
              reviewText,
              style: TextStyle(color: txt, height: 1.5),
              textAlign: TextAlign.start,
            ),
        ],
      ),
    );
  }

  static String _formatWhen(UserRatings r) {
    final raw = (r.createdAt ?? '').toString();
    if (raw.isEmpty) return '';
    DateTime? dt;
    try {
      dt = DateTime.tryParse(raw);
    } catch (_) {}
    if (dt == null) return '';
    return timeago.format(dt, locale: UiUtils.resolveLanguageCode(null));
  }
}

class _StarsRow extends StatelessWidget {
  final double value;

  const _StarsRow({required this.value});

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(0, 5);
    final full = v.floor();
    final half = (v - full) >= 0.5;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        IconData icon;
        if (i < full) {
          icon = Icons.star;
        } else if (i == full && half) {
          icon = Icons.star_half;
        } else {
          icon = Icons.star_border;
        }
        return Padding(
          padding: const EdgeInsetsDirectional.only(start: 2),
          child: Icon(icon, size: 18, color: const Color(0xFFF37A00)),
        );
      }),
    );
  }
}
