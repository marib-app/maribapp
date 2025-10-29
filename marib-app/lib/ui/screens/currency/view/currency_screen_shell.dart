// lib/new_code/ui/currency/currency_screen_ui.dart
//
// Shell UI for the currency screen.
// - يوفر البنية العامة، التبويبات، وأجزاء الحالة العامة.
// - كل تبويب موجود في ملفه الخاص داخل مجلد view/.
// - يحافظ على نمط الألوان والحدود كما في التصميم الأصلي.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';
import 'package:marib/data/cubits/currency/currency_filters.dart';

import 'package:marib/data/model/preference_option.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart'; // context.color
import 'package:marib/utils/ui_utils.dart';
import 'metals/metals_tab_view.dart';
import '../state/state.dart';
import 'convert_tab_view.dart';
import 'rates_tab_view.dart';
import 'shell/currency_header.dart';
import 'shell/currency_tab_bar.dart';
import 'shell/rates_filter_bar.dart';

class CurrencyScreenUI extends StatelessWidget {
  const CurrencyScreenUI({
    super.key,
    required this.state,
    required this.tabController,
    required this.amountController,
    required this.onChangeFrom,
    required this.onChangeTo,
    required this.onAmountChanged,
    required this.onReset,
    required this.onConvert,
    required this.onGovernorateChanged,
    required this.onShareRates,
    required this.amountInputFormatters,
    required this.systemUiOverlayStyle,
    required this.onToggleWatchlistFilter,
    required this.onToggleCurrencyWatchlist,
    required this.onToggleMetalWatchlist,
    required this.onNotificationFrequencyChanged,
    required this.onSelectHistoryRange,
    required this.onDirectionFilterChanged,
    required this.onNotificationRegionChanged,
  });

  final CurrencyViewState state;
  final void Function(bool) onToggleWatchlistFilter;
  final void Function(int) onToggleCurrencyWatchlist;
  final void Function(int) onToggleMetalWatchlist;
  final void Function(String) onNotificationFrequencyChanged;
  final TabController tabController;
  final TextEditingController amountController;

  final ValueChanged<String> onChangeFrom;
  final ValueChanged<String> onChangeTo;
  final ValueChanged<String> onAmountChanged;
  final VoidCallback onReset;
  final VoidCallback onConvert;
  final VoidCallback onShareRates;
  final void Function(String?) onGovernorateChanged;
  final void Function(int? currencyId, int days) onSelectHistoryRange;
  final void Function(int currencyId, String? regionCode)
      onNotificationRegionChanged;
  final void Function(RateChangeFilter) onDirectionFilterChanged;
  final List<TextInputFormatter> amountInputFormatters;
  final SystemUiOverlayStyle systemUiOverlayStyle;

  bool _isDark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;

  @override
  Widget build(BuildContext context) {
    final bg = _isDark(context) ? Colors.black : Colors.white;
    final onBg = _isDark(context) ? Colors.white : Colors.black;
    final brand = context.color.territoryColor;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemUiOverlayStyle,
      child: Scaffold(
        backgroundColor: bg,
        appBar: CurrencyHeader(
          state: state,
          onToggleWatchlistFilter: onToggleWatchlistFilter,
          onGovernorateChanged: onGovernorateChanged,
          onNotificationFrequencyChanged: onNotificationFrequencyChanged,
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CurrencyTabBar(tabController: tabController),
            AnimatedBuilder(
              animation: tabController,
              builder: (context, child) {
                final bool showFilters = tabController.index == 0;
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  switchInCurve: Curves.easeInOut,
                  switchOutCurve: Curves.easeInOut,
                  child: showFilters
                      ? RatesFilterBar(
                          key: const ValueKey('rates-compact-filters'),
                          state: state,
                          onToggleWatchlistFilter: onToggleWatchlistFilter,
                          onDirectionFilterChanged: onDirectionFilterChanged,
                        )
                      : const SizedBox.shrink(
                          key: ValueKey('rates-compact-filters-hidden'),
                        ),
                );
              },
            ),
            const SizedBox(height: 4),
            Expanded(child: _buildBody(context, brand, onBg)),
          ],
        ),
      ),
    );
  }

  // ——— محتوى الصفحة ———
  Widget _buildBody(BuildContext context, Color brand, Color onBg) {
    switch (state.status) {
      case CurrencyPageStatus.loading:
        return _buildLoadingShimmer(context); // 👈 شيمر بدل الدائرة
      case CurrencyPageStatus.error:
        return Center(child: Text(state.errorMessage ?? 'حدث خطأ ما'));
      case CurrencyPageStatus.ready:
        return TabBarView(
          controller: tabController,
          children: [
            RatesTabView(
              state: state,
              onShareRates: onShareRates,
              brand: brand,
              onToggleCurrencyWatchlist: onToggleCurrencyWatchlist,
              onToggleMetalWatchlist: onToggleMetalWatchlist,
              onSelectHistoryRange: onSelectHistoryRange,
              onNotificationRegionChanged: onNotificationRegionChanged,
            ),
            ConvertTabView(
              state: state,
              amountController: amountController,
              onChangeFrom: onChangeFrom,
              onChangeTo: onChangeTo,
              onAmountChanged: onAmountChanged,
              onReset: onReset,
              onConvert: onConvert,
              amountInputFormatters: amountInputFormatters,
              brand: brand,
              onGovernorateChanged: onGovernorateChanged,
            ),
            MetalsTabView(
              onShareRates: onShareRates,
              state: state,
              brand: brand,
              onToggleMetalWatchlist: onToggleMetalWatchlist,
            ),
          ],
        );
    }
  }

  // ——— شيمر خفيف جدًا للوضعين ———
  Widget _buildLoadingShimmer(BuildContext context) {
    final isDark = _isDark(context);
    final colorScheme = Theme.of(context).colorScheme;
    final base = colorScheme.shimmerBaseColor;
    final highlight = colorScheme.shimmerHighlightColor;

    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      period: const Duration(milliseconds: 1200),
      child: CustomScrollView(
        slivers: [
          // شريط علوي شبيه بالترويسة
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: _SkeletonBar(height: 44, radius: 12),
            ),
          ),
          // عناصر قائمة (٦ صفوف)
          SliverList.separated(
            itemCount: 6,
            itemBuilder: (ctx, i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  _SkeletonCircle(size: 28),
                  const SizedBox(width: 10),
                  // اسم العملة (سطر طويل قليلًا)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SkeletonLine(
                            widthFactor: 0.45, height: 12, radius: 6),
                        const SizedBox(height: 10),
                        // شارتا سعر صغيرتان يمينًا
                        Row(
                          children: [
                            _SkeletonPill(
                                width: 70, height: 22, radius: 999),
                            const SizedBox(width: 8),
                            _SkeletonPill(
                                width: 70, height: 22, radius: 999),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            separatorBuilder: (_, __) => Divider(
              height: 1,
              color: isDark ? Colors.white12 : Colors.black12,
            ),
          ),
          // سطر ملاحظة سفلي
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
              child: _SkeletonBar(height: 40, radius: 10),
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonBar extends StatelessWidget {
  const _SkeletonBar({required this.height, this.radius = 8});

  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.shimmerContentColor,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class _SkeletonCircle extends StatelessWidget {
  const _SkeletonCircle({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.shimmerContentColor,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  const _SkeletonLine(
      {this.widthFactor = 1, this.height = 10, this.radius = 6});

  final double widthFactor;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.shimmerContentColor,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

class _SkeletonPill extends StatelessWidget {
  const _SkeletonPill(
      {required this.width, required this.height, this.radius = 999});

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.shimmerContentColor,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
