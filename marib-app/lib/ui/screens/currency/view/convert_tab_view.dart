import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:marib/data/model/currency_rate.dart';

import '../state/state.dart';

class ConvertTabView extends StatelessWidget {
  const ConvertTabView({
    super.key,
    required this.state,
    required this.amountController,
    required this.onChangeFrom,
    required this.onChangeTo,
    required this.onAmountChanged,
    required this.onReset,
    required this.onConvert,
    required this.amountInputFormatters,
    required this.brand,
    required this.onGovernorateChanged,
  });

  final CurrencyViewState state;
  final TextEditingController amountController;
  final ValueChanged<String> onChangeFrom;
  final ValueChanged<String> onChangeTo;
  final ValueChanged<String> onAmountChanged;
  final VoidCallback onReset;
  final VoidCallback onConvert;
  final List<TextInputFormatter> amountInputFormatters;
  final Color brand;
  final void Function(String?) onGovernorateChanged;

  bool _isDark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;

  // ——— دوال داخلية ———

  String _format(double value) => NumberFormat('#,##0.000').format(value);

  OutlineInputBorder _border(BuildContext context) {
    final color = _isDark(context) ? Colors.white12 : Colors.black12;
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color),
    );
  }

  Widget _labeledBox(BuildContext context, String label, Widget child) {
    final onBg = _isDark(context) ? Colors.white : Colors.black;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
              color: onBg.withOpacity(0.7),
              fontWeight: FontWeight.w700,
            )),
        const SizedBox(height: 6),
        child,
      ],
    );
  }

  Widget _swapButton(BuildContext context) {
    return Center(
      child: InkResponse(
        onTap: () {
          if (state.toCurrency.isNotEmpty && state.fromCurrency.isNotEmpty) {
            final oldFrom = state.fromCurrency;
            final oldTo = state.toCurrency;
            onChangeFrom(oldTo);
            onChangeTo(oldFrom);
          }
        },
        radius: 28,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: brand.withOpacity(0.45)),
          ),
          child: Icon(Icons.swap_vert, color: brand),
        ),
      ),
    );
  }

  Widget _resultStrip(BuildContext context, String value) {
    final onBg = _isDark(context) ? Colors.white : Colors.black;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: brand.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              "المبلغ المحول",
              style: TextStyle(
                color: onBg.withOpacity(0.75),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: onBg,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _primaryBtn(BuildContext context,
      {required String label,
      required IconData icon,
      required VoidCallback onPressed}) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: brand,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _ghostBtn(BuildContext context,
      {required String label,
      required IconData icon,
      required VoidCallback onPressed}) {
    final onBg = _isDark(context) ? Colors.white : Colors.black;
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: onBg),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: onBg.withOpacity(0.25)),
        foregroundColor: onBg,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    );
  }

  CurrencyRate? _resolveSelectedCurrencyRate() {
    final Iterable<dynamic> entries = state.rates;
    final String? currencyName = state.fromCurrency.isNotEmpty
        ? state.fromCurrency
        : (state.toCurrency.isNotEmpty ? state.toCurrency : null);
    if (currencyName == null) {
      return null;
    }
    for (final dynamic entry in entries) {
      if (entry is CurrencyRate && entry.currencyName == currencyName) {
        return entry;
      }
    }
    return null;
  }

  Widget _infoCard(BuildContext context,
      {required String label, required String value}) {
    final onBg = _isDark(context) ? Colors.white : Colors.black;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: brand.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: onBg.withOpacity(0.7),
              fontWeight: FontWeight.w600,
            ),
            textDirection: TextDirection.rtl,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: onBg,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
            textDirection: TextDirection.rtl,
          ),
        ],
      ),
    );
  }

  Widget _governorateSection(BuildContext context) {
    final theme = Theme.of(context);
    final onBg = _isDark(context) ? Colors.white : Colors.black;
    const defaultValue = '_default_';

    final List<DropdownMenuItem<String>> items = [
      const DropdownMenuItem<String>(
        value: defaultValue,
        child: Text(
          'المتوسط الافتراضي الوطني',
          textDirection: TextDirection.rtl,
        ),
      ),
      ...state.governorates.map((Map<String, String?> governorate) {
        final String code = (governorate['code'] ?? '').toString();
        if (code.isEmpty) {
          return null;
        }
        final dynamic rawName = governorate['name'];
        final String label =
            (rawName is String && rawName.isNotEmpty) ? rawName : code;
        return DropdownMenuItem<String>(
          value: code,
          child: Text(
            label,
            textDirection: TextDirection.rtl,
          ),
        );
      }).whereType<DropdownMenuItem<String>>(),
    ];

    final String selectedValue = (state.selectedGovernorateCode ?? '').isEmpty
        ? defaultValue
        : state.selectedGovernorateCode!;
    final bool hasSelectedItem = items
        .any((DropdownMenuItem<String> item) => item.value == selectedValue);
    if (!hasSelectedItem && selectedValue != defaultValue) {
      final String fallbackLabel = state.appliedGovernorateName ??
          state.requestedGovernorateName ??
          selectedValue;
      items.add(
        DropdownMenuItem<String>(
          value: selectedValue,
          child: Text(
            fallbackLabel,
            textDirection: TextDirection.rtl,
          ),
        ),
      );
    }
    final bool enabled = items.length > 1;

    final CurrencyRate? selectedRate = _resolveSelectedCurrencyRate();
    final bool hasSelectedGovernorate =
        (state.selectedGovernorateCode ?? '').isNotEmpty;
    final bool canDisplayRates = hasSelectedGovernorate && selectedRate != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'أسعار المحافظة',
          style: theme.textTheme.titleMedium?.copyWith(
            color: onBg,
            fontWeight: FontWeight.w800,
          ),
          textDirection: TextDirection.rtl,
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          key: const Key('convertGovernorateDropdown'),
          value: selectedValue,
          items: items,
          onChanged: enabled
              ? (String? value) {
                  if (value == defaultValue) {
                    onGovernorateChanged(null);
                  } else {
                    onGovernorateChanged(value);
                  }
                }
              : null,
          decoration: InputDecoration(
            border: _border(context),
            enabledBorder: _border(context),
            focusedBorder: _border(context),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: brand),
          dropdownColor: theme.scaffoldBackgroundColor,
          style: theme.textTheme.bodyLarge?.copyWith(color: onBg),
        ),
        const SizedBox(height: 12),
        if (canDisplayRates)
          Row(
            children: [
              Expanded(
                child: _infoCard(
                  context,
                  label: 'سعر البيع',
                  value: _format(selectedRate!.sellPrice),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _infoCard(
                  context,
                  label: 'سعر الشراء',
                  value: _format(selectedRate.buyPrice),
                ),
              ),
            ],
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: onBg.withOpacity(0.12)),
              color: onBg.withOpacity(_isDark(context) ? 0.04 : 0.03),
            ),
            child: Text(
              'اختر المحافظة لعرض أسعار البيع والشراء للعملة المختارة.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: onBg.withOpacity(0.55),
                fontWeight: FontWeight.w600,
              ),
              textDirection: TextDirection.rtl,
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final edge = const EdgeInsets.fromLTRB(12, 8, 12, 18);

    String _name(d) => (d as dynamic).currencyName?.toString() ?? '';
    final all = state.rates;
    final fromItems = all.map<DropdownMenuItem<String>>((r) {
      final v = _name(r);
      return DropdownMenuItem(value: v, child: Text(v));
    }).toList(growable: false);
    final toItems = all
        .where((r) => _name(r) != state.fromCurrency)
        .map<DropdownMenuItem<String>>((r) {
      final v = _name(r);
      return DropdownMenuItem(value: v, child: Text(v));
    }).toList(growable: false);

    return SingleChildScrollView(
      padding: edge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _governorateSection(context),
          const SizedBox(height: 16),
          // من
          _labeledBox(
            context,
            'من',
            DropdownButtonFormField<String>(
              value: state.fromCurrency.isEmpty ? null : state.fromCurrency,
              items: fromItems,
              onChanged: (v) => v != null ? onChangeFrom(v) : null,
              decoration: InputDecoration(
                border: _border(context),
                enabledBorder: _border(context),
                focusedBorder: _border(context),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // تبادل
          _swapButton(context),
          const SizedBox(height: 10),

          // إلى
          _labeledBox(
            context,
            'إلى',
            DropdownButtonFormField<String>(
              value: state.toCurrency.isEmpty ? null : state.toCurrency,
              items: toItems,
              onChanged: (v) => v != null ? onChangeTo(v) : null,
              decoration: InputDecoration(
                border: _border(context),
                enabledBorder: _border(context),
                focusedBorder: _border(context),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // المبلغ
          _labeledBox(
            context,
            'المبلغ',
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              inputFormatters: amountInputFormatters,
              onChanged: onAmountChanged,
              decoration: InputDecoration(
                hintText: "ادخل المبلغ",
                border: _border(context),
                enabledBorder: _border(context),
                focusedBorder: _border(context),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // النتيجة
          _resultStrip(
            context,
            state.hasCalculated
                ? "${NumberFormat('#,##0.##').format(state.convertedAmount)} ${state.toCurrency}"
                : "---",
          ),
          const SizedBox(height: 12),

          // الأزرار
          Row(
            children: [
              Expanded(
                child: _primaryBtn(context,
                    label: "تحويل", icon: Icons.check, onPressed: onConvert),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ghostBtn(context,
                    label: "تصفير", icon: Icons.refresh, onPressed: onReset),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ===================================================================
// تبويب 3: الذهب — نفس منطق الأسعار مع فلترة (ذهب/عيار/Gold)
// ===================================================================
