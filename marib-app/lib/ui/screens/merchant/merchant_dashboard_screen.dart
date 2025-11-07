import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:marib/app/navigation/app_page_route.dart';
import 'package:marib/app/navigation/motion/route_motion.dart';
import 'package:marib/data/cubits/merchant/merchant_dashboard_cubit.dart';
import 'package:marib/data/model/merchant/merchant_dashboard_summary.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/ui_utils.dart';

class MerchantDashboardScreen extends StatelessWidget {
  const MerchantDashboardScreen({super.key});

  static Route route(RouteSettings settings) {
    return AppPageRoute.build(
      settings: settings,
      motionPattern: AppMotionPattern.glide,
      builder: (_) => BlocProvider(
        create: (_) => MerchantDashboardCubit()..load(),
        child: const MerchantDashboardScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: UiUtils.buildAppBar(
        context,
        title: 'لوحة المتجر',
        showBackButton: true,
      ),
      body: BlocBuilder<MerchantDashboardCubit, MerchantDashboardState>(
        builder: (context, state) {
          if (state is MerchantDashboardLoading ||
              state is MerchantDashboardInitial) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is MerchantDashboardFailure) {
            return _ErrorView(
              error: state.error,
              onRetry: () => context.read<MerchantDashboardCubit>().load(),
            );
          }

          final summary = (state as MerchantDashboardSuccess).summary;
          return RefreshIndicator(
            color: context.color.territoryColor,
            onRefresh: () => context.read<MerchantDashboardCubit>().refresh(),
            child: _MerchantDashboardBody(summary: summary),
          );
        },
      ),
    );
  }
}

class _MerchantDashboardBody extends StatelessWidget {
  const _MerchantDashboardBody({required this.summary});

  final MerchantDashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[
      _MetricsGrid(summary: summary),
      const SizedBox(height: 16),
      _StatusCard(status: summary.status),
      const SizedBox(height: 16),
      _WorkingHoursCard(hours: summary.workingHours),
      const SizedBox(height: 16),
      if (summary.policies.isNotEmpty)
        _PoliciesCard(policies: summary.policies),
      if (summary.policies.isNotEmpty) const SizedBox(height: 16),
      _StaffCard(staff: summary.staff),
    ];

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      physics: const AlwaysScrollableScrollPhysics(),
      itemBuilder: (_, index) => cards[index],
      separatorBuilder: (_, __) => const SizedBox.shrink(),
      itemCount: cards.length,
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({required this.summary});

  final MerchantDashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final cards = <_MetricCardData>[
      _MetricCardData(
        title: 'اليوم',
        snapshot: summary.overview.today,
        color: context.color.territoryColor.withOpacity(0.14),
      ),
      _MetricCardData(
        title: 'آخر 7 أيام',
        snapshot: summary.overview.week,
        color: Colors.indigo.withOpacity(0.1),
      ),
      _MetricCardData(
        title: 'آخر 30 يوماً',
        snapshot: summary.overview.month,
        color: Colors.teal.withOpacity(0.1),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'أداء المتجر',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 680;
            final crossAxisCount = isWide ? 3 : 1;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: isWide ? 1.4 : 1.2,
              ),
              itemCount: cards.length,
              itemBuilder: (_, index) => _MetricCard(data: cards[index]),
            );
          },
        ),
      ],
    );
  }
}

class _MetricCardData {
  const _MetricCardData({
    required this.title,
    required this.snapshot,
    required this.color,
  });

  final String title;
  final MerchantMetricSnapshot snapshot;
  final Color color;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.data});

  final _MetricCardData data;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: data.color,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              data.title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _MetricValue(label: 'الطلبات', value: data.snapshot.orders),
                _MetricValue(
                    label: 'الإيراد',
                    valueText: NumberFormat.currency(symbol: 'ر.ي')
                        .format(data.snapshot.revenue)),
                _MetricValue(label: 'الزيارات', value: data.snapshot.visits),
                _MetricValue(
                    label: 'مشاهدات المنتجات',
                    value: data.snapshot.productViews),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricValue extends StatelessWidget {
  const _MetricValue({
    required this.label,
    this.value,
    this.valueText,
  }) : assert(valueText != null || value != null);

  final String label;
  final int? value;
  final String? valueText;

  @override
  Widget build(BuildContext context) {
    final displayValue = valueText ?? NumberFormat.compact().format(value ?? 0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          displayValue,
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.status});

  final MerchantStoreStatus status;

  @override
  Widget build(BuildContext context) {
    final bool browseOnly = status.closureMode == 'browse_only';
    final bool isClosed = status.isManuallyClosed || !status.isOpenNow;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.circle,
                  size: 12,
                  color: status.isOpenNow ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  status.isOpenNow ? 'المتجر مفتوح' : 'المتجر مغلق حالياً',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            if (!status.isOpenNow && status.nextOpenAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  'يفتح في: ${status.nextOpenAt}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            const Divider(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _StatusBadge(
                  label: 'حالة النظام',
                  value: browseOnly ? 'تصفح فقط' : 'كامل',
                ),
                _StatusBadge(
                  label: 'حد الطلب',
                  value: status.minOrderAmount != null
                      ? NumberFormat.currency(symbol: 'ر.ي')
                          .format(status.minOrderAmount)
                      : 'غير محدد',
                ),
                _StatusBadge(
                  label: 'التوصيل',
                  value: status.allowDelivery ? 'مفعل' : 'موقوف',
                ),
                _StatusBadge(
                  label: 'الاستلام',
                  value: status.allowPickup ? 'مفعل' : 'موقوف',
                ),
                _StatusBadge(
                  label: 'حوالات يدوية',
                  value: status.allowManualPayments ? 'مسموح' : 'موقوف',
                ),
                _StatusBadge(
                  label: 'الدفع بالمحفظة',
                  value: status.allowWallet ? 'مسموح' : 'موقوف',
                ),
                _StatusBadge(
                  label: 'الدفع عند الاستلام',
                  value: status.allowCod ? 'مسموح' : 'موقوف',
                ),
              ],
            ),
            if (isClosed && status.closureReason != null) ...[
              const SizedBox(height: 12),
              Text(
                'سبب الإغلاق: ${status.closureReason}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: context.color.secondaryColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}

class _WorkingHoursCard extends StatelessWidget {
  const _WorkingHoursCard({required this.hours});

  final List<MerchantWorkingHour> hours;

  static const List<String> weekdayLabels = <String>[
    'الأحد',
    'الإثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
    'السبت',
  ];

  @override
  Widget build(BuildContext context) {
    final sortedHours = hours.toList()
      ..sort((a, b) => a.weekday.compareTo(b.weekday));

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ساعات العمل',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            ...sortedHours.map((hour) {
              final label = weekdayLabels[hour.weekday.clamp(0, 6)];
              String range = 'مغلق';
              if (hour.isOpen &&
                  hour.opensAt != null &&
                  hour.closesAt != null) {
                range = '${hour.opensAt} - ${hour.closesAt}';
              }
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(label),
                    Text(
                      range,
                      style: TextStyle(
                        color: hour.isOpen
                            ? context.color.territoryColor
                            : Colors.grey,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _PoliciesCard extends StatelessWidget {
  const _PoliciesCard({required this.policies});

  final List<MerchantPolicy> policies;

  @override
  Widget build(BuildContext context) {
    final entries = policies
        .map((policy) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(policy.title ?? policy.type),
              subtitle: Text(policy.content),
            ))
        .toList();

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'السياسات',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            ...entries,
          ],
        ),
      ),
    );
  }
}

class _StaffCard extends StatelessWidget {
  const _StaffCard({required this.staff});

  final MerchantStaffInfo? staff;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'بريد لوحة المتجر',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (staff == null)
              Text(
                'لم يتم حجز بريد بعد. يمكنك إنشاؤه من إعدادات المتجر.',
                style: Theme.of(context).textTheme.bodySmall,
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    staff!.email,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'الحالة: ${staff!.status}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            const SizedBox(height: 8),
            Text(
              'استخدم هذا البريد لتسجيل الدخول إلى لوحة التحكم المخصصة للمتجر ومتابعة الطلبات.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});

  final dynamic error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 42, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(
              'تعذر تحميل بيانات المتجر',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              error?.toString() ?? '',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }
}
