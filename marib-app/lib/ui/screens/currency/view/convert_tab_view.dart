import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' show NumberFormat;

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

  bool _isDark(BuildContext c) =>
      Theme
          .of(c)
          .brightness == Brightness.dark;

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
      {required String label, required IconData icon, required VoidCallback onPressed}) {
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
      {required String label, required IconData icon, required VoidCallback onPressed}) {
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

  @override
  Widget build(BuildContext context) {
    final edge = const EdgeInsets.fromLTRB(12, 8, 12, 18);

    String _name(d) => (d as dynamic).currencyName?.toString() ?? '';
    final all = state.rates;
    final fromItems = all
        .map<DropdownMenuItem<String>>((r) {
      final v = _name(r);
      return DropdownMenuItem(value: v, child: Text(v));
    })
        .toList(growable: false);
    final toItems = all
        .where((r) => _name(r) != state.fromCurrency)
        .map<DropdownMenuItem<String>>((r) {
      final v = _name(r);
      return DropdownMenuItem(value: v, child: Text(v));
    })
        .toList(growable: false);

    return SingleChildScrollView(

      padding: edge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 12),
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
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 12),
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
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // النتيجة
          _resultStrip(
            context,
            state.hasCalculated
                ? "${NumberFormat('#,##0.##').format(
                state.convertedAmount)} ${state.toCurrency}"
                : "---",
          ),
          const SizedBox(height: 12),

          // الأزرار
          Row(
            children: [
              Expanded(
                child: _primaryBtn(context, label: "تحويل",
                    icon: Icons.check,
                    onPressed: onConvert),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ghostBtn(context, label: "تصفير",
                    icon: Icons.refresh,
                    onPressed: onReset),
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