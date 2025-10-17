import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;
import 'package:flutter/foundation.dart' show listEquals;

import 'package:marib/data/model/currency_history.dart';
import 'package:marib/data/model/currency_rate.dart';

import '../state/state.dart';

class RatesTabView extends StatelessWidget {
  const RatesTabView({
    super.key,
    required this.state,
    required this.onShareRates,
    required this.brand,

    required this.onToggleCurrencyWatchlist,
    required this.onSelectHistoryRange,


  });

  final CurrencyViewState state;
  final VoidCallback onShareRates;
  final Color brand;
  final void Function(int) onToggleCurrencyWatchlist;
  final void Function(int? currencyId, int days) onSelectHistoryRange;

  bool _isDark(BuildContext c) =>
      Theme
          .of(c)
          .brightness == Brightness.dark;

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
    final dateStr = hasTime ? DateFormat('yyyy-MM-dd').format(
        state.lastUpdatedAt!) : 'غير متاح';
    final timeStr = hasTime
        ? DateFormat('HH:mm').format(state.lastUpdatedAt!)
        : '--:--';
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
                'تم استخدام أسعار ${state
                    .appliedGovernorateName} بدلًا من ${state
                    .requestedGovernorateName}.',
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


      }) {
    final theme = Theme.of(context);
    final onBg = _isDark(context) ? Colors.white : Colors.black;
    final divider = _isDark(context) ? Colors.white12 : Colors.black12;

    // تنسيق الرقم إن أمكن
    String _fmt(String v) {
      final double? d = double.tryParse(v.replaceAll(',', ''));
      return d == null ? v : NumberFormat('#,##0.####').format(d);
    }

    final TextStyle nameStyle = theme.textTheme.titleSmall?.copyWith(
      color: onBg,
      fontWeight: FontWeight.w800,
    ) ??
        TextStyle(color: onBg, fontWeight: FontWeight.w800, fontSize: 15.5);

    Widget fallbackIcon() {
      return Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: onBg.withOpacity(0.20)),
        ),
        child: Icon(
          Icons.account_balance_wallet_outlined,
          size: 17,
          color: brand,
        ),
      );
    }

    Widget leadingIcon;

    if (iconUrl != null && iconUrl.isNotEmpty) {
      leadingIcon = Container(
        width: 32,
        height: 32,
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
            errorBuilder: (_, __, ___) => fallbackIcon(),
            loadingBuilder: (ctx, child, progress) {
              if (progress == null) return child;
              return Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
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
    } else {
      leadingIcon = fallbackIcon();
    }

    Widget priceStat(String label, String value, Color accent) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
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
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 2, height: 18, color: accent.withOpacity(0.9)),
              const SizedBox(width: 6),
              Text(
                _fmt(value),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.2,
                ) ??
                    TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.2,
                      fontSize: 15.5,
                    ),
              ),
            ],
          ),
        ],
      );
    }


    final NumberFormat changeFormatter = NumberFormat('+#0.##;-#0.##;0', 'en');
    final NumberFormat highLowFormatter = NumberFormat('#,##0.###', 'en');

    final Set<int> availableRanges = history?.ranges.keys
        .map((dynamic key) => key is int
        ? key
        : int.tryParse(key.toString()))
        .whereType<int>()
        .toSet() ??
        <int>{};

    int effectiveRangeDays = selectedRangeDays;
    if (!availableRanges.contains(effectiveRangeDays) &&
        availableRanges.isNotEmpty) {
      if (availableRanges.contains(state.defaultHistoryRangeDays)) {
        effectiveRangeDays = state.defaultHistoryRangeDays;
      } else if (availableRanges.contains(7)) {
        effectiveRangeDays = 7;
      } else if (availableRanges.contains(3)) {
        effectiveRangeDays = 3;
      } else if (availableRanges.contains(1)) {
        effectiveRangeDays = 1;
      } else {
        effectiveRangeDays = availableRanges.first;
      }
    }

    final CurrencyHistoryRange? selectedRange =
    history?.range(effectiveRangeDays);
    final CurrencyHistorySummary? summary = selectedRange?.summary;
    final List<double> sparklineValues = selectedRange?.points
        .map((CurrencyHistoryPoint point) => point.sellPrice)
        .where((double value) => value.isFinite)
        .toList(growable: false) ??
        <double>[];

    final bool hasSparkline = sparklineValues.length >= 2;
    final bool hasHistoryData = history != null && availableRanges.isNotEmpty;
    final Color positiveColor = Colors.green;
    final Color negativeColor = Colors.redAccent;
    final Color neutralColor = onBg.withOpacity(0.6);
    final Color trendColor = summary == null
        ? neutralColor
        : summary.isNegativeTrend
        ? negativeColor
        : summary.isPositiveTrend
        ? positiveColor
        : neutralColor;

    final IconData trendIcon = summary == null
        ? Icons.trending_flat
        : summary.isNegativeTrend
        ? Icons.arrow_downward_rounded
        : summary.isPositiveTrend
        ? Icons.arrow_upward_rounded
        : Icons.trending_flat;

    final String changeText = summary?.changeSellPercent != null
        ? '${changeFormatter.format(summary!.changeSellPercent)}%'
        : '--';

    final String? highText = summary?.highSell != null
        ? highLowFormatter.format(summary!.highSell)
        : null;
    final String? lowText = summary?.lowSell != null
        ? highLowFormatter.format(summary!.lowSell)
        : null;

    Widget buildRangeSelector() {
      return _HistoryRangeChips(
        availableRanges: availableRanges,
        effectiveRangeDays: effectiveRangeDays,
        brand: brand,
        onBg: onBg,
        onHistoryRangeSelected: onHistoryRangeSelected,
        textTheme: theme.textTheme,
      );
    }


    final Widget star = IconButton(
      onPressed: onToggleWatchlist,
      icon: Icon(
        isWatchlisted ? Icons.star_rounded : Icons.star_outline_rounded,
        color: isWatchlisted ? Colors.amber : onBg.withOpacity(0.35),
      ),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 40, height: 40),
      splashRadius: 20,
      tooltip:
      isWatchlisted ? 'إزالة من قائمة المراقبة' : 'إضافة إلى قائمة المراقبة',
    );


    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {},
        splashColor: brand.withOpacity(0.06),
        highlightColor: brand.withOpacity(0.03),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: divider, width: 1)),
          ),
          child: LayoutBuilder(
            builder: (BuildContext ctx, BoxConstraints cons) {
              final bool narrow = cons.maxWidth < 360;

              final Widget leading = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  leadingIcon,
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      name,
                      style: nameStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textDirection: TextDirection.rtl,
                    ),
                  ),
                ],
              );

              final Widget sellBlock = priceStat('بيع', sell, Colors.redAccent);
              final Widget buyBlock = priceStat('شراء', buy, Colors.green);

              final Widget priceContent = narrow
                  ? Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  sellBlock,
                  const SizedBox(height: 6),
                  buyBlock,
                ],
              )
                  : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  sellBlock,
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    width: 1,
                    height: 22,
                    color: onBg.withOpacity(0.12),
                  ),
                  buyBlock,
                ],
              );

              Widget buildHistorySection(double availableWidth) {
                final List<Widget> historyChildren = <Widget>[
                  buildRangeSelector(),
                  const SizedBox(height: 8),
                ];

                if (hasSparkline) {
                  historyChildren.add(
                    SizedBox(
                      width: availableWidth,
                      height: 40,
                      child: _MiniTrendChart(
                        values: sparklineValues,
                        color: trendColor,
                      ),
                    ),
                  );
                } else if (hasHistoryData) {
                  historyChildren.add(
                    Container(
                      width: availableWidth,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: onBg.withOpacity(0.12)),
                      ),
                      child: Icon(
                        Icons.trending_flat,
                        color: trendColor,
                        size: 18,
                      ),
                    ),
                  );
                } else {
                  historyChildren.add(
                    Container(
                      width: availableWidth,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: onBg.withOpacity(0.12)),
                      ),
                      child: Text(
                        'لا يوجد سجل',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: onBg.withOpacity(0.5),
                          fontWeight: FontWeight.w600,
                        ) ??
                            TextStyle(
                              color: onBg.withOpacity(0.5),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                      ),

                    ),

                  );
                }

                historyChildren.add(const SizedBox(height: 6));
                historyChildren.add(
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: trendColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(trendIcon, size: 14, color: trendColor),
                        const SizedBox(width: 4),
                        Text(
                          changeText,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: trendColor,
                            fontWeight: FontWeight.w700,
                          ) ??
                              TextStyle(
                                color: trendColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                        ),
                      ],
                    ),
                  ),
                );

                if (highText != null && lowText != null) {
                  historyChildren.addAll([
                    const SizedBox(height: 4),
                    Text(
                      'أعلى: $highText | أدنى: $lowText',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: onBg.withOpacity(0.6),
                        fontWeight: FontWeight.w600,
                      ) ??
                          TextStyle(
                            color: onBg.withOpacity(0.6),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                      textDirection: TextDirection.rtl,
                    ),
                  ]);
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: historyChildren,
                );
              }

              if (narrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: leading),
                        star,
                      ],
                    ),
                    const SizedBox(height: 8),
                    priceContent,
                    const SizedBox(height: 12),
                    buildHistorySection(cons.maxWidth),
                  ],
                );
              }

              return Row(

                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(child: leading),
                        const SizedBox(width: 12),
                        priceContent,
                        const SizedBox(width: 16),
                        SizedBox(
                          width: 160,
                          child: buildHistorySection(160),
                        ),
                      ],
                    ),
                  ),
                  star,
                ],
              );
            },
          ),
        ),
      ),
    );
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

                style: Theme
                    .of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(
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
    final Color foreground = dark
        ? Colors.orange.shade200
        : Colors.orange.shade800;

    return Tooltip(
      message: 'تم رصد أن البيانات المعروضة قديمة، وسيتم تحديثها عند توفر مصادر أحدث.',
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

class _HistoryRangeChips extends StatelessWidget {
  const _HistoryRangeChips({
    required this.availableRanges,
    required this.effectiveRangeDays,
    required this.onHistoryRangeSelected,
    required this.brand,
    required this.onBg,
    required this.textTheme,
  });

  final Set<int> availableRanges;
  final int effectiveRangeDays;
  final ValueChanged<int> onHistoryRangeSelected;
  final Color brand;
  final Color onBg;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    const List<int> options = <int>[1, 3, 7];
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: options.map((int days) {
          final bool enabled = availableRanges.contains(days);
          final bool selected = enabled && effectiveRangeDays == days;
          final String label = days == 1 ? 'آخر يوم' : 'آخر $days أيام';
          final Color labelColor = selected
              ? Colors.white
              : onBg.withOpacity(enabled ? 0.85 : 0.35);

          return ChoiceChip(
            label: Text(label),
            selected: selected,
            onSelected: enabled
                ? (bool value) {
              if (value) {
                onHistoryRangeSelected(days);
              }
            }
                : null,
            labelStyle: textTheme.labelSmall?.copyWith(
              color: labelColor,
              fontWeight: FontWeight.w700,
            ) ??
                TextStyle(
                  color: labelColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
            selectedColor: brand,
            backgroundColor: onBg.withOpacity(0.05),
            disabledColor: onBg.withOpacity(0.06),
            shape: StadiumBorder(
              side: BorderSide(
                color: selected ? brand : onBg.withOpacity(0.12),
              ),
            ),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          );
        }).toList(),
      ),
    );
  }
}




class _MiniTrendChart extends StatelessWidget {
  const _MiniTrendChart({required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (values.length < 2) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Theme
                .of(context)
                .dividerColor
                .withOpacity(0.12),
          ),
        ),
      );
    }

    return CustomPaint(
      painter: _MiniTrendChartPainter(
        values: values,
        color: color,
        background: Theme
            .of(context)
            .canvasColor,
      ),
    );
  }
}

class _MiniTrendChartPainter extends CustomPainter {
  _MiniTrendChartPainter({
    required this.values,
    required this.color,
    required this.background,
  });

  final List<double> values;
  final Color color;
  final Color background;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) {
      return;
    }

    final double minValue = values.reduce((double a, double b) =>
    a < b
        ? a
        : b);
    final double maxValue = values.reduce((double a, double b) =>
    a > b
        ? a
        : b);
    final double range = (maxValue - minValue).abs() < 0.0001
        ? 1
        : (maxValue - minValue);

    final Path path = Path();
    for (int i = 0; i < values.length; i++) {
      final double x = (i / (values.length - 1)) * size.width;
      final double normalized = (values[i] - minValue) / range;
      final double y = size.height - (normalized * size.height);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final Paint fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        colors: [color.withOpacity(0.18), color.withOpacity(0.05)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final Path areaPath = Path.from(path)
      ..lineTo(size.width, size.height)..lineTo(0, size.height)
      ..close();

    canvas.drawPath(areaPath, fillPaint);

    final Paint linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = color;

    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _MiniTrendChartPainter oldDelegate) {
    return !listEquals(oldDelegate.values, values) ||
        oldDelegate.color != color;
  }
}




// ===================================================================
// تبويب 2: التحويل — تخطيط رأسي + زر تبادل في المنتصف (بدوال داخلية)
// ===================================================================