import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/data/model/seller_ratings_model.dart' show UserRatings;
import 'service_ratings_api.dart';


class ItemCommentsList extends StatefulWidget {
  final int itemId;
  final EdgeInsetsGeometry? padding;
  final ValueChanged<bool>? onCanReviewChanged;
  final String? serviceUid;

  const ItemCommentsList({
    super.key,
    required this.itemId,
    this.onCanReviewChanged,
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

  @override
  void initState() {
    super.initState();
    // تهيئة timeago بالعربية (بهدوء لو كانت مسجلة مسبقًا)
    try { timeago.setLocaleMessages('ar', timeago.ArMessages()); } catch (_) {}
    _loadFirst();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
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
    });
    try {
      final res = await ServiceRatingsApi.fetchRatings(
        itemId: widget.itemId,
        page: _page,
        perPage: 20,
        sort: _sort,
        serviceUid: widget.serviceUid,

      );
      _items.addAll(res.list);
      _hasMore = res.hasMore;
      _page = res.nextPage;
      widget.onCanReviewChanged?.call(res.canReview);

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
        itemId: widget.itemId,
        page: _page,
        perPage: 20,
        sort: _sort,
        serviceUid: widget.serviceUid,

      );
      _items.addAll(res.list);
      _hasMore = res.hasMore;
      _page = res.nextPage;
      widget.onCanReviewChanged?.call(res.canReview);

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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
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
        itemCount: _items.length + (_loadingMore ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (ctx, i) {
          if (i >= _items.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Center(
                child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            );
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
    final txt  = context.color.textColorDark;

    final double stars = (rating.ratings ?? 0).toDouble();
    final String reviewText = (rating.review ?? '').toString().trim();
    final String timeText = _formatWhen(rating);

    return Container(
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
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
                Text(timeText, style: TextStyle(fontSize: 12, color: txt.withOpacity(0.65))),
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
    try { dt = DateTime.tryParse(raw); } catch (_) {}
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
