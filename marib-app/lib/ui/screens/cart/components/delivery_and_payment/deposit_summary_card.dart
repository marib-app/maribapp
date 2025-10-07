import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DepositSummaryCard extends StatelessWidget {
  const DepositSummaryCard({
    super.key,
    required this.data,
    this.onToggle,
  });

  final Map<String, dynamic>? data;
  final ValueChanged<bool>? onToggle;


  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> deposit = data ?? <String, dynamic>{};
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    final bool toggleAllowedRaw = deposit.containsKey('toggleAllowed')
        ? _asBool(deposit['toggleAllowed'])
        : true;
    final bool toggleAllowed = toggleAllowedRaw && onToggle != null;

    final bool toggleRequired = _asBool(deposit['toggleRequired']);
    final bool appliedRaw = _asBool(deposit['applied']);
    final bool serverEnabled =
        _asBool(deposit['depositEnabled']) || _asBool(deposit['enabled']);
    final bool toggleValue = deposit.containsKey('toggleValue')
        ? _asBool(deposit['toggleValue'])
        : (toggleAllowed ? serverEnabled : appliedRaw);

    final bool depositActive = toggleRequired ||
        (!toggleAllowed && (serverEnabled || appliedRaw)) ||

        (toggleAllowed && toggleValue);
    final bool previewMode = toggleAllowed && !depositActive;

    final String title =
        _asString(deposit['title']) ?? 'تفاصيل الدفعة المقدمة';
    final String? toggleLabel = _asString(deposit['toggleLabel']);
    final String? toggleDescription = _asString(deposit['toggleDescription']);


    final String? totalDisplay =
        _asString(deposit['effectiveTotalDisplay']) ??
            _asString(deposit['totalAmount']);
    final String? amountDueDisplay =
        _asString(deposit['effectiveAmountDueDisplay']) ??
            _asString(deposit['previewAmountDueDisplay']) ??
            _asString(deposit['amountDueNow']);

    final String? rawRemainingDisplay =
        _asString(deposit['effectiveRemainingDisplay']) ??
            _asString(deposit['previewRemainingDisplay']) ??
            _asString(deposit['remainingBalance']);

    final String? remainingDisplay = depositActive
        ? rawRemainingDisplay
        : (previewMode ? rawRemainingDisplay : null);


    final double? amountDueValue =
        _asDouble(deposit['effectiveAmountDueValue']) ??
            _asDouble(deposit['amountDueNowValue']);
    final double? totalValue =
        _asDouble(deposit['effectiveTotalValue']) ??
            _asDouble(deposit['totalAmountValue']);
    final double? ratioValue = _asDouble(deposit['ratioValue']) ??
        ((amountDueValue != null && totalValue != null && totalValue != 0)

            ? amountDueValue / totalValue
            : null);
    final String? percent =
        _asString(deposit['percent']) ?? _formatPercentFromRatio(ratioValue);



    final String? goodsValue = _asString(deposit['goodsValue']);
    final String? shippingFee = _asString(deposit['shippingFee']);


    final bool? includesShipping = deposit['includesShipping'] as bool?;
    final bool hasDetails = <String?>[
      totalDisplay,
      amountDueDisplay,
      rawRemainingDisplay,
      percent,
      goodsValue,
      shippingFee,
    ].any((String? value) => value != null && value.trim().isNotEmpty);


    // لا نعرض التفاصيل الحساسة (المبلغ المطلوب والمبلغ المتبقي) إلا بعد التفعيل الفعلي
    // للدفعة المقدمة، وذلك ليتوافق مع السلوك المطلوب من النقر على البطاقة لتفعيلها
    // ثم الكشف عن الأرقام ذات الصلة للمستخدم.
    final bool showDetails = hasDetails && depositActive;

    final String? previewMessage =
        _asString(deposit['previewMessage']) ?? _asString(deposit['inactiveMessage']);
    String? message = depositActive
        ? _asString(deposit['message'])
        : previewMessage;


    if (message == null) {
      if (depositActive) {
        if (percent != null && amountDueDisplay != null && totalDisplay != null) {
          message =
          'يمكنك دفع $percent من إجمالي طلبك ($totalDisplay) كدفعة مقدمة الآن بمبلغ $amountDueDisplay، وسيتم تحصيل المبلغ المتبقي لاحقًا.';
        } else if (percent != null && amountDueDisplay != null) {
          message =
          'يمكنك دفع $percent من قيمة طلبك الآن بمبلغ $amountDueDisplay، ويتم تحصيل الباقي لاحقًا.';
        } else if (percent != null) {
          message =
          'يمكنك دفع $percent من إجمالي الطلب كدفعة مقدمة الآن، ويتم تحصيل الباقي لاحقًا.';
        } else if (amountDueDisplay != null && totalDisplay != null) {
          message =
          'يمكنك دفع $amountDueDisplay الآن من أصل $totalDisplay، وسيتم تحصيل المتبقي عند التسليم.';
        }
      } else {
        if (percent != null && totalDisplay != null) {
          message =
          'عند تفعيل الدفعة المقدمة ستدفع $percent من إجمالي طلبك ($totalDisplay) الآن ويتم جدولة الباقي لاحقًا.';
        } else if (percent != null) {
          message =
          'يمكنك تفعيل خيار الدفعة المقدمة لدفع $percent من قيمة طلبك الآن وترك الباقي للتسليم.';
        } else if (totalDisplay != null) {
          message =
          'يمكنك دفع جزء من إجمالي طلبك ($totalDisplay) مقدمًا وترك المتبقي للتسليم عند تفعيل هذا الخيار.';
        } else {
          message =
          'يمكنك تفعيل خيار الدفعة المقدمة لدفع جزء من المبلغ الآن وترك الباقي لحين التسليم. لن يتم احتساب الدفعة إلا بعد اختيار هذا الخيار.';
        }
      }
    }


    final String statusText = toggleRequired
        ? 'إجباري'
        : (depositActive ? 'مفعّلة' : 'غير مفعّلة');
    final Color statusColor = toggleRequired
        ? Colors.deepOrange
        : (depositActive ? Colors.teal : Colors.blueGrey);


    final List<Widget> badges = <Widget>[
      _buildBadge(statusText, statusColor, isDark),
    ];
    if (toggleAllowed && !toggleRequired) {
      badges.add(_buildBadge('اختياري', Colors.indigo, isDark));
    }
    if (includesShipping == true) {
      badges.add(_buildBadge('يشمل الشحن', Colors.lightBlue, isDark));
    }

    String? shippingNote;
    if (includesShipping == true) {
      shippingNote = '📦 رسوم الشحن مشمولة ضمن الدفعة المقدمة.';
    } else if (includesShipping == false && shippingFee != null) {
      shippingNote = '🚚 يتم تحصيل رسوم الشحن مع المبلغ المتبقي عند التسليم.';
    }

    if (deposit.isEmpty && !toggleAllowed && !toggleRequired) {
      return _buildEmptyState(isDark);
    }

    final BorderRadius borderRadius = BorderRadius.circular(12);

    return MouseRegion(
      cursor: SystemMouseCursors.basic,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: borderRadius,
          splashColor: Colors.teal.withOpacity(0.12),
          highlightColor: isDark ? Colors.teal.withOpacity(0.08) : Colors.teal.withOpacity(0.05),

          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1F1F21) : Colors.white,
              borderRadius: borderRadius,
              border: Border.all(color: Colors.blueGrey.withOpacity(0.25)),
              boxShadow: [
                if (!isDark)
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.teal.shade700 : Colors.teal.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.savings_outlined,
                        color: isDark ? Colors.white : Colors.teal.shade700,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF1F1F1F),
                            ),
                          ),
                          if (badges.isNotEmpty) ...<Widget>[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: badges,
                            ),
                          ],
                          if (message != null) ...<Widget>[
                            const SizedBox(height: 10),
                            Text(
                              message!,
                              style: TextStyle(
                                fontSize: 13.5,
                                height: 1.5,
                                color: isDark
                                    ? Colors.grey.shade300
                                    : Colors.blueGrey.shade700,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                if (toggleAllowed) ...<Widget>[
                  const SizedBox(height: 14),
                  _buildToggle(
                    context,
                    label: toggleLabel ?? 'تفعيل الدفعة المقدمة',
                    description: toggleDescription,
                    value: toggleValue,
                    onChanged: onToggle!,
                  ),
                ] else if (toggleRequired) ...<Widget>[
                  const SizedBox(height: 14),
                  _buildMandatoryNotice(context, toggleDescription),
                ] else if (toggleDescription != null) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(
                    toggleDescription,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? Colors.grey.shade300
                          : Colors.blueGrey.shade600,
                    ),
                  ),
                ],
                if (showDetails) ...<Widget>[
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: depositActive ? 1 : 0.45,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        ..._buildDetails(
                          context,
                          totalDisplay: totalDisplay,
                          amountDueDisplay: amountDueDisplay,
                          remainingDisplay: remainingDisplay,
                          percent: percent,
                          goodsValue: goodsValue,
                          shippingFee: shippingFee,
                          includesShipping: includesShipping,
                          isDark: isDark,
                          previewMode: previewMode,
                        ),
                        if (shippingNote != null) ...<Widget>[
                          const SizedBox(height: 12),
                          Text(
                            shippingNote,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: isDark
                                  ? Colors.grey.shade300
                                  : Colors.blueGrey.shade600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (previewMode)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        'سيتم تطبيق هذه القيم بعد تفعيل خيار الدفعة المقدمة أعلاه.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: isDark
                              ? Colors.grey.shade300
                              : Colors.blueGrey.shade600,
                        ),
                      ),
                    ),
                ] else if (!depositActive && toggleAllowed && !showDetails) ...<Widget>[
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  Text(
                    'لن يتم عرض تفاصيل الدفعة المقدمة أو احتسابها ما لم يتم تفعيل الخيار من خلال المفتاح أعلاه.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark
                          ? Colors.grey.shade300
                          : Colors.blueGrey.shade600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildEmptyState(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F1F21) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blueGrey.withOpacity(0.25)),
      ),
      child: Text(
        'لم يتم توفير تفاصيل الدفعة المقدمة بعد.',
        style: TextStyle(
          color: isDark ? Colors.grey.shade300 : Colors.blueGrey.shade700,
          fontSize: 13.5,
        ),
      ),
    );
  }

  Widget _buildBadge(String label, Color color, bool isDark) {
    final Color textColor = isDark
        ? Colors.white
        : Color.lerp(color, Colors.black, 0.35) ?? color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.45 : 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildToggle(
      BuildContext context, {
        required String label,
        String? description,
        required bool value,
        required ValueChanged<bool> onChanged,
      }) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2D) : const Color(0xFFF4F6FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.tealAccent.withOpacity(0.2)
              : Colors.teal.withOpacity(0.25),
        ),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1F1F1F),
                  ),
                ),
                if (description != null && description.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      description,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark
                            ? Colors.grey.shade300
                            : Colors.blueGrey.shade600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.teal,
          ),
        ],
      ),
    );
  }

  Widget _buildMandatoryNotice(BuildContext context, String? description) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final String resolved = description ??
        'تطبيق الدفعة المقدمة إلزامي في هذا القسم، وسيتم تحصيل الجزء المتبقي عند التسليم.';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF3A2A1F) : const Color(0xFFFFF4E5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.deepOrangeAccent.withOpacity(0.4)
              : Colors.orange.shade200,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            Icons.lock_outline,
            color: isDark
                ? Colors.orangeAccent.shade100
                : Colors.orange.shade700,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              resolved,
              style: TextStyle(
                fontSize: 12.8,
                height: 1.5,
                color: isDark
                    ? Colors.orangeAccent.shade100
                    : Colors.orange.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildDetails(
      BuildContext context, {
        String? totalDisplay,
        String? amountDueDisplay,
        String? remainingDisplay,
        String? percent,
        String? goodsValue,
        String? shippingFee,
        bool? includesShipping,
        bool previewMode = false,

        required bool isDark,
      }) {
    final List<Widget> rows = <Widget>[];

    void addRow(String label, String? value,
        {Color? valueColor, IconData? icon}) {
      if (value == null || value.trim().isEmpty) {
        return;
      }
      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(
                  icon,
                  size: 18,
                  color: isDark
                      ? Colors.grey.shade300
                      : Colors.blueGrey.shade400,
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13.2,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? Colors.grey.shade200
                        : const Color(0xFF1F1F1F),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13.2,
                  fontWeight: FontWeight.w700,
                  color: valueColor ??
                      (isDark
                          ? Colors.white
                          : Colors.blueGrey.shade900),
                ),
                textAlign: TextAlign.end,
              ),
            ],
          ),
        ),
      );
    }

    addRow('إجمالي الطلب', totalDisplay, icon: Icons.receipt_long_outlined);
    final Color dueColor = previewMode
        ? (isDark ? Colors.grey.shade400 : Colors.blueGrey.shade500)
        : (isDark ? Colors.tealAccent.shade200 : Colors.teal.shade700);
    addRow(
      'المبلغ المطلوب الآن',
      amountDueDisplay,
      icon: Icons.payments_outlined,
      valueColor: dueColor,

    );
    if (remainingDisplay != null && remainingDisplay.trim().isNotEmpty) {
      final Color remainingColor = previewMode
          ? (isDark ? Colors.grey.shade500 : Colors.orange.shade300)
          : (isDark ? Colors.orange.shade200 : Colors.orange.shade700);

      addRow(
        'المتبقي عند التسليم',
        remainingDisplay,
        icon: Icons.schedule_outlined,
        valueColor: remainingColor,

      );
    }
    addRow('نسبة الدفعة المقدمة', percent, icon: Icons.percent);
    addRow('قيمة المنتجات', goodsValue, icon: Icons.shopping_bag_outlined);
    final String? shippingLabel;
    if (shippingFee != null && shippingFee.trim().isNotEmpty) {
      shippingLabel = includesShipping == false
          ? '$shippingFee (غير مشمولة)'
          : shippingFee;
    } else {
      shippingLabel = shippingFee;
    }
    addRow('رسوم التوصيل', shippingLabel, icon: Icons.local_shipping_outlined);

    return rows;
  }
  String? _asString(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      final String trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    return value.toString();
  }

  bool _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final String normalized = value.trim().toLowerCase();
      if (normalized.isEmpty) return false;
      return <String>{'1', 'true', 'yes', 'y', 'on'}.contains(normalized);
    }
    return false;
  }

  double? _asDouble(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      final String sanitized = value.replaceAll(RegExp(r'[^0-9.,-]'), '');
      if (sanitized.isEmpty) {
        return null;
      }
      final String normalized = sanitized.contains(',') && !sanitized.contains('.')
          ? sanitized.replaceAll(',', '.')
          : sanitized.replaceAll(',', '');
      return double.tryParse(normalized);
    }
    return null;
  }

  String? _formatPercentFromRatio(double? ratio) {
    if (ratio == null) {
      return null;
    }
    double value = ratio;
    if (value <= 1 && value >= -1) {
      value *= 100;
    }
    final bool isInteger = value % 1 == 0;
    final String formatted;
    if (isInteger) {
      formatted = value.toStringAsFixed(0);
    } else if (value.abs() >= 10) {
      formatted = value.toStringAsFixed(1);
    } else {
      formatted = value.toStringAsFixed(2);
    }
    return '$formatted%';
  }
}