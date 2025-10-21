import 'package:flutter/material.dart';
import 'package:marib/data/model/preference_option.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/ui_utils.dart';

import '../../state/state.dart';

class CurrencyHeader extends StatelessWidget implements PreferredSizeWidget {
  const CurrencyHeader({
    super.key,
    required this.state,
    required this.onToggleWatchlistFilter,
    required this.onGovernorateChanged,
    required this.onNotificationFrequencyChanged,
  });

  final CurrencyViewState state;
  final ValueChanged<bool> onToggleWatchlistFilter;
  final ValueChanged<String?> onGovernorateChanged;
  final ValueChanged<String> onNotificationFrequencyChanged;

  bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  @override
  Widget build(BuildContext context) {
    final Color brand = context.color.territoryColor;

    return UiUtils.buildAppBar(
      context,
      showBackButton: true,
      title: 'العملات والذهب',
      actions: [
        _GovernorateButton(
          brand: brand,
          state: state,
          onToggleWatchlistFilter: onToggleWatchlistFilter,
          onGovernorateChanged: onGovernorateChanged,
          onNotificationFrequencyChanged: onNotificationFrequencyChanged,
          isDark: _isDark(context),
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _GovernorateButton extends StatelessWidget {
  const _GovernorateButton({
    required this.brand,
    required this.state,
    required this.onToggleWatchlistFilter,
    required this.onGovernorateChanged,
    required this.onNotificationFrequencyChanged,
    required this.isDark,
  });

  final Color brand;
  final CurrencyViewState state;
  final ValueChanged<bool> onToggleWatchlistFilter;
  final ValueChanged<String?> onGovernorateChanged;
  final ValueChanged<String> onNotificationFrequencyChanged;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appliedName = state.appliedGovernorateName ?? 'المتوسط الوطني';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TextButton.icon(
        onPressed: () => _showGovernorateSheet(context),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          foregroundColor: brand,
          textStyle: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        icon: Icon(Icons.place_outlined, color: brand, size: 20),
        label: Text(
          appliedName,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  void _showGovernorateSheet(BuildContext context) {
    final bool dark = isDark;
    final background = dark ? Colors.black : Colors.white;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        final bool sheetDark = Theme.of(sheetContext).brightness == Brightness.dark;
        final sheetBg = sheetDark ? Colors.black : Colors.white;
        final sheetOnBg = sheetDark ? Colors.white : Colors.black;
        final sheetBrand = sheetContext.color.territoryColor;
        final notificationSettings = _NotificationSettings(
          state: state,
          brand: sheetBrand,
          bg: sheetBg,
          onBg: sheetOnBg,
          isDark: sheetDark,
          onNotificationFrequencyChanged: onNotificationFrequencyChanged,
        ).build(sheetContext);

        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: sheetOnBg.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'اختيار المحافظة والتفضيلات',
                    textAlign: TextAlign.center,
                    style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: sheetOnBg,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _GovernorateSelector(
                    state: state,
                    brand: sheetBrand,
                    bg: sheetBg,
                    onBg: sheetOnBg,
                    isDark: sheetDark,
                    onGovernorateChanged: onGovernorateChanged,
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile.adaptive(
                    value: state.showWatchlistOnly,
                    onChanged: onToggleWatchlistFilter,
                    activeColor: sheetBrand,
                    contentPadding: EdgeInsets.zero,
                    secondary: Icon(Icons.visibility_outlined, color: sheetBrand),
                    title: Text(
                      'عرض قائمة المراقبة فقط',
                      style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: sheetOnBg,
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                  ),
                  if (notificationSettings != null) ...[
                    const SizedBox(height: 16),
                    notificationSettings,
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GovernorateSelector extends StatelessWidget {
  const _GovernorateSelector({
    required this.state,
    required this.brand,
    required this.bg,
    required this.onBg,
    required this.isDark,
    required this.onGovernorateChanged,
  });

  final CurrencyViewState state;
  final Color brand;
  final Color bg;
  final Color onBg;
  final bool isDark;
  final ValueChanged<String?> onGovernorateChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final border = isDark ? Colors.white12 : Colors.black12;
    const defaultValue = '_default_';

    final items = <DropdownMenuItem<String>>[
      const DropdownMenuItem<String>(
        value: defaultValue,
        child: Text(
          'المتوسط الافتراضي الوطني',
          textDirection: TextDirection.rtl,
        ),
      ),
    ];

    for (final gov in state.governorates) {
      final code = (gov['code'] ?? '').toString();
      if (code.isEmpty) continue;
      final rawName = gov['name'];
      final name = (rawName is String && rawName.isNotEmpty) ? rawName : code;
      items.add(
        DropdownMenuItem<String>(
          value: code,
          child: Text(
            name,
            textDirection: TextDirection.rtl,
          ),
        ),
      );
    }

    final selected = state.selectedGovernorateCode;
    final dropdownValue =
    (selected == null || selected.isEmpty) ? defaultValue : selected;
    final enabled =
        state.status == CurrencyPageStatus.ready && items.length > 1;

    final appliedName = state.appliedGovernorateName ??
        (dropdownValue == defaultValue ? 'المتوسط الافتراضي' : null);
    final requestedName = state.requestedGovernorateName;
    final showFallback = state.status == CurrencyPageStatus.ready &&
        state.usedFallback &&
        requestedName != null &&
        appliedName != null &&
        requestedName != appliedName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'اختر المحافظة لعرض الأسعار',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: onBg,
          ),
          textDirection: TextDirection.rtl,
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: dropdownValue,
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: brand),
          dropdownColor: bg,
          style: theme.textTheme.bodyLarge?.copyWith(color: onBg),
          decoration: InputDecoration(
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            filled: true,
            fillColor:
            isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: border),
            ),
          ),
          onChanged: enabled
              ? (value) {
            if (value == defaultValue) {
              onGovernorateChanged(null);
            } else {
              onGovernorateChanged(value);
            }
          }
              : null,
          items: items,
        ),
        if (appliedName != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'الأسعار المعروضة: $appliedName',
              style: theme.textTheme.labelMedium?.copyWith(
                color: onBg.withOpacity(0.75),
                fontWeight: FontWeight.w600,
              ),
              textDirection: TextDirection.rtl,
            ),
          ),
        if (showFallback)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'لم تتوفر بيانات لمحافظة $requestedName، تم استخدام أسعار $appliedName كبديل.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: brand,
                fontWeight: FontWeight.w600,
              ),
              textDirection: TextDirection.rtl,
            ),
          ),
      ],
    );
  }
}

class _NotificationSettings {
  const _NotificationSettings({
    required this.state,
    required this.brand,
    required this.bg,
    required this.onBg,
    required this.isDark,
    required this.onNotificationFrequencyChanged,
  });

  final CurrencyViewState state;
  final Color brand;
  final Color bg;
  final Color onBg;
  final bool isDark;
  final ValueChanged<String> onNotificationFrequencyChanged;

  Widget? build(BuildContext context) {
    final options = state.notificationOptions;
    if (options.isEmpty) {
      return null;
    }

    final theme = Theme.of(context);
    final border = isDark ? Colors.white24 : Colors.black12;
    final String initialValue = state.notificationFrequency.isNotEmpty
        ? state.notificationFrequency
        : options.first.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'تواتر الإشعارات',
          style: theme.textTheme.bodySmall?.copyWith(
            color: onBg.withOpacity(0.7),
            fontWeight: FontWeight.w600,
          ),
          textDirection: TextDirection.rtl,
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: initialValue,
          decoration: InputDecoration(
            filled: true,
            fillColor:
            isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: border),
            ),
          ),
          dropdownColor: bg,
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: brand),
          items: options
              .map(
                (PreferenceOption option) => DropdownMenuItem<String>(
              value: option.value,
              child: Text(
                option.label,
                textDirection: TextDirection.rtl,
              ),
            ),
          )
              .toList(growable: false),
          onChanged: (String? value) {
            if (value != null && value.isNotEmpty) {
              onNotificationFrequencyChanged(value);
            }
          },
        ),
      ],
    );
  }
}