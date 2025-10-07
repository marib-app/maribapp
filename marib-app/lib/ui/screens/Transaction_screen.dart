// lib/ui/screens/subscription/transaction_history_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:intl/intl.dart';

import 'package:marib/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:marib/ui/screens/widgets/errors/no_data_found.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/ui_utils.dart';

// التحويل البنكي (الموديل + الخدمة)
import 'package:marib/utils/payment/manual_payment.dart';
import 'package:marib/utils/payment/manual_payment_service.dart';
import 'package:marib/app/routes.dart';

class TransactionScreen extends StatefulWidget {

  const TransactionScreen({super.key, this.service});

  final ManualPaymentService? service;
  @override
  State<TransactionScreen> createState() => SoonScreenState();

  static Route route(RouteSettings routeSettings) {
    return BlurredRouter(
      builder: (_) => const TransactionScreen(),
    );
  }
}

class SoonScreenState extends State<TransactionScreen> {
  static const Duration _pollInterval = Duration(seconds: 20);

  late final ManualPaymentService _service;

  final DateFormat _dateFormat = DateFormat('d MMM yyyy, h:mm a', 'ar');

  List<ManualPayment> _transactions = [];
  bool _loading = false;
  bool _fetching = false;
  Object? _error;
  Timer? _pollTimer;

  @override
  void initState() {

    super.initState();
    _service = widget.service ?? ManualPaymentService();

    _loadManualPayments();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadManualPayments({bool showLoader = true}) async {
    if (_fetching) return;
    _fetching = true;

    if (showLoader) {
      if (mounted) {
        setState(() {
          _loading = true;
          _error = null;
        });
      } else {
        _loading = true;
        _error = null;
      }
    }

    DateTime _toDt(dynamic v) {
      if (v is DateTime) return v;
      final s = (v ?? '').toString().trim();
      if (s.isEmpty) return DateTime.fromMillisecondsSinceEpoch(0);

      // أرقام إبوك: ثوان/ملّي
      final numVal = num.tryParse(s);
      if (numVal != null) {
        if (s.length >= 13) {
          return DateTime.fromMillisecondsSinceEpoch(numVal.toInt(), isUtc: true).toLocal();
        }
        if (s.length >= 10) {
          return DateTime.fromMillisecondsSinceEpoch(numVal.toInt() * 1000, isUtc: true).toLocal();
        }
      }

      // ISO مع فراغ أو T
      final iso = DateTime.tryParse(s.replaceFirst(' ', 'T'));
      if (iso != null) return iso;

      // صيغة شائعة: yyyy-MM-dd HH:mm[:ss]
      final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})[ T](\d{2}):(\d{2})(?::(\d{2}))?$').firstMatch(s);
      if (m != null) {
        final year = int.parse(m.group(1)!);
        final mon  = int.parse(m.group(2)!);
        final day  = int.parse(m.group(3)!);
        final hh   = int.parse(m.group(4)!);
        final mm   = int.parse(m.group(5)!);
        final ss   = int.parse(m.group(6) ?? '0');
        return DateTime(year, mon, day, hh, mm, ss);
      }

      // فشل: أعد أقدم تاريخ لتضمن نزوله أسفل
      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    try {
      final list = await _service.fetchMyManualPayments();

      final sorted = List<ManualPayment>.from(list)
        ..sort((a, b) => _toDt(b.createdAt).compareTo(_toDt(a.createdAt))); // الأحدث أولًا

      if (!mounted) return;
      setState(() {
        _transactions = sorted;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      final message = e.toString();
      final normalizedMessage = message.toLowerCase();
      final indicatesNoData = message.contains('لم يتم العثور') ||
          normalizedMessage.contains('no manual payments found');

      setState(() {
        if (indicatesNoData) {
          _transactions = [];
          _error = null;
        } else {
          _error = e;
        }
      });
    } finally {
      _fetching = false;
      if (!mounted) return;
      if (showLoader) {
        setState(() {
          _loading = false;
        });
      }
      _updatePolling();
    }
  }


  void _handleManualRefresh() {
    _loadManualPayments();
  }

  Future<void> _onRefresh() => _loadManualPayments(showLoader: false);

  void _updatePolling() {
    final shouldPoll = _transactions.any((mp) => mp.shouldAutoRefresh);
    if (!shouldPoll) {
      _pollTimer?.cancel();
      _pollTimer = null;
      return;
    }
    if (_pollTimer != null) return;

    _pollTimer = Timer.periodic(_pollInterval, (_) {
      if (!mounted) return;
      _loadManualPayments(showLoader: false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion(
      value: UiUtils.getSystemUiOverlayStyle(
        context: context,
        statusBarColor: context.color.secondaryColor,
      ),
      child: Scaffold(
        backgroundColor: context.color.primaryColor,
        appBar: UiUtils.buildAppBar(
          context,
          title: "transactionHistory".translate(context),
          bottomHeight: 20,
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _fetching ? null : _handleManualRefresh,
          child: _fetching && _transactions.isEmpty
              ? const CircularProgressIndicator.adaptive()
              : const Icon(Icons.refresh),

        ),
        body: RefreshIndicator(
          onRefresh: _onRefresh,
          child: _buildBody(),
        ),
      ),
    );
  }





  Widget _buildBody() {
    if (_loading && _transactions.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 160),
          Center(child: UiUtils.progress()),
        ],
      );
    }

    if (_error != null && _transactions.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _errorBanner(context, includeRetry: true),
        ],
      );
    }

    if (_transactions.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(8),
        children: [
          NoDataFound(onTap: _handleManualRefresh),
        ],
      );
    }

    return ListView.separated(
      reverse: true,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
      itemCount: _transactions.length + (_error != null ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (_error != null) {
          if (index == 0) {
            return _errorBanner(context);
          }
          final mp = _transactions[index - 1];
          return _manualPaymentTile(context, mp);
        }

        final mp = _transactions[index];
        return _manualPaymentTile(context, mp);
      },
    );
  }



  Widget _manualPaymentTile(BuildContext context, ManualPayment mp) {
    final statusColor = mp.statusColor;
    final statusLabel = mp.statusLabelAr;
    final gatewayColor =
    mp.isEastYemen ? context.color.territoryColor : statusColor;
    final Widget? finalStatusWidget = _finalStatusSection(context, mp);

    return Container(
      decoration: BoxDecoration(
        color: context.color.secondaryColor,
        border: Border.all(color: context.color.borderColor, width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sideBar(color: statusColor),
          const SizedBox(width: 12),

          // تفاصيل يسار
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _tag(mp.gatewayLabel, gatewayColor),
                    const Spacer(),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(mp.amountValueLabel)
                            .bold(weight: FontWeight.w700)
                            .size(18)
                            .color(context.color.territoryColor),
                        if (mp.currencyLabel != null) ...[
                          const SizedBox(width: 4),
                          Text(mp.currencyLabel!)
                              .bold(weight: FontWeight.w600)
                              .size(12)
                              .color(context.color.onSurfaceVariant),
                        ],
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 8),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: statusColor.withOpacity(0.35)),
                        ),
                        child: Text(statusLabel)
                            .color(statusColor)
                            .size(context.font.small),
                      ),
                      if (_shouldShowUpdatedAt(mp)) ...[
                        const SizedBox(height: 6),
                        _lastUpdatedTag(context, mp),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _infoRow(
                  context,
                  label: 'معرّف العملية',
                  value: mp.displayTransactionIdentifier,
                  icon: Icons.confirmation_number_outlined,
                  allowCopy: mp.displayTransactionIdentifier != '—',
                ),
                if (mp.manualPaymentDisplayId != null) ...[
                  const SizedBox(height: 6),
                  _infoRow(
                    context,
                    label: 'طلب التحويل',
                    value: mp.manualPaymentDisplayId!,
                    icon: Icons.tag_outlined,
                  ),
                ],
                if (mp.transactionReference != null &&
                    mp.transactionReference!.isNotEmpty &&
                    mp.transactionReference != mp.displayTransactionIdentifier) ...[
                  const SizedBox(height: 6),
                  _infoRow(
                    context,
                    label: 'مرجع المعاملة',
                    value: mp.transactionReference!,
                    icon: Icons.numbers_outlined,
                    allowCopy: true,
                  ),
                ],
                if (mp.manualReference != null && mp.manualReference!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _infoRow(
                    context,
                    label: 'مرجع التحويل',
                    value: mp.manualReference!,
                    icon: Icons.receipt_long_outlined,
                    allowCopy: true,
                  ),
                ],

                const SizedBox(height: 6),
                _infoRow(
                  context,
                  label: 'تاريخ الإنشاء',
                  value: _formatDateTime(mp.createdAt),
                  icon: Icons.event_outlined,
                ),
                if (mp.approvedAt != null) ...[
                  const SizedBox(height: 6),
                  _infoRow(
                    context,
                    label: 'تاريخ الموافقة',
                    value: _formatDateTime(mp.approvedAt),
                    icon: Icons.verified_outlined,
                  ),
                ],
                if (mp.payableSummary != null) ...[
                  const SizedBox(height: 6),
                  _infoRow(
                    context,
                    label: 'الجهة المرتبطة',
                    value: mp.payableSummary!,
                    icon: Icons.link_outlined,
                  ),
                ],
                if (mp.additionalHighlights.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  ...mp.additionalHighlights.map(
                        (line) => Padding(
                      padding: const EdgeInsetsDirectional.only(start: 4, top: 2),
                      child: Text('• $line')
                          .size(context.font.small)
                          .color(Theme.of(context).colorScheme.onSurface.withOpacity(0.8)),
                    ),
                  ),
                ],

                if (mp.statusMessage != null && mp.statusMessage!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _statusMessageBanner(context, mp),
                ],
                if (mp.isExpired) ...[
                  const SizedBox(height: 12),
                  _expiredBanner(context),
                ] else if (mp.isFailure && (mp.statusMessage == null || mp.statusMessage!.isEmpty)) ...[
                  const SizedBox(height: 12),
                  _failureBanner(context),
                ] else if (mp.isRefunded && (mp.statusMessage == null || mp.statusMessage!.isEmpty)) ...[
                  const SizedBox(height: 12),
                  _refundedBanner(context),
                ] else if (mp.shouldAutoRefresh) ...[
                  const SizedBox(height: 12),
                  _pendingInfoBanner(context),
                ],
                if (finalStatusWidget != null) ...[
                  const SizedBox(height: 12),
                  finalStatusWidget,
                ],

              ],
            ),
          ),
        ],
      ),
    );
  }



  Widget _errorBanner(BuildContext context, {bool includeRetry = false}) {
    final color = Colors.red.shade600;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,


            children: [


              Icon(Icons.warning_amber_rounded, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'حدث خطأ أثناء تحديث معاملات التحويل البنكي. سيتم إعادة المحاولة تلقائيًا.',
                ).size(context.font.small).color(color),
              ),
            ],
          ),
          if (includeRetry) ...[
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: _handleManualRefresh,
                child: const Text('إعادة المحاولة'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(
      BuildContext context, {
        required String label,
        required String value,
        IconData? icon,
        bool allowCopy = false,
      }) {
    final labelColor = Theme.of(context).colorScheme.onSurface.withOpacity(0.6);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(top: 4, end: 8),
            child: Icon(
              icon,
              size: context.font.larger,
              color: context.color.territoryColor,
            ),
          ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label).size(context.font.small).color(labelColor),
              const SizedBox(height: 2),
              Text(value)
                  .bold(weight: FontWeight.w600)
                  .setMaxLines(lines: 2),
            ],
          ),
        ),
        if (allowCopy && value.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 8),
            child: _copyBtn(context, value),
          ),
      ],
    );
  }

  Widget _statusMessageBanner(BuildContext context, ManualPayment mp) {
    final bool isError = mp.isFailure || mp.isExpired;
    final Color color = isError
        ? Colors.red.shade600
        : mp.isApproved
        ? Colors.green.shade600
        : context.color.territoryColor;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(mp.statusMessage!)
          .size(context.font.small)
          .color(color)
          .setMaxLines(lines: 4),
    );
  }




  Widget _pendingInfoBanner(BuildContext context) {
    final color = context.color.territoryColor;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(
        'جاري مراجعة هذه العملية. يتم تحديث الحالة تلقائيًا كل ${_pollInterval.inSeconds} ثانية.',
      ).size(context.font.small).color(color),
    );
  }





  Widget? _finalStatusSection(BuildContext context, ManualPayment mp) {
    final bool isFinalState = mp.isSucceeded || mp.isRejected;
    if (!isFinalState) return null;

    final String? message = _finalStatusMessage(mp);
    final Color color = mp.isSucceeded
        ? Colors.green.shade600
        : mp.isRejected
        ? Colors.red.shade600
        : context.color.territoryColor;

    final List<Widget> actions =
    _finalStatusActions(context, mp, color);

    if (message == null && actions.isEmpty) {
      return null;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (message != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Text(message)
                .size(context.font.small)
                .color(color)
                .setMaxLines(lines: 4),
          ),
        if (actions.isNotEmpty) ...[
          if (message != null) const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: actions,
          ),
        ],
      ],
    );
  }

  String? _finalStatusMessage(ManualPayment mp) {
    final String? type = _resolvePayableType(mp);
    if (type == null) return 'تمت معالجة العملية';

    switch (type) {
      case 'package':
        return 'تم تفعيل الباقة';
      case 'order':
        return 'تم تأكيد طلبك. يمكنك متابعة تفاصيله من قسم طلباتي.';
      default:
        return 'تمت معالجة العملية';
    }
  }

  List<Widget> _finalStatusActions(
      BuildContext context, ManualPayment mp, Color color) {
    final List<Widget> actions = [];
    final String? type = _resolvePayableType(mp);

    if (type == 'package') {
      actions.add(
        _finalActionButton(
          context,
          label: 'تفاصيل الباقة',
          color: color,
          icon: Icons.auto_awesome_outlined,
          onPressed: () => _openPackageDetails(mp),
        ),
      );
    }

    if (type == 'order') {
      actions.add(
        _finalActionButton(
          context,
          label: 'طلباتي',
          color: color,
          icon: Icons.receipt_long_outlined,
          onPressed: () => _openOrders(mp),
        ),
      );
    }

    return actions;
  }

  Widget _finalActionButton(
      BuildContext context, {
        required String label,
        required Color color,
        required VoidCallback onPressed,
        required IconData icon,
      }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withOpacity(0.6)),
        textStyle: TextStyle(
          fontSize: context.font.small,
          fontWeight: FontWeight.w600,
        ),
      ),
      icon: Icon(icon, size: context.font.larger),
      label: Text(label),
    );
  }

  String? _resolvePayableType(ManualPayment mp) {
    final dynamic rawType = mp.payable?['type'] ?? mp.payableType;
    if (rawType == null) return null;
    final String normalized = '$rawType'.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    if (normalized == 'package' || normalized == 'subscription_package') {
      return 'package';
    }
    if (normalized == 'order' || normalized == 'user_order') {
      return 'order';
    }
    return normalized;
  }

  void _openPackageDetails(ManualPayment mp) {
    final Map<String, dynamic>? arguments = _packageRouteArguments(mp);
    Navigator.of(context).pushNamed(
      Routes.subscriptionPackageListRoute,
      arguments: arguments,
    );
  }

  Map<String, dynamic>? _packageRouteArguments(ManualPayment mp) {
    final String? packageId = _resolveIdentifier(mp, const [
      'package_id',
      'packageId',
      'id',
    ]);
    final String? fallback = mp.payableId != null ? '${mp.payableId}' : null;
    final String? resolvedId = packageId ?? fallback;
    if (resolvedId == null) return null;
    return {'packageId': resolvedId};
  }

  void _openOrders(ManualPayment mp) {
    final String? orderId = _resolveIdentifier(mp, const [
      'order_id',
      'orderId',
      'id',
      'code',
      'order_code',
    ]) ??
        (mp.payableId != null ? '${mp.payableId}' : null);

    Navigator.of(context).pushNamed(
      Routes.orderSteps,
      arguments: orderId == null ? null : {'orderId': orderId},
    );
  }

  String? _resolveIdentifier(ManualPayment mp, List<String> keys) {
    if (mp.payable == null) return null;
    for (final key in keys) {
      final dynamic value = mp.payable![key];
      if (value == null) continue;
      final String stringValue = '$value'.trim();
      if (stringValue.isNotEmpty) {
        return stringValue;
      }
    }
    return null;
  }



  Widget _failureBanner(BuildContext context) {
    final color = Colors.red.shade600;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        'فشلت هذه العملية. يمكنك إعادة إرسال التحويل أو التواصل مع الدعم للمساعدة.',
      ).size(context.font.small).color(color),
    );
  }

  Widget _expiredBanner(BuildContext context) {
    final color = Colors.grey.shade600;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(
        'انتهت صلاحية هذه العملية. الرجاء إرسال تحويل جديد إذا كنت لا تزال ترغب في المتابعة.',
      ).size(context.font.small).color(color),
    );
  }

  Widget _refundedBanner(BuildContext context) {
    final color = Colors.blueGrey.shade600;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        'تم رد هذه العملية بنجاح. سيظهر المبلغ في حسابك حسب مزود الخدمة.',
      ).size(context.font.small).color(color),
    );
  }



  bool _shouldShowUpdatedAt(ManualPayment mp) {
    final updatedAt = mp.updatedAt;
    if (updatedAt == null) return false;
    return !updatedAt.isAtSameMomentAs(mp.createdAt);
  }

  Widget _lastUpdatedTag(BuildContext context, ManualPayment mp) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final textColor = onSurface.withOpacity(0.6);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: textColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: textColor.withOpacity(0.3)),
      ),
      child: Text('آخر تحديث: ${_formatDateTime(mp.updatedAt)}')
          .color(textColor)
          .size(context.font.smaller),
    );
  }



  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return '—';
    return _dateFormat.format(dateTime.toLocal());
  }



  Future<void> _copyToClipboard(BuildContext context, String value,
      {String? message}) async {
    await HapticFeedback.vibrate();
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message ?? "copied".translate(context))),
    );
  }

  Widget _sideBar({required Color color}) => Container(
    width: 4,
    height: 48,
    decoration: BoxDecoration(
      color: color,
      borderRadius: const BorderRadiusDirectional.only(
        topEnd: Radius.circular(4),
        bottomEnd: Radius.circular(4),
      ),
    ),
  );

  Widget _tag(String text, Color color) => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(6),
      color: color.withOpacity(0.1),
    ),
    padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 8),
    child: Text(text).size(12).color(color),
  );

  Widget _copyBtn(BuildContext context, String value) => GestureDetector(
    onTap: () => _copyToClipboard(context, value),
    child: Container(
      height: 30,
      width: 30,
      decoration: BoxDecoration(
        color: context.color.secondaryColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.color.borderColor, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(5.0),
        child: Icon(Icons.copy, size: context.font.larger),
      ),
    ),
  );


}


