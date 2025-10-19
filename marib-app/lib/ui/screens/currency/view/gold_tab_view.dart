import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;

import 'package:marib/data/model/metal_rate.dart';

import '../state/state.dart';

class GoldTabView extends StatelessWidget {
  const GoldTabView({
    super.key,
    required this.state,
    required this.onShareRates,
    required this.brand,
    required this.onToggleMetalWatchlist,
  });

  final void Function(int) onToggleMetalWatchlist;

  final CurrencyViewState state;
  final VoidCallback onShareRates;
  final Color brand;

  DateTime? get _lastUpdated => state.metalsLastUpdatedAt;

  String? _resolveSource() {
    String? pick(List<MetalRate> rates) {
      for (final MetalRate rate in rates) {
        final String? source = rate.source;
        if (source != null && source.trim().isNotEmpty) {
          return source.trim();
        }
      }
      return null;
    }

    return pick(state.displayGoldRates) ?? pick(state.goldRates);
  }

  bool _isDark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;

  String get rateFallbackLabel => 'المتوسط الوطني';

  String _headerGovernorateLabel() {
    final String? applied =
        state.appliedGovernorateName ?? state.requestedGovernorateName;
    if (applied != null && applied.isNotEmpty) {
      return state.usedFallback ? '$applied (افتراضي)' : applied;
    }

    return rateFallbackLabel;
  }

  String _governorateLabel(MetalRate rate) {
    final String? name = rate.quoteGovernorateName ??
        state.appliedGovernorateName ??
        state.requestedGovernorateName;

    final String base =
        (name == null || name.isEmpty) ? rateFallbackLabel : name;

    if (rate.quoteUsedFallback || rate.quoteIsDefault) {
      return '$base (افتراضي)';
    }

    return base;
  }

  String _format(double? value) {
    if (value == null) {
      return '—';
    }

    return NumberFormat('#,##0.000').format(value);
  }

  // ——— دوال داخلية ———
  Widget _header(BuildContext context) {
    final onBg = _isDark(context) ? Colors.white : Colors.black;
    final border = _isDark(context) ? Colors.white12 : Colors.black12;
    final updatedLabel = _lastUpdated == null
        ? 'آخر تحديث غير متاح'
        : DateFormat('yyyy-MM-dd HH:mm').format(_lastUpdated!);
    final source = _resolveSource() ?? 'غير متاح';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(Icons.workspace_premium_outlined,
              size: 18, color: onBg.withOpacity(0.7)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'أسعار الذهب — $updatedLabel',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: onBg.withOpacity(0.85),
                        fontWeight: FontWeight.w700,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textDirection: TextDirection.rtl,
                ),
                const SizedBox(height: 2),
                Text(
                  'المصدر: $source',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: onBg.withOpacity(0.6),
                        fontWeight: FontWeight.w600,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textDirection: TextDirection.rtl,
                ),
                const SizedBox(height: 2),
                Text(
                  'المحافظة المعروضة: ${_headerGovernorateLabel()}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: onBg.withOpacity(0.6),
                        fontWeight: FontWeight.w500,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textDirection: TextDirection.rtl,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onShareRates,
            icon: Icon(Icons.ios_share, size: 18, color: brand),
            splashRadius: 18,
            tooltip: 'مشاركة',
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, MetalRate rate, bool isWatchlisted) {
    final onBg = _isDark(context) ? Colors.white : Colors.black;

    final Color borderColor = onBg.withOpacity(0.25);
    final Color fallbackIconColor = Colors.amber[700] ?? Colors.amber;

    final nameStyle = Theme.of(context).textTheme.titleSmall?.copyWith(
              color: onBg,
              fontWeight: FontWeight.w800,
            ) ??
        TextStyle(color: onBg, fontWeight: FontWeight.w800, fontSize: 15.5);
    final labelStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
              color: onBg.withOpacity(0.6),
              fontWeight: FontWeight.w700,
            ) ??
        TextStyle(color: onBg.withOpacity(0.6), fontWeight: FontWeight.w700);

    final star = IconButton(
      onPressed: () => onToggleMetalWatchlist(rate.id),
      icon: Icon(
        isWatchlisted ? Icons.star_rounded : Icons.star_outline_rounded,
        color: isWatchlisted ? Colors.amber : onBg.withOpacity(0.35),
      ),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 40, height: 40),
      splashRadius: 20,
      tooltip: isWatchlisted
          ? 'إزالة من قائمة المراقبة'
          : 'إضافة إلى قائمة المراقبة',
    );

    Widget chip(String value, Color color) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: color.withOpacity(0.5)),
          ),
          child: Text(
            value,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.2,
                ),
          ),
        );

    Widget buildFallbackIcon() {
      return Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: borderColor),
        ),
        child: Icon(
          Icons.workspace_premium,
          size: 16,
          color: fallbackIconColor,
        ),
      );
    }

    Widget buildIcon() {
      final String? iconUrl = rate.iconUrl;
      if (iconUrl != null && iconUrl.isNotEmpty) {
        final String semanticsLabel =
            rate.iconAlt != null && rate.iconAlt!.trim().isNotEmpty
                ? rate.iconAlt!
                : 'أيقونة ${rate.displayName}';

        return Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: borderColor),
          ),
          clipBehavior: Clip.antiAlias,
          child: Semantics(
            label: semanticsLabel,
            child: Image.network(
              iconUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => buildFallbackIcon(),
              loadingBuilder: (context, child, progress) {
                if (progress == null) {
                  return child;
                }

                return Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(brand),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      }

      return buildFallbackIcon();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          // أيقونة المعدن
          buildIcon(),
          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  rate.displayName,
                  style: nameStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textDirection: TextDirection.rtl,
                ),
                const SizedBox(height: 2),
                Text(
                  _governorateLabel(rate),
                  style: labelStyle.copyWith(
                      fontSize: 11, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textDirection: TextDirection.rtl,
                ),
              ],
            ),
          ),
          star,

          const SizedBox(width: 10),

          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('بيع', style: labelStyle),
              const SizedBox(height: 4),
              chip(_format(rate.sellPrice), Colors.orangeAccent),
            ],
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('شراء', style: labelStyle),
              const SizedBox(height: 4),
              chip(_format(rate.buyPrice), Colors.blueAccent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _empty(BuildContext context) {
    final onBg = _isDark(context) ? Colors.white : Colors.black;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.info_outline, color: brand),
          const SizedBox(height: 8),
          Text(
            state.showWatchlistOnly
                ? 'لا توجد عناصر مراقبة في الذهب حالياً'
                : 'لا توجد بيانات ذهب حالياً',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: onBg,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final divider = _isDark(context) ? Colors.white12 : Colors.black12;
    final rates = state.displayGoldRates;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _header(context)),
        if (rates.isEmpty)
          SliverFillRemaining(hasScrollBody: false, child: _empty(context))
        else
          SliverList.separated(
            itemCount: rates.length,
            itemBuilder: (ctx, i) {
              final MetalRate rate = rates[i];
              final bool isWatchlisted = state.metalWatchlist.contains(rate.id);

              return _row(ctx, rate, isWatchlisted);
            },
            separatorBuilder: (_, __) => Divider(height: 1, color: divider),
          ),
      ],
    );
  }
}
