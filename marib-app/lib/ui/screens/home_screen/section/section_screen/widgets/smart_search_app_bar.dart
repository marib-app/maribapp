import 'package:flutter/material.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:marib/utils/app_icon.dart';
import 'dart:async' show Timer;
import 'package:flutter/services.dart';

import 'dart:async';

import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';

import 'dart:ui' as ui show TextDirection;

// الواجهة الجديدة

// ⚠️ الملف المنطقي (مثلاً يُعرّف ViewMode) بنفس مكانه القديم:
enum ViewMode {
  list,
  grid,
}

/// =============================================================
/// AppBar ذكي + اقتراحات بحث متحركة.
/// =============================================================
class SmartSearchAppBar extends StatefulWidget implements PreferredSizeWidget {
  final String appBarTitle;
  final TextEditingController searchController;
  final VoidCallback onSearchTap;
  final VoidCallback onSearchEditingComplete;
  final VoidCallback onClearSearch;
  final ValueChanged<String> onSearchChanged;

  final double toolbarH;
  final Duration hintInterval;
  final double marqueeSpeedPxPerS;

  final ViewMode viewMode;
  final VoidCallback onCycleViewMode;

  final bool isLoading;

  const SmartSearchAppBar({
    super.key,
    required this.appBarTitle,
    required this.searchController,
    required this.onSearchTap,
    required this.onSearchEditingComplete,
    required this.onClearSearch,
    required this.onSearchChanged,
    this.toolbarH = 80,
    this.hintInterval = const Duration(seconds: 3),
    this.marqueeSpeedPxPerS = 48.0,
    required this.viewMode,
    required this.onCycleViewMode,
    this.isLoading = false,
  });

  @override
  Size get preferredSize => Size.fromHeight(toolbarH + 2);

  @override
  State<SmartSearchAppBar> createState() => _SmartSearchAppBarState();
}

class _SmartSearchAppBarState extends State<SmartSearchAppBar> {
  final FocusNode _focusNode = FocusNode();
  late final ValueNotifier<bool> _showClear;

  late final List<String> _hints;
  late final IconData _hintIcon;
  int _hintIndex = 0;
  Timer? _hintTimer;

  @override
  void initState() {
    super.initState();

    final result = RealEstateSearchHints.forTitle(widget.appBarTitle);
    _hints = result.hints;
    _hintIcon = result.icon;

    _showClear = ValueNotifier<bool>(widget.searchController.text.isNotEmpty);
    widget.searchController.addListener(_onTextChanged);

    _startHintsRotation(interval: widget.hintInterval);
  }

  @override
  void dispose() {
    widget.searchController.removeListener(_onTextChanged);
    _focusNode.dispose();
    _showClear.dispose();
    _hintTimer?.cancel();
    super.dispose();
  }

  void _onTextChanged() {
    _showClear.value = widget.searchController.text.isNotEmpty;

    final shouldPause =
        _focusNode.hasFocus || widget.searchController.text.isNotEmpty;
    if (shouldPause) {
      _hintTimer?.cancel();
    } else {
      if (_hintTimer == null || !_hintTimer!.isActive) {
        _startHintsRotation(interval: widget.hintInterval);
      }
    }

    setState(() {});
  }

  void _startHintsRotation({Duration interval = const Duration(seconds: 3)}) {
    if (_hints.isEmpty) return;
    _hintTimer?.cancel();
    _hintTimer = Timer.periodic(interval, (_) {
      if (!mounted) return;
      final idle = !_focusNode.hasFocus && widget.searchController.text.isEmpty;
      if (!idle) return;
      setState(() => _hintIndex = (_hintIndex + 1) % _hints.length);
    });
  }

  String _nextLabel(ViewMode m) {
    switch (m) {
      case ViewMode.list:
        return 'الوضع التالي: افقية ';
      case ViewMode.grid:
        return 'الوضع التالي: شبكة (عمودان)';
    }
  }

  Widget _viewModeIcon(ViewMode m, Color color) {
    switch (m) {
      case ViewMode.list:
        return UiUtils.getSvg(AppIcons.gridViewIcon, color: color);
      case ViewMode.grid:
        return Icon(Icons.grid_3x3_outlined, color: color, size: 30);
    }
  }

  @override
  Widget build(BuildContext context) {
    final showHintOverlay =
        !_focusNode.hasFocus && widget.searchController.text.isEmpty;

    return AppBar(
      toolbarHeight: widget.toolbarH,
      backgroundColor: context.color.secondaryColor,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        color: context.color.territoryColor,
        onPressed: () => Navigator.pop(context),
        tooltip: 'رجوع',
      ),
      titleSpacing: 0,
      title: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        height: 50,
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: context.color.primaryColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _focusNode.hasFocus
                ? context.color.borderColor.darken(20)
                : context.color.borderColor.darken(35),
            width: _focusNode.hasFocus ? 1.2 : 1,
          ),
          boxShadow: _focusNode.hasFocus
              ? [
                  BoxShadow(
                      color: Colors.black12,
                      blurRadius: 8,
                      offset: const Offset(0, 2))
                ]
              : null,
        ),
        child: Row(
          children: [
            const SizedBox(width: 12),
            Expanded(
              child: Stack(
                alignment: AlignmentDirectional.centerStart,
                children: [
                  TextField(
                    controller: widget.searchController,
                    focusNode: _focusNode,
                    textInputAction: TextInputAction.search,
                    textAlign: TextAlign.start,
                    textDirection: TextDirection.rtl,
                    onTap: widget.onSearchTap,
                    onEditingComplete: widget.onSearchEditingComplete,
                    onChanged: widget.onSearchChanged,
                    textAlignVertical: TextAlignVertical.center,
                    style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black87),
                    cursorColor: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Colors.black87,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsetsDirectional.only(
                        start: 12,
                        end: 12,
                        top: 12,
                        bottom: 12,
                      ),
                    ),
                  ),

                  // تلميح Overlay بدون منع الكتابة
                  if (showHintOverlay)
                    Positioned.fill(
                      child: IgnorePointer(
                        ignoring: true,
                        child: Padding(
                          padding: const EdgeInsetsDirectional.symmetric(
                              horizontal: 12),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 320),
                            child: _MarqueeHint(
                              text: _hints[_hintIndex],
                              icon: _hintIcon,
                              style: TextStyle(
                                  color: context.color.textLightColor,
                                  fontSize: 12.5),
                              maxWidth: MediaQuery.of(context).size.width - 80,
                              speedPxPerSecond: widget.marqueeSpeedPxPerS,
                              isActive: showHintOverlay,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            ValueListenableBuilder<bool>(
              valueListenable: _showClear,
              builder: (_, show, __) {
                if (!show) return const SizedBox(width: 8);
                return IconButton(
                  tooltip: 'مسح',
                  icon: Icon(Icons.close_rounded,
                      color: context.color.textDefaultColor),
                  onPressed: () {
                    widget.searchController.clear();
                    _showClear.value = false;
                    widget.onClearSearch();
                    _startHintsRotation(interval: widget.hintInterval);
                  },
                );
              },
            ),
          ],
        ),
      ),
      actions: [
        Semantics(
          button: true,
          label: _nextLabel(widget.viewMode),
          child: IconButton(
            tooltip: _nextLabel(widget.viewMode),
            onPressed: () {
              HapticFeedback.selectionClick();
              widget.onCycleViewMode();
            },
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: KeyedSubtree(
                key: ValueKey<ViewMode>(widget.viewMode),
                child: _viewModeIcon(
                    widget.viewMode, context.color.territoryColor),
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(2),
        child: AnimatedOpacity(
          opacity: widget.isLoading ? 1 : 0,
          duration: const Duration(milliseconds: 180),
          child: LinearProgressIndicator(
            minHeight: 2,
            backgroundColor: Colors.transparent,
            color: context.color.territoryColor,
          ),
        ),
      ),
    );
  }
}

// تحريك النص الطويل داخل طبقة الاقتراح
class _MarqueeHint extends StatefulWidget {
  final String text;
  final IconData icon;
  final TextStyle style;
  final double maxWidth;
  final double speedPxPerSecond;
  final bool bounce;
  final double edgeFade;
  final bool autoBounceOnTight;
  final double tightThresholdPx;
  final bool isActive;

  const _MarqueeHint({
    required this.text,
    required this.icon,
    required this.style,
    required this.maxWidth,
    required this.speedPxPerSecond,
    this.isActive = true,
  });

  @override
  State<_MarqueeHint> createState() => _MarqueeHintState();
}

class _MarqueeHintState extends State<_MarqueeHint>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  double _overflowPx = 0;
  double _iconW = 18;
  double _gapW = 8;

  bool _useBounce = false;

  static const double _minDurSec = 2.0;
  static const double _maxDurSec = 12.0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.linear);
    _setup();
  }

  void _setup() {
    if (widget.maxWidth <= 220) {
      _iconW = 16;
      _gapW = 6;
    } else if (widget.maxWidth <= 300) {
      _iconW = 18;
      _gapW = 8;
    } else {
      _iconW = 20;
      _gapW = 10;
    }

    final tp = TextPainter(
      text: TextSpan(text: widget.text, style: widget.style),
      maxLines: 1,
      textDirection: ui.TextDirection.rtl,
    )..layout(maxWidth: double.infinity);

    final availableTextW =
        (widget.maxWidth - _iconW - _gapW).clamp(0, double.infinity);
    _overflowPx = (tp.size.width - availableTextW).clamp(0, double.infinity);

    _useBounce = widget.bounce ||
        (widget.autoBounceOnTight && _overflowPx < widget.tightThresholdPx);

    _ctrl.stop();
    _ctrl.reset();
    if (!widget.isActive || _overflowPx <= 0) {
      if (mounted) setState(() {});
      return;
    }
    final spacer = (_iconW + _gapW).clamp(12, 28);
    final totalTravel = _overflowPx + spacer;
    final seconds =
        (totalTravel / widget.speedPxPerSecond).clamp(_minDurSec, _maxDurSec);
    _ctrl.duration = Duration(milliseconds: (seconds * 1000).round());
    _useBounce ? _ctrl.repeat(reverse: true) : _ctrl.repeat();
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant _MarqueeHint oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        oldWidget.maxWidth != widget.maxWidth ||
        oldWidget.speedPxPerSecond != widget.speedPxPerSecond ||
        oldWidget.bounce != widget.bounce ||
        oldWidget.tightThresholdPx != widget.tightThresholdPx ||
        oldWidget.autoBounceOnTight != widget.autoBounceOnTight ||
        oldWidget.isActive != widget.isActive) {
      _setup();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.maxWidth < 40) {
      return SizedBox(width: widget.maxWidth, height: 20);
    }

    final textStyle = widget.style;

    if (_overflowPx <= 0) {
      return SizedBox(
        width: widget.maxWidth,
        child: Row(
          children: [
            Icon(widget.icon, size: _iconW, color: textStyle.color),
            SizedBox(width: _gapW),
            Expanded(
              child: Text(
                widget.text,
                maxLines: 1,
                overflow: TextOverflow.clip,
                softWrap: false,
                style: textStyle,
                textDirection: ui.TextDirection.rtl,
              ),
            ),
          ],
        ),
      );
    }

    final spacer = (_iconW + _gapW).clamp(12, 28);
    final totalTravel = _overflowPx + spacer;

    Widget scrollingText(double dx) {
      return Transform.translate(
        offset: Offset(-dx, 0),
        child: Text(
          widget.text,
          maxLines: 1,
          overflow: TextOverflow.visible,
          softWrap: false,
          style: textStyle,
          textDirection: ui.TextDirection.rtl,
        ),
      );
    }

    return SizedBox(
      width: widget.maxWidth,
      child: Row(
        children: [
          Icon(widget.icon, size: _iconW, color: textStyle.color),
          SizedBox(width: _gapW),
          Expanded(
            child: ShaderMask(
              shaderCallback: (Rect r) {
                final double width = r.width <= 1 ? 1.0 : r.width;
                final double f = 10.0.clamp(0, width / 4).toDouble();
                final double leftStop = (f / width).clamp(0.0, 0.49);
                final double rightStop = (1 - (f / width)).clamp(0.51, 1.0);

                return LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: const [
                    Colors.transparent,
                    Colors.black,
                    Colors.black,
                    Colors.transparent
                  ],
                  stops: [0.0, leftStop, rightStop, 1.0],
                ).createShader(r);
              },
              blendMode: BlendMode.dstIn,
              child: ClipRect(
                child: TickerMode(
                  enabled: widget.isActive,
                  child: AnimatedBuilder(
                    animation: _anim,
                    builder: (_, __) {
                      if (_useBounce) {
                        final dx = _anim.value * _overflowPx;
                        return scrollingText(dx);
                      } else {
                        final dx = (_anim.value * totalTravel) % totalTravel;
                        final bool needSecond = totalTravel > 40;
                        if (!needSecond) {
                          return scrollingText(dx);
                        }
                        return Stack(
                          children: [
                            scrollingText(dx),
                            Transform.translate(
                              offset: Offset(-(dx - totalTravel), 0),
                              child: Text(
                                widget.text,
                                maxLines: 1,
                                overflow: TextOverflow.visible,
                                softWrap: false,
                                style: textStyle,
                                textDirection: ui.TextDirection.rtl,
                              ),
                            ),
                          ],
                        );
                      }
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// =============================================================
/// اقتراحات بحث مبنية على عنوان القسم (عقارات مأرب كمثال).
/// =============================================================
///
class HintsResult {
  final List<String> hints;
  final IconData icon;
  const HintsResult(this.hints, this.icon);
}

class RealEstateSearchHints {
  static HintsResult forTitle(String appBarTitle) {
    final String normalized = _normalize(appBarTitle);
    return _hintMap[normalized] ?? _defaultHints;
  }

  static String _normalize(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '').trim();
  }

  static const HintsResult _defaultHints = HintsResult(
    ['اكتب ما تبحث عنه…', 'أفضل العروض اليوم', 'منتجات قريبة منك'],
    Icons.search,
  );

  static final Map<String, HintsResult> _hintMap = {
    'realestate':
        HintsResult(_buildMaribRealEstateHints(), Icons.home_work_outlined),
    'realestateservices':
        HintsResult(_buildMaribRealEstateHints(), Icons.home_work_outlined),
    'jobs': const HintsResult(
      ['وظائف بدوام كامل', 'فرص عمل عن بعد', 'فرص للطلاب وحديثي التخرج'],
      Icons.work_outline,
    ),
    'jobservices': const HintsResult(
      ['وظائف بدوام كامل', 'فرص عمل عن بعد', 'فرص للطلاب وحديثي التخرج'],
      Icons.work_outline,
    ),
    'localservices': const HintsResult(
      [
        'فني كهرباء قريب منك',
        'تنظيف المنازل والمكاتب',
        'صيانة مكيفات في منطقتك'
      ],
      Icons.design_services_outlined,
    ),
    'medicalservices': const HintsResult(
      ['حجز عيادة أسنان', 'أطباء باطنة وطوارئ', 'مختبرات تحاليل قريبة'],
      Icons.medical_services_outlined,
    ),
    'studentservices': const HintsResult(
      ['دروس تقوية لجميع المراحل', 'معاهد لغات معتمدة', 'مدرس خصوصي قريب منك'],
      Icons.menu_book_outlined,
    ),
    'eventsoffers': const HintsResult(
      ['عروض المحلات اليوم', 'فعاليات نهاية الأسبوع', 'خصومات رمضان وعيد'],
      Icons.event_available_outlined,
    ),
    'mariblost': const HintsResult(
      ['مفقودات تم العثور عليها', 'أشياء مفقودة حديثاً', 'وثائق رسمية مفقودة'],
      Icons.help_outline,
    ),
    'maribguide': const HintsResult(
      ['أفضل المطاعم في مأرب', 'شاليهات ومنتجعات', 'أماكن سياحية وتاريخية'],
      Icons.map_outlined,
    ),
    'otherservices': const HintsResult(
      ['خدمات متنوعة للأفراد', 'مقاولين وشركات محلية', 'مقدمو خدمات سريعة'],
      Icons.miscellaneous_services_outlined,
    ),
    'publicads': const HintsResult(
      ['إعلانات حديثة', 'عروض بيع وشراء', 'منتجات مستعملة بحالة جيدة'],
      Icons.campaign_outlined,
    ),
    'requestad': const HintsResult(
      ['أعلن عن منتجك الآن', 'أكتب تفاصيل إعلانك', 'حدد السعر وموقعك'],
      Icons.post_add_outlined,
    ),
    'tourismservices': const HintsResult(
      ['رحلات سياحية محلية', 'حجوزات فنادق ومنتجعات', 'مخيمات وبرامج استكشاف'],
      Icons.flight_takeoff,
    ),
    'sheinproducts': const HintsResult(
      ['وصل حديثاً من شين', 'ملابس نسائية رائجة', 'اكسسوارات وعروض خاصة'],
      Icons.shopping_bag_outlined,
    ),
    'computersection': const HintsResult(
      ['أجهزة كمبيوتر محمولة', 'إكسسوارات وشاشات', 'ألعاب وإضاءات RGB'],
      Icons.computer_outlined,
    ),
  };

  static List<String> _buildMaribRealEstateHints() {
    final Set<String> out = {};

    const areas = [
      'المجمع',
      'الروضة',
      'الفاو',
      'مفرق السد',
      'الصحن',
      'الميل',
      'الشبواني',
      'المطار',
      'مجمع الخير',
      'البقايل',
      'الجفينة',
      'شارع الأربعين',
      'الوادي',
      'الشركة',
      'حي الشركة',
      'الصيانة',
      'شارع الجامعة',
      'بن عبود',
      'سوق الغنم',
      'ميلانو',
      'المواصلات',
      'داخل المجمع',
      'أطراف المجمع'
    ];
    const landmarks = [
      'ميلانو',
      'الجامعة',
      'مجمع الخير',
      'سوق الغنم',
      'شارع الأربعين',
      'المطار',
      'مفرق السد'
    ];
    const types = ['شقة', 'بيت', 'فيلا', 'هنجر تخزين', 'محل', 'أرض'];
    const actions = ['للإيجار', 'للبيع'];
    const payments = ['بدون مقدم', 'بمقدم', 'تقسيط', 'كاش'];
    const aptExtras = [
      'مفروشة',
      'مدخل مستقل',
      'دور أرضي',
      'جديدة',
      'قريبة من الخدمات'
    ];
    const houseExtras = [
      'حوش',
      'دورين',
      'مدخلين',
      'ملحق',
      'مع سطح',
      'واجهة شارع'
    ];
    const villaExtras = ['مودرن', 'حديقة', 'مسبح', 'مساحة كبيرة', 'تشطيب فاخر'];
    const sizes = ['غرفتين', '3 غرف', '4 غرف'];

    String _p(String kind, String action,
        {String? area, String? extra, String? pay, String? near}) {
      final b = StringBuffer(kind);
      if (action.isNotEmpty) b.write(' $action');
      if (area?.isNotEmpty == true) b.write(' في $area');
      if (near?.isNotEmpty == true)
        b.write(
            ' ${near!.startsWith("خلف") || near.startsWith("قرب") ? near : "قرب $near"}');
      if (extra?.isNotEmpty == true) b.write(' $extra');
      if (pay?.isNotEmpty == true) b.write(' $pay');
      return b.toString().trim();
    }

    for (final a in areas) {
      for (final s in sizes) {
        out.add(_p('شقة $s', 'للإيجار', area: a));
        out.add(_p('شقة $s', 'للبيع', area: a));
      }
      for (final ex in aptExtras) {
        out.add(_p('شقة', 'للإيجار', area: a, extra: ex));
      }
      out.addAll(payments.map((p) => _p('شقة', 'للبيع', area: a, pay: p)));
    }
    for (final lm in landmarks) {
      out.add(_p('شقة', 'للإيجار', near: 'خلف $lm'));
      out.add(_p('شقة', 'للبيع', near: 'قرب $lm'));
    }

    for (final a in areas) {
      out.add(_p('بيت', 'للبيع', area: a));
      out.add(_p('بيت', 'للإيجار', area: a));
      for (final ex in houseExtras) {
        out.add(_p('بيت', 'للبيع', area: a, extra: ex));
      }
      out.addAll(payments.map((p) => _p('بيت', 'للبيع', area: a, pay: p)));
    }
    for (final lm in landmarks) {
      out.add(_p('بيت', 'للبيع', near: 'في $lm'));
    }

    for (final a in areas) {
      out.add(_p('فيلا', 'للبيع', area: a));
      out.add(_p('فيلا', 'للإيجار', area: a));
      for (final ex in villaExtras) {
        out.add(_p('فيلا', 'للبيع', area: a, extra: ex));
      }
      out.addAll(payments.map((p) => _p('فيلا', 'للبيع', area: a, pay: p)));
    }

    for (final a in areas) {
      out.add(_p('محل', 'للإيجار', area: a));
      out.add(_p('محل', 'للإيجار', area: a, pay: 'بدون مقدم'));
      out.add(_p('محل', 'للإيجار', area: a, pay: 'بمقدم بسيط'));
      out.add(_p('محل تجاري', 'للإيجار', area: a, extra: 'موقع مميز'));
    }

    for (final a in areas) {
      out.add(_p('هنجر تخزين', 'للإيجار', area: a));
      out.add(_p('هنجر تخزين', 'للإيجار', area: a, extra: 'مدخل شاحنات'));
      out.add(_p('ساحة تخزين', 'للإيجار', area: a));
    }

    for (final a in areas) {
      out.add(_p('أرض سكنية', 'للبيع', area: a));
      out.add(_p('أرضية عَرْطة', 'للبيع', area: a));
      out.add(_p('أرض تجارية', 'للبيع', area: a));
      out.add(_p('أرض زراعية', 'للبيع', area: a));
      out.add(_p('أرض زاوية', 'للبيع', area: a));
      out.add(_p('أرض بصك', 'للبيع', area: a));
      out.add(_p('قطعة أرض', 'للبيع', area: a, pay: 'تقسيط'));
    }

    const abr = 'العَبْر';
    const alJawhara = 'مدينة الجوهرة السكنية';
    out.addAll([
      'أرض للبيع في العَبْر',
      'أرض في مدينة الجوهرة السكنية بالعَبْر',
      'أرضية استثمارية في العَبْر',
      'قطع أراضي في مدينة الجوهرة السكنية',
      'أرض سكنية بالعَبْر تقسيط',
      'أرض زاوية بالعَبْر كاش',
      'مخططات معتمدة في العَبْر',
      'أراضي بمقدم بسيط في مدينة الجوهرة السكنية',
      'تمليك أراضي في العَبْر',
      'بيت للبيع في العَبْر',
      'شقة تمليك في مدينة الجوهرة السكنية',
      'فلل في مدينة الجوهرة السكنية',
    ]);

    for (final lm in landmarks) {
      out.add('شقة خلف $lm');
      out.add('بيت للبيع في $lm');
      out.add('محل إيجار في $lm');
      out.add('أرضية عرطة في $lm');
    }
    out.addAll([
      'شقة خلف ميلانو',
      'بيت للبيع في الصحن',
      'محل إيجار في مفرق السد',
      'أرضية عرطة في الميل',
    ]);

    final list = out.toList();
    list.sort((a, b) => a.length.compareTo(b.length));
    const maxHints = 400;
    return list.take(maxHints).toList();
  }
}
