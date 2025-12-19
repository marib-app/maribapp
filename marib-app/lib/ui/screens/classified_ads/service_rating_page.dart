import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:marib/app/routes.dart';
import 'package:marib/data/model/seller_ratings_model.dart' show UserRatings;
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/hive_utils.dart';
import 'widgets/addrating.dart';
import 'widgets/comments.dart';
import 'widgets/service_ratings_api.dart';

String _tr(BuildContext context, String ar, String en) =>
    Directionality.of(context) == TextDirection.rtl ? ar : en;

const Map<int, int> _emptyRatingDistribution = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};

class ServiceRatingPage extends StatefulWidget {
  const ServiceRatingPage({super.key});

  /// ظ…ظپطھط§ط­ ظ‚ط§ط¦ظ…ط© ط§ظ„طھط¹ظ„ظٹظ‚ط§طھ ظ„ظ†ط¯ط§ط، reload()
  static final GlobalKey<ItemCommentsListState> commentsKey =
      GlobalKey<ItemCommentsListState>();

  /// ظ†ط§ط´ط± ط¨ط³ظٹط· ظ„ط¥ط¹ط§ط¯ط© ط¨ظ†ط§ط، ظƒط±طھ ط§ظ„طھظ‚ظٹظٹظ… ط§ظ„ط¹ط§ظ… ط¨ط¹ط¯ ط¥ط¶ط§ظپط© طھظ‚ظٹظٹظ…
  static final ValueNotifier<int> headerRefresh = ValueNotifier<int>(0);

  @override
  State<ServiceRatingPage> createState() => _ServiceRatingPageState();
}

class _ServiceRatingPageState extends State<ServiceRatingPage> {
  bool? _canReview;
  int? _serviceId;

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

  void _updateServiceId(int? value) {
    if (!mounted || value == null || value <= 0 || _serviceId == value) return;
    setState(() => _serviceId = value);
  }

  void _scheduleServiceIdUpdate(int? value) {
    if (value == null || value <= 0 || _serviceId == value) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _serviceId == value) return;
      setState(() => _serviceId = value);
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

    final int? serviceIdArg = parseId(args['serviceId'] ?? args['service_id']);
    final int? itemIdArg =
        parseId(args['itemId'] ?? args['item_id'] ?? args['id']);
    final int? effectiveServiceId = serviceIdArg ?? itemIdArg;

    final dynamic sellerIdRaw = args['sellerId'];
    final int? sellerIdArg =
        sellerIdRaw is String ? int.tryParse(sellerIdRaw) : sellerIdRaw as int?;
    final String serviceTitleResolved =
        (args['serviceTitle'] as String?)?.trim() ??
            _t('بدون عنوان', 'Untitled service');

    final dynamic serviceUidRaw = args['serviceUid'] ?? args['service_uid'];
    final String? serviceUidArg = serviceUidRaw is String
        ? (serviceUidRaw.trim().isNotEmpty ? serviceUidRaw.trim() : null)
        : null;

    final bool hasLookupKey =
        (effectiveServiceId != null && effectiveServiceId > 0) ||
            (serviceUidArg != null && serviceUidArg.isNotEmpty);

    _scheduleServiceIdUpdate(effectiveServiceId);

    return Scaffold(
      appBar: AppBar(
        title: Text(_t('تقييم الخدمة', 'Rate service'),
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
                valueListenable: ServiceRatingPage.headerRefresh,
                builder: (context, _, __) {
                  if (!hasLookupKey) {
                    return OverallRatingSection(
                      serviceTitle: serviceTitleResolved,
                      ratingValue: 0.0,
                      ratingCount: 0,
                      ratingDistribution: _emptyRatingDistribution,
                    );
                  }
                  return FutureBuilder<ServiceRatingsResult>(
                    future: ServiceRatingsApi.fetchRatings(
                      serviceId: _serviceId ?? effectiveServiceId,
                      page: 1,
                      perPage: 100,
                      serviceUid: serviceUidArg,
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
                            'ServiceRatingPage: failed to fetch ratings for service ${_serviceId ?? effectiveServiceId} => ${snap.error}');
                        return _buildOverallRatingErrorFallback(
                          context,
                          serviceTitle: serviceTitleResolved,
                        );
                      }

                      if (!snap.hasData) {
                        return OverallRatingSection(
                          serviceTitle: serviceTitleResolved,
                          ratingValue: 0.0,
                          ratingCount: 0,
                          ratingDistribution: _emptyRatingDistribution,
                        );
                      }
                      final result = snap.data!;
                      _scheduleCanReviewUpdate(result.canReview);
                      _scheduleServiceIdUpdate(result.serviceId);
                      final list = result.list;
                      final cached = ItemCommentsListState.cachedRatings(
                        serviceId: _serviceId ?? effectiveServiceId,
                        serviceUid: serviceUidArg,
                      );
                      final effectiveList =
                          list.isNotEmpty ? list : cached;

                      final summary = _summaryFrom(effectiveList);
                      final double ratingValue =
                          (result.averageRating > 0 || effectiveList.isEmpty)
                              ? result.averageRating
                              : summary.avg;
                      final int ratingCount =
                          result.totalReviews >= summary.count && summary.count > 0
                              ? result.totalReviews
                              : summary.count;
                      return OverallRatingSection(
                        serviceTitle: serviceTitleResolved,
                        ratingValue: ratingValue,
                        ratingCount: ratingCount,
                        ratingDistribution: summary.dist,
                      );
                    },
                  );
                },
              ),
            ),

            // âœ… ط§ظ„ط¹ظ†ظˆط§ظ† "ط¢ط±ط§ط، ط§ظ„ط¹ظ…ظ„ط§ط،" â€” ط«ط§ط¨طھ ظ…ط¹ ظپظ„طھط±ط© (ط­ط§ظ„ظٹظ‹ط§ ظ†ط¹ظ…ظ„ reload ظپظ‚ط·)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: CommentsListSection(
                onFilter: (value) {
                  ServiceRatingPage.commentsKey.currentState?.reload();
                },
              ),
            ),

            const SizedBox(height: 8),

            // âœ… ظ‚ط§ط¦ظ…ط© ط§ظ„طھط¹ظ„ظٹظ‚ط§طھ â€” ظ…ط±ط¨ظˆط·ط© ط¨ط§ظ„ط³ظٹط±ظپط±
            Expanded(
              child: !hasLookupKey
                  ? const Center(
                      child: Text('لا يمكن جلب التعليقات بدون معرف الخدمة.'))
                  : ItemCommentsList(
                      key: ServiceRatingPage.commentsKey,
                      serviceId: _serviceId ?? effectiveServiceId,
                      serviceUid: serviceUidArg,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      onCanReviewChanged: _updateCanReview,
                      onServiceIdResolved: _updateServiceId,
                      onRatingsUpdated: (_) {
                        ServiceRatingPage.headerRefresh.value++;
                      },
                    ),
            ),
          ],
        ),
      ),

      // âœ… ط²ط± ط¥ط¶ط§ظپط© طھظ‚ظٹظٹظ… â€” ظ†ظپط³ ط§ظ„ط´ظƒظ„. ط¨ط¹ط¯ ط§ظ„ط¥ط±ط³ط§ظ„: ظ†ط¹ظٹط¯ طھط­ظ…ظٹظ„ ط§ظ„طھط¹ظ„ظٹظ‚ط§طھ ظˆط§ظ„ط±ط£ط³.
      bottomNavigationBar: _buildAddRatingButton(
        context,
        serviceId: _serviceId ?? effectiveServiceId,
        serviceTitle: serviceTitleResolved,
        canReview: _canReview,
        sellerId: sellerIdArg,
        serviceUid: serviceUidArg,
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
    required String serviceTitle,
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
          serviceTitle: serviceTitle,
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

// ط²ط± ط«ط§ط¨طھ ط£ط³ظپظ„ ط§ظ„ط´ط§ط´ط© ظ„ط¥ط¶ط§ظپط© طھظ‚ظٹظٹظ… ط¬ط¯ظٹط¯ (ظ†ظپط³ طھطµظ…ظٹظ…ظƒ)
Widget _buildAddRatingButton(
  BuildContext context, {
  int? serviceId,
  String? serviceTitle,
  int? sellerId,
  bool? canReview,
  String? serviceUid,
}) {
  final theme = Theme.of(context);
  final colors = context.color;
  final accent = colors.territoryColor;
  final bool isRtl = Directionality.of(context) == TextDirection.rtl;
  String _t(String ar, String en) => isRtl ? ar : en;

  Widget buildInfoMessage(String message, {IconData icon = Icons.info_outline}) {
    final bg = colors.secondaryColor.withOpacity(
      theme.brightness == Brightness.dark ? 0.4 : 0.7,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.borderColor.withOpacity(0.35)),
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

  if (serviceId == null || serviceId <= 0) {
    final missing = _t(
        'لا يمكن العثور على الخدمة الحالية لإضافة تقييم.',
        'Cannot resolve the current service to add a rating.');
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
                    ServiceRatingPage.commentsKey.currentState?.reload();
                    ServiceRatingPage.headerRefresh.value++;
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
        _t('لقد قمت بتقييم هذه الخدمة مسبقاً، شكراً لمساهمتك.',
            'You already rated this service, thank you.'),
        icon: Icons.info,
      ),
    );
  }

  final bool isLoading = canReview == null;
  final loadingText = _t('جاري التحميل...', 'Loading...');
  final actionText = _t('قيّم الخدمة', 'Rate service');

  return SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: SizedBox(
        height: 50,
        width: double.infinity,
        child: ElevatedButton.icon(
          icon: Icon(isLoading ? Icons.hourglass_top : Icons.rate_review,
              size: 22),
          label: Text(
            isLoading ? loadingText : actionText,
            style: const TextStyle(fontSize: 16),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: colors.secondaryColor,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: isLoading
              ? null
              : () async {
                  final dynamic added =
                      await showModalBottomSheet<dynamic>(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    backgroundColor: Theme.of(context).cardColor,
                    shape: const RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    builder: (ctx) => Padding(
                      padding: EdgeInsets.only(
                        bottom: MediaQuery.of(ctx).viewInsets.bottom,
                      ),
                      child: AddRatingBottomSheet(
                        serviceId: serviceId,
                        serviceTitle: serviceTitle,
                        sellerId: sellerId,
                        serviceUid: serviceUid,
                      ),
                    ),
                  );

                  if (added is Map) {
                    final stars = (added['stars'] as num?)?.toDouble();
                    final review = (added['review'] as String?)?.trim() ?? '';
                    if (stars != null) {
                      ServiceRatingPage.commentsKey.currentState
                          ?.addLocalRating(
                        stars: stars,
                        review: review,
                      );
                      ServiceRatingPage.headerRefresh.value++;
                    }
                    // اترك التعليق المحلي ظاهر بدون إعادة تحميل فورية
                    // (يمكن للمستخدم السحب للتحديث لاحقاً)
                  } else if (added == true) {
                    ServiceRatingPage.commentsKey.currentState?.reload();
                    ServiceRatingPage.headerRefresh.value++;
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
  final String serviceTitle;

  const OverallRatingSection({
    super.key,
    required this.ratingValue,
    required this.ratingCount,
    required this.ratingDistribution,
    required this.serviceTitle,
  });

  @override
  Widget build(BuildContext context) {
    final args =
        (ModalRoute.of(context)?.settings.arguments ?? const {}) as Map;
    final serviceTitleArg =
        (args['serviceTitle'] as String?)?.trim() ??
            _tr(context, 'بدون عنوان', 'Untitled service');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            style: DefaultTextStyle.of(context).style.copyWith(fontSize: 12),
            children: [
              TextSpan(
                  text: _tr(context, 'تقييمات المستخدمين لخدمة ',
                      'User ratings for service '),
                  style: const TextStyle(fontWeight: FontWeight.w500)),
              TextSpan(
                text: serviceTitle,
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

// ط­ط³ط§ط¨ ط§ظ„ظ…طھظˆط³ط· ظˆط§ظ„طھظˆط²ظٹط¹ ظ…ظ† ظ‚ط§ط¦ظ…ط© UserRatings (ط¨ط¯ظˆظ† ط£ظٹ طھط؛ظٹظٹط± ظپظٹ ظˆط§ط¬ظ‡طھظƒ)
({double avg, int count, Map<int, int> dist}) _summaryFrom(
    List<UserRatings> list) {
  if (list.isEmpty)
    return (avg: 0.0, count: 0, dist: {1: 0, 2: 0, 3: 0, 4: 0, 5: 0});
  final dist = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
  double sum = 0;
  for (final r in list) {
    final s = ((r.ratings ?? 0).round()).clamp(1, 5);
    dist[s] = (dist[s] ?? 0) + 1;
    sum += (r.ratings ?? 0);
  }
  final avg = sum / list.length;
  return (avg: avg, count: list.length, dist: dist);
}

// ظ†ظپط³ ظˆظٹط¬طھ ط§ظ„ط¹ظ†ظˆط§ظ† ظˆط§ظ„ظپظ„طھط±ط© ط§ظ„طھظٹ ط¹ظ†ط¯ظƒ
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
              Icon(Icons.sort, size: 18, color: color.withOpacity(0.8)),
              const SizedBox(width: 6),
              Text(_t('فرز', 'Sort'),
                  style: TextStyle(color: color.withOpacity(0.9))),
            ],
          ),
        ),
      ],
    );
  }
}
