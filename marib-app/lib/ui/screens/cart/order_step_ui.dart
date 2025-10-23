import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:marib/data/model/orders/user_order.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:shimmer/shimmer.dart';
import 'package:marib/ui/screens/cart/order_outstanding_info.dart';

class OrderStepData {
  const OrderStepData({
    required this.label,
    this.status,
    this.timestamp,
    this.isCompleted = false,
    this.isCurrent = false,
    this.outstanding,
    this.onPayOutstanding,
    this.depositSummary,
  });

  final String label;
  final String? status;
  final DateTime? timestamp;
  final bool isCompleted;
  final bool isCurrent;
  final OrderOutstandingInfo? outstanding;
  final VoidCallback? onPayOutstanding;
  final Map<String, dynamic>? depositSummary;

  OrderStepData copyWith({
    String? label,
    String? status,
    DateTime? timestamp,
    bool? isCompleted,
    bool? isCurrent,
  }) {
    return OrderStepData(
      label: label ?? this.label,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
      isCompleted: isCompleted ?? this.isCompleted,
      isCurrent: isCurrent ?? this.isCurrent,
    );
  }
}

List<OrderStepData> buildOrderStepData(UserOrder order) {
  const List<String> defaultLabels = <String>[
    'تم الطلب',
    'تم تأكيد الطلب',
    'تحضير الطلب',
    'في طريقه إليك',
    'تم التوصيل',
  ];

  final List<OrderTimelineEntry> timeline = order.effectiveTimeline;
  int length = defaultLabels.length;
  if (timeline.length > length) {
    length = timeline.length;
  }

  List<OrderStepData> steps = List<OrderStepData>.generate(length, (int index) {
    final String label;
    if (index < defaultLabels.length) {
      label = defaultLabels[index];
    } else if (index < timeline.length) {
      label = timeline[index].label;
    } else {
      label = defaultLabels.last;
    }
    return OrderStepData(label: label);
  });

  int completedCount = 0;
  int currentIndex = -1;

  for (int i = 0; i < timeline.length && i < steps.length; i++) {
    final OrderTimelineEntry entry = timeline[i];
    final bool entryCompleted = entry.isCompleted || entry.timestamp != null;
    final bool entryCurrent = entry.isCurrent;

    steps[i] = steps[i].copyWith(
      status: entry.status ?? entry.label,
      timestamp: entry.timestamp,
      isCompleted: entryCompleted,
      isCurrent: entryCurrent,
    );

    if (entryCompleted) {
      completedCount = i + 1;
    }
    if (entryCurrent) {
      currentIndex = i;
    }
  }

  if (currentIndex == -1) {
    if (completedCount < steps.length) {
      currentIndex = completedCount;
    } else if (steps.isNotEmpty) {
      currentIndex = steps.length - 1;
    }
  }

  for (int i = 0; i < steps.length; i++) {
    final bool isCompleted =
        steps[i].isCompleted || (currentIndex != -1 && i < currentIndex);
    final bool isCurrent = currentIndex != -1 && i == currentIndex;

    steps[i] = steps[i].copyWith(
      isCompleted: isCompleted,
      isCurrent: isCurrent,
    );
  }
  if (steps.isEmpty) {
    return const <OrderStepData>[
      OrderStepData(label: 'تم الطلب', isCurrent: true),
    ];
  }

  return steps;
}

class OrderStepContent extends StatelessWidget {
  const OrderStepContent({
    super.key,
    required this.isLoading,
    required this.order,
    required this.orderDetails,
    required this.steps,
    required this.errorMessage,
    required this.dateFormat,
    required this.onRetry,
    required this.onOpenInvoice,
    required this.onCancelOrder,
    required this.isCancelling,
    required this.canOpenInvoice,
    required this.isInvoiceLoading,
    this.invoiceBlockReason,
    this.outstanding,
    this.onPayOutstanding,
    this.depositSummary,
    this.paymentSummary,
    this.deliveryPaymentSummary,
    this.depositReceipts,
  });

  final bool isLoading;
  final UserOrder? order;
  final OrderDetails? orderDetails;

  final List<OrderStepData> steps;
  final String? errorMessage;
  final DateFormat dateFormat;
  final Future<void> Function() onRetry;
  final Future<void> Function(UserOrder) onOpenInvoice;
  final Future<void> Function(UserOrder) onCancelOrder;
  final bool isCancelling;
  final bool canOpenInvoice;
  final bool isInvoiceLoading;
  final String? invoiceBlockReason;
  final String? outstanding;
  final Future<void> Function()? onPayOutstanding;
  final Map<String, dynamic>? paymentSummary;
  final Map<String, dynamic>? deliveryPaymentSummary;
  final Map<String, dynamic>? depositReceipts;
  final Map<String, dynamic>? depositSummary;

  static const List<String> _depositKeywords = <String>[
    'deposit',
    'down_payment',
    'downpayment',
    'advance',
    'reservation',
    'reserve',
    'booking',
  ];

  static const List<String> _goodsKeywords = <String>[
    'goods',
    'product',
    'products',
    'item',
    'items',
    'order',
    'subtotal',
    'total',
    'merchandise',
  ];

  static const List<String> _deliveryKeywords = <String>[
    'delivery',
    'shipping',
    'logistics',
    'courier',
    'driver',
    'transport',
    'cod',
    'cash_on_delivery',
    'cash-on-delivery',
    'on_delivery',
    'on-delivery',
  ];

  static const List<String> _paidKeywords = <String>[
    'paid',
    'settled',
    'received',
    'collected',
    'captured',
    'completed',
  ];

  static const List<String> _dueKeywords = <String>[
    'due',
    'outstanding',
    'remaining',
    'balance',
    'pending',
    'unpaid',
    'rest',
    'left',
  ];

  static const List<String> _noteKeywords = <String>[
    'note',
    'notes',
    'hint',
    'message',
    'comment',
    'status_text',
    'status_message',
    'description',
    'details',
    'user_note',
    'usernote',
    'customer_note',
    'customer_message',
  ];

  static const List<String> _displayKeys = <String>[
    'display',
    'formatted',
    'text',
    'label',
    'value_display',
    'amount_display',
    'formatted_amount',
    'formatted_value',
    'string',
    'readable',
  ];

  static const List<String> _urlKeywords = <String>[
    'url',
    'link',
    'href',
    'file',
    'attachment',
    'image',
    'document',
    'download',
  ];

  @override
  Widget build(BuildContext context) {
    final bool showShimmer = isLoading && errorMessage == null;

    Widget body;
    if (order != null) {
      final OrderDetails? details = orderDetails;
      final UserOrder resolvedOrder = order!;
      final Map<String, dynamic>? paymentSummaryData = paymentSummary ??
          details?.paymentSummary ??
          resolvedOrder.paymentSummary;
      final Map<String, dynamic>? deliverySummaryData =
          deliveryPaymentSummary ??
              details?.deliveryPaymentSummary ??
              resolvedOrder.deliveryPaymentSummary;
      final Map<String, dynamic>? depositReceiptsData =
          depositReceipts ?? details?.depositReceipts;
      final Map<String, dynamic>? depositSummaryData = depositSummary ??
          details?.depositSummary ??
          resolvedOrder.depositSummary;
      body = _buildContent(
        context,
        resolvedOrder,
        steps,
        details,
        outstanding: outstanding,
        onPayOutstanding: onPayOutstanding,
        paymentSummary: paymentSummaryData,
        deliveryPaymentSummary: deliverySummaryData,
        depositReceipts: depositReceiptsData,
        depositSummary: depositSummaryData,
      );
    } else if (showShimmer) {
      body = _buildSkeleton(context);
    } else if (errorMessage != null && errorMessage!.isNotEmpty) {
      body = _buildErrorState(context, errorMessage!);
    } else {
      body = _buildEmptyState(context);
    }

    final Widget effectiveBody = showShimmer
        ? Shimmer.fromColors(
            baseColor: Colors.grey.shade300,
            highlightColor: Colors.grey.shade100,
            child: body,
          )
        : body;

    return AnnotatedRegion(
      value: UiUtils.getSystemUiOverlayStyle(
        context: context,
        statusBarColor: context.color.secondaryColor,
      ),
      child: Scaffold(
        appBar: UiUtils.buildAppBar(
          context,
          title: 'تفاصيل الطلب',
          bottomHeight: 20,
          showBackButton: true,
        ),
        backgroundColor: context.color.primaryColor,
        body: effectiveBody,
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    UserOrder order,
    List<OrderStepData> providedSteps,
    OrderDetails? details, {
    String? outstanding,
    Future<void> Function()? onPayOutstanding,
    Map<String, dynamic>? paymentSummary,
    Map<String, dynamic>? deliveryPaymentSummary,
    Map<String, dynamic>? depositReceipts,
    Map<String, dynamic>? depositSummary,
  }) {
    final List<OrderStepData> effectiveSteps =
        providedSteps.isNotEmpty ? providedSteps : buildOrderStepData(order);
    final List<OrderTimelineEntry> timeline = order.effectiveTimeline;

    final OrderStatusDisplay? statusDisplay = order.statusDisplay;
    final OrderStatusReserveOptions? reserveOptions =
        order.statusReserveOptions;
    final OrderPolicy? policy = details?.policy;
    final OrderSupport? support = details?.support;
    final OrderActions actions = order.actions;
    final Map<String, dynamic>? resolvedDepositSummary =
        depositSummary ?? details?.depositSummary ?? order.depositSummary;
    final bool showStatusDisplay =
        statusDisplay != null && statusDisplay.hasContent;
    final bool showReserveOptions =
        reserveOptions != null && reserveOptions.hasContent;
    final bool showPolicySection = (policy != null && policy.hasReturnPolicy) ||
        (support != null && support.hasContact);

    final Widget? timelineSection = _buildTimelineSection(context, timeline);

    final Widget? paymentsSummarySection = _buildFinancialSummarySection(
      context,
      order,
      paymentSummary: paymentSummary,
      deliveryPaymentSummary: deliveryPaymentSummary,
      depositReceipts: depositReceipts,
      depositSummary: resolvedDepositSummary,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (showStatusDisplay) ...<Widget>[
            _buildStatusDisplayCard(context, statusDisplay!),
            const SizedBox(height: 20),
          ],
          if (showReserveOptions) ...<Widget>[
            _buildReserveOptionsCard(context, reserveOptions!),
            const SizedBox(height: 20),
          ],
          if (effectiveSteps.isNotEmpty)
            _buildStepsRow(context, effectiveSteps)
          else
            _buildStepsPlaceholder(context),
          const SizedBox(height: 20),
          if (timelineSection != null) ...<Widget>[
            timelineSection,
            const SizedBox(height: 20),
          ],
          _buildInfoCard(
            context,
            order,
            actions,
            outstanding: outstanding,
            onPayOutstanding: onPayOutstanding,
          ),
          const SizedBox(height: 20),
          if (paymentsSummarySection != null) ...<Widget>[
            paymentsSummarySection,
            const SizedBox(height: 20),
          ],
          _buildOrderSummary(context, order),
          if (showPolicySection) ...<Widget>[
            const SizedBox(height: 20),
            _buildPolicySection(context, policy, support),
          ],
        ],
      ),
    );
  }

  Widget? _buildFinancialSummarySection(
    BuildContext context,
    UserOrder order, {
    Map<String, dynamic>? paymentSummary,
    Map<String, dynamic>? deliveryPaymentSummary,
    Map<String, dynamic>? depositReceipts,
    Map<String, dynamic>? depositSummary,
  }) {
    final List<_ReceiptEntry> receipts = _parseDepositReceipts(depositReceipts);

    final Map<String, dynamic>? depositSource =
        depositSummary ?? _extractSection(paymentSummary, _depositKeywords);
    final Map<String, dynamic>? goodsCandidate = _extractSection(
      paymentSummary,
      _goodsKeywords,
      excludeKeywords: _depositKeywords,
    );
    final Map<String, dynamic>? goodsSource =
        goodsCandidate ?? _stripKeywords(paymentSummary, _depositKeywords);
    final Map<String, dynamic>? deliverySource =
        _extractSection(deliveryPaymentSummary, _deliveryKeywords) ??
            deliveryPaymentSummary;
    final String? depositNoteFallback =
        _depositSummaryNote(order, depositSource ?? paymentSummary);
    final _PaymentBreakdown? depositBreakdown = _summarizeBreakdown(
      title: 'العربون',
      summary: depositSource,
      fallbackSource: paymentSummary,
      receipts: receipts,
      fallbackPaidValue: order.depositAmountPaid,
      fallbackDueValue: order.depositRemainingBalance,
      fallbackNote: depositNoteFallback,
    );

    _PaymentBreakdown? goodsBreakdown;
    if (goodsSource != null && goodsSource.isNotEmpty) {
      goodsBreakdown = _summarizeBreakdown(
        title: 'البضائع',
        summary: goodsSource,
        fallbackSource: goodsSource,
      );
    } else if (paymentSummary != null &&
        (depositBreakdown == null || !depositBreakdown.hasContent)) {
      goodsBreakdown = _summarizeBreakdown(
        title: 'البضائع',
        summary: paymentSummary,
        fallbackSource: paymentSummary,
      );
    }

    final _PaymentBreakdown? deliveryBreakdown = _summarizeBreakdown(
      title: 'التوصيل',
      summary: deliverySource,
      fallbackSource: deliveryPaymentSummary,
    );

    final List<_PaymentBreakdown> breakdowns = <_PaymentBreakdown>[
      if (depositBreakdown != null && depositBreakdown.hasContent)
        depositBreakdown,
      if (goodsBreakdown != null && goodsBreakdown.hasContent) goodsBreakdown,
      if (deliveryBreakdown != null && deliveryBreakdown.hasContent)
        deliveryBreakdown,
    ];

    if (breakdowns.isEmpty && receipts.isEmpty) {
      return null;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.color.primaryColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'ملخص المدفوعات',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          if (breakdowns.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            for (int i = 0; i < breakdowns.length; i++) ...<Widget>[
              _PaymentBreakdownTile(
                breakdown: breakdowns[i],
                currency: order.currency,
              ),
              if (i != breakdowns.length - 1 || receipts.isNotEmpty)
                const SizedBox(height: 12),
            ],
          ],
          if (receipts.isNotEmpty) ...<Widget>[
            if (breakdowns.isNotEmpty) const Divider(height: 32),
            _buildDepositReceiptsList(context, receipts, order.currency),
          ],
        ],
      ),
    );
  }

  String? _depositSummaryNote(UserOrder order, Map<String, dynamic>? summary) {
    Map<String, dynamic>? normalized;
    if (summary != null && summary.isNotEmpty) {
      normalized = _normalizeMap(summary as Map<dynamic, dynamic>);
    }

    double? requiredAmount = order.depositRequiredAmount;
    double? minimumAmount = order.depositMinimumAmount;
    double? ratio = order.depositRatio;
    bool? includesShipping = order.depositIncludesShipping;

    if (normalized != null) {
      requiredAmount ??= _tryParseNumeric(normalized['required_amount']) ??
          _tryParseNumeric(normalized['required']);
      minimumAmount ??= _tryParseNumeric(normalized['minimum_amount']);
      ratio ??= _tryParseNumeric(normalized['ratio']);
      includesShipping ??= _boolFromDynamic(
        normalized['includes_shipping'] ?? normalized['shipping_included'],
      );
    }

    final List<String> lines = <String>[];
    if (requiredAmount != null && requiredAmount > 0) {
      lines.add(
        'إجمالي العربون المطلوب: ${_formatCurrency(requiredAmount, order.currency)}',
      );
    }
    if (minimumAmount != null && minimumAmount > 0) {
      lines.add(
        'الحد الأدنى للعربون: ${_formatCurrency(minimumAmount, order.currency)}',
      );
    }
    if (ratio != null && ratio > 0) {
      final double percent = ratio <= 1 ? ratio * 100 : ratio;
      final NumberFormat percentFormat = NumberFormat('#,##0.##');
      lines.add(
        'نسبة العربون من قيمة الطلب: ${percentFormat.format(percent)}%',
      );
    }
    if (includesShipping == true) {
      lines.add('يشمل العربون رسوم التوصيل.');
    }

    if (lines.isEmpty) {
      return null;
    }

    return lines.join('\n');
  }

  Widget? _buildTimelineSection(
      BuildContext context, List<OrderTimelineEntry> timeline) {
    if (timeline.isEmpty) {
      return null;
    }

    final DateFormat timelineFormat = DateFormat(
      'yyyy/MM/dd HH:mm',
      dateFormat.locale,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.color.primaryColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'سجل التحديثات',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          for (int i = 0; i < timeline.length; i++) ...<Widget>[
            _buildTimelineEntry(
              context,
              timeline[i],
              timelineFormat,
              isLast: i == timeline.length - 1,
            ),
            if (i != timeline.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _buildTimelineEntry(
    BuildContext context,
    OrderTimelineEntry entry,
    DateFormat timelineFormat, {
    required bool isLast,
  }) {
    final Color accent = _timelineAccentColor(entry);
    final IconData icon = _resolveTimelineIcon(entry);
    final String title = (entry.status ?? entry.label).trim().isEmpty
        ? entry.label
        : (entry.status ?? entry.label).trim();
    final String? timestamp = entry.timestamp != null
        ? timelineFormat.format(entry.timestamp!.toLocal())
        : null;

    final Map<String, dynamic> raw = entry.raw != null
        ? _normalizeMap(entry.raw as Map<dynamic, dynamic>)
        : <String, dynamic>{};
    final String? display = _stringFromDynamic(raw['display']) ??
        _stringFromDynamic(raw['message']);
    final String? comment = entry.description;
    final String? note = _stringFromDynamic(raw['note'] ?? raw['notes']);
    final String? metaNote = _stringFromDynamic(raw['meta']);

    final List<String> details = <String>[];
    void addDetail(String? value) {
      if (_isMeaningfulText(value)) {
        final String trimmed = value!.trim();
        if (!details.contains(trimmed)) {
          details.add(trimmed);
        }
      }
    }

    addDetail(display);
    addDetail(comment);
    addDetail(note);
    addDetail(metaNote);

    final Map<String, dynamic>? userMap = _asMap(raw['user']);
    String? recordedBy;
    if (userMap != null) {
      recordedBy = _stringFromDynamic(userMap['name']) ??
          _stringFromDynamic(userMap['full_name']) ??
          _stringFromDynamic(userMap['username']);
    }
    recordedBy ??= _stringFromDynamic(raw['user_name']);
    recordedBy ??= _stringFromDynamic(raw['recorded_by']);
    if (recordedBy == null && raw['user_id'] != null) {
      recordedBy = '#${raw['user_id']}';
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            width: 40,
            child: Column(
              children: <Widget>[
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: entry.isCompleted || entry.isCurrent
                        ? accent
                        : accent.withOpacity(0.15),
                    border: Border.all(color: accent, width: 2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 16,
                    color: entry.isCompleted || entry.isCurrent
                        ? Colors.white
                        : accent,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: Colors.grey.shade300,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: TextStyle(
                    fontWeight:
                        entry.isCurrent ? FontWeight.bold : FontWeight.w600,
                    color:
                        entry.isCurrent ? accent : context.color.textColorDark,
                  ),
                ),
                if (timestamp != null || recordedBy != null) ...<Widget>[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: <Widget>[
                      if (timestamp != null)
                        _buildTimelineMetaChip(
                          icon: Icons.schedule,
                          label: timestamp,
                        ),
                      if (recordedBy != null)
                        _buildTimelineMetaChip(
                          icon: Icons.person_outline,
                          label: recordedBy,
                        ),
                    ],
                  ),
                ],
                for (final String detail in details) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(
                    detail,
                    style: TextStyle(
                      height: 1.5,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineMetaChip({
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: Colors.grey.shade700),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  IconData _resolveTimelineIcon(OrderTimelineEntry entry) {
    final String combined =
        '${entry.status ?? ''} ${entry.label}'.toLowerCase();
    if (combined.contains('cancel') || combined.contains('ملغ')) {
      return Icons.cancel_outlined;
    }
    if (combined.contains('fail') || combined.contains('فشل')) {
      return Icons.error_outline;
    }
    if (combined.contains('deliver') ||
        combined.contains('تسليم') ||
        combined.contains('توصيل') ||
        combined.contains('استلام')) {
      return Icons.home_outlined;
    }
    if (combined.contains('ship') ||
        combined.contains('شحن') ||
        combined.contains('طريق')) {
      return Icons.local_shipping_outlined;
    }
    if (combined.contains('paid') ||
        combined.contains('مدفوع') ||
        combined.contains('سداد') ||
        combined.contains('دفع')) {
      return Icons.payments_outlined;
    }
    if (combined.contains('processing') ||
        combined.contains('قيد') ||
        combined.contains('انتظار')) {
      return Icons.hourglass_bottom;
    }
    return entry.isCompleted
        ? Icons.check_circle_outline
        : Icons.radio_button_unchecked;
  }

  Color _timelineAccentColor(OrderTimelineEntry entry) {
    if (entry.isCurrent) {
      return Colors.orange.shade600;
    }
    if (entry.isCompleted) {
      return Colors.green.shade600;
    }
    final String combined =
        '${entry.status ?? ''} ${entry.label}'.toLowerCase();
    if (combined.contains('cancel') || combined.contains('ملغ')) {
      return Colors.red.shade600;
    }
    if (combined.contains('fail') || combined.contains('فشل')) {
      return Colors.red.shade400;
    }
    if (combined.contains('pending') ||
        combined.contains('قيد') ||
        combined.contains('انتظار')) {
      return Colors.blueGrey.shade500;
    }
    return Colors.blue.shade600;
  }

  Widget _buildDepositReceiptsList(
      BuildContext context, List<_ReceiptEntry> receipts, String? currency) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'إيصالات العربون',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        for (final _ReceiptEntry entry in receipts) ...<Widget>[
          _buildReceiptCard(context, entry, currency),
        ],
      ],
    );
  }

  Widget _buildReceiptCard(
      BuildContext context, _ReceiptEntry entry, String? currency) {
    final String? amount = entry.displayAmount(currency);
    final List<Widget> details = <Widget>[];

    if (amount != null && amount.isNotEmpty) {
      details.add(
        Text(
          'المبلغ: $amount',
          style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600) ??
              const TextStyle(fontWeight: FontWeight.w600),
        ),
      );
    }

    if (entry.subtitle != null && entry.subtitle!.trim().isNotEmpty) {
      details.add(
        Text(
          entry.subtitle!.trim(),
          style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey.shade700) ??
              TextStyle(color: Colors.grey.shade700, fontSize: 12),
        ),
      );
    }

    if (entry.fields.isNotEmpty) {
      final TextStyle labelStyle =
          Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ) ??
              TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
                fontSize: 12,
              );
      final TextStyle valueStyle =
          Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w400,
                    color: Colors.grey.shade800,
                  ) ??
              TextStyle(
                fontWeight: FontWeight.w400,
                color: Colors.grey.shade800,
                fontSize: 12,
              );

      for (final _ReceiptField field in entry.fields) {
        details.add(
          RichText(
            text: TextSpan(
              text: '${field.label}: ',
              style: labelStyle,
              children: <InlineSpan>[
                TextSpan(
                  text: field.value,
                  style: valueStyle,
                ),
              ],
            ),
          ),
        );
      }
    }

    if (entry.note != null && entry.note!.trim().isNotEmpty) {
      details.add(
        Text(
          entry.note!.trim(),
          style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey.shade600, height: 1.4) ??
              TextStyle(color: Colors.grey.shade600, fontSize: 12, height: 1.4),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  entry.title ?? 'إيصال',
                  style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600) ??
                      const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (details.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 6),
                  for (int i = 0; i < details.length; i++) ...<Widget>[
                    details[i],
                    if (i != details.length - 1) const SizedBox(height: 4),
                  ],
                ],
              ],
            ),
          ),
          if (entry.hasUrl)
            IconButton(
              icon: const Icon(Icons.open_in_new),
              tooltip: 'عرض الإيصال',
              onPressed: () => _launchExternalUrl(context, entry.url),
            ),
        ],
      ),
    );
  }

  List<_ReceiptEntry> _parseDepositReceipts(Map<String, dynamic>? source) {
    if (source == null || source.isEmpty) {
      return const <_ReceiptEntry>[];
    }

    final List<_ReceiptEntry> receipts = <_ReceiptEntry>[];
    final Set<Object> visited = <Object>{};

    void traverse(dynamic node) {
      if (node == null) {
        return;
      }
      if (node is Map) {
        if (visited.contains(node)) {
          return;
        }
        visited.add(node);
        final Map<String, dynamic> normalized =
            _normalizeMap(node as Map<dynamic, dynamic>);
        if (_looksLikeReceipt(normalized)) {
          receipts.add(_buildReceiptEntry(normalized));
          return;
        }
        for (final dynamic value in normalized.values) {
          traverse(value);
        }
      } else if (node is Iterable) {
        for (final dynamic element in node) {
          traverse(element);
        }
      }
    }

    traverse(source);
    return receipts;
  }

  _PaymentBreakdown? _summarizeBreakdown({
    required String title,
    Map<String, dynamic>? summary,
    Map<String, dynamic>? fallbackSource,
    List<_ReceiptEntry> receipts = const <_ReceiptEntry>[],
    String? currency,
    double? fallbackPaidValue,
    String? fallbackPaidText,
    double? fallbackDueValue,
    String? fallbackDueText,
    String? fallbackNote,
  }) {
    final Map<String, dynamic>? source = summary ?? fallbackSource;
    _AmountInfo? paidInfo = _scanForAmount(source, _paidKeywords);
    _AmountInfo? dueInfo = _scanForAmount(source, _dueKeywords);
    final String? note = _extractNote(source);

    _AmountInfo? effectivePaid = paidInfo;

    if ((effectivePaid == null || !effectivePaid.hasContent) &&
        receipts.isNotEmpty) {
      double total = 0;
      bool hasNumeric = false;
      String? fallbackText;
      for (final _ReceiptEntry receipt in receipts) {
        if (receipt.amountValue != null) {
          total += receipt.amountValue!;
          hasNumeric = true;
        } else if (fallbackText == null &&
            receipt.amountText != null &&
            receipt.amountText!.trim().isNotEmpty) {
          fallbackText = receipt.amountText!.trim();
        }
      }
      if (hasNumeric || fallbackText != null) {
        effectivePaid = _AmountInfo(
          text: fallbackText,
          value: hasNumeric ? total : null,
        );
      }
    }

    if ((effectivePaid == null || !effectivePaid.hasContent) &&
        (fallbackPaidValue != null ||
            (fallbackPaidText != null && fallbackPaidText.trim().isNotEmpty))) {
      effectivePaid = _AmountInfo(
        text: fallbackPaidText,
        value: fallbackPaidValue,
      );
    }

    if ((dueInfo == null || !dueInfo.hasContent) &&
        (fallbackDueValue != null ||
            (fallbackDueText != null && fallbackDueText.trim().isNotEmpty))) {
      dueInfo = _AmountInfo(
        text: fallbackDueText,
        value: fallbackDueValue,
      );
    }

    final bool hasPaid = effectivePaid != null && effectivePaid.hasContent;
    final bool hasDue = dueInfo != null && dueInfo.hasContent;

    String? resolvedNote = note;
    if (resolvedNote != null && resolvedNote.trim().isEmpty) {
      resolvedNote = null;
    }

    final String? trimmedFallbackNote =
        fallbackNote != null && fallbackNote.trim().isNotEmpty
            ? fallbackNote.trim()
            : null;

    if (resolvedNote == null) {
      resolvedNote = trimmedFallbackNote;
    } else if (trimmedFallbackNote != null &&
        trimmedFallbackNote != resolvedNote.trim()) {
      resolvedNote = '${resolvedNote.trim()}\n$trimmedFallbackNote';
    }

    final bool hasNote = resolvedNote != null && resolvedNote.trim().isNotEmpty;

    if (!hasPaid && !hasDue && !hasNote) {
      return null;
    }

    return _PaymentBreakdown(
      title: title,
      paidText: effectivePaid?.text,
      paidValue: effectivePaid?.value,
      dueText: dueInfo?.text,
      dueValue: dueInfo?.value,
      note: resolvedNote,
    );
  }

  Map<String, dynamic>? _extractSection(
    Map<String, dynamic>? source,
    List<String> includeKeywords, {
    List<String> excludeKeywords = const <String>[],
  }) {
    if (source == null || source.isEmpty) {
      return null;
    }

    final Map<String, dynamic> normalized =
        _normalizeMap(source as Map<dynamic, dynamic>);

    final Map<String, dynamic> directMatches = <String, dynamic>{};
    Map<String, dynamic>? singleMatchMap;
    int matchCount = 0;

    for (final MapEntry<String, dynamic> entry in normalized.entries) {
      final String lowerKey = entry.key.toLowerCase();
      if (_containsKeyword(lowerKey, includeKeywords) &&
          !_containsKeyword(lowerKey, excludeKeywords)) {
        matchCount++;
        final dynamic value = entry.value;
        final Map<String, dynamic>? asMap = _asMap(value);
        if (asMap != null) {
          if (matchCount == 1) {
            singleMatchMap = asMap;
          } else {
            singleMatchMap = null;
          }
          directMatches[entry.key] = asMap;
          continue;
        }
        if (value is Iterable) {
          final List<dynamic> normalizedList = <dynamic>[];
          for (final dynamic element in value) {
            normalizedList.add(_asMap(element) ?? element);
          }
          if (matchCount == 1 &&
              normalizedList.length == 1 &&
              normalizedList.first is Map<String, dynamic>) {
            singleMatchMap = normalizedList.first as Map<String, dynamic>;
          } else {
            singleMatchMap = null;
          }
          directMatches[entry.key] = normalizedList;
          continue;
        }
        singleMatchMap = null;
        directMatches[entry.key] = value;
      }
    }

    if (directMatches.isNotEmpty) {
      if (matchCount == 1 && singleMatchMap != null) {
        return singleMatchMap;
      }
      return directMatches;
    }

    for (final dynamic value in normalized.values) {
      final Map<String, dynamic>? nested = _asMap(value);
      if (nested != null) {
        final Map<String, dynamic>? candidate = _extractSection(
          nested,
          includeKeywords,
          excludeKeywords: excludeKeywords,
        );
        if (candidate != null) {
          return candidate;
        }
      } else if (value is Iterable) {
        for (final dynamic element in value) {
          final Map<String, dynamic>? elementMap = _asMap(element);
          if (elementMap == null) {
            continue;
          }
          final Map<String, dynamic>? candidate = _extractSection(
            elementMap,
            includeKeywords,
            excludeKeywords: excludeKeywords,
          );
          if (candidate != null) {
            return candidate;
          }
        }
      }
    }

    return null;
  }

  Map<String, dynamic>? _stripKeywords(
      Map<String, dynamic>? source, List<String> keywords) {
    if (source == null || source.isEmpty) {
      return null;
    }

    final Map<String, dynamic> normalized =
        _normalizeMap(source as Map<dynamic, dynamic>);
    final Map<String, dynamic> result = <String, dynamic>{};

    normalized.forEach((String key, dynamic value) {
      final String lower = key.toLowerCase();
      if (!_containsKeyword(lower, keywords)) {
        result[key] = value;
      }
    });

    return result.isEmpty ? null : result;
  }

  _AmountInfo? _scanForAmount(dynamic source, List<String> keywords) {
    if (source == null) {
      return null;
    }

    final Set<Object> visited = <Object>{};

    _AmountInfo? traverse(dynamic node) {
      if (node == null) {
        return null;
      }
      if (node is Map) {
        if (visited.contains(node)) {
          return null;
        }
        visited.add(node);
        final Map<String, dynamic> normalized =
            _normalizeMap(node as Map<dynamic, dynamic>);
        for (final MapEntry<String, dynamic> entry in normalized.entries) {
          final String key = entry.key.toLowerCase();
          if (_containsKeyword(key, keywords)) {
            final _AmountInfo? direct = _extractAmountFromValue(entry.value);
            if (direct != null && direct.hasContent) {
              return direct;
            }
          }
        }
        for (final dynamic value in normalized.values) {
          final _AmountInfo? nested = traverse(value);
          if (nested != null && nested.hasContent) {
            return nested;
          }
        }
        return null;
      }
      if (node is Iterable) {
        for (final dynamic element in node) {
          final _AmountInfo? nested = traverse(element);
          if (nested != null && nested.hasContent) {
            return nested;
          }
        }
        return null;
      }
      return _extractAmountFromValue(node);
    }

    final _AmountInfo? result = traverse(source);
    return result != null && result.hasContent ? result : null;
  }

  _AmountInfo? _extractAmountFromValue(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is String) {
      final String trimmed = value.trim();
      if (trimmed.isEmpty || !_hasDigits(trimmed)) {
        return null;
      }
      return _AmountInfo(
        text: trimmed,
        value: _tryParseNumeric(trimmed),
      );
    }
    if (value is num) {
      return _AmountInfo(value: value.toDouble());
    }
    if (value is Map) {
      final Map<String, dynamic> normalized =
          _normalizeMap(value as Map<dynamic, dynamic>);
      final String? display = _firstDisplayString(normalized);
      final double? numeric = _firstNumericValue(normalized);
      if (display != null || numeric != null) {
        return _AmountInfo(
          text: display,
          value:
              numeric ?? (display != null ? _tryParseNumeric(display) : null),
        );
      }
      for (final dynamic nested in normalized.values) {
        final _AmountInfo? candidate = _extractAmountFromValue(nested);
        if (candidate != null && candidate.hasContent) {
          return candidate;
        }
      }
    }
    if (value is Iterable) {
      for (final dynamic element in value) {
        final _AmountInfo? candidate = _extractAmountFromValue(element);
        if (candidate != null && candidate.hasContent) {
          return candidate;
        }
      }
    }
    return null;
  }

  String? _firstDisplayString(Map<String, dynamic> map) {
    for (final String key in _displayKeys) {
      final dynamic value = map[key];
      final String? candidate = _stringFromDynamic(value, requireDigits: true);
      if (candidate != null) {
        return candidate;
      }
    }
    for (final MapEntry<String, dynamic> entry in map.entries) {
      if (_containsKeyword(entry.key.toLowerCase(), _displayKeys)) {
        final String? candidate =
            _stringFromDynamic(entry.value, requireDigits: true);
        if (candidate != null) {
          return candidate;
        }
      }
    }
    return null;
  }

  double? _firstNumericValue(Map<String, dynamic> map) {
    const List<String> numericKeys = <String>[
      'amount',
      'value',
      'total',
      'number',
      'paid',
      'due',
      'balance',
      'remaining',
      'price',
    ];

    for (final String key in numericKeys) {
      final double? candidate = _tryParseNumeric(map[key]);
      if (candidate != null) {
        return candidate;
      }
    }

    for (final MapEntry<String, dynamic> entry in map.entries) {
      if (_containsKeyword(entry.key.toLowerCase(), numericKeys)) {
        final double? candidate = _tryParseNumeric(entry.value);
        if (candidate != null) {
          return candidate;
        }
      }
    }

    return null;
  }

  bool _containsKeyword(String key, List<String> keywords) {
    for (final String keyword in keywords) {
      if (key.contains(keyword)) {
        return true;
      }
    }
    return false;
  }

  Map<String, dynamic> _normalizeMap(Map<dynamic, dynamic> map) {
    final Map<String, dynamic> result = <String, dynamic>{};
    map.forEach((dynamic key, dynamic value) {
      result[key.toString()] = value;
    });
    return result;
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return _normalizeMap(value as Map<dynamic, dynamic>);
    }
    return null;
  }

  String? _stringFromDynamic(dynamic value, {bool requireDigits = false}) {
    if (value == null) {
      return null;
    }
    if (value is String) {
      final String trimmed = value.trim();
      if (trimmed.isEmpty) {
        return null;
      }
      if (requireDigits && !_hasDigits(trimmed)) {
        return null;
      }
      return trimmed;
    }
    if (value is num) {
      if (requireDigits) {
        final NumberFormat formatter = NumberFormat('#,##0.##');
        return formatter.format(value);
      }
      return value.toString();
    }
    if (value is Map) {
      return _stringFromDynamic(
        (value as Map).values,
        requireDigits: requireDigits,
      );
    }
    if (value is Iterable) {
      for (final dynamic element in value) {
        final String? candidate =
            _stringFromDynamic(element, requireDigits: requireDigits);
        if (candidate != null) {
          return candidate;
        }
      }
    }
    return null;
  }

  bool _hasDigits(String value) => RegExp(r'[0-9]').hasMatch(value);

  bool _isMeaningfulText(String? value) {
    if (value == null) {
      return false;
    }
    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      return false;
    }
    if (trimmed.length >= 6) {
      return true;
    }
    return trimmed.contains(' ') ||
        trimmed.contains('،') ||
        trimmed.contains('.');
  }

  String? _joinNonEmpty(List<String?> values, {String separator = ' '}) {
    final List<String> parts = <String>[];
    for (final String? value in values) {
      if (_isMeaningfulText(value)) {
        parts.add(value!.trim());
      }
    }
    if (parts.isEmpty) {
      return null;
    }
    return parts.join(separator);
  }

  String? _extractNote(Map<String, dynamic>? source) {
    if (source == null || source.isEmpty) {
      return null;
    }
    final Set<Object> visited = <Object>{};
    String? result;

    void traverse(dynamic node) {
      if (node == null || result != null) {
        return;
      }
      if (node is Map) {
        if (visited.contains(node)) {
          return;
        }
        visited.add(node);
        final Map<String, dynamic> normalized =
            _normalizeMap(node as Map<dynamic, dynamic>);
        for (final MapEntry<String, dynamic> entry in normalized.entries) {
          final String key = entry.key.toLowerCase();
          if (_containsKeyword(key, _noteKeywords)) {
            final String? candidate = _stringFromDynamic(entry.value);
            if (_isMeaningfulText(candidate)) {
              result = candidate!.trim();
              return;
            }
          }
        }
        for (final dynamic value in normalized.values) {
          traverse(value);
          if (result != null) {
            return;
          }
        }
      } else if (node is Iterable) {
        for (final dynamic element in node) {
          traverse(element);
          if (result != null) {
            return;
          }
        }
      }
    }

    traverse(source);
    return result;
  }

  bool _looksLikeReceipt(Map<String, dynamic> map) {
    if (map.isEmpty) {
      return false;
    }
    final Iterable<String> keys =
        map.keys.map((String key) => key.toLowerCase());
    int score = 0;
    if (keys.any((String key) =>
        key.contains('receipt') ||
        key.contains('reference') ||
        key.contains('number') ||
        key.contains('code'))) {
      score++;
    }
    if (keys.any((String key) =>
        key.contains('amount') ||
        key.contains('value') ||
        key.contains('total') ||
        key.contains('paid'))) {
      score++;
    }
    if (keys
        .any((String key) => key.contains('status') || key.contains('state'))) {
      score++;
    }
    if (keys.any((String key) => _containsKeyword(key, _urlKeywords))) {
      score++;
    }
    return score >= 2;
  }

  _ReceiptEntry _buildReceiptEntry(Map<String, dynamic> map) {
    final String? title = _firstReadableString(
          map,
          const <String>[
            'title',
            'label',
            'name',
            'reference',
            'receipt',
            'bank',
            'method'
          ],
        ) ??
        _firstReadableString(map, const <String>['id', 'number', 'code']);
    final String? status =
        _firstReadableString(map, const <String>['status', 'state', 'result']);
    final String? date = _firstReadableString(
      map,
      const <String>['date', 'created_at', 'submitted_at', 'timestamp', 'time'],
    );
    final String? subtitle =
        _joinNonEmpty(<String?>[status, date], separator: ' • ');
    final _AmountInfo? amount =
        _scanForAmount(map, const <String>['amount', 'value', 'total', 'paid']);
    String? note = _extractNote(map);
    final String? userNoteCandidate = _firstReadableString(
      map,
      const <String>[
        'user_note',
        'usernote',
        'customer_note',
        'customer_message'
      ],
    );
    if (!_isMeaningfulText(note) && _isMeaningfulText(userNoteCandidate)) {
      note = userNoteCandidate!.trim();
    }

    final List<_ReceiptField> fields = <_ReceiptField>[];
    final Set<String> seenFieldKeys = <String>{};

    void addField(String? value, String label) {
      if (!_isMeaningfulText(value)) {
        return;
      }
      final String trimmed = value!.trim();
      if (trimmed.isEmpty) {
        return;
      }
      final String uniqueKey = '$label|$trimmed';
      if (seenFieldKeys.add(uniqueKey)) {
        fields.add(_ReceiptField(label: label, value: trimmed));
      }
    }

    final String? senderName = _firstReadableString(
      map,
      const <String>['sender_name', 'sendername', 'customer_name'],
    );
    addField(senderName, 'اسم المرسل');

    final String? transferCode = _firstReadableString(
      map,
      const <String>[
        'transfer_code',
        'transfer_number',
        'transfer_reference',
        'reference_number',
        'manual_reference',
      ],
    );
    addField(transferCode, 'رقم التحويل');

    final String? url = _extractUrlFromMap(map);

    return _ReceiptEntry(
      title: title,
      subtitle: subtitle,
      amountText: amount?.text,
      amountValue: amount?.value,
      note: note,
      url: url,
      fields: fields,
    );
  }

  String? _firstReadableString(
      Map<String, dynamic> map, List<String> keywords) {
    for (final MapEntry<String, dynamic> entry in map.entries) {
      final String key = entry.key.toLowerCase();
      if (_containsKeyword(key, keywords)) {
        final String? candidate = _stringFromDynamic(entry.value);
        if (_isMeaningfulText(candidate)) {
          return candidate!.trim();
        }
      }
    }
    for (final dynamic value in map.values) {
      final Map<String, dynamic>? nested = _asMap(value);
      if (nested != null) {
        final String? candidate = _firstReadableString(nested, keywords);
        if (candidate != null) {
          return candidate;
        }
      } else if (value is Iterable) {
        for (final dynamic element in value) {
          final Map<String, dynamic>? elementMap = _asMap(element);
          if (elementMap == null) {
            continue;
          }
          final String? candidate = _firstReadableString(elementMap, keywords);
          if (candidate != null) {
            return candidate;
          }
        }
      }
    }
    return null;
  }

  String? _extractUrlFromMap(Map<String, dynamic> map) {
    for (final String key in _urlKeywords) {
      final dynamic value = map[key];
      final String? candidate = _resolveUrl(value);
      if (candidate != null) {
        return candidate;
      }
    }
    for (final MapEntry<String, dynamic> entry in map.entries) {
      if (_containsKeyword(entry.key.toLowerCase(), _urlKeywords)) {
        final String? candidate = _resolveUrl(entry.value);
        if (candidate != null) {
          return candidate;
        }
      }
    }
    return null;
  }

  String? _resolveUrl(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is String) {
      final String trimmed = value.trim();
      if (trimmed.isEmpty) {
        return null;
      }
      return _isLikelyUrl(trimmed) ? trimmed : null;
    }
    if (value is Map) {
      return _resolveUrl((value as Map).values);
    }
    if (value is Iterable) {
      for (final dynamic element in value) {
        final String? candidate = _resolveUrl(element);
        if (candidate != null) {
          return candidate;
        }
      }
    }
    return null;
  }

  bool _isLikelyUrl(String value) {
    final String lower = value.toLowerCase();
    return lower.startsWith('http://') ||
        lower.startsWith('https://') ||
        lower.startsWith('www.');
  }

  double? _tryParseNumeric(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      String normalized = value.replaceAll(RegExp('[^0-9,.-]'), '');
      if (normalized.isEmpty) {
        return null;
      }
      final int lastComma = normalized.lastIndexOf(',');
      final int lastDot = normalized.lastIndexOf('.');
      if (lastComma > lastDot) {
        normalized = normalized.replaceAll('.', '');
        normalized = normalized.replaceAll(',', '.');
      } else {
        normalized = normalized.replaceAll(',', '');
      }
      return double.tryParse(normalized);
    }
    if (value is Map) {
      return _tryParseNumeric((value as Map).values);
    }
    if (value is Iterable) {
      for (final dynamic element in value) {
        final double? candidate = _tryParseNumeric(element);
        if (candidate != null) {
          return candidate;
        }
      }
    }
    return null;
  }

  bool? _boolFromDynamic(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      final String normalized = value.trim().toLowerCase();
      if (normalized.isEmpty) {
        return null;
      }
      const Set<String> truthy = <String>{
        '1',
        'true',
        'yes',
        'y',
        'on',
        'enabled',
      };
      const Set<String> falsy = <String>{
        '0',
        'false',
        'no',
        'n',
        'off',
        'disabled',
      };
      if (truthy.contains(normalized)) {
        return true;
      }
      if (falsy.contains(normalized)) {
        return false;
      }
    }
    return null;
  }

  Widget _buildStepsRow(BuildContext context, List<OrderStepData> steps) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: List<Widget>.generate(steps.length * 2 - 1, (int index) {
        if (index.isEven) {
          return _OrderStepIndicator(
            step: steps[index ~/ 2],
            index: index ~/ 2,
          );
        }
        return Expanded(
          child: SizedBox(
            height: 44,
            child: Align(
              alignment: Alignment.center,
              child: Container(
                height: 1,
                color: Colors.grey.shade400,
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildStepsPlaceholder(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
        color: context.color.primaryColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: const Center(
        child: Text('لا يتوفر خط زمني لهذا الطلب حاليًا.'),
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context,
    UserOrder order,
    OrderActions actions, {
    String? outstanding,
    Future<void> Function()? onPayOutstanding,
  }) {
    final String createdAt =
        order.createdAt != null ? dateFormat.format(order.createdAt!) : '—';
    final String paymentStatus = order.paymentLabel;
    final String deliveryStatus = order.deliveryLabel;
    final String address = order.addressLabel ?? '—';
    final bool showWarning = _shouldShowWarning(paymentStatus);
    final bool showCancel = actions.canCancel;
    final String? cancelHint =
        actions.hasCancelHint ? actions.cancelHint!.trim() : null;
    final bool showOutstanding =
        outstanding != null && outstanding.trim().isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.color.primaryColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _buildInfoRow(context, 'رقم الطلب:', order.displayLabel),
          _buildInfoRow(context, 'تاريخ تقديم الطلب:', createdAt),
          _buildInfoRow(
            context,
            'موافقة التاجر:',
            deliveryStatus,
            valueColor: _statusColor(deliveryStatus),
          ),
          _buildInfoRow(
            context,
            'حالة السداد:',
            paymentStatus,
            valueColor: _statusColor(paymentStatus),
          ),
          const Divider(height: 30),
          const Text(
            'عنوان الشحن',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            address,
            style: const TextStyle(height: 1.6),
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: (!canOpenInvoice || isInvoiceLoading)
                      ? null
                      : () => onOpenInvoice(order),
                  icon: isInvoiceLoading
                      ? SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        )
                      : const Icon(Icons.picture_as_pdf_outlined),
                  label: Text(
                    isInvoiceLoading ? 'جار الفتح…' : 'عرض الفاتورة',
                  ),
                ),
              ),
              if (showCancel) ...<Widget>[
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isCancelling ? null : () => onCancelOrder(order),
                    icon: isCancelling
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.cancel_outlined),
                    label: Text(
                      isCancelling ? 'جار الإلغاء…' : actions.cancelButtonLabel,
                    ),
                  ),
                ),
              ],
              if (showOutstanding) ...<Widget>[
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Row(
                          children: <Widget>[
                            Icon(
                              Icons.payments_outlined,
                              color: Colors.orange.shade700,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'المتبقي للسداد: ${outstanding!.trim()}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.orange.shade800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (onPayOutstanding != null) ...<Widget>[
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: () async {
                            await onPayOutstanding();
                          },
                          icon: const Icon(Icons.payment),
                          label: const Text('تسديد المتبقي'),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
          if (invoiceBlockReason != null) ...<Widget>[
            const SizedBox(height: 12),
            _buildActionNotice(
              context,
              invoiceBlockReason!,
              icon: Icons.info_outline,
              accentColor: Colors.orange.shade700,
            ),
          ],
          if (showCancel &&
              (actions.canRefundDeposit || cancelHint != null)) ...<Widget>[
            const SizedBox(height: 12),
            _buildActionNotice(
              context,
              actions.canRefundDeposit
                  ? 'سيتم بدء عملية استرداد العربون عند تأكيد الإلغاء.'
                  : cancelHint!,
              icon: actions.canRefundDeposit
                  ? Icons.savings_outlined
                  : Icons.info_outline,
              accentColor: actions.canRefundDeposit
                  ? Colors.green.shade700
                  : Colors.orange.shade700,
            ),
          ],
          const SizedBox(height: 20),
          if (showWarning)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                '⚠️ ملاحظة هامة:\n'
                'في حال كانت حالة السداد معلّقة، فهذا يعني أن الطلب لم يتم تسليمه بعد لإدارة التطبيق. '
                'يُرجى العلم أن تأخير المعالجة يكون عادةً من جهة التاجر، حيث لم يقم بعد بتأكيد عملية الدفع الخاصة بك. '
                'عند مراجعة التاجر للطلب وتأكيد السداد، سيتم تحديث الحالة تلقائيًا إلى (مدفوع)، '
                'وسيتولى فريق التوصيل مباشرة تنفيذ الطلب دون أي تأخير إضافي.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.6,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.justify,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusDisplayCard(
    BuildContext context,
    OrderStatusDisplay display,
  ) {
    final _StatusBannerVisual visual =
        _resolveStatusBannerVisual(context, display);
    final String? primary = display.primaryText;
    final String? secondary = display.secondaryText;
    final String? note = _hasValue(display.note) ? display.note!.trim() : null;
    final String? badge =
        _hasValue(display.badge) ? display.badge!.trim() : null;
    final bool hasPrimary = _hasValue(primary);
    final bool hasSecondary = _hasValue(secondary);

    bool showSecondary = false;
    if (hasSecondary) {
      if (!hasPrimary) {
        showSecondary = true;
      } else {
        showSecondary = primary!.trim() != secondary!.trim();
      }
    }

    final bool showNote =
        note != null && (!showSecondary || note != secondary?.trim());

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: visual.backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: visual.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                visual.icon,
                color: visual.iconColor,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (hasPrimary)
                      Text(
                        primary!.trim(),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: visual.textColor,
                        ),
                      ),
                    if (showSecondary)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          secondary!.trim(),
                          style: TextStyle(
                            height: 1.5,
                            color: visual.textColor.withOpacity(0.85),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (badge != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: visual.badgeBackground,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      color: visual.badgeTextColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          if (showNote) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              note!,
              style: TextStyle(
                height: 1.5,
                color: visual.textColor.withOpacity(0.85),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReserveOptionsCard(
    BuildContext context,
    OrderStatusReserveOptions options,
  ) {
    final String? title =
        _hasValue(options.title) ? options.title!.trim() : null;
    final String? emphasis = options.emphasisText;

    String? body;
    for (final String? candidate in <String?>[
      options.message,
      options.disclaimer
    ]) {
      if (_hasValue(candidate) && candidate!.trim() != emphasis) {
        body = candidate.trim();
        break;
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(8),
                child: Icon(
                  Icons.watch_later_outlined,
                  color: Colors.orange.shade700,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (title != null)
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade800,
                        ),
                      ),
                    if (_hasValue(emphasis))
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          emphasis!.trim(),
                          style: TextStyle(
                            height: 1.6,
                            color: Colors.orange.shade800,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (body != null) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              body!,
              style: TextStyle(
                height: 1.5,
                color: Colors.orange.shade700,
              ),
            ),
          ],
          if (options.points.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: options.points
                  .map((String point) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const Text('• '),
                            Expanded(
                              child: Text(
                                point.trim(),
                                style: const TextStyle(height: 1.5),
                              ),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ],
          if (_hasValue(options.actionLabel) &&
              _hasValue(options.actionUrl)) ...<Widget>[
            const SizedBox(height: 12),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: () => _launchExternalUrl(context, options.actionUrl),
                child: Text(options.actionLabel!.trim()),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPolicySection(
    BuildContext context,
    OrderPolicy? policy,
    OrderSupport? support,
  ) {
    final bool hasPolicy = policy != null && policy.hasReturnPolicy;
    final bool hasSupport = support != null && support.hasContact;
    final String? subtitle = hasSupport ? _supportSubtitle(support!) : null;

    if (!hasPolicy && !hasSupport) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.color.primaryColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (hasPolicy) ...<Widget>[
            Text(
              policy!.effectiveTitle,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              policy.returnPolicyText!.trim(),
              style: const TextStyle(height: 1.6),
            ),
          ],
          if (hasPolicy && hasSupport) const SizedBox(height: 16),
          if (hasSupport) ...<Widget>[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _openSupport(context, support!),
                icon: const Icon(Icons.headset_mic_outlined),
                label: Text(support.effectiveLabel),
              ),
            ),
            if (_hasValue(subtitle)) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                subtitle!.trim(),
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildActionNotice(
    BuildContext context,
    String message, {
    IconData icon = Icons.info_outline,
    Color? accentColor,
  }) {
    final Color baseColor = accentColor ?? Colors.orange.shade700;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: baseColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: baseColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message.trim(),
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: baseColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openSupport(BuildContext context, OrderSupport support) async {
    if (!support.hasContact) {
      UiUtils.showSoftSnackBar(context, message: 'لا يتوفر رابط دعم حاليًا.');
      return;
    }
    await _launchExternalUrl(context, support.url);
  }

  Future<void> _launchExternalUrl(BuildContext context, String? url) async {
    final String? resolved = url?.trim();
    if (!_hasValue(resolved)) {
      UiUtils.showSoftSnackBar(context, message: 'لا يتوفر رابط متاح حاليًا.');
      return;
    }

    try {
      await UiUtils.launchURL(resolved!);
    } catch (_) {
      UiUtils.showSoftSnackBar(context,
          message: 'تعذر فتح الرابط. حاول لاحقًا.');
    }
  }

  String? _supportSubtitle(OrderSupport support) {
    if (_hasValue(support.subtitle)) {
      return support.subtitle!.trim();
    }
    if (_hasValue(support.whatsappNumber)) {
      return 'رقم التواصل: ${support.whatsappNumber!.trim()}';
    }
    return null;
  }

  bool _hasValue(String? value) => value != null && value.trim().isNotEmpty;

  Widget _buildOrderSummary(BuildContext context, UserOrder order) {
    final OrderLine? line = order.items.isNotEmpty ? order.items.first : null;

    final String productName = (line != null && line.name.trim().isNotEmpty)
        ? line.name
        : 'لا توجد منتجات مسجلة';
    final String quantityText =
        line != null ? 'عدد: ${line.quantity}' : 'عدد: 0';
    final String subtotal = line?.totalText ?? order.totalLabel;
    final String total = order.totalLabel;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.color.primaryColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'المنتج المطلوب',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          Text(productName),
          const SizedBox(height: 4),
          Text(quantityText),
          const Divider(height: 30),
          _SummaryRow(title: 'المجموع الفرعي', amount: subtotal),
          const Divider(height: 30),
          _SummaryRow(
            title: 'المجموع الإجمالي',
            amount: total,
            isBold: true,
          ),
        ],
      ),
    );
  }

  Widget _buildSkeleton(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List<Widget>.generate(9, (int index) {
              if (index.isEven) {
                return _buildSkeletonStep();
              }
              return Expanded(
                child: SizedBox(
                  height: 44,
                  child: Align(
                    alignment: Alignment.center,
                    child: Container(
                      height: 1,
                      color: Colors.grey.shade300,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 20),
          _buildSkeletonCard(context, height: 320),
          const SizedBox(height: 20),
          _buildSkeletonCard(context, height: 200),
        ],
      ),
    );
  }

  Widget _buildSkeletonStep() {
    return Column(
      children: <Widget>[
        CircleAvatar(
          backgroundColor: Colors.grey.shade300,
          radius: 22,
        ),
        const SizedBox(height: 6),
        Container(
          width: 60,
          height: 10,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ],
    );
  }

  Widget _buildSkeletonCard(BuildContext context, {double height = 280}) {
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: context.color.primaryColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.warning_amber_rounded,
              color: context.color.secondaryColor,
              size: 40,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => onRetry(),
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.inbox_outlined,
              size: 48,
              color: Colors.grey,
            ),
            SizedBox(height: 12),
            Text(
              'لا توجد طلبات متاحة حتى الآن.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    String title,
    String value, {
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? context.color.textColorDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _shouldShowWarning(String paymentStatus) {
    final String normalized = paymentStatus.toLowerCase();
    return normalized.contains('معل') ||
        normalized.contains('pending') ||
        normalized.contains('انتظار') ||
        normalized.contains('قيد');
  }

  Color? _statusColor(String status) {
    final String normalized = status.toLowerCase();
    if (normalized.contains('مدفوع') || normalized.contains('paid')) {
      return Colors.green;
    }
    if (normalized.contains('معل') || normalized.contains('pending')) {
      return Colors.orange;
    }
    if (normalized.contains('فشل') ||
        normalized.contains('ملغى') ||
        normalized.contains('canceled') ||
        normalized.contains('failed')) {
      return Colors.redAccent;
    }
    return null;
  }
}

class _OrderStepIndicator extends StatelessWidget {
  const _OrderStepIndicator({
    required this.step,
    required this.index,
  });

  final OrderStepData step;
  final int index;

  @override
  Widget build(BuildContext context) {
    final _StepVisual visual = _resolveStepVisual(context, step, index);

    return Column(
      children: <Widget>[
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: visual.isHighlighted
                ? visual.highlightColor
                : Colors.transparent,
            boxShadow: visual.isHighlighted
                ? <BoxShadow>[
                    BoxShadow(
                      color: visual.highlightColor.withOpacity(0.5),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ]
                : const <BoxShadow>[],
          ),
          child: CircleAvatar(
            backgroundColor: visual.backgroundColor,
            radius: 22,
            child: Icon(
              visual.icon,
              color: visual.iconColor,
              size: 24,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          step.label,
          style: TextStyle(
            fontWeight:
                visual.isHighlighted ? FontWeight.bold : FontWeight.normal,
            color: visual.isHighlighted
                ? visual.labelColor
                : context.color.textColorDark,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _StepVisual {
  const _StepVisual({
    required this.icon,
    required this.backgroundColor,
    required this.iconColor,
    required this.highlightColor,
    required this.labelColor,
    required this.isHighlighted,
  });

  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;
  final Color highlightColor;
  final Color labelColor;
  final bool isHighlighted;
}

class _StatusBannerVisual {
  const _StatusBannerVisual({
    required this.backgroundColor,
    required this.borderColor,
    required this.textColor,
    required this.icon,
    required this.iconColor,
    required this.badgeBackground,
    required this.badgeTextColor,
  });

  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;
  final IconData icon;
  final Color iconColor;
  final Color badgeBackground;
  final Color badgeTextColor;
}

_StepVisual _resolveStepVisual(
  BuildContext context,
  OrderStepData step,
  int index,
) {
  const List<IconData> icons = <IconData>[
    Icons.assignment_turned_in,
    Icons.check_circle,
    Icons.local_shipping,
    Icons.delivery_dining,
    Icons.home,
  ];

  final IconData icon =
      index < icons.length ? icons[index] : Icons.check_circle;

  if (step.isCurrent) {
    return _StepVisual(
      icon: icon,
      backgroundColor: Colors.orange,
      iconColor: Colors.white,
      highlightColor: Colors.orange.withOpacity(0.2),
      labelColor: Colors.orange,
      isHighlighted: true,
    );
  }

  if (step.isCompleted) {
    return _StepVisual(
      icon: icon,
      backgroundColor: Colors.green[100]!,
      iconColor: Colors.green,
      highlightColor: Colors.transparent,
      labelColor: context.color.textColorDark,
      isHighlighted: false,
    );
  }

  return _StepVisual(
    icon: icon,
    backgroundColor: Colors.grey[300]!,
    iconColor: Colors.grey.shade600,
    highlightColor: Colors.transparent,
    labelColor: context.color.textColorDark,
    isHighlighted: false,
  );
}

_StatusBannerVisual _resolveStatusBannerVisual(
  BuildContext context,
  OrderStatusDisplay display,
) {
  final String style = (display.style ?? '').toLowerCase();
  final String combinedText =
      '${display.primaryText ?? ''} ${display.badge ?? ''} ${display.note ?? ''}'
          .toLowerCase();

  Color resolveColor(MaterialColor base, int shade) => base[shade] ?? base;

  if (style.contains('success') ||
      style.contains('done') ||
      style.contains('completed') ||
      combinedText.contains('تم') ||
      combinedText.contains('مكتمل')) {
    return _StatusBannerVisual(
      backgroundColor: resolveColor(Colors.green, 50),
      borderColor: resolveColor(Colors.green, 200),
      textColor: resolveColor(Colors.green, 800),
      icon: Icons.check_circle_outline,
      iconColor: Colors.green.shade600,
      badgeBackground: resolveColor(Colors.green, 100),
      badgeTextColor: resolveColor(Colors.green, 800),
    );
  }

  if (style.contains('warning') ||
      style.contains('pending') ||
      style.contains('hold') ||
      combinedText.contains('انتظار') ||
      combinedText.contains('معلق')) {
    return _StatusBannerVisual(
      backgroundColor: resolveColor(Colors.orange, 50),
      borderColor: resolveColor(Colors.orange, 200),
      textColor: resolveColor(Colors.orange, 800),
      icon: Icons.schedule,
      iconColor: Colors.orange.shade700,
      badgeBackground: resolveColor(Colors.orange, 100),
      badgeTextColor: resolveColor(Colors.orange, 800),
    );
  }

  if (style.contains('danger') ||
      style.contains('error') ||
      style.contains('cancel') ||
      style.contains('failed') ||
      combinedText.contains('ملغ') ||
      combinedText.contains('رفض')) {
    return _StatusBannerVisual(
      backgroundColor: resolveColor(Colors.red, 50),
      borderColor: resolveColor(Colors.red, 200),
      textColor: resolveColor(Colors.red, 800),
      icon: Icons.error_outline,
      iconColor: Colors.red.shade600,
      badgeBackground: resolveColor(Colors.red, 100),
      badgeTextColor: resolveColor(Colors.red, 800),
    );
  }

  return _StatusBannerVisual(
    backgroundColor: resolveColor(Colors.blue, 50),
    borderColor: resolveColor(Colors.blue, 200),
    textColor: resolveColor(Colors.blue, 800),
    icon: Icons.info_outline,
    iconColor: Colors.blue.shade600,
    badgeBackground: resolveColor(Colors.blue, 100),
    badgeTextColor: resolveColor(Colors.blue, 800),
  );
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.title,
    required this.amount,
    this.isBold = false,
  });

  final String title;
  final String amount;
  final bool isBold;

  @override
  Widget build(BuildContext context) {
    final TextStyle style = TextStyle(
      fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(title, style: style),
          Text(amount, style: style),
        ],
      ),
    );
  }
}

class _PaymentBreakdownTile extends StatelessWidget {
  const _PaymentBreakdownTile({
    required this.breakdown,
    this.currency,
  });

  final _PaymentBreakdown breakdown;
  final String? currency;

  @override
  Widget build(BuildContext context) {
    final TextStyle titleStyle = Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.bold) ??
        const TextStyle(fontWeight: FontWeight.bold, fontSize: 16);
    final TextStyle labelStyle = Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: Colors.grey.shade600) ??
        TextStyle(color: Colors.grey.shade600, fontSize: 12);
    final TextStyle valueStyle = Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(fontWeight: FontWeight.w600) ??
        const TextStyle(fontWeight: FontWeight.w600);

    final String paidDisplay = breakdown.formattedPaid(currency) ?? '—';
    final String dueDisplay = breakdown.formattedDue(currency) ?? '—';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(breakdown.title, style: titleStyle),
        const SizedBox(height: 6),
        Row(
          children: <Widget>[
            Expanded(
              child: _buildValueColumn(
                label: 'المدفوع',
                value: paidDisplay,
                labelStyle: labelStyle,
                valueStyle: valueStyle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildValueColumn(
                label: 'المتبقي',
                value: dueDisplay,
                labelStyle: labelStyle,
                valueStyle: valueStyle,
              ),
            ),
          ],
        ),
        if (breakdown.note != null &&
            breakdown.note!.trim().isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            breakdown.note!.trim(),
            style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey.shade700, height: 1.4) ??
                TextStyle(
                    color: Colors.grey.shade700, fontSize: 12, height: 1.4),
          ),
        ],
      ],
    );
  }

  Widget _buildValueColumn({
    required String label,
    required String value,
    required TextStyle labelStyle,
    required TextStyle valueStyle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: labelStyle),
        const SizedBox(height: 4),
        Text(value, style: valueStyle),
      ],
    );
  }
}

class _PaymentBreakdown {
  const _PaymentBreakdown({
    required this.title,
    this.paidText,
    this.paidValue,
    this.dueText,
    this.dueValue,
    this.note,
  });

  final String title;
  final String? paidText;
  final double? paidValue;
  final String? dueText;
  final double? dueValue;
  final String? note;

  bool get hasContent =>
      (paidText != null && paidText!.trim().isNotEmpty) ||
      paidValue != null ||
      (dueText != null && dueText!.trim().isNotEmpty) ||
      dueValue != null ||
      (note != null && note!.trim().isNotEmpty);

  String? formattedPaid(String? currency) {
    if (paidText != null && paidText!.trim().isNotEmpty) {
      return paidText!.trim();
    }
    if (paidValue != null) {
      return _formatCurrency(paidValue!, currency);
    }
    return null;
  }

  String? formattedDue(String? currency) {
    if (dueText != null && dueText!.trim().isNotEmpty) {
      return dueText!.trim();
    }
    if (dueValue != null) {
      return _formatCurrency(dueValue!, currency);
    }
    return null;
  }
}

class _AmountInfo {
  const _AmountInfo({this.text, this.value});

  final String? text;
  final double? value;

  bool get hasContent =>
      (text != null && text!.trim().isNotEmpty) || value != null;
}

class _ReceiptEntry {
  const _ReceiptEntry({
    this.title,
    this.subtitle,
    this.amountText,
    this.amountValue,
    this.note,
    this.url,
    this.fields = const <_ReceiptField>[],
  });

  final String? title;
  final String? subtitle;
  final String? amountText;
  final double? amountValue;
  final String? note;
  final String? url;
  final List<_ReceiptField> fields;

  bool get hasUrl => url != null && url!.trim().isNotEmpty;

  String? displayAmount(String? currency) {
    if (amountText != null && amountText!.trim().isNotEmpty) {
      return amountText!.trim();
    }
    if (amountValue != null) {
      return _formatCurrency(amountValue!, currency);
    }
    return null;
  }
}

class _ReceiptField {
  const _ReceiptField({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;
}

String _formatCurrency(double value, String? currency) {
  final NumberFormat formatter = NumberFormat('#,##0.##');
  final String formatted = formatter.format(value);
  final String suffix = (currency != null && currency.trim().isNotEmpty)
      ? ' ${currency.trim().toUpperCase()}'
      : '';
  return '$formatted$suffix'.trim();
}
