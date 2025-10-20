import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;
import 'widgets/rate_detail_sheet.dart';
import 'package:marib/data/model/metal_rate.dart';

import 'package:marib/data/model/currency_history.dart';
import 'package:marib/data/model/currency_rate.dart';

import '../state/state.dart';

class RatesTabView extends StatelessWidget {
  const RatesTabView({
    super.key,
    required this.state,
    required this.onShareRates,
    required this.brand,
    required this.onToggleMetalWatchlist,
    required this.onToggleCurrencyWatchlist,
    required this.onSelectHistoryRange,
    required this.onNotificationRegionChanged,
  });

  final CurrencyViewState state;
  final VoidCallback onShareRates;
  final Color brand;
  final void Function(int) onToggleCurrencyWatchlist;
  final void Function(int? currencyId, int days) onSelectHistoryRange;
  final void Function(int) onToggleMetalWatchlist;
  final void Function(int currencyId, String? regionCode)
      onNotificationRegionChanged;
  static const String _defaultGovernorateLabel = 'المتوسط الوطني';

  bool _isDark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;

  String? _resolveQuoteSource() {
    String? _extract(List<dynamic> rates) {
      for (final dynamic item in rates) {
        if (item is CurrencyRate) {
          final String? source = item.quoteSource;
          if (source != null && source.trim().isNotEmpty) {
            return source.trim();
          }
          continue;
        }
        if (item is MetalRate) {
          final String? source = item.source;
          if (source != null && source.trim().isNotEmpty) {
            return source.trim();
          }
          continue;
        }
        try {
          final dynamic source = (item as dynamic).quoteSource;
          if (source is String && source.trim().isNotEmpty) {
            return source.trim();
          }
        } catch (_) {
          continue;
        }
      }
      return null;
    }

    return _extract(state.displayRates) ?? _extract(state.rates);
  }

  // ---------- Header (بسيط بدون إطارات ثقيلة) ----------
  Widget _header(BuildContext context) {
    final theme = Theme.of(context);
    final onBg = _isDark(context) ? Colors.white : Colors.black;
    final bool isStale = state.isDisplayRatesStale;

    final hasTime = state.lastUpdatedAt != null;
    final dateStr = hasTime
        ? DateFormat('yyyy-MM-dd').format(state.lastUpdatedAt!)
        : 'غير متاح';
    final timeStr =
        hasTime ? DateFormat('HH:mm').format(state.lastUpdatedAt!) : '--:--';
    final quoteSource = _resolveQuoteSource();
    final sourceLabel = quoteSource ?? 'غير متاح';
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // العنوان + أيقونة مشاركة فقط
          Row(
            children: [
              Expanded(
                child: Text(
                  "آخر تحديث للبيانات كان في:",
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: onBg.withOpacity(0.9),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (isStale) ...[
                _StaleBadge(dark: _isDark(context)),
                const SizedBox(width: 6),
              ],
              IconButton(
                onPressed: onShareRates,
                icon: const Icon(Icons.share_outlined),
                splashRadius: 20,
                color: brand,
                tooltip: "مشاركة",
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            "التاريخ: $dateStr  •  الساعة: $timeStr",
            style: theme.textTheme.labelLarge?.copyWith(
              color: onBg.withOpacity(0.65),
              fontWeight: FontWeight.w600,
            ),
            textDirection: TextDirection.rtl,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 4),
          Text(
            'المصدر: $sourceLabel',
            style: theme.textTheme.labelLarge?.copyWith(
              color: onBg.withOpacity(0.55),
              fontWeight: FontWeight.w600,
            ),
            textDirection: TextDirection.rtl,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 6),
          Text(
            'الأسعار المعروضة: '
            '${state.appliedGovernorateName ?? 'المتوسط الافتراضي'}',
            style: theme.textTheme.labelMedium?.copyWith(
              color: onBg.withOpacity(0.75),
              fontWeight: FontWeight.w600,
            ),
            textDirection: TextDirection.rtl,
          ),
          if (state.usedFallback &&
              state.requestedGovernorateName != null &&
              state.appliedGovernorateName != null &&
              state.requestedGovernorateName != state.appliedGovernorateName)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'تم استخدام أسعار ${state.appliedGovernorateName} بدلًا من ${state.requestedGovernorateName}.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: brand,
                  fontWeight: FontWeight.w600,
                ),
                textDirection: TextDirection.rtl,
              ),
            ),
        ],
      ),
    );
  }

  int? _resolveEffectiveHistoryRange(Set<int> availableRanges, int preferred) {
    if (availableRanges.isEmpty) {
      return null;
    }
    if (availableRanges.contains(preferred)) {
      return preferred;
    }

    final List<int> candidates = <int>[
      preferred,
      state.defaultHistoryRangeDays,
      1,
      3,
      7,
    ];

    for (final int candidate in candidates) {
      if (availableRanges.contains(candidate)) {
        return candidate;
      }
    }

    return availableRanges.first;
  }

  Widget _buildCurrencyIcon({
    required String name,
    String? iconUrl,
    String? iconAlt,
    required Color onBg,
    double size = 40,
    double iconSize = 18,
  }) {
    Widget fallback() {
      return Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: onBg.withOpacity(0.20)),
        ),
        child: Icon(
          Icons.account_balance_wallet_outlined,
          size: iconSize,
          color: brand,
        ),
      );
    }

    if (iconUrl == null || iconUrl.isEmpty) {
      return fallback();
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: onBg.withOpacity(0.20)),
      ),
      clipBehavior: Clip.hardEdge,
      child: Semantics(
        label: iconAlt?.isNotEmpty == true ? iconAlt : 'أيقونة $name',
        child: Image.network(
          iconUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => fallback(),
          loadingBuilder: (BuildContext ctx, Widget child,
              ImageChunkEvent? progress) {
            if (progress == null) {
              return child;
            }
            return Center(
                child: SizedBox(
                  width: iconSize,
                  height: iconSize,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(brand),
                    value: progress.expectedTotalBytes != null
                        ? progress.cumulativeBytesLoaded /
                        (progress.expectedTotalBytes ?? 1)
                        : null,
                ),
                ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildChangeIndicatorWidget(
      BuildContext context, {
        required IconData icon,
        required Color color,
        required String text,
        bool compact = false,
      }) {
    final TextStyle baseStyle = (compact
        ? Theme.of(context).textTheme.labelLarge
        : Theme.of(context).textTheme.titleMedium) ??
        TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: compact ? 14 : 16,
        );

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 18 : 22, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: baseStyle.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget? _buildNotificationSelector({
    required Color onBg,
    required TextTheme textTheme,
    required int? currencyId,
    required ValueChanged<String?>? onNotificationRegionChanged,
  }) {
    if (currencyId == null || onNotificationRegionChanged == null) {
      return null;
    }
    if (state.governorates.isEmpty) {
      return null;
    }

    const String notificationDefaultValue = '_default_';
    final Map<int, String> notificationRegions =
        state.currency.currencyNotificationRegions;
    final String? storedNotification = notificationRegions[currencyId];
    String selection = notificationDefaultValue;
    if (storedNotification != null && storedNotification.trim().isNotEmpty) {
      selection = storedNotification.trim();
    }

    final List<DropdownMenuItem<String>> items = <DropdownMenuItem<String>>[
      const DropdownMenuItem<String>(
        value: notificationDefaultValue,
        child: Text(
          'المتوسط الافتراضي الوطني',
          textDirection: TextDirection.rtl,
        ),
      ),
    ];
    final Set<String> addedValues = <String>{notificationDefaultValue};

    for (final Map<String, String?> governorate in state.governorates) {
      final String? code = governorate['code'];
      if (code == null) {
        continue;
      }
      final String trimmedCode = code.trim();
      if (trimmedCode.isEmpty) {
        continue;
      }
      if (!addedValues.add(trimmedCode)) {
        continue;
      }

      final String? rawName = governorate['name'];
      final String name =
      (rawName != null && rawName.trim().isNotEmpty)
          ? rawName.trim()
          : trimmedCode;
      items.add(
        DropdownMenuItem<String>(
          value: trimmedCode,
          child: Text(
            name,
            textDirection: TextDirection.rtl,
          ),
        ),
      );

    }

    if (!addedValues.contains(selection)) {
      addedValues.add(selection);
      items.add(
        DropdownMenuItem<String>(
          value: selection,
          child: Text(
            selection,
            textDirection: TextDirection.rtl,
          ),
        ),
      );
    }

    final Color borderColor = onBg.withOpacity(0.12);
    final Color iconColor = onBg.withOpacity(0.7);

    return Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            'تنبيهات المحافظة',
            style: textTheme.labelSmall?.copyWith(
                  color: onBg.withOpacity(0.6),
                  fontWeight: FontWeight.w700,
                ) ??
                TextStyle(
                  color: onBg.withOpacity(0.6),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
          ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              key: ValueKey<String>('notification-region-$currencyId'),
              value: selection,
              isExpanded: true,
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: iconColor,
              ),
              onChanged: (String? value) {
                if (value == null) {
                  return;
                }
                final String? normalized =
                value == notificationDefaultValue ? null : value;
                onNotificationRegionChanged(normalized);
              },
              items: items,
              ),
          ),
          ),
        ],
        ),
    );
  }

  Widget _buildInfoCard(
      BuildContext context,
      String label,
      String value,
      Color onBg,
      ) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: onBg.withOpacity(0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: onBg.withOpacity(0.7),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: onBg,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- صفّ العملة (نظيف مع عرض بيع/شراء احترافي) ----------
  Widget _row(
      BuildContext context, {
        required String name,
        required String sell,
        required String buy,
        String? iconUrl,
        String? iconAlt,
        required bool isWatchlisted,
        required VoidCallback onToggleWatchlist,
        CurrencyHistoryBundle? history,
        required int selectedRangeDays,
        required ValueChanged<int> onHistoryRangeSelected,
        int? currencyId,
        ValueChanged<String?>? onNotificationRegionChanged,
      }) {
    final ThemeData theme = Theme.of(context);
    final bool dark = _isDark(context);
    final Color onBg = dark ? Colors.white : Colors.black;
    final Color divider = dark ? Colors.white12 : Colors.black12;

    final NumberFormat valueFormatter = NumberFormat('#,##0.####', 'en');
    String formatValue(String value) {
      final double? parsed = double.tryParse(value.replaceAll(',', ''));
      return parsed == null ? value : valueFormatter.format(parsed);
    }


    final Set<int> availableRanges = history?.ranges.keys
        .map((dynamic key) => key is int ? key : int.tryParse(key.toString()))

            .whereType<int>()
            .toSet() ??
        <int>{};

    final int? effectiveRange =
    _resolveEffectiveHistoryRange(availableRanges, selectedRangeDays);
    final CurrencyHistorySummary? summary = effectiveRange != null
        ? history?.range(effectiveRange)?.summary
        : null;

    final NumberFormat changeFormatter = NumberFormat('+#0.##;-#0.##;0', 'en');
    final String changeText = summary?.changeSellPercent != null
        ? '${changeFormatter.format(summary!.changeSellPercent)}%'
        : '--';


    final Color neutralColor = onBg.withOpacity(0.6);
    final Color trendColor = summary == null
        ? neutralColor
        : summary.isNegativeTrend
        ? Colors.redAccent
            : summary.isPositiveTrend
        ? Colors.green
                : neutralColor;

    final IconData trendIcon = summary == null
        ? Icons.trending_flat
        : summary.isNegativeTrend
            ? Icons.arrow_downward_rounded
            : summary.isPositiveTrend
                ? Icons.arrow_upward_rounded
                : Icons.trending_flat;

    final Widget changeIndicator = _buildChangeIndicatorWidget(
      context,
      icon: trendIcon,
      color: trendColor,
      text: changeText,
      compact: true,
    );

    final Widget detailChangeIndicator = _buildChangeIndicatorWidget(
      context,
      icon: trendIcon,
      color: trendColor,
      text: changeText,
    );

    final Widget leading = _buildCurrencyIcon(
      name: name,
      iconUrl: iconUrl,
      iconAlt: iconAlt,
      onBg: onBg,
    );

    final Widget detailLeading = _buildCurrencyIcon(
      name: name,
      iconUrl: iconUrl,
      iconAlt: iconAlt,
      onBg: onBg,
      size: 56,
      iconSize: 24,
    );

    final Widget? notificationSelector = _buildNotificationSelector(
      onBg: onBg,
      textTheme: theme.textTheme,
      currencyId: currencyId,
      onNotificationRegionChanged: onNotificationRegionChanged,
    );

    final String detailSubtitle = state.appliedGovernorateName ??
        state.requestedGovernorateName ??
        'المتوسط الافتراضي الوطني';

    void handleTap() {
      _showCurrencyDetails(
        context: context,
        name: name,
        subtitle: 'حسب $detailSubtitle',
        sell: formatValue(sell),
        buy: formatValue(buy),
        isWatchlisted: isWatchlisted,
        onToggleWatchlist: onToggleWatchlist,
        history: history,
        initialRange: effectiveRange,
        onHistoryRangeSelected: onHistoryRangeSelected,
        leading: detailLeading,
        changeIndicator: detailChangeIndicator,
        notificationSelector: notificationSelector,
      );
    }

    Widget priceColumn(String label, String value, Color color) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: onBg.withOpacity(0.6),
              fontWeight: FontWeight.w700,
            ) ??
                TextStyle(
                  color: onBg.withOpacity(0.6),
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ) ??
                TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 15.5,
                ),
          ),
        ],
      );
    }


    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: handleTap,
        splashColor: brand.withOpacity(0.06),
        highlightColor: brand.withOpacity(0.03),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: divider, width: 1)),
          ),
            child: Row(
                children: [
                leading,
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                    Text(
                      name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: onBg,
                        fontWeight: FontWeight.w800,
                          ) ??
                          TextStyle(
                            color: onBg,
                            fontWeight: FontWeight.w800,
                            fontSize: 15.5,
                          ),
                      textDirection: TextDirection.rtl,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                          const SizedBox(height: 6),
                          Directionality(
                            textDirection: TextDirection.rtl,
                            child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                priceColumn('سعر البيع', formatValue(sell), brand),
                            const SizedBox(width: 16),
                            priceColumn(
                              'سعر الشراء',
                              formatValue(buy),
                              onBg.withOpacity(0.85),
                          ),
                                ],
                            ),
                    ),
                        ],
                    ),
                ),
                  const SizedBox(width: 12),
                  changeIndicator,
                  const SizedBox(width: 6),
                  Icon(
                    Icons.chevron_left_rounded,
                    color: onBg.withOpacity(0.4),
                  ),
                ],
          ),
        ),
      ),
    );
  }



  void _showCurrencyDetails({
    required BuildContext context,
    required String name,
    String? subtitle,
    required String sell,
    required String buy,
    required bool isWatchlisted,
    required VoidCallback onToggleWatchlist,
    CurrencyHistoryBundle? history,
    int? initialRange,
    ValueChanged<int>? onHistoryRangeSelected,
    required Widget leading,
    required Widget changeIndicator,
    Widget? notificationSelector,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext ctx) {
        return RateDetailSheet(
          title: name,
          subtitle: subtitle,
          leading: leading,
          sellLabel: 'سعر البيع',
          sellValue: sell,
          buyLabel: 'سعر الشراء',
          buyValue: buy,
          brand: brand,
          isWatchlisted: isWatchlisted,
          onToggleWatchlist: onToggleWatchlist,
          onShare: onShareRates,
          history: history,
          initialHistoryRange: initialRange,
          onHistoryRangeSelected: onHistoryRangeSelected,
          notificationSelector: notificationSelector,
          changeIndicator: changeIndicator,
        );
      },
    );
  }


  Widget _metalRow(
    BuildContext context, {
    required MetalRate rate,
    required bool isWatchlisted,
    required VoidCallback onToggleWatchlist,
  }) {
    final ThemeData theme = Theme.of(context);
    final bool dark = _isDark(context);
    final Color onBg = dark ? Colors.white : Colors.black;
    final Color divider = dark ? Colors.white12 : Colors.black12;
    final NumberFormat formatter = NumberFormat('#,##0.###', 'en');

    String format(double? value) {
      if (value == null || value.isNaN || value.isInfinite) {
        return '--';
      }
      return formatter.format(value);
    }

    final String sellValue = format(rate.sellPrice);
    final String buyValue = format(rate.buyPrice);

    final Widget leading = _buildMetalIcon(
      rate: rate,
      onBg: onBg,
    );
    final Widget detailLeading = _buildMetalIcon(
      rate: rate,
      onBg: onBg,
      size: 56,
    );

    final Widget changeIndicator = _buildChangeIndicatorWidget(
      context,
      icon: Icons.trending_flat,
      color: onBg.withOpacity(0.6),
      text: '--',
      compact: true,
    );



    final Widget detailChangeIndicator = _buildChangeIndicatorWidget(
      context,
      icon: Icons.trending_flat,
      color: onBg.withOpacity(0.6),
      text: '--',
    );

    final List<Widget> infoSections =
    _buildMetalInfoSections(context, rate, onBg);

    void handleTap() {
      _showMetalDetails(
        context: context,
        rate: rate,
        sell: sellValue,
        buy: buyValue,
        isWatchlisted: isWatchlisted,
        onToggleWatchlist: onToggleWatchlist,
        leading: detailLeading,
        changeIndicator: detailChangeIndicator,
        infoSections: infoSections,
      );
    }

    Widget priceColumn(String label, String value, Color color) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: onBg.withOpacity(0.6),
              fontWeight: FontWeight.w700,
            ) ??
                TextStyle(
                  color: onBg.withOpacity(0.6),
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ) ??
                TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 15.5,
                ),
          ),
        ],
      );
    }



    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: handleTap,
        splashColor: brand.withOpacity(0.06),
        highlightColor: brand.withOpacity(0.03),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: divider, width: 1)),
          ),
          child: Row(
            children: [
              leading,

              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      rate.displayName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: onBg,
                        fontWeight: FontWeight.w800,
                      ) ??
                          TextStyle(
                            color: onBg,
                            fontWeight: FontWeight.w800,
                            fontSize: 15.5,
                          ),
                      textDirection: TextDirection.rtl,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    Text(
                      rate.karatLabel,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: onBg.withOpacity(0.6),
                        fontWeight: FontWeight.w600,
                      ) ??
                          TextStyle(
                            color: onBg.withOpacity(0.6),
                            fontWeight: FontWeight.w600,
                          ),
                      textDirection: TextDirection.rtl,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Directionality(
                      textDirection: TextDirection.rtl,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          priceColumn('سعر البيع', sellValue, brand),
                          const SizedBox(width: 16),
                          priceColumn(
                            'سعر الشراء',
                            buyValue,
                            onBg.withOpacity(0.85),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),
              changeIndicator,
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_left_rounded,
                color: onBg.withOpacity(0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }




  void _showMetalDetails({
    required BuildContext context,
    required MetalRate rate,
    required String sell,
    required String buy,
    required bool isWatchlisted,
    required VoidCallback onToggleWatchlist,
    required Widget leading,
    required Widget changeIndicator,
    required List<Widget> infoSections,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext ctx) {
        return RateDetailSheet(
          title: rate.displayName,
          subtitle: rate.karatLabel,
          leading: leading,
          sellLabel: 'سعر البيع',
          sellValue: sell,
          buyLabel: 'سعر الشراء',
          buyValue: buy,
          brand: brand,
          isWatchlisted: isWatchlisted,
          onToggleWatchlist: onToggleWatchlist,
          onShare: onShareRates,
          history: null,
          initialHistoryRange: null,
          onHistoryRangeSelected: null,
          notificationSelector: null,
          changeIndicator: changeIndicator,
          additionalSections: infoSections,
        );
      },
    );
  }

  Widget _buildMetalIcon({
    required MetalRate rate,
    required Color onBg,
    double size = 44,
  }) {
    final bool isGold = rate.isGold;
    final bool isSilver = rate.isSilver;
    final Color accent = isGold
        ? Colors.amber[700] ?? Colors.amber
        : isSilver
        ? Colors.blueGrey[300] ?? Colors.blueGrey
        : brand;
    final IconData icon = isGold
        ? Icons.workspace_premium_outlined
        : isSilver
        ? Icons.diamond_outlined
        : Icons.inventory_2_outlined;

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: onBg.withOpacity(0.20)),
      ),
      child: Icon(
        icon,
        color: accent,
        size: size * 0.55,
      ),
    );
  }

  List<Widget> _buildMetalInfoSections(
      BuildContext context,
      MetalRate rate,
      Color onBg,
      ) {
    final List<Widget> cards = <Widget>[
      _buildInfoCard(
        context,
        'المحافظة المعروضة',
        _metalGovernorateLabel(rate),
        onBg,
      ),
    ];

    if (rate.source != null && rate.source!.trim().isNotEmpty) {
      cards.add(
        _buildInfoCard(
          context,
          'المصدر',
          rate.source!.trim(),
          onBg,
        ),
      );
    }

    if (rate.quotedAt != null) {
      cards.add(
        _buildInfoCard(
          context,
          'آخر تحديث',
          DateFormat('yyyy-MM-dd HH:mm').format(rate.quotedAt!),
          onBg,
        ),
      );
    }

    if (cards.isEmpty) {
      return const <Widget>[];
    }

    return <Widget>[
      Wrap(
        spacing: 12,
        runSpacing: 12,
        alignment: WrapAlignment.end,
        children: cards,
      ),
    ];
  }

  String _metalGovernorateLabel(MetalRate rate) {
    final String? name = rate.quoteGovernorateName ??
        state.appliedGovernorateName ??
        state.requestedGovernorateName;
    final String base =
    (name == null || name.isEmpty) ? _defaultGovernorateLabel : name;
    if (rate.quoteUsedFallback || rate.quoteIsDefault) {
      return '$base (افتراضي)';
    }
    return base;
  }


  // ---------- بطاقة الملاحظة (احتفظنا بها كما أعجبتك) ----------
  Widget _noteCard(BuildContext context) {
    final theme = Theme.of(context);
    final onBg = _isDark(context) ? Colors.white : Colors.black;

    // TODO(backend): مرّر نص الملاحظة من السيرفر عبر state.note مثلاً
    final serverNote = null; // استبدلها لاحقًا بقيمة قادمة من الـ API
    final text = serverNote ??
        "الأسعار المعروضة يتم جلبها من بنك الشرق اليمني، وهي الأسعار الرسمية المعتمدة من البنك المركزي - عدن.";

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 18),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: brand.withOpacity(0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: brand),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("ملاحظة",
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: onBg.withOpacity(0.9),
                      fontWeight: FontWeight.w800,
                    )),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: onBg.withOpacity(0.78),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "⚙ يمكن استبدال هذا النص من السيرفر لاحقًا.",
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: onBg.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Build ----------
  @override
  Widget build(BuildContext context) {
    final rates = state.displayRates;

    String _name(d) => (d as dynamic).currencyName?.toString() ?? '';
    String _sell(d) => (d as dynamic).sellPrice?.toString() ?? '';
    String _buy(d) => (d as dynamic).buyPrice?.toString() ?? '';
    String? _icon(d) => (d as dynamic).iconUrl?.toString();
    String? _iconAlt(d) => (d as dynamic).iconAlt?.toString();
    CurrencyHistoryBundle? _history(d) => d is CurrencyRate ? d.history : null;
    int? _id(d) {
      try {
        final dynamic raw = (d as dynamic).id;
        if (raw is int) return raw;
        if (raw is num) return raw.toInt();
      } catch (_) {}
      return null;
    }

    if (rates.isEmpty) {
      final onBg = _isDark(context) ? Colors.white : Colors.black;
      return ListView(
        children: [
          _header(context),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text(
                state.showWatchlistOnly
                    ? 'قائمة المراقبة فارغة حاليًا'
                    : 'لا توجد بيانات حالياً',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: onBg,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ),
          _noteCard(context),
        ],
      );
    }

    return ListView.builder(
      itemCount: rates.length + 2, // + header + note
      itemBuilder: (ctx, i) {
        if (i == 0) return _header(context);
        if (i == rates.length + 1) return _noteCard(context);
        final dynamic r = rates[i - 1];

        if (r is CurrencyRate) {
          final bool isWatchlisted = state.currencyWatchlist.contains(r.id);
          return _row(
            context,
            name: r.currencyName,
            sell: r.sellPrice.toString(),
            buy: r.buyPrice.toString(),
            iconUrl: r.iconUrl,
            iconAlt: r.iconAlt,
            isWatchlisted: isWatchlisted,
            onToggleWatchlist: () => onToggleCurrencyWatchlist(r.id),
            history: r.history,
            selectedRangeDays: state.historyRangeForCurrency(r.id),
            onHistoryRangeSelected: (int days) =>
                onSelectHistoryRange(r.id, days),
            currencyId: r.id,
            onNotificationRegionChanged: (String? code) =>
                onNotificationRegionChanged(r.id, code),
          );
        }

        if (r is MetalRate) {
          final bool isWatchlisted = state.metalWatchlist.contains(r.id);
          return _metalRow(
            context,
            rate: r,
            isWatchlisted: isWatchlisted,
            onToggleWatchlist: () => onToggleMetalWatchlist(r.id),
          );
        }

        final int? currencyId = _id(r);
        final int rateId = currencyId ?? 0;
        final bool isWatchlisted = state.currencyWatchlist.contains(rateId);
        return _row(
          context,
          name: _name(r),
          sell: _sell(r),
          buy: _buy(r),
          iconUrl: _icon(r),
          iconAlt: _iconAlt(r),
          isWatchlisted: isWatchlisted,
          onToggleWatchlist: () => onToggleCurrencyWatchlist(rateId),
          history: _history(r),
          selectedRangeDays: state.historyRangeForCurrency(currencyId),
          onHistoryRangeSelected: (int days) =>
              onSelectHistoryRange(currencyId, days),
          currencyId: currencyId,
          onNotificationRegionChanged: currencyId == null
              ? null
              : (String? code) => onNotificationRegionChanged(currencyId, code),
        );
      },
    );
  }
}

class _StaleBadge extends StatelessWidget {
  const _StaleBadge({required this.dark});

  final bool dark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color background = dark
        ? Colors.orange.shade900.withOpacity(0.55)
        : Colors.orange.shade100;
    final Color foreground =
        dark ? Colors.orange.shade200 : Colors.orange.shade800;

    return Tooltip(
      message:
          'تم رصد أن البيانات المعروضة قديمة، وسيتم تحديثها عند توفر مصادر أحدث.',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              size: 16,
              color: foreground,
            ),
            const SizedBox(width: 4),
            Text(
              'قديم',
              style: theme.textTheme.labelSmall?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w700,
                  ) ??
                  TextStyle(
                    color: foreground,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
