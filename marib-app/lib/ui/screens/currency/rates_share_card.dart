import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:marib/data/model/currency_rate.dart';

import 'package:marib/data/model/metal_rate.dart';

import 'state/state.dart';

class RatesShareCard extends StatelessWidget {
  const RatesShareCard({
    super.key,
    required this.viewState,
    required this.boundaryKey,
  });

  final CurrencyViewState viewState;
  final GlobalKey boundaryKey;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color backgroundColor = isDark ? const Color(0xFF0F172A) : Colors.white;
    final Color textColor = isDark ? Colors.white : const Color(0xFF111827);
    final Color accentColor = theme.colorScheme.secondary;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: IgnorePointer(
        child: Material(
          type: MaterialType.transparency,
          child: Center(
            child: RepaintBoundary(
              key: boundaryKey,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 420),
                margin: const EdgeInsets.all(24),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.4 : 0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 12),
                    ),
                  ],
                  border: Border.all(
                    color: accentColor.withOpacity(0.2),
                    width: 1.5,
                  ),
                ),
                child: _RatesShareContent(
                  viewState: viewState,
                  textColor: textColor,
                  accentColor: accentColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RatesShareContent extends StatelessWidget {
  const _RatesShareContent({
    required this.viewState,
    required this.textColor,
    required this.accentColor,
  });

  final CurrencyViewState viewState;
  final Color textColor;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextStyle? titleStyle = theme.textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w800,
      color: textColor,
    );
    final TextStyle sectionStyle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w700,
      color: accentColor,
    ) ?? TextStyle(
      fontWeight: FontWeight.w700,
      fontSize: 18,
      color: accentColor,
    );
    final TextStyle bodyStyle = theme.textTheme.bodyMedium?.copyWith(
      height: 1.4,
      color: textColor,
    ) ?? TextStyle(
      height: 1.4,
      color: textColor,
      fontSize: 14,
    );

    final NumberFormat numberFormat = NumberFormat('#,##0.000');

    final List<Widget> sections = <Widget>[
      Text('أسعار العملات والمعادن', style: titleStyle),
      const SizedBox(height: 4),
      Text(
        viewState.appliedGovernorateName != null
            ? 'المحافظة المعروضة: ${viewState.appliedGovernorateName}'
            : 'المتوسط الافتراضي الوطني',
        style: bodyStyle.copyWith(color: textColor.withOpacity(0.75)),
      ),
      const SizedBox(height: 16),
    ];

    void addDivider() {
      sections.add(const Divider(thickness: 1.2));
      sections.add(const SizedBox(height: 12));
    }

    final List<CurrencyRate> currencyRates = viewState.displayRates
        .whereType<CurrencyRate>()
        .toList(growable: false);
    final List<MetalRate> inlineMetalRates = viewState.displayRates
        .whereType<MetalRate>()
        .toList(growable: false);

    if (currencyRates.isNotEmpty) {

      sections
        ..add(Text('العملات', style: sectionStyle))
        ..add(const SizedBox(height: 8));

      for (final CurrencyRate rate in currencyRates) {
        final String name = _readString(() => rate.currencyName) ?? 'عملة غير معروفة';
        final String buy = _formatPrice(rate.buyPrice, numberFormat);
        final String sell = _formatPrice(rate.sellPrice, numberFormat);
        final String source = _normalizeSource(rate.quoteSource);

        sections.add(_ShareRateRow(
          title: name,
          subtitle: 'شراء: $buy | بيع: $sell',
          source: 'المصدر: $source',
          textColor: textColor,
          bodyStyle: bodyStyle,
        ));
      }

      addDivider();
    }

    List<MetalRate> _mergeMetalRates(
        List<MetalRate> existing,
        Iterable<MetalRate> additional,
        ) {
      final Map<int, MetalRate> merged = <int, MetalRate>{};
      for (final MetalRate rate in existing) {
        merged[rate.id] = rate;
      }

      for (final MetalRate rate in additional) {
        merged.putIfAbsent(rate.id, () => rate);
      }
      return merged.values.toList(growable: false);
    }

    void addMetalSection(String title, List<MetalRate> rates) {
      if (rates.isEmpty) {
        return;
      }
      sections
        ..add(Text(title, style: sectionStyle))
        ..add(const SizedBox(height: 8));

      for (final MetalRate rate in rates) {
        sections.add(_ShareRateRow(
          title: rate.displayName,
          subtitle:
          '${_metalGovernorateLabel(rate)} — شراء: ${_formatPrice(rate.buyPrice, numberFormat)} | بيع: ${_formatPrice(rate.sellPrice, numberFormat)}',
          source: 'المصدر: ${_normalizeSource(rate.source)}',
          textColor: textColor,
          bodyStyle: bodyStyle,
        ));
      }

      addDivider();
    }


    final List<MetalRate> goldRates = _mergeMetalRates(
      viewState.displayGoldRates,
      inlineMetalRates.where((MetalRate rate) => rate.isGold),
    );
    final List<MetalRate> silverRates = _mergeMetalRates(
      viewState.displaySilverRates,
      inlineMetalRates.where((MetalRate rate) => rate.isSilver),
    );
    final List<MetalRate> otherMetalRates = inlineMetalRates
        .where((MetalRate rate) => !rate.isGold && !rate.isSilver)
        .toList(growable: false);

    addMetalSection('أسعار الذهب', goldRates);
    addMetalSection('أسعار الفضة', silverRates);
    addMetalSection('أسعار المعادن الأخرى', otherMetalRates);


    final DateTime? currencyUpdatedAt = viewState.lastUpdatedAt;
    if (currencyUpdatedAt != null) {
      sections.add(Text(
        'آخر تحديث للعملات: ${DateFormat('yyyy-MM-dd HH:mm').format(currencyUpdatedAt)}',
        style: bodyStyle,
      ));
      sections.add(const SizedBox(height: 4));
    }

    final DateTime? metalsUpdatedAt = viewState.metalsLastUpdatedAt;
    if (metalsUpdatedAt != null) {
      sections.add(Text(
        'آخر تحديث للمعادن: ${DateFormat('yyyy-MM-dd HH:mm').format(metalsUpdatedAt)}',
        style: bodyStyle,
      ));
      sections.add(const SizedBox(height: 4));
    }

    sections
      ..add(const SizedBox(height: 8))
      ..add(Text(
        'حمّل تطبيق "مارب بين يديك" الآن واستفد من المزيد من الخدمات المميزة!',
        style: bodyStyle.copyWith(fontWeight: FontWeight.w600),
      ));

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sections,
    );
  }

  String? _readString(String? Function() accessor) {
    try {
      final String? result = accessor();
      if (result != null && result.trim().isNotEmpty) {
        return result.trim();
      }
    } catch (_) {}
    return null;
  }


  String _normalizeSource(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return 'غير متاح';
    }
    return raw.trim();
  }




  String _metalGovernorateLabel(MetalRate rate) {
    final String? name = rate.quoteGovernorateName ??
        viewState.appliedGovernorateName ??
        viewState.requestedGovernorateName;

    final String base = (name == null || name.isEmpty) ? 'المتوسط الوطني' : name;

    if (rate.quoteUsedFallback || rate.quoteIsDefault) {
      return '$base (افتراضي)';
    }

    return base;
  }



  String _formatPrice(dynamic value, NumberFormat numberFormat) {
    if (value is num) {
      return numberFormat.format(value);
    }
    if (value is String && value.trim().isNotEmpty) {
      final double? parsed = double.tryParse(value);
      if (parsed != null) {
        return numberFormat.format(parsed);
      }
      return value.trim();
    }
    return '—';
  }
}

class _ShareRateRow extends StatelessWidget {
  const _ShareRateRow({
    required this.title,
    required this.subtitle,
    required this.source,
    required this.textColor,
    required this.bodyStyle,
  });

  final String title;
  final String subtitle;
  final String source;
  final Color textColor;
  final TextStyle bodyStyle;

  @override
  Widget build(BuildContext context) {
    final TextStyle titleStyle = bodyStyle.copyWith(
      fontWeight: FontWeight.w700,
      color: textColor,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: titleStyle),
          const SizedBox(height: 4),
          Text(subtitle, style: bodyStyle),
          const SizedBox(height: 2),
          Text(
            source,
            style: bodyStyle.copyWith(color: textColor.withOpacity(0.7)),
          ),
        ],
      ),
    );
  }
}