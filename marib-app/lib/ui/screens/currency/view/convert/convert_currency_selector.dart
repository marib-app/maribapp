import 'package:characters/characters.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        const double breakpoint = 560;
        final bool isCompact =
            !constraints.hasBoundedWidth || constraints.maxWidth <= breakpoint;

        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _CurrencyPickerCard(
                brand: brand,
                label: 'من',
                options: fromOptions,
                controller: fromController,
                selectedValue: selectedFrom,
                dropdownKey: const Key('fromCurrencyDropdownField'),
                iconPrefix: 'fromCurrencyIcon',
                onChanged: (String? value) {
                  if (value != null) {
                    onChangeFrom(value);
                  }
                },
              ),
              const SizedBox(height: 12),
              Center(child: _SwapButton(onSwap: onSwap, brand: brand, isDark: isDark)),
              const SizedBox(height: 12),
              _CurrencyPickerCard(
                brand: brand,
                label: 'إلى',
                options: toOptions,
                controller: toController,
                selectedValue: selectedTo,
                dropdownKey: const Key('toCurrencyDropdownField'),
                iconPrefix: 'toCurrencyIcon',
                onChanged: (String? value) {
                  if (value != null) {
                    onChangeTo(value);
                  }
                },
              ),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              flex: 3,
              child: _CurrencyPickerCard(
                brand: brand,
                label: 'من',
                options: fromOptions,
                controller: fromController,
                selectedValue: selectedFrom,
                dropdownKey: const Key('fromCurrencyDropdownField'),
                iconPrefix: 'fromCurrencyIcon',
                onChanged: (String? value) {
                  if (value != null) {
                    onChangeFrom(value);
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              flex: 1,
              child: Align(
                alignment: Alignment.topCenter,
                child: _SwapButton(onSwap: onSwap, brand: brand, isDark: isDark),
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              flex: 3,
              child: _CurrencyPickerCard(
                brand: brand,
                label: 'إلى',
                options: toOptions,
                controller: toController,
                selectedValue: selectedTo,
                dropdownKey: const Key('toCurrencyDropdownField'),
                iconPrefix: 'toCurrencyIcon',
                onChanged: (String? value) {
                  if (value != null) {
                    onChangeTo(value);
                  }
                },
              ),
            ),
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
    return Card(
      margin: EdgeInsets.zero,
      elevation: isDark ? 0 : 1,
      shape: const CircleBorder(),
      child: IconButton(
        key: const Key('swapCurrenciesAction'),
        tooltip: 'تبديل العملات',
        icon: Icon(Icons.swap_horiz_rounded, color: brand),
        onPressed: onSwap,
      ),
    );
  }
}

class _CurrencyPickerCard extends StatelessWidget {
  const _CurrencyPickerCard({
    required this.brand,
    required this.label,
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
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color cardColor = isDark ? Colors.white10 : Colors.white;
    final Color shadowColor = isDark ? Colors.transparent : Colors.black12;
    final TextStyle labelStyle = Theme.of(context)
        .textTheme
        .titleSmall
        ?.copyWith(fontWeight: FontWeight.w700) ??
        const TextStyle(fontWeight: FontWeight.w700);

    final List<DropdownMenuEntry<String>> menuItems = options
        .map(
          (String currency) => DropdownMenuEntry<String>(
        value: currency,
        label: currency,
        labelWidget: _CurrencyMenuRow(
          label: currency,
          iconKey: ValueKey('${iconPrefix}_menu_$currency'),
        ),
      ),
    )
        .toList(growable: false);

    final String? normalizedSelection =
        _normalizedSelection(selectedValue, options) ??
            _normalizedSelection(controller.text, options);

    final String avatarLabel =
        normalizedSelection ?? (options.isNotEmpty ? options.first : label);

    return Card(
      color: cardColor,
      shadowColor: shadowColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: isDark ? 0 : 2,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              label,
              style: labelStyle,
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints fieldConstraints) {
                return DropdownMenu<String>(
                  key: dropdownKey,
                  controller: controller,
                  initialSelection: normalizedSelection,
                  width: fieldConstraints.maxWidth.isFinite
                      ? fieldConstraints.maxWidth
                      : null,
                  onSelected: onChanged,
                  dropdownMenuEntries: menuItems,
                  inputDecorationTheme: InputDecorationTheme(
                    border: _border(context),
                    enabledBorder: _border(context),
                    focusedBorder: _border(context),
                    contentPadding: const EdgeInsetsDirectional.fromSTEB(
                      12,
                      14,
                      12,
                      14,
                    ),
                  ),
                  textStyle: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                  leadingIcon: Padding(
                    padding: const EdgeInsetsDirectional.only(start: 8),
                    child: _CurrencyAvatar(
                      key: ValueKey('${iconPrefix}_selected'),
                      label: avatarLabel,
                      radius: 16,
                    ),
                  ),
                  trailingIcon: const Icon(Icons.expand_more_rounded),
                  menuHeight: 360,
                );
              },
            ),
          ],
        ),
      ),
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

  String? _normalizedSelection(String selection, List<String> options) {
    final String trimmed = selection.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return options.contains(trimmed) ? trimmed : null;
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
              maxLines: 3,
              softWrap: true,
              overflow: TextOverflow.visible,
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