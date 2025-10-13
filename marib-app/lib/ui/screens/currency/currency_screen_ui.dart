// lib/new_code/ui/currency/currency_screen_ui.dart
//
// UI-Only — ثلاث كلاسات فقط:
// 1) CurrencyScreenUI  (الهيكل العام + التبويبات)
// 2) RatesTabView      (تبويب الأسعار)
// 3) ConvertTabView    (تبويب التحويل)
// 4) GoldTabView       (تبويب الذهب)
//
// ملاحظات:
// - الخلفية: أبيض في الفاتح / أسود في الداكن.
// - تمييز رمادي خفيف وحدود رفيعة.
// - لون الهوية من context.color.territoryColor.
// - لا يوجد Widgets مساعدة إضافية؛ كل شيء بدوال خاصة داخل الكلاسات.
// - يعتمد على CurrencyViewState/CurrencyPageStatus من ملف المنطق.
//
// تأكد أن TabController في المنطق length: 3.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;
import 'package:shimmer/shimmer.dart';

import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:marib/utils/extensions/extensions.dart'; // context.color

import 'currency_screen.dart' show CurrencyViewState, CurrencyPageStatus;
import 'package:marib/data/model/metal_rate.dart';
import 'package:marib/data/model/preference_option.dart';



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
          Tab(text: 'الذهب'),
          Tab(text: 'الفضة'),
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
          physics: const BouncingScrollPhysics(),
          children: [
            RatesTabView(
              state: state,
              onShareRates: onShareRates,
              brand: brand,
              onToggleCurrencyWatchlist: onToggleCurrencyWatchlist,
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
            GoldTabView(
              state: state,
              onShareRates: onShareRates,
              brand: brand,
              onToggleMetalWatchlist: onToggleMetalWatchlist,
            ),
            SilverTabView(
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
    final base = isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06);
    final highlight = isDark ? Colors.white.withOpacity(0.16) : Colors.black.withOpacity(0.12);

    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      period: const Duration(milliseconds: 1200),
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // شريط علوي شبيه بالترويسة
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: _skeletonBar(height: 44, radius: 12),
            ),
          ),
          // عناصر قائمة (٦ صفوف)
          SliverList.separated(
            itemCount: 6,
            itemBuilder: (ctx, i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  _skeletonCircle(size: 28),
                  const SizedBox(width: 10),
                  // اسم العملة (سطر طويل قليلًا)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _skeletonLine(widthFactor: 0.45, height: 12, radius: 6),
                        const SizedBox(height: 10),
                        // شارتا سعر صغيرتان يمينًا
                        Row(
                          children: [
                            _skeletonPill(width: 70, height: 22, radius: 999),
                            const SizedBox(width: 8),
                            _skeletonPill(width: 70, height: 22, radius: 999),
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
              child: _skeletonBar(height: 40, radius: 10),
            ),
          ),
        ],
      ),
    );
  }

  // ——— دوال عناصر الشيمر ———

  Widget _skeletonBar({required double height, double radius = 8}) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white, // اللون يتصبغ بالشيمر
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  Widget _skeletonCircle({required double size}) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Colors.white, // اللون يتصبغ بالشيمر
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _skeletonLine({double widthFactor = 1, double height = 10, double radius = 6}) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: Colors.white, // اللون يتصبغ بالشيمر
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }

  Widget _skeletonPill({required double width, required double height, double radius = 999}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white, // اللون يتصبغ بالشيمر
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}





class RatesTabView extends StatelessWidget {
  const RatesTabView({
    super.key,
    required this.state,
    required this.onShareRates,
    required this.brand,

    required this.onToggleCurrencyWatchlist,




  });

  final CurrencyViewState state;
  final VoidCallback onShareRates;
  final Color brand;
  final void Function(int) onToggleCurrencyWatchlist;

  bool _isDark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;

  // ---------- Header (بسيط بدون إطارات ثقيلة) ----------
  Widget _header(BuildContext context) {
    final theme = Theme.of(context);
    final onBg = _isDark(context) ? Colors.white : Colors.black;

    final hasTime = state.lastUpdatedAt != null;
    final dateStr = hasTime ? DateFormat('yyyy-MM-dd').format(state.lastUpdatedAt!) : 'غير متاح';
    final timeStr = hasTime ? DateFormat('HH:mm').format(state.lastUpdatedAt!) : '--:--';

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
      }) {
    final theme = Theme.of(context);
    final onBg = _isDark(context) ? Colors.white : Colors.black;
    final divider = _isDark(context) ? Colors.white12 : Colors.black12;

    // تنسيق الرقم إن أمكن
    String _fmt(String v) {
      final d = double.tryParse(v.replaceAll(',', ''));
      return d == null ? v : NumberFormat('#,##0.####').format(d);
    }

    final nameStyle = theme.textTheme.titleSmall?.copyWith(
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
        child: Icon(Icons.account_balance_wallet_outlined, size: 17, color: brand),
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

    final Widget star = IconButton(
      onPressed: onToggleWatchlist,
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
            builder: (ctx, cons) {
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
                        // فاصل عمودي خافت بين البيع والشراء
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 10),
                          width: 1,
                          height: 22,
                          color: onBg.withOpacity(0.12),
                        ),
                        buyBlock,
                      ],
              );

              return Row(
                crossAxisAlignment:
                narrow ? CrossAxisAlignment.start : CrossAxisAlignment.center,
                children: [
              Expanded(
              child: Row(
              crossAxisAlignment: narrow
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
                children: [
                  Expanded(child: leading),
                  const SizedBox(width: 12),
                  priceContent,
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
    String _buy(d)  => (d as dynamic).buyPrice?.toString() ?? '';
    String? _icon(d) => (d as dynamic).iconUrl?.toString();
    String? _iconAlt(d) => (d as dynamic).iconAlt?.toString();
    if (rates.isEmpty) {
      final onBg = _isDark(context) ? Colors.white : Colors.black;
      return ListView(
        physics: const BouncingScrollPhysics(),
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
      physics: const BouncingScrollPhysics(),
      itemCount: rates.length + 2, // + header + note
      itemBuilder: (ctx, i) {
        if (i == 0) return _header(context);
        if (i == rates.length + 1) return _noteCard(context);
        final dynamic r = rates[i - 1];
        final int rateId = (r as dynamic).id is int ? (r as dynamic).id as int : 0;
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
        );
      },
    );
  }
}











// ===================================================================
// تبويب 2: التحويل — تخطيط رأسي + زر تبادل في المنتصف (بدوال داخلية)
// ===================================================================
class ConvertTabView extends StatelessWidget {
  const ConvertTabView({
    super.key,
    required this.state,
    required this.amountController,
    required this.onChangeFrom,
    required this.onChangeTo,
    required this.onAmountChanged,
    required this.onReset,
    required this.onConvert,
    required this.amountInputFormatters,
    required this.brand,
  });

  final CurrencyViewState state;
  final TextEditingController amountController;
  final ValueChanged<String> onChangeFrom;
  final ValueChanged<String> onChangeTo;
  final ValueChanged<String> onAmountChanged;
  final VoidCallback onReset;
  final VoidCallback onConvert;
  final List<TextInputFormatter> amountInputFormatters;
  final Color brand;

  bool _isDark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;

  // ——— دوال داخلية ———

  List<MetalRate> get _rates => state.goldRates;
  DateTime? get _lastUpdated => state.metalsLastUpdatedAt;

  String _format(double value) => NumberFormat('#,##0.000').format(value);

  OutlineInputBorder _border(BuildContext context) {
    final color = _isDark(context) ? Colors.white12 : Colors.black12;
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color),
    );
  }

  Widget _labeledBox(BuildContext context, String label, Widget child) {
    final onBg = _isDark(context) ? Colors.white : Colors.black;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
              color: onBg.withOpacity(0.7),
              fontWeight: FontWeight.w700,
            )),
        const SizedBox(height: 6),
        child,
      ],
    );
  }

  Widget _swapButton(BuildContext context) {
    return Center(
      child: InkResponse(
        onTap: () {
          if (state.toCurrency.isNotEmpty && state.fromCurrency.isNotEmpty) {
            final oldFrom = state.fromCurrency;
            final oldTo = state.toCurrency;
            onChangeFrom(oldTo);
            onChangeTo(oldFrom);
          }
        },
        radius: 28,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: brand.withOpacity(0.45)),
          ),
          child: Icon(Icons.swap_vert, color: brand),
        ),
      ),
    );
  }

  Widget _resultStrip(BuildContext context, String value) {
    final onBg = _isDark(context) ? Colors.white : Colors.black;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: brand.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              "المبلغ المحول",
              style: TextStyle(
                color: onBg.withOpacity(0.75),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: onBg,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _primaryBtn(BuildContext context, {required String label, required IconData icon, required VoidCallback onPressed}) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: brand,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _ghostBtn(BuildContext context, {required String label, required IconData icon, required VoidCallback onPressed}) {
    final onBg = _isDark(context) ? Colors.white : Colors.black;
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: onBg),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: onBg.withOpacity(0.25)),
        foregroundColor: onBg,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final edge = const EdgeInsets.fromLTRB(12, 8, 12, 18);

    String _name(d) => (d as dynamic).currencyName?.toString() ?? '';
    final all = state.rates;
    final fromItems = all
        .map<DropdownMenuItem<String>>((r) {
      final v = _name(r);
      return DropdownMenuItem(value: v, child: Text(v));
    })
        .toList(growable: false);
    final toItems = all
        .where((r) => _name(r) != state.fromCurrency)
        .map<DropdownMenuItem<String>>((r) {
      final v = _name(r);
      return DropdownMenuItem(value: v, child: Text(v));
    })
        .toList(growable: false);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: edge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // من
          _labeledBox(
            context,
            'من',
            DropdownButtonFormField<String>(
              value: state.fromCurrency.isEmpty ? null : state.fromCurrency,
              items: fromItems,
              onChanged: (v) => v != null ? onChangeFrom(v) : null,
              decoration: InputDecoration(
                border: _border(context),
                enabledBorder: _border(context),
                focusedBorder: _border(context),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // تبادل
          _swapButton(context),
          const SizedBox(height: 10),

          // إلى
          _labeledBox(
            context,
            'إلى',
            DropdownButtonFormField<String>(
              value: state.toCurrency.isEmpty ? null : state.toCurrency,
              items: toItems,
              onChanged: (v) => v != null ? onChangeTo(v) : null,
              decoration: InputDecoration(
                border: _border(context),
                enabledBorder: _border(context),
                focusedBorder: _border(context),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // المبلغ
          _labeledBox(
            context,
            'المبلغ',
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              inputFormatters: amountInputFormatters,
              onChanged: onAmountChanged,
              decoration: InputDecoration(
                hintText: "ادخل المبلغ",
                border: _border(context),
                enabledBorder: _border(context),
                focusedBorder: _border(context),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // النتيجة
          _resultStrip(
            context,
            state.hasCalculated
                ? "${NumberFormat('#,##0.##').format(state.convertedAmount)} ${state.toCurrency}"
                : "---",
          ),
          const SizedBox(height: 12),

          // الأزرار
          Row(
            children: [
              Expanded(
                child: _primaryBtn(context, label: "تحويل", icon: Icons.check, onPressed: onConvert),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ghostBtn(context, label: "تصفير", icon: Icons.refresh, onPressed: onReset),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ===================================================================
// تبويب 3: الذهب — نفس منطق الأسعار مع فلترة (ذهب/عيار/Gold)
// ===================================================================
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

  bool _isDark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;

  String _format(double value) => NumberFormat('#,##0.000').format(value);
  // ——— دوال داخلية ———
  Widget _header(BuildContext context) {
    final onBg = _isDark(context) ? Colors.white : Colors.black;
    final border = _isDark(context) ? Colors.white12 : Colors.black12;
    final updatedLabel = _lastUpdated == null
        ? 'آخر تحديث غير متاح'
        : DateFormat('yyyy-MM-dd HH:mm').format(_lastUpdated!);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(Icons.workspace_premium_outlined, size: 18, color: onBg.withOpacity(0.7)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'أسعار الذهب — $updatedLabel',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: onBg.withOpacity(0.85),
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textDirection: TextDirection.rtl,
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          // دائرة ذهب
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: onBg.withOpacity(0.25)),
            ),
            child: Icon(Icons.workspace_premium, size: 16, color: Colors.amber[700]),
          ),
          const SizedBox(width: 10),

          Expanded(
            child: Text(
              rate.displayName,
              style: nameStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textDirection: TextDirection.rtl,
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
      physics: const BouncingScrollPhysics(),
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


class SilverTabView extends StatelessWidget {
  const SilverTabView({
    super.key,
    required this.state,
    required this.brand,
    required this.onToggleMetalWatchlist,

  });
  final void Function(int) onToggleMetalWatchlist;

  final CurrencyViewState state;
  final Color brand;

  bool _isDark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;

  List<MetalRate> get _rates => state.displaySilverRates;

  String _format(double value) => NumberFormat('#,##0.000').format(value);

  Widget _header(BuildContext context) {
    final onBg = _isDark(context) ? Colors.white : Colors.black;
    final border = _isDark(context) ? Colors.white12 : Colors.black12;
    final updatedLabel = state.metalsLastUpdatedAt == null
        ? 'آخر تحديث غير متاح'
        : DateFormat('yyyy-MM-dd HH:mm').format(state.metalsLastUpdatedAt!);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(Icons.diamond_outlined, size: 18, color: onBg.withOpacity(0.7)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'أسعار الفضة — $updatedLabel',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: onBg.withOpacity(0.85),
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textDirection: TextDirection.rtl,
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, MetalRate rate, bool isWatchlisted) {
    final onBg = _isDark(context) ? Colors.white : Colors.black;
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: onBg.withOpacity(0.25)),
            ),
            child: Icon(
              Icons.diamond,
              size: 16,
              color: Colors.grey[400] ?? Colors.grey,
            ),

          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              rate.displayName,
              style: nameStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textDirection: TextDirection.rtl,
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('بيع', style: labelStyle),
              const SizedBox(height: 4),
              chip(_format(rate.sellPrice), Colors.blueGrey),
            ],
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('شراء', style: labelStyle),
              const SizedBox(height: 4),
              chip(_format(rate.buyPrice), Colors.indigoAccent),
            ],
          ),
          const SizedBox(width: 8),
          star,
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
                ? 'قائمة مراقبة الفضة فارغة حالياً'
                : 'لا توجد بيانات فضة حالياً',
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
    final rates = _rates;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: _header(context)),
        if (rates.isEmpty)

          SliverFillRemaining(hasScrollBody: false, child: _empty(context))
        else
          SliverList.separated(
            itemCount: rates.length,
            itemBuilder: (ctx, i) {
              final MetalRate rate = rates[i];
              final bool isWatchlisted =
              state.metalWatchlist.contains(rate.id);
              return _row(ctx, rate, isWatchlisted);
            },
            separatorBuilder: (_, __) => Divider(height: 1, color: divider),
          ),
      ],
    );
  }
}
