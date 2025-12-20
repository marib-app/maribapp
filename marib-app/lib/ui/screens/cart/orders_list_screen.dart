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
import 'package:marib/app/navigation/app_page_route.dart';
import 'package:marib/app/navigation/motion/route_motion.dart';

class OrdersListScreen extends StatefulWidget {
  const OrdersListScreen({super.key});

  static Route route(RouteSettings settings) {
    return AppPageRoute.build(
      settings: settings,
      builder: (_) => const OrdersListScreen(),
      motionPattern: AppMotionPattern.glide,
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
  _OrderFilter _selectedFilter = _OrderFilter.all;

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
    if (_loading) {
      return _buildLoadingSkeleton();
    }

    if (_errorMessage != null && _orders.isEmpty) {
      return _buildErrorState();
    }

    if (_orders.isEmpty) {
      return _buildEmptyState();
    }

    final List<UserOrder> visibleOrders = _filteredOrders;

    if (!_loading && visibleOrders.isEmpty) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: _FilterChips(
              selected: _selectedFilter,
              onChanged: (filter) => setState(() => _selectedFilter = filter),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.color.secondaryColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: context.color.borderColor),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.inbox_outlined, size: 48),
                        SizedBox(height: 8),
                        Text(
                          'لا توجد طلبات في هذا التصنيف.',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: _FilterChips(
            selected: _selectedFilter,
            onChanged: (filter) => setState(() => _selectedFilter = filter),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              itemCount: visibleOrders.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (BuildContext context, int index) {
                final UserOrder order = visibleOrders[index];
                return _OrderCard(
                  order: order,
                  dateFormat: _dateFormat,
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    final Color accentColor = Theme.of(context).colorScheme.primary;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 56, color: accentColor),
            const SizedBox(height: 12),
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
    final Color accentColor = Theme.of(context).colorScheme.primary;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: accentColor),
            const SizedBox(height: 12),
            const Text(
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
    final colorScheme = Theme.of(context).colorScheme;
    final Color baseColor = colorScheme.shimmerBaseColor;
    final Color highlightColor = colorScheme.shimmerHighlightColor;

    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: _FiltersSkeleton(),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: Shimmer.fromColors(
              baseColor: baseColor,
              highlightColor: highlightColor,
              period: const Duration(milliseconds: 1200),
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                itemCount: 3,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, __) => const _OrderCardSkeleton(),
              ),
            ),
          ),
        ),
      ],
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
  'payment completed': 'مدفوع',
  'payment complete': 'مدفوع',
  'payment success': 'مدفوع',
  'payment succeeded': 'مدفوع',
  'payment received': 'مدفوع',
  'payment captured': 'مدفوع',
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
  'paid': 'مدفوع',
  'paid in full': 'مدفوع بالكامل',
  'fully paid': 'مدفوع بالكامل',
  'partial paid': 'مدفوع جزئياً',
  'partially paid': 'مدفوع جزئياً',
  'part payment': 'مدفوع جزئياً',
  'unpaid': 'غير مدفوع',
  'not paid': 'غير مدفوع',
  'payment failed': 'فشل الدفع',
  'payment error': 'فشل الدفع',
  'payment declined': 'فشل الدفع',
  'payment cancelled': 'إلغاء الدفع',
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

Color _statusIconColor(_StatusVisual visual) {
  // اجعل الحالات المدفوعة خضراء للتمييز.
  if (visual.label.contains('مدفوع')) {
    return const Color(0xFF2E7D32);
  }
  return visual.textColor;
}

String _formatAddressShort(String value) {
  // نظف الرموز غير المقروءة ثم احتفظ بالمحافظة والحي/الشارع فقط (دون الدولة ودون رموز).
  final String cleaned = value
      .replaceAll(RegExp(r'[\u0000-\u001F\u007F]+'), ' ')
      .replaceAll(RegExp(r'[^\u0600-\u06FFa-zA-Z0-9 ,.\-]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  if (cleaned.isEmpty) return value;

  final List<String> parts = cleaned
      .split(RegExp(r'[،,/\-]+'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  // اعتبر الجزء الأول غالباً دولة، لذلك نتخطاه ونأخذ ما بعده.
  final List<String> picked = parts.length > 1 ? parts.skip(1).take(2).toList() : parts.take(2).toList();
  final String joined = picked.join(' ');

  if (joined.length > 40) {
    return '${joined.substring(0, 40).trim()}…';
  }
  return joined;
}

String _localizeShortLabel(String value) {
  final String lower = value.toLowerCase();
  if (lower.contains('pending')) return 'قيد الدفع';
  if (lower.contains('paid')) return 'مدفوع';
  if (lower.contains('unpaid') || lower.contains('not paid')) return 'غير مدفوع';
  return value;
}

enum _OrderFilter {
  all,
  review,
  processing,
  shipping,
  completed,
  canceled,
}

enum OrderStatusCategory { review, processing, shipping, completed, canceled }

const Map<_OrderFilter, String> _filterLabels = <_OrderFilter, String>{
  _OrderFilter.all: 'كل الطلبات',
  _OrderFilter.review: 'قيد المراجعة',
  _OrderFilter.processing: 'قيد المعالجة',
  _OrderFilter.shipping: 'الشحن',
  _OrderFilter.completed: 'مكتملة',
  _OrderFilter.canceled: 'ملغاة / فاشلة',
};

OrderStatusCategory _statusCategory(String? rawStatus) {
  final String normalized = _normalizeStatusKey(rawStatus ?? '');
  if (normalized.isEmpty) return OrderStatusCategory.review;

  bool containsAny(List<String> tokens) =>
      tokens.any((token) => normalized.contains(token));

  if (containsAny(<String>[
    'cancel',
    'ملغى',
    'ملغي',
    'الغاء',
    'failed',
    'fail',
    'فشل',
    'فاشل',
    'reject',
    'مرفوض',
    'مرفوضة',
    'decline',
    'رفض',
    'return',
    'ارجاع',
    'مرتجع',
    'refun',
  ])) {
    return OrderStatusCategory.canceled;
  }

  if (containsAny(<String>[
    'delivered',
    'completed',
    'fulfilled',
    'done',
    'success',
    'مكتمل',
    'تم التسليم',
    'تم التوصيل',
    'تم الاستلام',
  ])) {
    return OrderStatusCategory.completed;
  }

  if (containsAny(<String>[
    'ship',
    'شحن',
    'الشحن',
    'delivery',
    'توصيل',
    'طريق',
    'out for delivery',
    'in transit',
    'استلام',
    'التسليم',
    'pickup',
  ])) {
    return OrderStatusCategory.shipping;
  }

  if (containsAny(<String>[
    'process',
    'processing',
    'progress',
    'prepare',
    'معالجة',
    'قيد المعالجة',
    'معالجه',
    'الدفع',
    'payment',
  ])) {
    return OrderStatusCategory.processing;
  }

  if (containsAny(<String>[
    'pending',
    'review',
    'مراجعة',
    'معلّق',
    'معلق',
    'انتظار',
    'انتضار',
    'approval',
    'تأكيد',
    'انتظار موافقة',
  ])) {
    return OrderStatusCategory.review;
  }

  return OrderStatusCategory.review;
}

extension _OrdersFilterExtension on _OrdersListScreenState {
  List<UserOrder> get _filteredOrders {
    if (_selectedFilter == _OrderFilter.all) return _orders;

    return _orders.where((UserOrder order) {
      final OrderStatusCategory category = _statusCategory(order.statusLabel);
      switch (_selectedFilter) {
        case _OrderFilter.review:
          return category == OrderStatusCategory.review;
        case _OrderFilter.processing:
          return category == OrderStatusCategory.processing;
        case _OrderFilter.shipping:
          return category == OrderStatusCategory.shipping;
        case _OrderFilter.completed:
          return category == OrderStatusCategory.completed;
        case _OrderFilter.canceled:
          return category == OrderStatusCategory.canceled;
        case _OrderFilter.all:
          return true;
      }
    }).toList();
  }
}


class _FilterChips extends StatelessWidget {
  const _FilterChips({
    required this.selected,
    required this.onChanged,
  });

  final _OrderFilter selected;
  final ValueChanged<_OrderFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color primary = scheme.primary;
    final Color border = context.color.borderColor;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _OrderFilter.values.map((filter) {
          final bool isSelected = filter == selected;
          return Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: ChoiceChip(
              label: Text(_filterLabels[filter] ?? ''),
              selected: isSelected,
              pressElevation: 0,
              selectedColor: primary.withOpacity(0.12),
              backgroundColor: context.color.secondaryColor,
              side: BorderSide(color: isSelected ? primary : border),
              labelStyle: TextStyle(
                color: isSelected ? primary : context.color.textDefaultColor,
                fontWeight: FontWeight.w700,
              ),
              onSelected: (_) => onChanged(filter),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _FiltersSkeleton extends StatelessWidget {
  const _FiltersSkeleton();

  @override
  Widget build(BuildContext context) {
    final Color fill = Theme.of(context).colorScheme.shimmerContentColor;
    Widget box(double width) => Container(
          width: width,
          height: 32,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(20),
          ),
        );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          box(90),
          const SizedBox(width: 8),
          box(110),
          const SizedBox(width: 8),
          box(96),
          const SizedBox(width: 8),
          box(118),
        ],
      ),
    );
  }
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
    final String? dateText = order.createdAt != null
        ? dateFormat.format(order.createdAt!)
        : null;

    final String? productName = order.items
        .map((OrderLine line) => line.name.trim())
        .firstWhere(
          (String name) => name.isNotEmpty,
          orElse: () => '',
        );

    final String orderNumber = order.displayLabel;
    final String totalText = order.totalLabel;
    final String paymentMethod = _localizeShortLabel(order.paymentLabel.trim());
    final String deliveryMethod = _localizeShortLabel(order.deliveryLabel.trim());
    final String? address =
        order.addressLabel != null ? _formatAddressShort(order.addressLabel!) : null;

    const Set<String> dashTokens = <String>{'—', 'â€”', '-'};
    final String totalClean = totalText.trim();
    final String paymentClean = paymentMethod.trim();
    final String deliveryClean = deliveryMethod.trim();

    final bool hasTotal = totalClean.isNotEmpty && !dashTokens.contains(totalClean);
    final bool hasPayment = paymentClean.isNotEmpty && !dashTokens.contains(paymentClean);
    final bool hasDelivery = deliveryClean.isNotEmpty && !dashTokens.contains(deliveryClean);

    final TextTheme textTheme = Theme.of(context).textTheme;
    final Color textColor = context.color.textDefaultColor;

    final TextStyle labelStyle =
        (textTheme.bodySmall ?? const TextStyle()).copyWith(
          fontWeight: FontWeight.w600,
          color: textColor.withOpacity(0.75),
        );
    final TextStyle titleStyle =
        (textTheme.titleMedium ?? const TextStyle(fontSize: 17)).copyWith(
          fontWeight: FontWeight.w700,
          color: textColor,
        );
    final TextStyle valueStyle =
        (textTheme.bodyLarge ?? const TextStyle(fontSize: 16)).copyWith(
          fontWeight: FontWeight.w600,
          color: textColor,
        );
    final TextStyle mutedStyle =
        (textTheme.bodySmall ?? const TextStyle(fontSize: 12)).copyWith(
          fontWeight: FontWeight.w600,
          color: textColor.withOpacity(0.7),
        );

    final _StatusVisual statusVisual = _statusColors(order.statusLabel);

    final BorderRadius borderRadius = BorderRadius.circular(16);
    final Color splashColor =
        Theme.of(context).colorScheme.primary.withOpacity(0.16);
    final Color highlightColor =
        Theme.of(context).colorScheme.primary.withOpacity(0.08);
    final Color accentColor = Theme.of(context).colorScheme.primary;

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
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('رقم الطلب', style: labelStyle),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            orderNumber,
                            style: titleStyle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (dateText != null) ...[
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 15,
                            color: mutedStyle.color,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              dateText,
                              style: mutedStyle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (productName != null && productName.isNotEmpty)
                      Text(
                        productName,
                        style: valueStyle.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (address != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 16,
                            color: mutedStyle.color,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              address,
                              style: mutedStyle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 150),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _StatusChip(
                      label: statusVisual.label,
                      backgroundColor: statusVisual.backgroundColor,
                      textColor: statusVisual.textColor,
                    ),
                    if (hasTotal)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('الإجمالي', style: mutedStyle),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                totalText,
                                style: valueStyle.copyWith(
                                  color: accentColor,
                                  fontWeight: FontWeight.w800,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.end,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (hasPayment) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.account_balance_wallet_outlined,
                            size: 16,
                            color: _statusIconColor(statusVisual),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              paymentMethod,
                              style: mutedStyle.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.end,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (hasDelivery) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.local_shipping_outlined,
                            size: 16,
                            color: context.color.textDefaultColor,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              deliveryMethod,
                              style: mutedStyle.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.end,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}class _OrderDetailItem extends StatelessWidget {
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
    final colorScheme = Theme.of(context).colorScheme;
    final Color fillColor = colorScheme.shimmerContentColor;

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
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          skeletonBox(width: 70, height: 10),
                          const SizedBox(width: 8),
                          skeletonBox(width: 120, height: 14, radius: 10),
                        ],
                      ),
                      const SizedBox(height: 6),
                      skeletonBox(width: 150, height: 12, radius: 8),
                      const SizedBox(height: 8),
                      skeletonBox(width: 180, height: 14, radius: 10),
                      const SizedBox(height: 6),
                      skeletonBox(width: 140, height: 12, radius: 8),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    skeletonBox(width: 90, height: 28, radius: 999),
                    const SizedBox(height: 8),
                    skeletonBox(width: 80, height: 14, radius: 8),
                    const SizedBox(height: 4),
                    skeletonBox(width: 56, height: 10, radius: 6),
                    const SizedBox(height: 6),
                    skeletonBox(width: 110, height: 12, radius: 8),
                    const SizedBox(height: 4),
                    skeletonBox(width: 96, height: 12, radius: 8),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

