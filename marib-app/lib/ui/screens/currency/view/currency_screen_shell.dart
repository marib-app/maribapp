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
import 'metals_tab_view.dart';
import '../state/state.dart';
import 'convert_tab_view.dart';
import 'rates_tab_view.dart';

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
    required this.onAssetFilterChanged,
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
  final void Function(AssetFilterType) onAssetFilterChanged;
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
        appBar: UiUtils.buildAppBar(
          context,
          showBackButton: true,
          title: 'العملات والذهب',
        ),
        body: Column(
          children: [
            const SizedBox(height: 8),
            _buildGovernorateSelector(context, brand, bg, onBg),
            const SizedBox(height: 8),
            _buildPreferencesBar(context, brand, bg, onBg),
            const SizedBox(height: 8),
            _buildSegmentedTabs(context, brand, bg, onBg),
            const SizedBox(height: 4),
            Expanded(child: _buildBody(context, brand, onBg)),
          ],
        ),
      ),
    );
  }

  Widget _buildGovernorateSelector(
      BuildContext context, Color brand, Color bg, Color onBg) {
    final theme = Theme.of(context);
    final border = _isDark(context) ? Colors.white12 : Colors.black12;
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

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(
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
          const SizedBox(height: 6),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: dropdownValue,
              isExpanded: true,
              iconEnabledColor: brand,
              style: theme.textTheme.bodyLarge?.copyWith(color: onBg),
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
      ),
    );
  }

  Widget _buildPreferencesBar(
      BuildContext context, Color brand, Color bg, Color onBg) {
    final theme = Theme.of(context);
    final border = _isDark(context) ? Colors.white12 : Colors.black12;
    final options = state.notificationOptions;

    final Color selectedColor = brand;
    final Color inactiveColor = _isDark(context)
        ? Colors.white.withOpacity(0.08)
        : Colors.black.withOpacity(0.05);
    final ButtonStyle segmentedStyle = ButtonStyle(
      backgroundColor: MaterialStateProperty.resolveWith((states) {
        if (states.contains(MaterialState.selected)) {
          return selectedColor.withOpacity(0.12);
        }
        return inactiveColor;
      }),
      foregroundColor: MaterialStateProperty.all(onBg),
      overlayColor: MaterialStateProperty.all(selectedColor.withOpacity(0.15)),
      side: MaterialStateProperty.resolveWith((states) {
        if (states.contains(MaterialState.selected)) {
          return BorderSide(color: selectedColor, width: 1.4);
        }
        return BorderSide(color: border);
      }),
      shape: MaterialStateProperty.all(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      textStyle: MaterialStateProperty.all(
        theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'عرض قائمة المراقبة فقط',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: onBg,
                  ),
                  textDirection: TextDirection.rtl,
                ),
              ),
              Switch(
                value: state.showWatchlistOnly,
                activeColor: brand,
                onChanged: onToggleWatchlistFilter,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'نوع الأصل',
            style: theme.textTheme.bodySmall?.copyWith(
              color: onBg.withOpacity(0.7),
              fontWeight: FontWeight.w600,
            ),
            textDirection: TextDirection.rtl,
          ),
          const SizedBox(height: 6),
          Directionality(
            textDirection: TextDirection.rtl,
            child: SegmentedButton<AssetFilterType>(
              style: segmentedStyle,
              segments: const <ButtonSegment<AssetFilterType>>[
                ButtonSegment<AssetFilterType>(
                  value: AssetFilterType.all,
                  label: Text('الكل'),
                  icon: Icon(Icons.all_inbox_outlined),
                ),
                ButtonSegment<AssetFilterType>(
                  value: AssetFilterType.currencies,
                  label: Text('عملات فقط'),
                  icon: Icon(Icons.payments_outlined),
                ),
                ButtonSegment<AssetFilterType>(
                  value: AssetFilterType.metals,
                  label: Text('معادن'),
                  icon: Icon(Icons.auto_awesome_outlined),
                ),
              ],
              selected: <AssetFilterType>{state.assetFilter},
              onSelectionChanged: (Set<AssetFilterType> value) {
                if (value.isNotEmpty) {
                  onAssetFilterChanged(value.first);
                }
              },
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'اتجاه التغيّر',
            style: theme.textTheme.bodySmall?.copyWith(
              color: onBg.withOpacity(0.7),
              fontWeight: FontWeight.w600,
            ),
            textDirection: TextDirection.rtl,
          ),
          const SizedBox(height: 6),
          Directionality(
            textDirection: TextDirection.rtl,
            child: SegmentedButton<RateChangeFilter>(
              style: segmentedStyle,
              segments: const <ButtonSegment<RateChangeFilter>>[
                ButtonSegment<RateChangeFilter>(
                  value: RateChangeFilter.all,
                  label: Text('الكل'),
                  icon: Icon(Icons.filter_list),
                ),
                ButtonSegment<RateChangeFilter>(
                  value: RateChangeFilter.rising,
                  label: Text('ارتفاع'),
                  icon: Icon(Icons.trending_up),
                ),
                ButtonSegment<RateChangeFilter>(
                  value: RateChangeFilter.falling,
                  label: Text('انخفاض'),
                  icon: Icon(Icons.trending_down),
                ),
              ],
              selected: <RateChangeFilter>{state.changeFilter},
              onSelectionChanged: (Set<RateChangeFilter> value) {
                if (value.isNotEmpty) {
                  onDirectionFilterChanged(value.first);
                }
              },
            ),
          ),
          if (options.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'تواتر الإشعارات',
              style: theme.textTheme.bodySmall?.copyWith(
                color: onBg.withOpacity(0.7),
                fontWeight: FontWeight.w600,
              ),
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: state.notificationFrequency.isNotEmpty
                  ? state.notificationFrequency
                  : options.first.value,
              decoration: InputDecoration(
                filled: true,
                fillColor: _isDark(context)
                    ? Colors.white.withOpacity(0.04)
                    : Colors.black.withOpacity(0.02),
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
              iconEnabledColor: brand,
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
        ],
      ),
    );
  }

  // ——— تبويبات موحدة الخط ———
  Widget _buildSegmentedTabs(
      BuildContext context, Color brand, Color bg, Color onBg) {
    final theme = Theme.of(context);
    final isDark = _isDark(context);
    final border = isDark ? Colors.white12 : Colors.black12;

    final base = theme.textTheme.labelLarge ?? const TextStyle(fontSize: 14);
    final selected = base.copyWith(fontWeight: FontWeight.w700, height: 1.1);
    final unselected = base.copyWith(fontWeight: FontWeight.w500, height: 1.1);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: TabBar(
        controller: tabController,
        tabs: const [
          Tab(text: 'الأسعار'),
          Tab(text: 'التحويل'),
          Tab(text: 'الذهب والفضة'),
        ],
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: brand, width: 3),
          insets: const EdgeInsets.symmetric(horizontal: 24),
        ),
        labelStyle: selected,
        unselectedLabelStyle: unselected,
        labelColor: onBg,
        unselectedLabelColor: onBg.withOpacity(0.5),
        overlayColor: MaterialStateProperty.all(Colors.transparent),
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
    // ألوان خفيفة جدًا
    final base = isDark
        ? Colors.white.withOpacity(0.08)
        : Colors.black.withOpacity(0.06);
    final highlight = isDark
        ? Colors.white.withOpacity(0.16)
        : Colors.black.withOpacity(0.12);

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
              child: const _SkeletonBar(height: 44, radius: 12),
            ),
          ),
          // عناصر قائمة (٦ صفوف)
          SliverList.separated(
            itemCount: 6,
            itemBuilder: (ctx, i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  const _SkeletonCircle(size: 28),
                  const SizedBox(width: 10),
                  // اسم العملة (سطر طويل قليلًا)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SkeletonLine(
                            widthFactor: 0.45, height: 12, radius: 6),
                        const SizedBox(height: 10),
                        // شارتا سعر صغيرتان يمينًا
                        Row(
                          children: [
                            const _SkeletonPill(
                                width: 70, height: 22, radius: 999),
                            const SizedBox(width: 8),
                            const _SkeletonPill(
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
              child: const _SkeletonBar(height: 40, radius: 10),
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
        color: Colors.white,
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
      decoration: const BoxDecoration(
        color: Colors.white,
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
          color: Colors.white,
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
