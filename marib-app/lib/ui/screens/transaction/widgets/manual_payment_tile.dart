import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'package:marib/app/routes.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/payment/manual_payment.dart';
import 'package:flutter/material.dart';

class ManualPaymentTile extends StatelessWidget {
  const ManualPaymentTile({
    super.key,
    required this.manualPayment,
    required this.dateFormat,
    required this.pollInterval,
  });

  final ManualPayment manualPayment;
  final DateFormat dateFormat;
  final Duration pollInterval;

  @override
  Widget build(BuildContext context) {
    final ManualPayment mp = manualPayment;
    final Color statusColor = mp.statusColor;
    final String statusLabel = mp.statusLabelAr;
    final Color gatewayColor = mp.isEastYemen ? context.color.territoryColor : statusColor;
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
        children: <Widget>[
          _sideBar(color: statusColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _tag(mp.gatewayLabel, gatewayColor),
                    const Spacer(),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(mp.amountValueLabel)
                            .bold(weight: FontWeight.w700)
                            .size(18)
                            .color(context.color.territoryColor),
                        if (mp.currencyLabel != null) ...<Widget>[
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
                    children: <Widget>[
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
                      if (_shouldShowUpdatedAt(mp)) ...<Widget>[
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
                const SizedBox(height: 6),
                _infoRow(
                  context,
                  label: 'نوع العملية',
                  value: mp.categoryLabelAr ?? '',
                  icon: mp.categoryIcon,
                ),
                if (mp.isServiceRequest && mp.serviceDetailsLabel != null) ...<Widget>[
                  const SizedBox(height: 6),
                  _infoRow(
                    context,
                    label: 'الخدمة',
                    value: mp.serviceDetailsLabel!,
                    icon: Icons.home_repair_service_outlined,
                  ),
                ],
                if (mp.manualPaymentDisplayId != null) ...<Widget>[
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
                    mp.transactionReference != mp.displayTransactionIdentifier) ...<Widget>[
                  const SizedBox(height: 6),
                  _infoRow(
                    context,
                    label: 'مرجع المعاملة',
                    value: mp.transactionReference!,
                    icon: Icons.numbers_outlined,
                    allowCopy: true,
                  ),
                ],
                if (mp.manualReference != null && mp.manualReference!.isNotEmpty) ...<Widget>[
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
                if (mp.approvedAt != null) ...<Widget>[
                  const SizedBox(height: 6),
                  _infoRow(
                    context,
                    label: 'تاريخ الموافقة',
                    value: _formatDateTime(mp.approvedAt),
                    icon: Icons.verified_outlined,
                  ),
                ],
                if (mp.payableSummary != null) ...<Widget>[
                  const SizedBox(height: 6),
                  _infoRow(
                    context,
                    label: 'الجهة المرتبطة',
                    value: mp.payableSummary!,
                    icon: Icons.link_outlined,
                  ),
                ],
                if (mp.additionalHighlights.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 6),
                  ...mp.additionalHighlights.map(
                    (String line) => Padding(
                      padding: const EdgeInsetsDirectional.only(start: 4, top: 2),
                      child: Text('• $line')
                          .size(context.font.small)
                          .color(Theme.of(context).colorScheme.onSurface.withOpacity(0.8)),
                    ),
                  ),
                ],
                if (mp.statusMessage != null && mp.statusMessage!.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 12),
                  _statusMessageBanner(context, mp),
                ],
                if (mp.isExpired) ...<Widget>[
                  const SizedBox(height: 12),
                  _expiredBanner(context),
                ] else if (mp.isFailure && (mp.statusMessage == null || mp.statusMessage!.isEmpty)) ...<Widget>[
                  const SizedBox(height: 12),
                  _failureBanner(context),
                ] else if (mp.isRefunded && (mp.statusMessage == null || mp.statusMessage!.isEmpty)) ...<Widget>[
                  const SizedBox(height: 12),
                  _refundedBanner(context),
                ] else if (mp.shouldAutoRefresh) ...<Widget>[
                  const SizedBox(height: 12),
                  _pendingInfoBanner(context),
                ],
                if (finalStatusWidget != null) ...<Widget>[
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

  Widget _infoRow(
    BuildContext context, {
    required String label,
    required String value,
    IconData? icon,
    bool allowCopy = false,
  }) {
    final Color labelColor = Theme.of(context).colorScheme.onSurface.withOpacity(0.6);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
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
            children: <Widget>[
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
    final Color color = context.color.territoryColor;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(
        'جاري مراجعة هذه العملية. يتم تحديث الحالة تلقائيًا كل ${pollInterval.inSeconds} ثانية.',
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

    final List<Widget> actions = _finalStatusActions(context, mp, color);

    if (message == null && actions.isEmpty) {
      return null;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
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
        if (actions.isNotEmpty) ...<Widget>[
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

  List<Widget> _finalStatusActions(BuildContext context, ManualPayment mp, Color color) {
    final List<Widget> actions = <Widget>[];
    final String? type = _resolvePayableType(mp);

    if (type == 'package') {
      actions.add(
        _finalActionButton(
          context,
          label: 'تفاصيل الباقة',
          color: color,
          icon: Icons.auto_awesome_outlined,
          onPressed: () => _openPackageDetails(context, mp),
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
          onPressed: () => _openOrders(context, mp),
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

  void _openPackageDetails(BuildContext context, ManualPayment mp) {
    final Map<String, dynamic>? arguments = _packageRouteArguments(mp);
    Navigator.of(context).pushNamed(
      Routes.subscriptionPackageListRoute,
      arguments: arguments,
    );
  }

  Map<String, dynamic>? _packageRouteArguments(ManualPayment mp) {
    final String? packageId = _resolveIdentifier(mp, <String>[
      'package_id',
      'packageId',
      'id',
    ]);
    final String? fallback = mp.payableId != null ? '${mp.payableId}' : null;
    final String? resolvedId = packageId ?? fallback;
    if (resolvedId == null) return null;
    return <String, dynamic>{'packageId': resolvedId};
  }

  void _openOrders(BuildContext context, ManualPayment mp) {
    final String? orderId = _resolveIdentifier(mp, <String>[
          'order_id',
          'orderId',
          'id',
          'code',
          'order_code',
        ]) ??
        (mp.payableId != null ? '${mp.payableId}' : null);

    Navigator.of(context).pushNamed(
      Routes.orderSteps,
      arguments: orderId == null ? null : <String, dynamic>{'orderId': orderId},
    );
  }

  String? _resolveIdentifier(ManualPayment mp, List<String> keys) {
    if (mp.payable == null) return null;
    for (final String key in keys) {
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
    final Color color = Colors.red.shade600;
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
    final Color color = Colors.grey.shade600;
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
    final Color color = Colors.blueGrey.shade600;
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
    final DateTime? updatedAt = mp.updatedAt;
    if (updatedAt == null) return false;
    return !updatedAt.isAtSameMomentAs(mp.createdAt);
  }

  Widget _lastUpdatedTag(BuildContext context, ManualPayment mp) {
    final Color onSurface = Theme.of(context).colorScheme.onSurface;
    final Color textColor = onSurface.withOpacity(0.6);
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
    return dateFormat.format(dateTime.toLocal());
  }

  Future<void> _copyToClipboard(BuildContext context, String value, {String? message}) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    await HapticFeedback.vibrate();
    await Clipboard.setData(ClipboardData(text: value));
    messenger.showSnackBar(
      SnackBar(content: Text(message ?? 'copied'.translate(context))),
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