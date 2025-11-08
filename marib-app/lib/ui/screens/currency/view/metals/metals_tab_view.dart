import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;

import 'package:marib/data/model/metal_rate.dart';
import '../../state/state.dart';
import '../widgets/rate_detail_sheet.dart';
import 'metal_rate_card.dart';
import 'metal_section.dart';
import 'metals_filter_bar.dart';
import 'metals_header.dart';

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
  MetalsFilter _selectedFilter = MetalsFilter.all;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  Color get _onBackground => _isDark ? Colors.white : Colors.black;

  Color get _borderColor => _isDark ? Colors.white12 : Colors.black12;

  @override
  Widget build(BuildContext context) {
    final List<MetalSection> sections = _resolveSections();
    final bool hasOther = sections.any((section) => section.filter == MetalsFilter.other);

    if (!hasOther && _selectedFilter == MetalsFilter.other) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        if (_selectedFilter == MetalsFilter.other) {
          setState(() {
            _selectedFilter = MetalsFilter.all;
          });
        }
      });
    }

    final bool hasData = sections.any((section) => section.hasRates);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: MetalsHeader(
            updatedAt: widget.state.metalsLastUpdatedAt,
            source: _resolveSource(sections),
            governorateLabel: _headerGovernorateLabel(),
            onShare: widget.onShareRates,
            brand: widget.brand,
            onBackground: _onBackground,
            borderColor: _borderColor,
          ),
        ),
        SliverToBoxAdapter(
          child: MetalsFilterBar(
            selectedFilter: _selectedFilter,
            onFilterSelected: _handleFilterChange,
            showOther: hasOther,
            borderColor: _borderColor,
            onBackground: _onBackground,
            brand: widget.brand,
          ),
        ),
        if (!hasData)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _buildEmptyState(context),
          )
        else
          for (final MetalSection section in sections) ..._buildSection(context, section),
      ],
    );
  }

  void _handleFilterChange(MetalsFilter filter) {
    if (_selectedFilter == filter) {
      return;
    }
    setState(() {
      _selectedFilter = filter;
    });
  }

  Iterable<Widget> _buildSection(BuildContext context, MetalSection section) {
    if (_selectedFilter != MetalsFilter.all && _selectedFilter != section.filter) {
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
          final bool isWatchlisted = widget.state.metalWatchlist.contains(rate.id);
          final String sellValue = _formatPrice(rate.sellPrice);
          final String buyValue = _formatPrice(rate.buyPrice);

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

          return MetalRateCard(
            section: section,
            rate: rate,
            sellValue: sellValue,
            buyValue: buyValue,
            brand: widget.brand,
            onBackground: _onBackground,
            changeIndicator: changeIndicator,
            onTap: () {
              _showMetalDetails(
                rate: rate,
                sellValue: sellValue,
                buyValue: buyValue,
                isWatchlisted: isWatchlisted,
                leading: MetalRateIcon(
                  section: section,
                  rate: rate,
                  size: 60,
                  onBackground: _onBackground,
                ),
                changeIndicator: detailChangeIndicator,
              );
            },
          );
        },
        separatorBuilder: (_, __) => Divider(height: 1, color: divider),
      ),
    ];
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

  Widget _buildSectionEmptyState(BuildContext context, MetalSection section) {
    final String message;
    if (widget.state.showWatchlistOnly) {
      switch (section.filter) {
        case MetalsFilter.gold:
          message = 'لا توجد عناصر مراقبة في الذهب حالياً';
          break;
        case MetalsFilter.silver:
          message = 'لا توجد عناصر مراقبة في الفضة حالياً';
          break;
        case MetalsFilter.other:
          message = 'لا توجد عناصر مراقبة في المعادن الأخرى حالياً';
          break;
        case MetalsFilter.all:
          message = 'لا توجد عناصر مراقبة حالياً';
          break;
      }
    } else {
      switch (section.filter) {
        case MetalsFilter.gold:
          message = 'لا توجد بيانات ذهب حالياً';
          break;
        case MetalsFilter.silver:
          message = 'لا توجد بيانات فضة حالياً';
          break;
        case MetalsFilter.other:
          message = 'لا توجد بيانات للمعادن الأخرى حالياً';
          break;
        case MetalsFilter.all:
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

  List<MetalSection> _resolveSections() {
    final MetalsRatesState metals = widget.state.metals;
    return <MetalSection>[
      MetalSection(
        filter: MetalsFilter.gold,
        title: 'أسعار الذهب',
        icon: Icons.workspace_premium_outlined,
        iconColor: Colors.amber[700] ?? Colors.amber,
        accent: Colors.amber[700] ?? Colors.amber,
        rates: metals.displayGoldRates,
        subtitle: metals.goldRates.isNotEmpty ? null : 'لا توجد بيانات',
      ),
      MetalSection(
        filter: MetalsFilter.silver,
        title: 'أسعار الفضة',
        icon: Icons.diamond_outlined,
        iconColor: Colors.grey[400] ?? Colors.grey,
        accent: Colors.grey[400] ?? Colors.grey,
        rates: metals.displaySilverRates,
        subtitle: metals.silverRates.isNotEmpty ? null : 'لا توجد بيانات',
      ),
      if (metals.displayOtherRates.isNotEmpty || metals.otherRates.isNotEmpty)
        MetalSection(
          filter: MetalsFilter.other,
          title: 'أسعار المعادن الأخرى',
          icon: Icons.inventory_2_outlined,
          iconColor: widget.brand,
          accent: widget.brand,
          rates: metals.displayOtherRates,
          subtitle: metals.otherRates.isNotEmpty ? null : 'لا توجد بيانات',
        ),
    ];
  }

  String? _resolveSource(List<MetalSection> sections) {
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
    _selectedFilter == MetalsFilter.all || section.filter == _selectedFilter)
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