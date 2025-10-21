import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:marib/data/model/seller_ratings_model.dart' show UserRatings;
import 'widgets/comments.dart';
import 'widgets/addrating.dart';

// ✅ أضفنا ربط بيانات التقييم العام من السيرفر
import 'widgets/service_ratings_api.dart';
import 'package:marib/app/routes.dart';
import 'package:marib/data/model/seller_ratings_model.dart' show UserRatings;
import 'package:marib/utils/hive_utils.dart';

const Map<int, int> _emptyRatingDistribution = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};

class ServiceRatingPage extends StatefulWidget {
  const ServiceRatingPage({super.key});

  /// مفتاح قائمة التعليقات لنداء reload()
  static final GlobalKey<ItemCommentsListState> commentsKey =
      GlobalKey<ItemCommentsListState>();

  /// ناشر بسيط لإعادة بناء كرت التقييم العام بعد إضافة تقييم
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

    // 🟢 القيم القادمة عبر Route
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
        (args['serviceTitle'] as String?)?.trim() ?? 'بدون عنوان';

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
        title: Text('تقييم الخدمة',
            style: TextStyle(color: isDark ? Colors.white : Colors.black)),
        backgroundColor: isDark ? Colors.black : Colors.white,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
        elevation: 0,
      ),

      /// ✅ محتوى الصفحة
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// ✅ كرت التقييم العام — نفس الشكل، لكن القيم من السيرفر
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

                      final summary = _summaryFrom(list);
                      final double ratingValue =
                          (result.averageRating > 0 || list.isEmpty)
                              ? result.averageRating
                              : summary.avg;
                      final int ratingCount =
                          result.totalReviews >= summary.count
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

            // ✅ العنوان "آراء العملاء" — ثابت مع فلترة (حاليًا نعمل reload فقط)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: CommentsListSection(
                onFilter: (value) {
                  // لو رغبت تفعيل الفرز فعليًا، مرر value إلى reload(sort: value)
                  ServiceRatingPage.commentsKey.currentState?.reload();
                },
              ),
            ),

            const SizedBox(height: 8),

            // ✅ قائمة التعليقات — مربوطة بالسيرفر
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
                    ),
            ),
          ],
        ),
      ),

      // ✅ زر إضافة تقييم — نفس الشكل. بعد الإرسال: نعيد تحميل التعليقات والرأس.
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
          'تعذّر تحميل التقييمات حالياً، جرّب التحديث لاحقاً.',
          style: messageStyle,
          textAlign: TextAlign.start,
        ),
      ],
    );
  }
}

// زر ثابت أسفل الشاشة لإضافة تقييم جديد (نفس تصميمك)
Widget _buildAddRatingButton(
  BuildContext context, {
  int? serviceId,
  String? serviceTitle,
  int? sellerId,
  bool? canReview,
  String? serviceUid,
}) {
  final theme = Theme.of(context);

  Widget buildInfoMessage(String message,
      {IconData icon = Icons.info_outline}) {
    final colorScheme = theme.colorScheme;
    final bg = colorScheme.surfaceVariant.withOpacity(
      theme.brightness == Brightness.dark ? 0.35 : 1,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withOpacity(0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
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
    if (serviceUid != null && serviceUid.isNotEmpty) {
      return wrapInfoMessage(
        buildInfoMessage('جاري التحقق من الخدمة قبل السماح بإضافة تقييم...'),
      );
    }

    return wrapInfoMessage(
      buildInfoMessage('تعذّر تحديد الخدمة لإضافة تقييم.'),
    );
  }

  final bool isAuthenticated = HiveUtils.isUserAuthenticated();

  if (!isAuthenticated && canReview == false) {
    final info = buildInfoMessage(
      'سجّل دخولك لإضافة تقييم جديد.',
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
                label: const Text('سجّل دخولك'),
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
        'لا يمكنك إضافة تقييم حالياً. ربما أرسلت تقييماً سابقاً أو لا تملك صلاحية لذلك.',
        icon: Icons.info,
      ),
    );
  }

  final bool isLoading = canReview == null;

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
            isLoading ? 'جاري التحقق...' : 'إضافة تقييم',
            style: const TextStyle(fontSize: 16),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF37A00),
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: isLoading
              ? null
              : () async {
                  final added = await showModalBottomSheet<bool>(
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

                  if (added == true) {
                    // 1) حدّث قائمة التعليقات
                    ServiceRatingPage.commentsKey.currentState?.reload();
                    // 2) وأعد بناء كرت الرأس
                    ServiceRatingPage.headerRefresh.value++;
                  }
                },
        ),
      ),
    ),
  );
}

// عنوان الخدمة (نفس واجهتك تمامًا)
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
        (args['serviceTitle'] as String?)?.trim() ?? 'بدون عنوان';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            style: DefaultTextStyle.of(context).style.copyWith(fontSize: 12),
            children: [
              const TextSpan(
                  text: 'تقييمات المستخدمين لخدمة        ',
                  style: TextStyle(fontWeight: FontWeight.w500)),
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
                  Text('$ratingCount التقييمات',
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

// حساب المتوسط والتوزيع من قائمة UserRatings (بدون أي تغيير في واجهتك)
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

// نفس ويجت العنوان والفلترة التي عندك
class CommentsListSection extends StatelessWidget {
  final ValueChanged<String>? onFilter;

  const CommentsListSection({super.key, this.onFilter});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? Colors.white : Colors.black;

    return Row(
      children: [
        Text(
          'آراء العملاء',
          style: TextStyle(
              color: color, fontWeight: FontWeight.w700, fontSize: 16),
        ),
        const Spacer(),
        PopupMenuButton<String>(
          onSelected: (v) => onFilter?.call(v),
          itemBuilder: (ctx) => const [
            PopupMenuItem(value: 'default', child: Text('الافتراضي')),
            PopupMenuItem(value: 'recent', child: Text('الأحدث')),
            PopupMenuItem(value: 'top', child: Text('الأعلى تقييماً')),
          ],
          child: Row(
            children: [
              Icon(Icons.sort, size: 18, color: color.withOpacity(0.8)),
              const SizedBox(width: 6),
              Text('ترتيب', style: TextStyle(color: color.withOpacity(0.9))),
            ],
          ),
        ),
      ],
    );
  }
}
