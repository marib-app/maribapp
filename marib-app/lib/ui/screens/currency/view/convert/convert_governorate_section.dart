import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;
import '../../state/state.dart';
import '../../../../../data/model/currency_rate.dart';

class ConvertGovernorateSection extends StatelessWidget {
  ConvertGovernorateSection({
    super.key,
    required this.state,
    required this.brand,
    required this.selectedRate,
    required this.onGovernorateChanged,
  });

  final CurrencyViewState state;
  final Color brand;
  final CurrencyRate? selectedRate;
  final void Function(String?) onGovernorateChanged;

  final NumberFormat _numberFormat = NumberFormat('#,##0.000');

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color onBackground = isDark ? Colors.white : Colors.black;

    const String defaultValue = '_default_';

    final List<DropdownMenuItem<String>> items = [
      const DropdownMenuItem<String>(
        value: defaultValue,
        child: Text(
          'المتوسط الافتراضي الوطني',
          textDirection: ui.TextDirection.rtl,
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
            textDirection: ui.TextDirection.rtl,
          ),
        );
      }).whereType<DropdownMenuItem<String>>()
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
            textDirection: ui.TextDirection.rtl,
          ),
        ),
      );
    }

    final bool enabled = items.length > 1;

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
          textDirection: ui.TextDirection.rtl,
          child: Row(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.location_on_outlined, color: brand, size: 22),
              const SizedBox(width: 6),
              Text(
                'أسعار المحافظة',
                style: theme.textTheme.titleMedium?.copyWith(
                      color: onBackground,
                      fontWeight: FontWeight.w800,
                    ) ??
                    TextStyle(
                      color: onBackground,
                      fontWeight: FontWeight.w800,
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
                      horizontal: 8,
                      vertical: 8,
                    ),
                    isDense: true,
                  ),
                  icon: Icon(Icons.keyboard_arrow_down_rounded, color: brand),
                  dropdownColor: theme.scaffoldBackgroundColor,
                  style:
                      theme.textTheme.bodyMedium?.copyWith(color: onBackground),
                  isDense: true,
                  isExpanded: true,
                  menuMaxHeight: 360,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
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
                  value: _format(selectedRate!.buyPrice),
                ),
              ),
            ],
          )
        else
          Text(
            fallbackMessage,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: onBackground.withOpacity(0.6),
              fontWeight: FontWeight.w600,
            ),
            textDirection: ui.TextDirection.rtl,
          ),
      ],
    );
  }

  OutlineInputBorder _border(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color color = isDark ? Colors.white12 : Colors.black12;
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color),
    );
  }

  String _format(double value) => _numberFormat.format(value);

  Widget _infoCard(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color onBackground = isDark ? Colors.white : Colors.black;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
              color: onBackground.withOpacity(0.7),
              fontWeight: FontWeight.w600,
            ),
            textDirection: ui.TextDirection.rtl,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: onBackground,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
            textDirection: ui.TextDirection.rtl,
          ),
        ],
      ),
    );
  }
}
