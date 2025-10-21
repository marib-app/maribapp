import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/data/model/seller_ratings_model.dart' show UserRatings;
import 'service_ratings_api.dart';

class ItemCommentsList extends StatefulWidget {
  final int? serviceId;
  final EdgeInsetsGeometry? padding;
  final ValueChanged<bool>? onCanReviewChanged;
  final ValueChanged<int?>? onServiceIdResolved;
  final String? serviceUid;

  const ItemCommentsList({
    super.key,
    this.serviceId,
    this.onCanReviewChanged,
    this.onServiceIdResolved,
    this.serviceUid,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  @override
  State<ItemCommentsList> createState() => ItemCommentsListState();
}

class ItemCommentsListState extends State<ItemCommentsList> {
  final _scroll = ScrollController();

  final List<UserRatings> _items = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  String? _sort; // 'default' | 'recent' | 'top' (اختياري)
  int? _serviceId;
  bool _paginationEnded = false;
  bool _endOfListNotified = false;

  @override
  void initState() {
    super.initState();
    // تهيئة timeago بالعربية (بهدوء لو كانت مسجلة مسبقًا)
    try {
      timeago.setLocaleMessages('ar', timeago.ArMessages());
    } catch (_) {}
    _serviceId = widget.serviceId;
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
    if (widget.serviceId != null &&
        widget.serviceId != oldWidget.serviceId &&
        widget.serviceId != _serviceId) {
      _serviceId = widget.serviceId;
    }
  }

  /// تُستدعى من الخارج لتحديث القائمة
  Future<void> reload({String? sort}) async {
    _sort = sort ?? _sort;
    await _loadFirst();
  }

  Future<void> _loadFirst() async {
    setState(() {
      _loading = true;
      _items.clear();
      _page = 1;
      _hasMore = true;
      _paginationEnded = false;
      _endOfListNotified = false;
    });
    try {
      final res = await ServiceRatingsApi.fetchRatings(
        serviceId: _serviceId,
        page: _page,
        perPage: 20,
        sort: _sort,
        serviceUid: widget.serviceUid,
      );
      _items.addAll(res.list);
      _hasMore = res.hasMore;
      _paginationEnded = !_hasMore && _items.isNotEmpty;
      _page = res.nextPage;
      widget.onCanReviewChanged?.call(res.canReview);
      _serviceId = res.serviceId;
      widget.onServiceIdResolved?.call(_serviceId);
      if (_paginationEnded) {
        _notifyPaginationEndOnce();
      }
    } catch (_) {
      // بإمكانك عرض SnackBar هنا لو حبيت
    } finally {
      if (mounted) setState(() => _loading = false);
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
      final existingKeys = _items.map(_ratingKey).toSet();
      final List<UserRatings> unique = [];
      for (final rating in res.list) {
        final key = _ratingKey(rating);
        if (existingKeys.add(key)) {
          unique.add(rating);
        }
      }

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
      // تجاهل هادئ
    } finally {
      if (mounted) setState(() => _loadingMore = false);
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم عرض جميع التعليقات.')),
      );
    });
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
    if (_loading) {
      return const Center(
        child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (_items.isEmpty) {
      return const Center(child: Text('لا توجد تعليقات بعد'));
    }

    return RefreshIndicator(
      onRefresh: () => reload(),
      child: ListView.separated(
        controller: _scroll,
        padding: widget.padding ?? EdgeInsets.zero,
        itemCount: _items.length +
            (_loadingMore ? 1 : 0) +
            (_paginationEnded && _items.isNotEmpty ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (ctx, i) {
          final int loaderIndex = _items.length;
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
          final r = _items[i];
          return _CommentTile(rating: r);
        },
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final UserRatings rating;

  const _CommentTile({required this.rating});

  @override
  Widget build(BuildContext context) {
    final card = Theme.of(context).cardColor;
    final txt = context.color.textColorDark;

    final double stars = (rating.ratings ?? 0).toDouble();
    final String reviewText = (rating.review ?? '').toString().trim();
    final String timeText = _formatWhen(rating);

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
          Row(
            textDirection: TextDirection.rtl,
            children: [
              _StarsRow(value: stars),
              const Spacer(),
              if (timeText.isNotEmpty)
                Text(timeText,
                    style:
                        TextStyle(fontSize: 12, color: txt.withOpacity(0.65))),
            ],
          ),
          const SizedBox(height: 8),
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
    return timeago.format(dt, locale: 'ar');
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
