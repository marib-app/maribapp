import 'package:flutter/material.dart';

import 'shared_widgets.dart';
import 'deposit_summary_card.dart';

/// قسم مخصّص لعرض سياسات الإرجاع، تفاصيل الوديعة، والتنبيهات الداعمة.
class PoliciesSection extends StatelessWidget {
  const PoliciesSection({
    super.key,
    this.loading = false,
    this.returnPolicyText,
    this.depositInfo,
    this.departmentNotice,
    this.supportInfo,
  });

  /// حالة التحميل لإظهار شريط وميض بدلاً من المحتوى الحقيقي.
  final bool loading;

  /// نص سياسة الاسترجاع المراد عرضه للمستخدم.
  final String? returnPolicyText;

  /// تفاصيل الوديعة المستخرجة (المبلغ، النسبة، الحد الأدنى، حالة الشحن).
  final Map<String, dynamic>? depositInfo;

  /// تنبيه القسم أو الإدارة المرتبط بهذه الطلبية.
  final String? departmentNotice;

  /// بيانات قنوات الدعم مثل رقم أو رابط الواتساب.
  final Map<String, dynamic>? supportInfo;

  bool get _hasDepositContent {
    final Map<String, dynamic>? data = depositInfo;
    if (data == null) return false;
    final dynamic amount = data['amountDueNow'];
    final dynamic percent = data['percent'];
    final dynamic includesShipping = data['includesShipping'];
    return _isNonEmptyString(amount) ||
        _isNonEmptyString(percent) ||
        includesShipping != null;
  }

  bool get _hasSupportContent {
    final Map<String, dynamic>? data = supportInfo;
    if (data == null || data.isEmpty) return false;
    return data.values.any(_isNonEmptyString);
  }

  bool get hasContent =>
      _hasDepositContent ||
          _isNonEmptyString(returnPolicyText) ||
          _isNonEmptyString(departmentNotice) ||
          _hasSupportContent;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return buildShimmerLine(context, width: double.infinity, height: 60);
    }

    if (!hasContent) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF2C2C2E)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300.withOpacity(0.6)),
        ),
        child: const Text(
          'لا توجد معلومات سياسات إضافية حاليًا.',
          style: TextStyle(fontSize: 14),
        ),
      );
    }

    final List<Widget> children = <Widget>[];

    if (_hasDepositContent) {
      children.add(_buildDepositCard(context));
    }

    if (_isNonEmptyString(returnPolicyText)) {
      if (children.isNotEmpty) {
        children.add(const SizedBox(height: 12));
      }
      children.add(_buildPolicyText(context));
    }

    if (_isNonEmptyString(departmentNotice)) {
      if (children.isNotEmpty) {
        children.add(const SizedBox(height: 12));
      }
      children.add(_buildNoticeCard(context));
    }

    if (_hasSupportContent) {
      if (children.isNotEmpty) {
        children.add(const SizedBox(height: 12));
      }
      children.add(_buildSupportCard(context));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  /// يبني بطاقة صغيرة توضح تفاصيل الوديعة بالأرقام والنسب.
  Widget _buildDepositCard(BuildContext context) {
    return DepositSummaryCard(data: depositInfo);

  }

  /// يعرض نص سياسة الاسترجاع بتنسيق واضح ومقروء.
  Widget _buildPolicyText(BuildContext context) {
    return buildReturnPolicyCard(context, returnPolicyText!);

  }

  /// يبرز أي ملاحظة خاصة بالقسم أو الإدارة لمساعدة المستخدم.
  Widget _buildNoticeCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF2A2A2D)
            : const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.lightBlueAccent.withOpacity(0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.info_outline, color: Colors.blueAccent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              departmentNotice!,
              style: const TextStyle(fontSize: 13.5, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  /// يوفّر معلومات التواصل مع الدعم مثل رقم الواتساب أو الرسائل الجاهزة.
  Widget _buildSupportCard(BuildContext context) {
    final Map<String, dynamic>? data = supportInfo;
    final String? label = _stringOrNull(data?['whatsappLabel']);
    final String? number = _stringOrNull(data?['whatsappNumber']);
    final String? url = _stringOrNull(data?['whatsappUrl']);
    final String? message = _stringOrNull(data?['whatsappMessage']);

    final List<Widget> lines = <Widget>[];
    if (_isNonEmptyString(label)) {
      lines.add(Text(label!, style: const TextStyle(fontWeight: FontWeight.bold)));
    }
    if (_isNonEmptyString(number)) {
      lines.add(Text('رقم التواصل: $number'));
    }
    if (_isNonEmptyString(url)) {
      lines.add(Text('الرابط المباشر: $url', style: const TextStyle(decoration: TextDecoration.underline)));
    }
    if (_isNonEmptyString(message)) {
      lines.add(Text('رسالة جاهزة: $message'));
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF2F2F31)
            : const Color(0xFFF1F8E9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.greenAccent.withOpacity(0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.support_agent, color: Colors.green),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: lines,
            ),
          ),
        ],
      ),
    );
  }

  /// يبني صفًا نصيًا بمظهر موحّد بين جميع الأقسام الفرعية.
  Widget _buildInfoRow(
      BuildContext context,
      String label,
      String value, {
        Color? valueColor,
      }) {
    final TextStyle labelStyle = TextStyle(
      color: Theme.of(context).brightness == Brightness.dark
          ? Colors.white70
          : Colors.grey.shade700,
      fontSize: 13,
    );

    final TextStyle valueStyle = TextStyle(
      color: valueColor ?? Theme.of(context).colorScheme.onSurface,
      fontWeight: FontWeight.w600,
      fontSize: 13,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(child: Text(label, style: labelStyle)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: valueStyle,
            ),
          ),
        ],
      ),
    );
  }

  bool _isNonEmptyString(dynamic value) {
    if (value is String) {
      return value.trim().isNotEmpty;
    }
    return false;
  }

  String? _stringOrNull(dynamic value) {
    if (value is String) {
      final String trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    return null;
  }
}