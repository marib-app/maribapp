import 'dart:math' as math;

import 'package:characters/characters.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:marib/data/model/currency_rate.dart';
import 'package:flutter/foundation.dart';

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
    this.onShowAdvancedDetails,
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
  final VoidCallback? onShowAdvancedDetails;

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

  Widget _swapButton(bool isDarkContext) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: isDarkContext ? 0 : 1,
      shape: const CircleBorder(),
      child: IconButton(
        key: const Key('swapCurrenciesAction'),
        tooltip: 'تبديل العملات',
        icon: Icon(Icons.swap_horiz_rounded, color: brand),
        onPressed: () {
          if (state.toCurrency.isNotEmpty && state.fromCurrency.isNotEmpty) {
            final oldFrom = state.fromCurrency;
            final oldTo = state.toCurrency;
            onChangeFrom(oldTo);
            onChangeTo(oldFrom);
          }
        },
      ),
    );
  }

  Widget _primaryBtn(BuildContext context,
      {required String label,
      required IconData icon,
      required VoidCallback onPressed,
      Key? key}) {
    return FilledButton.icon(
      key: key,
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
      required VoidCallback onPressed,
      Key? key}) {
    final onBg = _isDark(context) ? Colors.white : Colors.black;
    return OutlinedButton.icon(
      key: key,
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

    final String fallbackMessage = hasSelectedGovernorate
        ? 'لا تتوفر أسعار محدثة لهذه المحافظة حاليًا.'
        : 'اختر محافظة لعرض أسعار البيع والشراء.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Directionality(
          textDirection: TextDirection.rtl,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.location_on_outlined, color: brand),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'أسعار المحافظة',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: onBg,
                    fontWeight: FontWeight.w800,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
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
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                  icon: Icon(Icons.keyboard_arrow_down_rounded, color: brand),
                  dropdownColor: theme.scaffoldBackgroundColor,
                  style: theme.textTheme.bodyLarge?.copyWith(color: onBg),
                  isDense: true,
                  menuMaxHeight: 360,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
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
          Text(
            fallbackMessage,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: onBg.withOpacity(0.6),
              fontWeight: FontWeight.w600,
            ),
            textDirection: TextDirection.rtl,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final edge = const EdgeInsets.fromLTRB(12, 8, 12, 18);

    final bool isDarkContext = _isDark(context);

    String _name(dynamic d) => (d as dynamic).currencyName?.toString() ?? '';
    final List<dynamic> all = state.rates;
    final List<String> fromOptions = all.map(_name).toList(growable: false);
    final List<String> toOptions = all
        .where((r) => _name(r) != state.fromCurrency)
        .map(_name)
        .toList(growable: false);

    return SafeArea(
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double bottomInset = MediaQuery.of(context).viewInsets.bottom;
          final EdgeInsets scrollPadding = edge.copyWith(
            bottom: edge.bottom + bottomInset,
          );

          return SingleChildScrollView(
            padding: scrollPadding,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth:
                    constraints.maxWidth.isFinite ? constraints.maxWidth : 0,
                minHeight: constraints.maxHeight.isFinite
                    ? math.max(0.0, constraints.maxHeight - bottomInset)
                    : 0.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _governorateSection(context),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _currencyPickerCard(
                          context,
                          label: 'من',
                          selectedValue: state.fromCurrency,
                          options: fromOptions,
                          iconPrefix: 'fromCurrencyIcon',
                          dropdownKey: const Key('fromCurrencyDropdownField'),
                          onChanged: (String? value) {
                            if (value != null) {
                              onChangeFrom(value);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      _swapButton(isDarkContext),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _currencyPickerCard(
                          context,
                          label: 'إلى',
                          selectedValue: state.toCurrency,
                          options: toOptions,
                          iconPrefix: 'toCurrencyIcon',
                          dropdownKey: const Key('toCurrencyDropdownField'),
                          onChanged: (String? value) {
                            if (value != null) {
                              onChangeTo(value);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
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
                  const SizedBox(height: 18),
                  _conversionResultCard(context),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _currencyPickerCard(
    BuildContext context, {
    required String label,
    required String selectedValue,
    required List<String> options,
    required String iconPrefix,
    required Key dropdownKey,
    required ValueChanged<String?> onChanged,
  }) {
    final bool isDark = _isDark(context);
    final Color cardColor = isDark ? Colors.white10 : Colors.white;
    final Color shadowColor = isDark ? Colors.transparent : Colors.black12;
    final TextStyle labelStyle = Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(fontWeight: FontWeight.w700) ??
        const TextStyle(fontWeight: FontWeight.w700);

    final List<DropdownMenuItem<String>> menuItems = options
        .map(
          (String currency) => DropdownMenuItem<String>(
            value: currency,
            child: _CurrencyMenuRow(
              label: currency,
              iconKey: ValueKey('${iconPrefix}_menu_$currency'),
            ),
          ),
        )
        .toList(growable: false);

    String? normalizedSelected =
        (selectedValue.isEmpty || !options.contains(selectedValue))
            ? null
            : selectedValue;

    final String avatarLabel =
        normalizedSelected ?? (options.isNotEmpty ? options.first : label);

    return Card(
      color: cardColor,
      shadowColor: shadowColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: isDark ? 0 : 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              label,
              style: labelStyle,
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _CurrencyAvatar(
                  key: ValueKey('${iconPrefix}_selected'),
                  label: avatarLabel,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: IntrinsicWidth(
                    child: DropdownButtonFormField<String>(
                      key: dropdownKey,
                      value: normalizedSelected,
                      isExpanded: true,
                      isDense: true,
                      menuMaxHeight: 360,
                      alignment: AlignmentDirectional.centerEnd,
                      items: menuItems,
                      onChanged: onChanged,
                      decoration: InputDecoration(
                        border: _border(context),
                        enabledBorder: _border(context),
                        focusedBorder: _border(context),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _conversionResultCard(BuildContext context) {
    final bool isDark = _isDark(context);
    final Color onBg = isDark ? Colors.white : Colors.black;
    final String convertedValue = state.hasCalculated
        ? "${NumberFormat('#,##0.##').format(state.convertedAmount)} ${state.toCurrency}"
        : "---";

    return Card(
      key: const Key('conversionResultCard'),
      color: isDark ? Colors.white10 : Colors.white,
      elevation: isDark ? 0 : 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: brand.withOpacity(0.1),
                  foregroundColor: brand,
                  child: const Icon(Icons.currency_exchange),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'المبلغ المحول',
                    style: TextStyle(
                      color: onBg.withOpacity(0.75),
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              convertedValue,
              key: const Key('convertedValueText'),
              style: TextStyle(
                color: onBg,
                fontWeight: FontWeight.w900,
                fontSize: 22,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                key: const Key('advancedDetailsButton'),
                onPressed: onShowAdvancedDetails,
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('التفاصيل المتقدمة'),
                style: TextButton.styleFrom(
                  foregroundColor: brand,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _primaryBtn(
                    context,
                    label: 'تحويل',
                    icon: Icons.check,
                    onPressed: onConvert,
                    key: const Key('convertAction'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ghostBtn(
                    context,
                    label: 'تصفير',
                    icon: Icons.refresh,
                    onPressed: onReset,
                    key: const Key('resetAction'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CurrencyMenuRow extends StatelessWidget {
  const _CurrencyMenuRow({
    required this.label,
    this.iconKey,
  });

  final String label;
  final Key? iconKey;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CurrencyAvatar(
            label: label,
            key: iconKey,
            radius: 12,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrencyAvatar extends StatelessWidget {
  const _CurrencyAvatar({
    super.key,
    required this.label,
    this.radius = 14,
  });

  final String label;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color background = theme.colorScheme.primary.withOpacity(0.12);
    final Color foreground = theme.colorScheme.primary;
    final String initials = label.isEmpty
        ? '—'
        : label.trim().characters.take(2).toString().toUpperCase();
    final double clampedRadius = radius.clamp(10.0, 14.0);

    return CircleAvatar(
      radius: clampedRadius,
      backgroundColor: background,
      foregroundColor: foreground,
      child: Text(
        initials,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: clampedRadius <= 12 ? 10 : 11,
        ),
      ),
    );
  }
}

@visibleForTesting
Widget buildCurrencyMenuRowForTesting(String label, {Key? iconKey}) {
  return _CurrencyMenuRow(label: label, iconKey: iconKey);
}
