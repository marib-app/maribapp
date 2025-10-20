import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;

import 'package:marib/data/model/metal_rate.dart';
import 'widgets/rate_detail_sheet.dart';

import '../state/state.dart';

enum _MetalsFilter {
  all,
  gold,
  silver,
  other,
}

class MetalsTabView extends StatefulWidget {
  const MetalsTabView({
    super.key,
    required this.state,
    required this.brand,
    required this.onShareRates,
    required this.onToggleMetalWatchlist,
  });

  final CurrencyViewState state;
  final Color brand;
  final VoidCallback onShareRates;
  final void Function(int) onToggleMetalWatchlist;

  @override
  State<MetalsTabView> createState() => _MetalsTabViewState();
}

class _MetalsTabViewState extends State<MetalsTabView> {
  static const String _defaultGovernorateLabel = 'المتوسط الوطني';

  final NumberFormat _numberFormat = NumberFormat('#,##0.000');
  _MetalsFilter _selectedFilter = _MetalsFilter.all;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  Color get _onBackground => _isDark ? Colors.white : Colors.black;

  Color get _borderColor => _isDark ? Colors.white12 : Colors.black12;

  @override
  Widget build(BuildContext context) {
    final List<_MetalSection> sections = _resolveSections();
    final bool hasData = sections.any((section) => section.rates.isNotEmpty);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildHeader(sections)),
        SliverToBoxAdapter(child: _buildFilterBar(sections)),
        if (!hasData)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _buildEmptyState(context),
          )
        else
          for (final _MetalSection section in sections)
            ..._buildSection(context, section),
      ],
    );
  }

  Widget _buildHeader(List<_MetalSection> sections) {
    final DateTime? updatedAt = widget.state.metalsLastUpdatedAt;
    final String updatedLabel = updatedAt == null
        ? 'آخر تحديث غير متاح'
        : DateFormat('yyyy-MM-dd HH:mm').format(updatedAt);

    final String? source = _resolveSource(sections) ?? 'غير متاح';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        children: [
          Icon(Icons.workspace_premium_outlined,
              size: 18, color: _onBackground.withOpacity(0.7)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'أسعار المعادن الثمينة — $updatedLabel',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: _onBackground.withOpacity(0.85),
                        fontWeight: FontWeight.w700,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textDirection: TextDirection.rtl,
                ),
                const SizedBox(height: 2),
                Text(
                  'المصدر: $source',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: _onBackground.withOpacity(0.6),
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
                        color: _onBackground.withOpacity(0.6),
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
            onPressed: widget.onShareRates,
            icon: Icon(Icons.ios_share, size: 18, color: widget.brand),
            splashRadius: 18,
            tooltip: 'مشاركة',
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(List<_MetalSection> sections) {
    final List<_FilterOption> options = <_FilterOption>[
      const _FilterOption(filter: _MetalsFilter.all, label: 'الكل'),
      const _FilterOption(filter: _MetalsFilter.gold, label: 'الذهب'),
      const _FilterOption(filter: _MetalsFilter.silver, label: 'الفضة'),
    ];

    final bool hasOther = sections
        .firstWhere(
          (section) => section.filter == _MetalsFilter.other,
          orElse: () => const _MetalSection.empty(),
        )
        .exists;
    if (hasOther) {
      options
          .add(const _FilterOption(filter: _MetalsFilter.other, label: 'أخرى'));
    } else if (_selectedFilter == _MetalsFilter.other) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _selectedFilter == _MetalsFilter.other) {
          setState(() {
            _selectedFilter = _MetalsFilter.all;
          });
        }
      });
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: options
            .map(
              (option) => ChoiceChip(
                label: Text(option.label),
                selected: _selectedFilter == option.filter,
                onSelected: (_) {
                  setState(() {
                    _selectedFilter = option.filter;
                  });
                },
                selectedColor: widget.brand.withOpacity(0.12),
                labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: _selectedFilter == option.filter
                          ? widget.brand
                          : _onBackground.withOpacity(0.75),
                      fontWeight: FontWeight.w700,
                    ),
                backgroundColor: Colors.transparent,
                side: BorderSide(color: _borderColor),
              ),
            )
            .toList(growable: false),
      ),
    );
  }

  Iterable<Widget> _buildSection(BuildContext context, _MetalSection section) {
    if (_selectedFilter != _MetalsFilter.all &&
        _selectedFilter != section.filter) {
      return const <Widget>[];
    }

    if (section.rates.isEmpty) {
      if (_selectedFilter == section.filter) {
        return <Widget>[
          SliverFillRemaining(
            hasScrollBody: false,
            child: _buildSectionEmptyState(context, section),
          ),
        ];
      }
      return const <Widget>[];
    }

    final Color divider = _borderColor;

    return <Widget>[
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: section.accent.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(section.icon, color: section.iconColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  section.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: _onBackground,
                        fontWeight: FontWeight.w800,
                      ),
                  textDirection: TextDirection.rtl,
                ),
              ),
              if (section.subtitle != null)
                Text(
                  section.subtitle!,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: _onBackground.withOpacity(0.6),
                        fontWeight: FontWeight.w600,
                      ),
                  textDirection: TextDirection.rtl,
                ),
            ],
          ),
        ),
      ),
      SliverList.separated(
        itemCount: section.rates.length,
        itemBuilder: (BuildContext _, int index) {
          final MetalRate rate = section.rates[index];
          final bool isWatchlisted =
              widget.state.metalWatchlist.contains(rate.id);
          return _buildRateRow(section, rate, isWatchlisted);
        },
        separatorBuilder: (_, __) => Divider(height: 1, color: divider),
      ),
    ];
  }

  Widget _buildRateRow(
    _MetalSection section,
    MetalRate rate,
    bool isWatchlisted,
  ) {
    final ThemeData theme = Theme.of(context);
    final String sellValue = _formatPrice(rate.sellPrice);
    final String buyValue = _formatPrice(rate.buyPrice);

    Widget buildIcon({double size = 48}) {
      final Color outline = _onBackground.withOpacity(0.25);
      final bool showFallback = rate.quoteUsedFallback || rate.quoteIsDefault;
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: outline),
            ),
            child:
                Icon(section.icon, color: section.iconColor, size: size * 0.5),
          ),
          if (showFallback)
            Positioned(
              bottom: -2,
              right: -2,
              child: Container(
                width: size * 0.38,
                height: size * 0.38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: section.accent,
                  border: Border.all(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    width: size * 0.08,
                  ),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
        ],
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
                  color: _onBackground.withOpacity(0.6),
                  fontWeight: FontWeight.w700,
                ) ??
                TextStyle(
                  color: _onBackground.withOpacity(0.6),
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

    final Widget changeIndicator = _buildChangeIndicatorWidget(
      icon: Icons.trending_flat,
      color: _onBackground.withOpacity(0.6),
      text: '--',
      compact: true,
    );
    final Widget detailChangeIndicator = _buildChangeIndicatorWidget(
      icon: Icons.trending_flat,
      color: _onBackground.withOpacity(0.6),
      text: '--',
    );

    void handleTap() {
      _showMetalDetails(
        rate: rate,
        sellValue: sellValue,
        buyValue: buyValue,
        isWatchlisted: isWatchlisted,
        leading: buildIcon(size: 60),
        changeIndicator: detailChangeIndicator,
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: handleTap,
        splashColor: widget.brand.withOpacity(0.06),
        highlightColor: widget.brand.withOpacity(0.03),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              buildIcon(size: 46),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      rate.displayName,
                      style: theme.textTheme.titleSmall?.copyWith(
                            color: _onBackground,
                            fontWeight: FontWeight.w800,
                          ) ??
                          TextStyle(
                            color: _onBackground,
                            fontWeight: FontWeight.w800,
                            fontSize: 15.5,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textDirection: TextDirection.rtl,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      rate.karatLabel,
                      style: theme.textTheme.labelMedium?.copyWith(
                            color: _onBackground.withOpacity(0.6),
                            fontWeight: FontWeight.w600,
                          ) ??
                          TextStyle(
                            color: _onBackground.withOpacity(0.6),
                            fontWeight: FontWeight.w600,
                          ),
                      textDirection: TextDirection.rtl,
                    ),
                    const SizedBox(height: 8),
                    Directionality(
                      textDirection: TextDirection.rtl,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          priceColumn('سعر البيع', sellValue, widget.brand),
                          const SizedBox(width: 16),
                          priceColumn(
                            'سعر الشراء',
                            buyValue,
                            _onBackground.withOpacity(0.85),
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
                color: _onBackground.withOpacity(0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChangeIndicatorWidget({
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

  void _showMetalDetails({
    required MetalRate rate,
    required String sellValue,
    required String buyValue,
    required bool isWatchlisted,
    required Widget leading,
    required Widget changeIndicator,
  }) {
    final List<Widget> infoSections = _buildMetalDetailSections(rate);
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
          sellValue: sellValue,
          buyLabel: 'سعر الشراء',
          buyValue: buyValue,
          brand: widget.brand,
          isWatchlisted: isWatchlisted,
          onToggleWatchlist: () => widget.onToggleMetalWatchlist(rate.id),
          onShare: widget.onShareRates,
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

  List<Widget> _buildMetalDetailSections(MetalRate rate) {
    final List<Widget> cards = <Widget>[
      _buildInfoCard('المحافظة المعروضة', _governorateLabel(rate)),
    ];

    if (rate.source != null && rate.source!.trim().isNotEmpty) {
      cards.add(
        _buildInfoCard('المصدر', rate.source!.trim()),
      );
    }

    if (rate.quotedAt != null) {
      cards.add(
        _buildInfoCard(
          'آخر تحديث',
          DateFormat('yyyy-MM-dd HH:mm').format(rate.quotedAt!),
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

  Widget _buildInfoCard(String label, String value) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _onBackground.withOpacity(0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: _onBackground.withOpacity(0.7),
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: _onBackground,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.info_outline, color: widget.brand),
          const SizedBox(height: 8),
          Text(
            widget.state.showWatchlistOnly
                ? 'لا توجد عناصر مراقبة في المعادن حالياً'
                : 'لا توجد بيانات متاحة حالياً للمعادن',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: _onBackground,
                  fontWeight: FontWeight.w700,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionEmptyState(BuildContext context, _MetalSection section) {
    final String message;
    if (widget.state.showWatchlistOnly) {
      switch (section.filter) {
        case _MetalsFilter.gold:
          message = 'لا توجد عناصر مراقبة في الذهب حالياً';
          break;
        case _MetalsFilter.silver:
          message = 'لا توجد عناصر مراقبة في الفضة حالياً';
          break;
        case _MetalsFilter.other:
          message = 'لا توجد عناصر مراقبة في المعادن الأخرى حالياً';
          break;
        case _MetalsFilter.all:
          message = 'لا توجد عناصر مراقبة حالياً';
          break;
      }
    } else {
      switch (section.filter) {
        case _MetalsFilter.gold:
          message = 'لا توجد بيانات ذهب حالياً';
          break;
        case _MetalsFilter.silver:
          message = 'لا توجد بيانات فضة حالياً';
          break;
        case _MetalsFilter.other:
          message = 'لا توجد بيانات للمعادن الأخرى حالياً';
          break;
        case _MetalsFilter.all:
          message = 'لا توجد بيانات متاحة حالياً للمعادن';
          break;
      }
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.info_outline, color: widget.brand),
          const SizedBox(height: 8),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: _onBackground,
                  fontWeight: FontWeight.w700,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  List<_MetalSection> _resolveSections() {
    final MetalsRatesState metals = widget.state.metals;
    return <_MetalSection>[
      _MetalSection(
        filter: _MetalsFilter.gold,
        title: 'أسعار الذهب',
        icon: Icons.workspace_premium_outlined,
        iconColor: Colors.amber[700] ?? Colors.amber,
        accent: Colors.amber[700] ?? Colors.amber,
        rates: metals.displayGoldRates,
        subtitle: metals.goldRates.isNotEmpty ? null : 'لا توجد بيانات',
      ),
      _MetalSection(
        filter: _MetalsFilter.silver,
        title: 'أسعار الفضة',
        icon: Icons.diamond_outlined,
        iconColor: Colors.grey[400] ?? Colors.grey,
        accent: Colors.grey[400] ?? Colors.grey,
        rates: metals.displaySilverRates,
        subtitle: metals.silverRates.isNotEmpty ? null : 'لا توجد بيانات',
      ),
      if (metals.displayOtherRates.isNotEmpty || metals.otherRates.isNotEmpty)
        _MetalSection(
          filter: _MetalsFilter.other,
          title: 'أسعار المعادن الأخرى',
          icon: Icons.inventory_2_outlined,
          iconColor: widget.brand,
          accent: widget.brand,
          rates: metals.displayOtherRates,
          subtitle: metals.otherRates.isNotEmpty ? null : 'لا توجد بيانات',
        ),
    ];
  }

  String? _resolveSource(List<_MetalSection> sections) {
    String? pick(Iterable<MetalRate> rates) {
      for (final MetalRate rate in rates) {
        final String? source = rate.source;
        if (source != null && source.trim().isNotEmpty) {
          return source.trim();
        }
      }
      return null;
    }

    final Iterable<MetalRate> visibleRates = sections
        .where((section) =>
            _selectedFilter == _MetalsFilter.all ||
            section.filter == _selectedFilter)
        .expand((section) => section.rates);

    return pick(visibleRates) ?? pick(widget.state.metals.allRates);
  }

  String _headerGovernorateLabel() {
    final String? applied = widget.state.appliedGovernorateName ??
        widget.state.requestedGovernorateName;
    if (applied != null && applied.isNotEmpty) {
      return widget.state.usedFallback ? '$applied (افتراضي)' : applied;
    }
    return _defaultGovernorateLabel;
  }

  String _governorateLabel(MetalRate rate) {
    final String? name = rate.quoteGovernorateName ??
        widget.state.appliedGovernorateName ??
        widget.state.requestedGovernorateName;
    final String base =
        (name == null || name.isEmpty) ? _defaultGovernorateLabel : name;
    if (rate.quoteUsedFallback || rate.quoteIsDefault) {
      return '$base (افتراضي)';
    }
    return base;
  }

  String _formatPrice(double? value) {
    if (value == null) {
      return '—';
    }
    return _numberFormat.format(value);
  }
}

class _FilterOption {
  const _FilterOption({required this.filter, required this.label});

  final _MetalsFilter filter;
  final String label;
}

class _MetalSection {
  const _MetalSection({
    required this.filter,
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.accent,
    required this.rates,
    this.subtitle,
  });

  const _MetalSection.empty()
      : filter = _MetalsFilter.all,
        title = '',
        icon = Icons.circle,
        iconColor = Colors.transparent,
        accent = Colors.transparent,
        rates = const <MetalRate>[],
        subtitle = null;

  final _MetalsFilter filter;
  final String title;
  final IconData icon;
  final Color iconColor;
  final Color accent;
  final List<MetalRate> rates;
  final String? subtitle;

  bool get exists => title.isNotEmpty;
}
