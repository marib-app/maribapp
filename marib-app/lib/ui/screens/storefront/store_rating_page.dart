import 'package:flutter/material.dart';
import 'package:marib/app/routes.dart';
import 'package:marib/data/model/seller_ratings_model.dart' show UserRatings;
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/hive_utils.dart';
import 'package:marib/ui/screens/storefront/widgets/store_addrating.dart';
import 'package:marib/ui/screens/storefront/widgets/store_comments.dart';
import 'package:marib/ui/screens/storefront/widgets/store_ratings_api.dart';

String _tr(BuildContext context, String ar, String en) =>
    Directionality.of(context) == TextDirection.rtl ? ar : en;

const Map<int, int> _emptyRatingDistribution = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};

class StoreRatingPage extends StatefulWidget {
  const StoreRatingPage({super.key});

  static Route route(RouteSettings settings) {
    return MaterialPageRoute(
      settings: settings,
      builder: (_) => const StoreRatingPage(),
    );
  }

  static final GlobalKey<StoreCommentsListState> commentsKey =
      GlobalKey<StoreCommentsListState>();

  static final ValueNotifier<int> headerRefresh = ValueNotifier<int>(0);

  @override
  State<StoreRatingPage> createState() => _StoreRatingPageState();
}

class _StoreRatingPageState extends State<StoreRatingPage> {
  bool? _canReview;
  int? _storeId;
  String? _storeSlug;
  _Summary? _overrideSummary;

  void _updateCanReview(bool? value) {
    if (!mounted || value == null || _canReview == value) return;
    setState(() => _canReview = value);
  }

  void _scheduleCanReviewUpdate(bool? value) {
    if (value == null || _canReview == value) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _canReview == value) return;
      setState(() => _canReview = value);
    });
  }

  void _updateStoreId(int? value) {
    if (!mounted || value == null || value <= 0 || _storeId == value) return;
    setState(() => _storeId = value);
  }

  void _scheduleStoreIdUpdate(int? value) {
    if (value == null || value <= 0 || _storeId == value) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _storeId == value) return;
      setState(() => _storeId = value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isRtl = Directionality.of(context) == TextDirection.rtl;
    String _t(String ar, String en) => isRtl ? ar : en;

    final args = (ModalRoute.of(context)?.settings.arguments as Map?)
            ?.cast<String, dynamic>() ??
        const {};

    int? parseId(dynamic raw) {
      if (raw == null) return null;
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      if (raw is String) return int.tryParse(raw.trim());
      return null;
    }

    final int? storeIdArg = parseId(args['storeId'] ?? args['store_id'] ?? args['id']);
    final String? storeSlugArg = (args['storeSlug'] ?? args['store_slug'] ?? args['slug'])?.toString().trim();
    final String storeNameResolved =
        (args['storeName'] ?? args['store_name'] ?? args['name'] as String?)
                ?.trim() ??
            _t('المتجر', 'Store');

    final bool hasLookupKey =
        (storeIdArg != null && storeIdArg > 0) || (storeSlugArg?.isNotEmpty ?? false);

    _scheduleStoreIdUpdate(storeIdArg);
    _storeSlug ??= storeSlugArg;

    return Scaffold(
      appBar: AppBar(
        title: Text(_t('تقييم المتجر', 'Rate store'),
            style: TextStyle(color: isDark ? Colors.white : Colors.black)),
        backgroundColor: isDark ? Colors.black : Colors.white,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: ValueListenableBuilder<int>(
                valueListenable: StoreRatingPage.headerRefresh,
                builder: (context, _, __) {
                  if (!hasLookupKey) {
                    return OverallRatingSection(
                      storeName: storeNameResolved,
                      ratingValue: 0.0,
                      ratingCount: 0,
                      ratingDistribution: _emptyRatingDistribution,
                    );
                  }
                  if (_overrideSummary != null && _overrideSummary!.count > 0) {
                    final s = _overrideSummary!;
                    return OverallRatingSection(
                      storeName: storeNameResolved,
                      ratingValue: s.avg,
                      ratingCount: s.count,
                      ratingDistribution: s.dist,
                    );
                  }
                  return FutureBuilder<StoreRatingsResult>(
                    future: StoreRatingsApi.fetchRatings(
                      storeId: _storeId ?? storeIdArg ?? 0,
                      storeSlug: _storeSlug ?? storeSlugArg,
                      page: 1,
                      perPage: 100,
                    ),
                    builder: (context, snap) {
                      switch (snap.connectionState) {
                        case ConnectionState.none:
                        case ConnectionState.waiting:
                        case ConnectionState.active:
                          return _buildOverallRatingLoadingCard(context);
                        case ConnectionState.done:
                          break;
                      }

                      if (snap.hasError) {
                        debugPrint(
                            'StoreRatingPage: failed to fetch ratings for store ${_storeId ?? storeIdArg} => ${snap.error}');
                        return _buildOverallRatingErrorFallback(
                          context,
                          storeName: storeNameResolved,
                        );
                      }

                      if (!snap.hasData) {
                        return OverallRatingSection(
                          storeName: storeNameResolved,
                          ratingValue: 0.0,
                          ratingCount: 0,
                          ratingDistribution: _emptyRatingDistribution,
                        );
                      }
                      final result = snap.data!;
                      _scheduleCanReviewUpdate(result.canReview);
                      _scheduleStoreIdUpdate(result.storeId);
                      final list = result.list;
                      final cached = StoreCommentsListState.cachedRatings(
                        storeId: _storeId ?? storeIdArg,
                        storeSlug: _storeSlug ?? storeSlugArg,
                      );
                      final effectiveList = list.isNotEmpty ? list : cached;

                      final summary = _summaryFrom(effectiveList);
                      final double ratingValue =
                          (result.averageRating > 0 || effectiveList.isEmpty)
                              ? result.averageRating
                              : summary.avg;
                      final int ratingCount = result.totalReviews > 0
                          ? result.totalReviews
                          : summary.count;
                      return OverallRatingSection(
                        storeName: storeNameResolved,
                        ratingValue: ratingValue,
                        ratingCount: ratingCount,
                        ratingDistribution: summary.dist,
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: CommentsListSection(
                onFilter: (value) {
                  StoreRatingPage.commentsKey.currentState?.reload(sort: value);
                },
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: !hasLookupKey
                  ? const Center(child: Text('لا يمكن جلب التعليقات بدون معرف المتجر.'))
                  : StoreCommentsList(
                      key: StoreRatingPage.commentsKey,
                      storeId: _storeId ?? storeIdArg,
                      storeSlug: _storeSlug ?? storeSlugArg,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      onCanReviewChanged: _updateCanReview,
                      onStoreIdResolved: _updateStoreId,
                      onRatingsUpdated: (list) {
                        final summary = _summaryFrom(list);
                        setState(() => _overrideSummary = summary);
                        StoreRatingPage.headerRefresh.value++;
                      },
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildAddRatingButton(
        context,
        storeId: _storeId ?? storeIdArg,
        storeName: storeNameResolved,
        canReview: _canReview,
        storeSlug: _storeSlug ?? storeSlugArg,
      ),
    );
  }

  Widget _buildOverallRatingLoadingCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))
        ],
      ),
      height: 110,
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  Widget _buildOverallRatingErrorFallback(
    BuildContext context, {
    required String storeName,
  }) {
    final theme = Theme.of(context);
    final messageStyle =
        (theme.textTheme.bodySmall ?? const TextStyle(fontSize: 12)).copyWith(
      color: theme.colorScheme.error,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OverallRatingSection(
          storeName: storeName,
          ratingValue: 0.0,
          ratingCount: 0,
          ratingDistribution: _emptyRatingDistribution,
        ),
        const SizedBox(height: 8),
        Text(
          _tr(context, 'تعذر تحميل التقييمات حالياً، جرب التحديث لاحقاً.',
              'Failed to load ratings, please try again.'),
          style: messageStyle,
          textAlign: TextAlign.start,
        ),
      ],
    );
  }
}

Widget _buildAddRatingButton(
  BuildContext context, {
  int? storeId,
  String? storeName,
  bool? canReview,
  String? storeSlug,
}) {
  final theme = Theme.of(context);
  final colors = context.color;
  final accent = colors.territoryColor;
  final bool isRtl = Directionality.of(context) == TextDirection.rtl;
  String _t(String ar, String en) => isRtl ? ar : en;

  Widget buildInfoMessage(String message, {IconData icon = Icons.info_outline}) {
    final double bgOpacity = theme.brightness == Brightness.dark ? 0.4 : 0.7;
    final bg = colors.secondaryColor.withValues(alpha: bgOpacity);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.borderColor.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: accent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.4,
                color: colors.textColorDark,
              ),
              textAlign: TextAlign.start,
            ),
          ),
        ],
      ),
    );
  }

  Widget wrapInfoMessage(Widget child) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: child,
      ),
    );
  }

  if (storeId == null || storeId <= 0) {
    final missing = _t('لا يمكن العثور على المتجر الحالي لإضافة تقييم.',
        'Cannot resolve the current store to add a rating.');
    return wrapInfoMessage(buildInfoMessage(missing));
  }

  final bool isAuthenticated = HiveUtils.isUserAuthenticated();

  if (!isAuthenticated && canReview == false) {
    final info = buildInfoMessage(
      _t('الرجاء تسجيل الدخول لإضافة تقييم.', 'Please log in to add a rating.'),
      icon: Icons.lock_outline,
    );
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            info,
            const SizedBox(height: 12),
            SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.login),
                label: Text(_t('تسجيل الدخول', 'Log in')),
                onPressed: () async {
                  await Navigator.pushNamed(
                    context,
                    Routes.login,
                    arguments: {'popToCurrent': true},
                  );
                  if (HiveUtils.isUserAuthenticated()) {
                    StoreRatingPage.commentsKey.currentState?.reload();
                    StoreRatingPage.headerRefresh.value++;
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  if (canReview == false) {
    return wrapInfoMessage(
      buildInfoMessage(
        _t('لقد قمت بتقييم هذا المتجر مسبقاً، شكراً لمساهمتك.',
            'You already rated this store, thank you.'),
        icon: Icons.info,
      ),
    );
  }

  final bool isLoading = canReview == null;
  final loadingText = _t('جاري التحميل...', 'Loading...');
  final actionText = _t('قيّم المتجر', 'Rate store');

  return SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: SizedBox(
        height: 50,
        width: double.infinity,
        child: ElevatedButton.icon(
          icon: Icon(isLoading ? Icons.hourglass_top : Icons.rate_review, size: 22),
          label: Text(
            isLoading ? loadingText : actionText,
            style: const TextStyle(fontSize: 16),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: colors.secondaryColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: isLoading
              ? null
              : () async {
                  final dynamic added = await showModalBottomSheet<dynamic>(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    backgroundColor: Theme.of(context).cardColor,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    builder: (ctx) => Padding(
                      padding: EdgeInsets.only(
                        bottom: MediaQuery.of(ctx).viewInsets.bottom,
                      ),
                      child: AddStoreRatingBottomSheet(
                        storeId: storeId,
                        storeSlug: storeSlug,
                        storeName: storeName,
                      ),
                    ),
                  );

                  if (added is Map) {
                    final stars = (added['stars'] as num?)?.toDouble();
                    final review = (added['review'] as String?)?.trim() ?? '';
                    if (stars != null) {
                      StoreRatingPage.commentsKey.currentState?.addLocalRating(
                        stars: stars,
                        review: review,
                      );
                      StoreRatingPage.headerRefresh.value++;
                    }
                  } else if (added == true) {
                    StoreRatingPage.commentsKey.currentState?.reload();
                    StoreRatingPage.headerRefresh.value++;
                  }
                },
        ),
      ),
    ),
  );
}

class OverallRatingSection extends StatelessWidget {
  final double ratingValue;
  final int ratingCount;
  final Map<int, int> ratingDistribution;
  final String storeName;

  const OverallRatingSection({
    super.key,
    required this.ratingValue,
    required this.ratingCount,
    required this.ratingDistribution,
    required this.storeName,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            style: DefaultTextStyle.of(context).style.copyWith(fontSize: 12),
            children: [
              TextSpan(
                  text: _tr(context, 'تقييمات المستخدمين لمتجر ',
                      'User ratings for store '),
                  style: const TextStyle(fontWeight: FontWeight.w500)),
              TextSpan(
                text: storeName,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.orange),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                  color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))
            ],
          ),
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(ratingValue.toStringAsFixed(2),
                      style: const TextStyle(
                          fontSize: 32, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(5, (index) {
                      return Icon(
                        Icons.star,
                        color: index < ratingValue.round()
                            ? const Color(0xFFF37A00)
                            : Colors.grey.shade300,
                        size: 20,
                      );
                    }),
                  ),
                  const SizedBox(height: 4),
                  Text('$ratingCount ${_tr(context, 'تقييم', 'ratings')}',
                      style:
                          const TextStyle(fontSize: 12, color: Colors.black54)),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(5, (index) {
                    final star = 5 - index;
                    final count = ratingDistribution[star] ?? 0;
                    final percent = ratingCount > 0 ? count / ratingCount : 0.0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          SizedBox(
                              width: 16,
                              child: Text(count.toString(),
                                  style: const TextStyle(fontSize: 12),
                                  textAlign: TextAlign.center)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: LinearProgressIndicator(
                              value: percent,
                              minHeight: 8,
                              backgroundColor: Colors.grey.shade300,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                  Color(0xFFF37A00)),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.star,
                              size: 14, color: Colors.black54),
                          Text(star.toString(),
                              style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Summary {
  _Summary({required this.avg, required this.count, required this.dist});
  final double avg;
  final int count;
  final Map<int, int> dist;
}

_Summary _summaryFrom(List<UserRatings> list) {
  if (list.isEmpty) {
    return _Summary(avg: 0.0, count: 0, dist: {1: 0, 2: 0, 3: 0, 4: 0, 5: 0});
  }
  final dist = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
  double sum = 0;
  for (final r in list) {
    final s = ((r.ratings ?? 0).round()).clamp(1, 5);
    dist[s] = (dist[s] ?? 0) + 1;
    sum += (r.ratings ?? 0);
  }
  final avg = sum / list.length;
  return _Summary(avg: avg, count: list.length, dist: dist);
}

class CommentsListSection extends StatelessWidget {
  final ValueChanged<String>? onFilter;

  const CommentsListSection({super.key, this.onFilter});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final color = isDark ? Colors.white : Colors.black;
    String _t(String ar, String en) => isRtl ? ar : en;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            _t('آراء العملاء', 'Reviews'),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        PopupMenuButton<String>(
          onSelected: (v) => onFilter?.call(v),
          itemBuilder: (ctx) => [
            PopupMenuItem(
                value: 'default', child: Text(_t('الافتراضي', 'Default'))),
            PopupMenuItem(
                value: 'recent', child: Text(_t('الأحدث', 'Recent'))),
            PopupMenuItem(
                value: 'top', child: Text(_t('الأعلى تقييماً', 'Top rated'))),
          ],
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.sort, size: 18, color: color.withValues(alpha: 0.8)),
              const SizedBox(width: 6),
              Text(_t('فرز', 'Sort'),
                  style: TextStyle(color: color.withValues(alpha: 0.9))),
            ],
          ),
        ),
      ],
    );
  }
}
