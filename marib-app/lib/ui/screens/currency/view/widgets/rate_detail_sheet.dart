import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;

import 'package:marib/data/model/currency_history.dart';

import 'rate_history_widgets.dart';

class RateDetailSheet extends StatefulWidget {
  const RateDetailSheet({
    super.key,
    required this.title,
    this.subtitle,
    required this.leading,
    required this.sellLabel,
    required this.sellValue,
    required this.buyLabel,
    required this.buyValue,
    required this.brand,
    required this.isWatchlisted,
    required this.onToggleWatchlist,
    this.onShare,
    this.history,
    this.initialHistoryRange,
    this.onHistoryRangeSelected,
    this.notificationSelector,
    this.changeIndicator,
    this.additionalSections = const <Widget>[],
  });

  final String title;
  final String? subtitle;
  final Widget leading;
  final String sellLabel;
  final String sellValue;
  final String buyLabel;
  final String buyValue;
  final Color brand;
  final bool isWatchlisted;
  final VoidCallback onToggleWatchlist;
  final VoidCallback? onShare;
  final CurrencyHistoryBundle? history;
  final int? initialHistoryRange;
  final ValueChanged<int>? onHistoryRangeSelected;
  final Widget? notificationSelector;
  final Widget? changeIndicator;
  final List<Widget> additionalSections;

  @override
  State<RateDetailSheet> createState() => _RateDetailSheetState();
}

class _RateDetailSheetState extends State<RateDetailSheet> {
  late int? _currentRange;

  @override
  void initState() {
    super.initState();
    _currentRange = widget.initialHistoryRange;
  }

  @override
  void didUpdateWidget(covariant RateDetailSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialHistoryRange != widget.initialHistoryRange) {
      _currentRange = widget.initialHistoryRange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color onBackground = isDark ? Colors.white : Colors.black;
    final CurrencyHistoryBundle? history = widget.history;
    final Set<int> availableRanges = history?.ranges.keys.toSet() ?? <int>{};

    final CurrencyHistoryRange? range =
    _currentRange != null ? history?.range(_currentRange!) : null;
    final CurrencyHistorySummary? summary = range?.summary;
    final List<double> chartValues = range?.points
        .map((CurrencyHistoryPoint point) => point.sellPrice)
        .where((double value) => value.isFinite)
        .toList(growable: false) ??
        <double>[];

    final NumberFormat numberFormat = NumberFormat('#,##0.###', 'en');
    String? _format(double? value) {
      if (value == null || value.isNaN || value.isInfinite) {
        return null;
      }
      return numberFormat.format(value);
    }

    Widget buildHistorySection() {
      if (history == null || availableRanges.isEmpty) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: onBackground.withOpacity(0.12)),
          ),
          child: Text(
            'لا توجد بيانات تاريخية متاحة لهذه العملة.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: onBackground.withOpacity(0.7),
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HistoryRangeSelector(
            availableRanges: availableRanges,
            selectedRange: _currentRange,
            onSelectRange: (int days) {
              setState(() {
                _currentRange = days;
              });
              widget.onHistoryRangeSelected?.call(days);
            },
            brand: widget.brand,
            onBackground: onBackground,
            textTheme: theme.textTheme,
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: MiniTrendChart(
              values: chartValues,
              color: widget.brand,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            alignment: WrapAlignment.end,
            textDirection: ui.TextDirection.rtl,

            children: [
              _HistoryStat(
                label: 'التغير',
                value: summary?.changeSellPercent != null
                    ? '${summary!.changeSellPercent! >= 0 ? '+' : ''}'
                    '${summary.changeSellPercent!.toStringAsFixed(2)}%'
                    : '--',
                icon: summary == null
                    ? Icons.trending_flat
                    : summary.isNegativeTrend
                    ? Icons.arrow_downward_rounded
                    : summary.isPositiveTrend
                    ? Icons.arrow_upward_rounded
                    : Icons.trending_flat,
                color: summary == null
                    ? onBackground.withOpacity(0.6)
                    : summary.isNegativeTrend
                    ? Colors.redAccent
                    : summary.isPositiveTrend
                    ? Colors.green
                    : onBackground.withOpacity(0.6),
              ),
              _HistoryStat(
                label: 'أعلى بيع',
                value: _format(summary?.highSell) ?? '--',
                icon: Icons.north_east_rounded,
                color: widget.brand,
              ),
              _HistoryStat(
                label: 'أدنى بيع',
                value: _format(summary?.lowSell) ?? '--',
                icon: Icons.south_east_rounded,
                color: widget.brand,
              ),
            ],
          ),
        ],
      );
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 20,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: onBackground.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                widget.leading,
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        widget.title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: onBackground,
                          fontWeight: FontWeight.w800,
                        ),
                        textDirection: ui.TextDirection.rtl,

                      ),
                      if (widget.subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          widget.subtitle!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: onBackground.withOpacity(0.65),
                            fontWeight: FontWeight.w600,
                          ),
                          textDirection: ui.TextDirection.rtl,

                        ),
                      ],
                      if (widget.changeIndicator != null) ...[
                        const SizedBox(height: 8),
                        widget.changeIndicator!,
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: onBackground.withOpacity(0.08)),
              ),
              child: Directionality(
                textDirection: ui.TextDirection.rtl,

                child: Row(
                  children: [
                    Expanded(
                      child: _PriceColumn(
                        label: widget.sellLabel,
                        value: widget.sellValue,
                        color: widget.brand,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _PriceColumn(
                        label: widget.buyLabel,
                        value: widget.buyValue,
                        color: onBackground.withOpacity(0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  onPressed: widget.onToggleWatchlist,
                  icon: Icon(
                    widget.isWatchlisted
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: widget.isWatchlisted
                        ? Colors.amber
                        : onBackground.withOpacity(0.35),
                  ),
                  tooltip: widget.isWatchlisted
                      ? 'إزالة من قائمة المراقبة'
                      : 'إضافة إلى قائمة المراقبة',
                ),
                if (widget.onShare != null)
                  IconButton(
                    onPressed: widget.onShare,
                    icon: Icon(Icons.ios_share, color: widget.brand),
                    tooltip: 'مشاركة',
                  ),
              ],
            ),
            if (widget.notificationSelector != null) ...[
              const SizedBox(height: 12),
              widget.notificationSelector!,
            ],
            const SizedBox(height: 16),
            buildHistorySection(),
            if (widget.additionalSections.isNotEmpty) ...[
              const SizedBox(height: 20),
              ...widget.additionalSections,
            ],
          ],
        ),
      ),
    );
  }
}

class _PriceColumn extends StatelessWidget {
  const _PriceColumn({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: textTheme.labelMedium?.copyWith(
            color: color.withOpacity(0.8),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: textTheme.headlineSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _HistoryStat extends StatelessWidget {
  const _HistoryStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: textTheme.labelSmall?.copyWith(
                  color: color.withOpacity(0.75),
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                value,
                style: textTheme.titleMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}