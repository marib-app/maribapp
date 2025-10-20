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
          actions: [
            _buildGovernorateAction(context, brand),
          ],
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSegmentedTabs(context, brand, bg, onBg),
            _buildCompactFilters(context, brand, onBg),
            const SizedBox(height: 4),
            Expanded(child: _buildBody(context, brand, onBg)),
          ],
        ),
      ),
    );
  }

  Widget _buildGovernorateAction(BuildContext context, Color brand) {
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
    final background = _isDark(context) ? Colors.black : Colors.white;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        final sheetBg = _isDark(sheetContext) ? Colors.black : Colors.white;
        final sheetOnBg = _isDark(sheetContext) ? Colors.white : Colors.black;
        final sheetBrand = sheetContext.color.territoryColor;
        final notificationSettings = _buildNotificationSettings(
            sheetContext, sheetBrand, sheetBg, sheetOnBg);

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
                    style:
                        Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: sheetOnBg,
                            ),
                  ),
                  const SizedBox(height: 20),
                  _buildGovernorateSelector(
                    sheetContext,
                    sheetBrand,
                    sheetBg,
                    sheetOnBg,
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile.adaptive(
                    value: state.showWatchlistOnly,
                    onChanged: onToggleWatchlistFilter,
                    activeColor: sheetBrand,
                    contentPadding: EdgeInsets.zero,
                    secondary:
                        Icon(Icons.visibility_outlined, color: sheetBrand),
                    title: Text(
                      'عرض قائمة المراقبة فقط',
                      style:
                          Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
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

  Widget _buildCompactFilters(BuildContext context, Color brand, Color onBg) {
    final theme = Theme.of(context);
    final bool isDark = _isDark(context);
    final Color borderColor = isDark ? Colors.white24 : Colors.black12;
    final Color selectedBg = brand.withOpacity(isDark ? 0.25 : 0.12);

    Widget label(String text) {
      return Padding(
        padding: const EdgeInsetsDirectional.only(end: 4),
        child: Text(
          text,
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: onBg.withOpacity(0.7),
          ),
        ),
      );
    }

    ChoiceChip buildChoiceChip({
      required String text,
      required bool selected,
      required VoidCallback onTap,
      IconData? icon,
    }) {
      final Color textColor = selected ? onBg : onBg.withOpacity(0.8);
      return ChoiceChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: textColor),
              const SizedBox(width: 4),
            ],
            Text(
              text,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
        selected: selected,
        onSelected: (_) {
          if (!selected) {
            onTap();
          }
        },
        backgroundColor: Colors.transparent,
        selectedColor: selectedBg,
        pressElevation: 0,
        shape: StadiumBorder(
          side: BorderSide(color: selected ? brand : borderColor),
        ),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      );
    }

    final watchlistChip = FilterChip(
      label: Text(
        'قائمة المراقبة',
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: state.showWatchlistOnly ? onBg : onBg.withOpacity(0.8),
        ),
      ),
      avatar: Icon(
        Icons.visibility_outlined,
        size: 18,
        color: state.showWatchlistOnly ? onBg : onBg.withOpacity(0.8),
      ),
      selected: state.showWatchlistOnly,
      onSelected: onToggleWatchlistFilter,
      showCheckmark: false,
      backgroundColor: Colors.transparent,
      selectedColor: selectedBg,
      shape: StadiumBorder(
        side: BorderSide(
          color: state.showWatchlistOnly ? brand : borderColor,
        ),
      ),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            label('الاتجاه'),
            buildChoiceChip(
              text: 'الكل',
              selected: state.changeFilter == RateChangeFilter.all,
              onTap: () => onDirectionFilterChanged(RateChangeFilter.all),
              icon: Icons.filter_list,
            ),
            buildChoiceChip(
              text: 'ارتفاع',
              selected: state.changeFilter == RateChangeFilter.rising,
              onTap: () => onDirectionFilterChanged(RateChangeFilter.rising),
              icon: Icons.trending_up,
            ),
            buildChoiceChip(
              text: 'انخفاض',
              selected: state.changeFilter == RateChangeFilter.falling,
              onTap: () => onDirectionFilterChanged(RateChangeFilter.falling),
              icon: Icons.trending_down,
            ),
            const SizedBox(width: 12),
            label('نوع الأصل'),
            buildChoiceChip(
              text: 'الكل',
              selected: state.assetFilter == AssetFilterType.all,
              onTap: () => onAssetFilterChanged(AssetFilterType.all),
              icon: Icons.all_inbox_outlined,
            ),
            buildChoiceChip(
              text: 'عملات',
              selected: state.assetFilter == AssetFilterType.currencies,
              onTap: () => onAssetFilterChanged(AssetFilterType.currencies),
              icon: Icons.payments_outlined,
            ),
            buildChoiceChip(
              text: 'معادن',
              selected: state.assetFilter == AssetFilterType.metals,
              onTap: () => onAssetFilterChanged(AssetFilterType.metals),
              icon: Icons.auto_awesome_outlined,
            ),
            const SizedBox(width: 12),
            watchlistChip,
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
            fillColor: _isDark(context)
                ? Colors.white.withOpacity(0.05)
                : Colors.black.withOpacity(0.03),
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

  Widget? _buildNotificationSettings(
      BuildContext context, Color brand, Color bg, Color onBg) {
    final options = state.notificationOptions;
    if (options.isEmpty) {
      return null;
    }
    final theme = Theme.of(context);
    final border = _isDark(context) ? Colors.white24 : Colors.black12;
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
            fillColor: _isDark(context)
                ? Colors.white.withOpacity(0.05)
                : Colors.black.withOpacity(0.03),
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
