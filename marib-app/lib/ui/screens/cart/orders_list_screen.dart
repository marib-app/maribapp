import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:marib/app/routes.dart';
import 'package:marib/data/model/orders/user_order.dart';
import 'package:marib/data/repositories/orders/orders_repository.dart';
import 'package:marib/utils/api.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:shimmer/shimmer.dart';

class OrdersListScreen extends StatefulWidget {
  const OrdersListScreen({super.key});

  static Route route(RouteSettings settings) {
    return MaterialPageRoute(
      settings: settings,
      builder: (_) => const OrdersListScreen(),
    );
  }

  @override
  State<OrdersListScreen> createState() => _OrdersListScreenState();
}

class _OrdersListScreenState extends State<OrdersListScreen> {
  final OrdersRepository _ordersRepository = const OrdersRepository();
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd HH:mm');

  bool _loading = true;
  String? _errorMessage;
  List<UserOrder> _orders = const <UserOrder>[];

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final List<UserOrder> orders = await _ordersRepository.fetchOrders();
      if (!mounted) return;
      setState(() {
        _orders = orders;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.errorMessage?.toString() ?? 'تعذر تحميل الطلبات.';
        _orders = const <UserOrder>[];
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString();
        _orders = const <UserOrder>[];
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _refresh() => _fetchOrders();

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion(
      value: UiUtils.getSystemUiOverlayStyle(
        context: context,
        statusBarColor: context.color.secondaryColor,
      ),
      child: Scaffold(
        appBar: UiUtils.buildAppBar(
          context,
          title: 'طلباتي',
          bottomHeight: 20,
          showBackButton: true,
        ),
        backgroundColor: context.color.primaryColor,
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _orders.isEmpty) {
      return _buildLoadingSkeleton();
    }

    if (_errorMessage != null && _orders.isEmpty) {
      return _buildErrorState();
    }

    if (_orders.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        itemCount: _orders.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (BuildContext context, int index) {
          final UserOrder order = _orders[index];
          return _OrderCard(
            order: order,
            dateFormat: _dateFormat,
          );
        },
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _errorMessage ?? 'تعذر تحميل الطلبات.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchOrders,
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.inbox_outlined, size: 64),
            SizedBox(height: 12),
            Text(
              'لا توجد طلبات متاحة حالياً.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color baseColor =
    isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06);
    final Color highlightColor =
    isDark ? Colors.white.withOpacity(0.16) : Colors.black.withOpacity(0.12);

    return RefreshIndicator(
      onRefresh: _refresh,
      child: Shimmer.fromColors(
        baseColor: baseColor,
        highlightColor: highlightColor,
        period: const Duration(milliseconds: 1200),
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          itemCount: 3,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, __) => const _OrderCardSkeleton(),
        ),
      ),
    );
  }

}






class _StatusVisual {
  const _StatusVisual({
    required this.label,
    required this.backgroundColor,
    required this.textColor,
  });

  final String label;
  final Color backgroundColor;
  final Color textColor;
}

String _normalizeStatusKey(String value) => value
    .trim()
    .toLowerCase()
    .replaceAll(RegExp(r'[_\-]+'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ');

const _StatusVisual _reviewVisual = _StatusVisual(
  label: 'قيد المراجعة',
  backgroundColor: Color(0xFFE8F0FE),
  textColor: Color(0xFF1A73E8),
);

const Map<String, _StatusVisual> _statusVisualDefinitions =
<String, _StatusVisual>{
  'قيد المراجعة': _reviewVisual,
  'قيد المعالجة': _StatusVisual(
    label: 'قيد المعالجة',
    backgroundColor: Color(0xFFFFF4E5),
    textColor: Color(0xFFB25B00),
  ),
  'قيد الدفع': _StatusVisual(
    label: 'قيد الدفع',
    backgroundColor: Color(0xFFFFF8E1),
    textColor: Color(0xFF8D6E00),
  ),
  'بانتظار الدفع': _StatusVisual(
    label: 'بانتظار الدفع',
    backgroundColor: Color(0xFFFFF8E1),
    textColor: Color(0xFF8D6E00),
  ),
  'قيد الشحن': _StatusVisual(
    label: 'قيد الشحن',
    backgroundColor: Color(0xFFE3F2FD),
    textColor: Color(0xFF1565C0),
  ),
  'في الطريق': _StatusVisual(
    label: 'في الطريق',
    backgroundColor: Color(0xFFE0F7FA),
    textColor: Color(0xFF006064),
  ),
  'جاهز للتسليم': _StatusVisual(
    label: 'جاهز للتسليم',
    backgroundColor: Color(0xFFE0F2F1),
    textColor: Color(0xFF00796B),
  ),
  'جاهز للاستلام': _StatusVisual(
    label: 'جاهز للاستلام',
    backgroundColor: Color(0xFFE0F2F1),
    textColor: Color(0xFF00796B),
  ),
  'تم التوصيل': _StatusVisual(
    label: 'تم التوصيل',
    backgroundColor: Color(0xFFE8F5E9),
    textColor: Color(0xFF2E7D32),
  ),
  'مكتمل': _StatusVisual(
    label: 'مكتمل',
    backgroundColor: Color(0xFFE8F5E9),
    textColor: Color(0xFF2E7D32),
  ),
  'تم الإرجاع': _StatusVisual(
    label: 'تم الإرجاع',
    backgroundColor: Color(0xFFF3E5F5),
    textColor: Color(0xFF6A1B9A),
  ),
  'ملغى': _StatusVisual(
    label: 'ملغى',
    backgroundColor: Color(0xFFFFEBEE),
    textColor: Color(0xFFC62828),
  ),
  'مرفوض': _StatusVisual(
    label: 'مرفوض',
    backgroundColor: Color(0xFFFFEBEE),
    textColor: Color(0xFFC62828),
  ),
};

const Map<String, String> _statusLabelOverridesDefinitions =
<String, String>{
  'processing': 'قيد المعالجة',
  'processing order': 'قيد المعالجة',
  'in progress': 'قيد المعالجة',
  'in processing': 'قيد المعالجة',
  'preparing': 'قيد المعالجة',
  'preparation': 'قيد المعالجة',
  'awaiting fulfillment': 'قيد المعالجة',
  'processing payment': 'قيد المعالجة',
  'pending payment': 'قيد الدفع',
  'payment pending': 'قيد الدفع',
  'awaiting payment': 'قيد الدفع',
  'waiting for payment': 'قيد الدفع',
  'pending': 'قيد المراجعة',
  'pending approval': 'قيد المراجعة',
  'pending review': 'قيد المراجعة',
  'pending confirmation': 'قيد المراجعة',
  'awaiting confirmation': 'قيد المراجعة',
  'awaiting approval': 'قيد المراجعة',
  'awaiting review': 'قيد المراجعة',
  'on hold': 'قيد المراجعة',
  'hold': 'قيد المراجعة',
  'review': 'قيد المراجعة',
  'draft': 'قيد المراجعة',
  'scheduled': 'قيد المراجعة',
  'ready': 'جاهز للتسليم',
  'ready for delivery': 'جاهز للتسليم',
  'ready to deliver': 'جاهز للتسليم',
  'ready for pickup': 'جاهز للاستلام',
  'ready to pickup': 'جاهز للاستلام',
  'ready to ship': 'قيد الشحن',
  'awaiting shipment': 'قيد الشحن',
  'pending shipment': 'قيد الشحن',
  'waiting shipment': 'قيد الشحن',
  'shipping': 'قيد الشحن',
  'shipped': 'قيد الشحن',
  'in transit': 'في الطريق',
  'out for delivery': 'في الطريق',
  'on the way': 'في الطريق',
  'pending delivery': 'في الطريق',
  'delivered': 'تم التوصيل',
  'completed': 'تم التوصيل',
  'fulfilled': 'تم التوصيل',
  'done': 'تم التوصيل',
  'success': 'تم التوصيل',
  'returned': 'تم الإرجاع',
  'return': 'تم الإرجاع',
  'refunded': 'تم الإرجاع',
  'refund': 'تم الإرجاع',
  'partial refund': 'تم الإرجاع',
  'cancelled': 'ملغى',
  'canceled': 'ملغى',
  'declined': 'ملغى',
  'failed': 'ملغى',
  'rejected': 'مرفوض',
};

final Map<String, _StatusVisual> _statusVisualLookup =
Map<String, _StatusVisual>.unmodifiable(
  _statusVisualDefinitions.map(
        (String key, _StatusVisual value) =>
        MapEntry(_normalizeStatusKey(key), value),
  ),
);

final Map<String, String> _statusLabelOverrides =
Map<String, String>.unmodifiable(
  _statusLabelOverridesDefinitions.map(
        (String key, String value) =>
        MapEntry(_normalizeStatusKey(key), value),
  ),
);

_StatusVisual? _findStatusVisual(String normalizedLabel) {
  final _StatusVisual? direct = _statusVisualLookup[normalizedLabel];
  if (direct != null) {
    return direct;
  }
  for (final MapEntry<String, _StatusVisual> entry
  in _statusVisualLookup.entries) {
    if (normalizedLabel.contains(entry.key)) {
      return entry.value;
    }
  }
  return null;
}

String? _resolveArabicStatusLabel(String normalizedStatus) {
  final String? direct = _statusLabelOverrides[normalizedStatus];
  if (direct != null) {
    return direct;
  }
  for (final MapEntry<String, String> entry in _statusLabelOverrides.entries) {
    if (normalizedStatus.contains(entry.key)) {
      return entry.value;
    }
  }
  return null;
}

_StatusVisual _statusColors(String? rawStatus) {
  final String sanitized = rawStatus?.trim() ?? '';
  if (sanitized.isEmpty) {
    return _reviewVisual;
  }

  final String normalized = _normalizeStatusKey(sanitized);
  final String? resolvedArabic = _resolveArabicStatusLabel(normalized);
  final String resolvedLabel = resolvedArabic ?? sanitized;
  final String normalizedResolved = _normalizeStatusKey(resolvedLabel);

  final _StatusVisual? resolvedMatch = _findStatusVisual(normalizedResolved);
  if (resolvedMatch != null) {
    final _StatusVisual visual = resolvedMatch;
    if (resolvedArabic != null && visual.label != resolvedArabic) {
      return _StatusVisual(
        label: resolvedArabic,
        backgroundColor: visual.backgroundColor,
        textColor: visual.textColor,
      );
    }
    return visual;
  }

  final _StatusVisual? fallbackMatch = _findStatusVisual(normalized);
  if (fallbackMatch != null) {
    final _StatusVisual visual = fallbackMatch;
    if (resolvedArabic != null && visual.label != resolvedArabic) {
      return _StatusVisual(
        label: resolvedArabic,
        backgroundColor: visual.backgroundColor,
        textColor: visual.textColor,
      );
    }
    return visual;
  }

  final _StatusVisual baseVisual = resolvedArabic != null
      ? (_findStatusVisual(_normalizeStatusKey(resolvedArabic)) ??
      _reviewVisual)
      : _reviewVisual;

  return _StatusVisual(
    label: resolvedLabel,
    backgroundColor: baseVisual.backgroundColor,
    textColor: baseVisual.textColor,
  );
}







class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.dateFormat,
  });

  final UserOrder order;
  final DateFormat dateFormat;

  @override
  Widget build(BuildContext context) {
    final String dateText = order.createdAt != null
        ? dateFormat.format(order.createdAt!)
        : 'غير متوفر';

    final String productName = order.items
        .map((OrderLine line) => line.name.trim())
        .firstWhere(
          (String name) => name.isNotEmpty,
      orElse: () => 'غير متوفر',
    );

    final TextTheme textTheme = Theme.of(context).textTheme;
    final Color textColor = context.color.textDefaultColor;

    final TextStyle labelStyle =
    (textTheme.bodySmall ?? const TextStyle()).copyWith(
      fontWeight: FontWeight.w600,
      color: textColor.withOpacity(0.8),
    );
    final TextStyle valueStyle =
    (textTheme.bodyLarge ?? const TextStyle(fontSize: 16)).copyWith(
      fontWeight: FontWeight.w600,
      color: textColor,
    );

    final _StatusVisual statusVisual = _statusColors(order.statusLabel);


    final BorderRadius borderRadius = BorderRadius.circular(16);
    final Color splashColor =
    Theme.of(context).colorScheme.primary.withOpacity(0.16);
    final Color highlightColor =
    Theme.of(context).colorScheme.primary.withOpacity(0.08);



    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius,
        side: BorderSide(color: context.color.borderColor),
      ),
      color: context.color.secondaryColor,
      child: InkWell(
        borderRadius: borderRadius,
        splashColor: splashColor,
        highlightColor: highlightColor,
        onTap: () {
          Navigator.pushNamed(
            context,
            Routes.orderSteps,
            arguments: <String, dynamic>{'orderId': order.id},
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,


            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 92,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('الحالة', style: labelStyle),
                        const SizedBox(height: 6),
                        _StatusChip(
                          label: statusVisual.label,
                          backgroundColor: statusVisual.backgroundColor,
                          textColor: statusVisual.textColor,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          productName,
                          style: valueStyle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text('رقم الطلب:', style: labelStyle),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                order.displayLabel,
                                style: valueStyle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text('تاريخ الطلب:', style: labelStyle),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                dateText,
                                style: valueStyle.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

            ],
          ),
        ),
      ),
    );
  }
}

class _OrderDetailItem extends StatelessWidget {
  const _OrderDetailItem({
    required this.title,
    this.value,
    required this.titleStyle,
    required this.valueStyle,
    this.valueWidget,
  }) : assert(value != null || valueWidget != null,
  'Either value or valueWidget must be provided.');

  final String title;
  final String? value;
  final TextStyle titleStyle;
  final TextStyle valueStyle;
  final Widget? valueWidget;

  @override
  Widget build(BuildContext context) {
    final Widget content = valueWidget ??
        Text(
          value ?? '',
          style: valueStyle,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: titleStyle),
        const SizedBox(height: 4),
        content,

      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.backgroundColor,
    required this.textColor,
  });

  final String label;
  final Color backgroundColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final TextStyle baseStyle =
        Theme.of(context).textTheme.bodySmall ?? const TextStyle(fontSize: 12);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: textColor.withOpacity(0.2)),
      ),
      child: Text(
        label,
        style: baseStyle.copyWith(
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}



class _OrderCardSkeleton extends StatelessWidget {
  const _OrderCardSkeleton();

  @override
  Widget build(BuildContext context) {
    final Color borderColor = context.color.borderColor;
    final Color cardColor = context.color.secondaryColor;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color fillColor =
    isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.08);

    Widget skeletonBox({double? width, double height = 12, double radius = 8}) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: fillColor,
          borderRadius: BorderRadius.circular(radius),
        ),
      );
    }

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor),
      ),
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 92,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      skeletonBox(width: 56),
                      const SizedBox(height: 6),
                      skeletonBox(width: 82, height: 28, radius: 999),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      skeletonBox(height: 18, radius: 10),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          skeletonBox(width: 70, height: 12),
                          const SizedBox(width: 6),
                          Expanded(child: skeletonBox(height: 14, radius: 10)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          skeletonBox(width: 86, height: 12),
                          const SizedBox(width: 6),
                          Expanded(child: skeletonBox(height: 14, radius: 10)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            skeletonBox(width: 110),
            const SizedBox(height: 8),
            skeletonBox(height: 10, radius: 6),
            const SizedBox(height: 4),
            skeletonBox(height: 10, radius: 6),
            const SizedBox(height: 4),
            skeletonBox(width: MediaQuery.of(context).size.width * 0.4, height: 10, radius: 6),
          ],
        ),
      ),
    );
  }
}