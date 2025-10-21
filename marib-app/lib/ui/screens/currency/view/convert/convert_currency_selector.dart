import 'package:characters/characters.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;

class ConvertCurrencySelector extends StatelessWidget {
  const ConvertCurrencySelector({
    super.key,
    required this.brand,
    required this.fromOptions,
    required this.toOptions,
    required this.fromController,
    required this.toController,
    required this.selectedFrom,
    required this.selectedTo,
    required this.onChangeFrom,
    required this.onChangeTo,
    required this.onSwap,
    required this.isDark,
  });

  final Color brand;
  final List<String> fromOptions;
  final List<String> toOptions;
  final TextEditingController fromController;
  final TextEditingController toController;
  final String selectedFrom;
  final String selectedTo;
  final ValueChanged<String> onChangeFrom;
  final ValueChanged<String> onChangeTo;
  final VoidCallback onSwap;
  final bool isDark;

  static const double _selectorFieldWidth = 184;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool isCompact =
            !constraints.hasBoundedWidth || constraints.maxWidth < 520;
        final double maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : double.infinity;
        final double fieldWidth =
            isCompact ? maxWidth : math.min(_selectorFieldWidth, maxWidth);

        final Widget fromField = SizedBox(
          width: isCompact ? double.infinity : fieldWidth,
          child: _CurrencyDropdown(
            label: 'من',
            brand: brand,
            options: fromOptions,
            controller: fromController,
            selectedValue: selectedFrom,
            dropdownKey: const Key('fromCurrencyDropdownField'),
            iconPrefix: 'fromCurrencyIcon',
            onChanged: onChangeFrom,
          ),
        );

        final Widget toField = SizedBox(
          width: isCompact ? double.infinity : fieldWidth,
          child: _CurrencyDropdown(
            label: 'إلى',
            brand: brand,
            options: toOptions,
            controller: toController,
            selectedValue: selectedTo,
            dropdownKey: const Key('toCurrencyDropdownField'),
            iconPrefix: 'toCurrencyIcon',
            onChanged: onChangeTo,
          ),
        );

        final Widget swapButton = _SwapButton(
          onSwap: onSwap,
          brand: brand,
          isDark: isDark,
        );

        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              fromField,
              const SizedBox(height: 10),
              Center(child: swapButton),
              const SizedBox(height: 10),
              toField,
            ],
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            fromField,
            const SizedBox(width: 12),
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: swapButton,
            ),
            const SizedBox(width: 12),
            toField,
          ],
        );
      },
    );
  }
}

class _SwapButton extends StatelessWidget {
  const _SwapButton({
    required this.onSwap,
    required this.brand,
    required this.isDark,
  });

  final VoidCallback onSwap;
  final Color brand;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final Color borderColor = brand.withOpacity(isDark ? 0.6 : 0.8);
    return SizedBox(
      width: 48,
      height: 48,
      child: OutlinedButton(
        key: const Key('swapCurrenciesAction'),
        onPressed: onSwap,
        style: OutlinedButton.styleFrom(
          shape: const CircleBorder(),
          side: BorderSide(color: borderColor),
          padding: EdgeInsets.zero,
        ),
        child: Icon(Icons.swap_horiz_rounded, color: brand),
      ),
    );
  }
}

class _CurrencyDropdown extends StatelessWidget {
  const _CurrencyDropdown({
    required this.label,
    required this.brand,
    required this.options,
    required this.controller,
    required this.selectedValue,
    required this.dropdownKey,
    required this.iconPrefix,
    required this.onChanged,
  });

  final Color brand;
  final String label;
  final List<String> options;
  final TextEditingController controller;
  final String selectedValue;
  final Key dropdownKey;
  final String iconPrefix;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color border = isDark ? Colors.white12 : Colors.black26;
    final Color fill = isDark ? Colors.white10 : Colors.white;
    final TextStyle labelStyle = theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ) ??
        const TextStyle(fontWeight: FontWeight.w700);

    final List<DropdownMenuItem<String>> items = options
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

    final String? normalizedSelection =
        _normalizedSelection(selectedValue, options) ??
            _normalizedSelection(controller.text, options);

    final String controllerText = normalizedSelection ?? '';
    if (controller.text != controllerText) {
      controller.value = controller.value.copyWith(
        text: controllerText,
        selection: TextSelection.collapsed(offset: controllerText.length),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: labelStyle,
          textDirection: TextDirection.rtl,
        ),
        const SizedBox(height: 6),
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border),
            color: fill,
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(10, 2, 8, 2),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  key: dropdownKey,
                  value: normalizedSelection,
                  icon: const Icon(Icons.expand_more_rounded, size: 18),
                  isExpanded: true,
                  isDense: true,
                  items: items,
                  hint: _CurrencyHint(label: label, brand: brand),
                  onChanged: (String? value) {
                    if (value != null) {
                      onChanged(value);
                    }
                  },
                  alignment: AlignmentDirectional.centerEnd,
                  selectedItemBuilder: (BuildContext context) {
                    return options
                        .map(
                          (String currency) => Align(
                            alignment: Alignment.centerRight,
                            child: _CurrencyMenuRow(
                              label: currency,
                              iconKey:
                                  ValueKey('${iconPrefix}_selected_$currency'),
                            ),
                          ),
                        )
                        .toList(growable: false);
                  },
                  dropdownColor: theme.scaffoldBackgroundColor,
                  menuMaxHeight: 360,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String? _normalizedSelection(String selection, List<String> options) {
    final String trimmed = selection.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return options.contains(trimmed) ? trimmed : null;
  }
}

class _CurrencyHint extends StatelessWidget {
  const _CurrencyHint({
    required this.label,
    required this.brand,
  });

  final String label;
  final Color brand;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Text(
        'اختر $label',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: brand.withOpacity(0.7),
                  fontWeight: FontWeight.w600,
                ) ??
            TextStyle(
              color: brand.withOpacity(0.7),
              fontWeight: FontWeight.w600,
            ),
        textDirection: TextDirection.rtl,
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
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              textDirection: TextDirection.rtl,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
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
    this.radius = 11,
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
