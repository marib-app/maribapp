import 'dart:async';
import 'dart:math' show min, max;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:marib/data/model/category_model.dart';
import 'package:marib/ui/theme/extensions/shimmer_colors.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marquee/marquee.dart';
import 'package:shimmer/shimmer.dart';

const double _subcatCardRadius = 20.0;

const double _verticalSpacingBetweenRows = 12.0;

class SubcatsHorizontalGrid extends StatefulWidget {
  final List<CategoryModel> subcats;
  final int? selectedId;
  final ValueChanged<int?> onTap; // إبقائها للتوافق
  final Color brand;

  /// هل هذا الصف يمثّل أبناء "الكل" (Top-Level) أم أبناء فئة علوية محددة؟
  final bool isTopLevel;

  final void Function(CategoryModel c) onTopCategoryPick;
  final void Function(CategoryModel c) onSubcatPick;
  final WidgetBuilder? leadingBuilder;

  const SubcatsHorizontalGrid({
    super.key,
    required this.subcats,
    required this.selectedId,
    required this.onTap,
    required this.brand,
    required this.isTopLevel,
    required this.onTopCategoryPick,
    required this.onSubcatPick,
    this.leadingBuilder,
  });

  @override
  State<SubcatsHorizontalGrid> createState() => SubcatsHorizontalGridState();
}

class SubcatsHorizontalGridState extends State<SubcatsHorizontalGrid> {
  static const double _hPad = 12.0;
  static const double _spacing = 10.0;

  int _slotsPerPage = 4;
  int _itemsPerRow = 4;
  int _maxRows = 1;
  int _firstPageCapacity = 4;
  bool _includeLeading = false;

  late final PageController _pageController;
  int _current = 0;

  int _indexOf(int? id) {
    if (id == null) return -1;
    return widget.subcats.indexWhere((c) => c.id == id);
  }

  int _pageOfIndex(int index,
      {bool? includeLeading, int? firstPageCapacity, int? slotsPerPage}) {
    return _pageOfIndexWithConfig(
      index,
      includeLeading: includeLeading ?? _includeLeading,
      firstPageCapacity: firstPageCapacity ?? _firstPageCapacity,
      slotsPerPage: slotsPerPage ?? _slotsPerPage,
    );
  }

  int _pageOfIndexWithConfig(int index,
      {required bool includeLeading,
      required int firstPageCapacity,
      required int slotsPerPage}) {
    if (index < 0) return 0;
    if (slotsPerPage <= 0) return 0;
    if (!includeLeading) {
      return index ~/ slotsPerPage;
    }
    if (firstPageCapacity <= 0) return 0;
    if (index < firstPageCapacity) return 0;
    final remaining = index - firstPageCapacity;
    if (slotsPerPage <= 0) return 0;
    return 1 + remaining ~/ slotsPerPage;
  }

  int _initialPage() {
    final idx = _indexOf(widget.selectedId);
    return _pageOfIndex(idx);
  }

  int _calculateItemsPerRow(double maxWidth, int totalItems) {
    final availableWidth = maxWidth - (_hPad * 2);
    if (availableWidth <= 0) return 1;
    final maxColumns = max(1, min(totalItems, 6));
    int result = 1;
    for (var cols = 1; cols <= maxColumns; cols++) {
      final spacing = _spacing * (cols - 1);
      final widthForItems = availableWidth - spacing;
      final perItem = widthForItems / cols;
      if (perItem >= 70.0) {
        result = cols;
      } else {
        break;
      }
    }
    return result;
  }

  @override
  void initState() {
    super.initState();
    final initPage = _initialPage();
    _pageController = PageController(initialPage: initPage);
    _current = initPage;
  }

  @override
  void didUpdateWidget(covariant SubcatsHorizontalGrid oldWidget) {
    super.didUpdateWidget(oldWidget);

    // لو تغيّر الاختيار أو تغيّر ترتيب/عدد العناصر، حافظ على الصفحة
    final idx = _indexOf(widget.selectedId);
    final tgt = _pageOfIndex(idx);

    if (tgt != _current) {
      _current = tgt;
      // لا تقفز للبداية — فقط انتقل للصفحة المطلوبة عند الحاجة
      if (mounted) {
        _pageController.animateToPage(
          tgt,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.subcats.isEmpty) return const SizedBox.shrink();

    final totalSubcats = widget.subcats.length;
    final hasLeading = widget.leadingBuilder != null && widget.isTopLevel;
    final displayCount = totalSubcats + (hasLeading ? 1 : 0);

    return LayoutBuilder(
      builder: (context, cons) {
        final w = cons.maxWidth;
        final itemsPerRow = _calculateItemsPerRow(w, displayCount);
        final rowsNeeded =
            itemsPerRow <= 0 ? 1 : (displayCount / itemsPerRow).ceil();
        final maxRows = rowsNeeded <= 1 ? 1 : min(2, rowsNeeded);
        final slotsPerPage = itemsPerRow * maxRows;
        final totalSpacing = _spacing * (itemsPerRow - 1);
        final widthForItems =
            (w - (_hPad * 2) - totalSpacing).clamp(0.0, 4000.0);
        final itemWidth = (widthForItems / itemsPerRow).clamp(70.0, 120.0);

        final cardExtent = (itemWidth * 0.82).clamp(48.0, 64.0);
        const titleHeight = 30.0;
        const gap = 6.0;
        final rowHeight = cardExtent + gap + titleHeight;

        final gridHeight =
            rowHeight * maxRows + _verticalSpacingBetweenRows * (maxRows - 1);
        final bool includeLeading = hasLeading && slotsPerPage > 1;
        final int availableSlotsForCategories =
            includeLeading ? max(0, slotsPerPage - 1) : slotsPerPage;
        final int desiredFirstPageCategories =
            min(totalSubcats, availableSlotsForCategories);

        final int firstPageCapacity =
            includeLeading ? desiredFirstPageCategories : slotsPerPage;
        final int otherPageCapacity = slotsPerPage;
        final int pages;
        if (slotsPerPage <= 0) {
          pages = 0;
        } else if (!includeLeading) {
          pages = (totalSubcats / slotsPerPage).ceil();
        } else {
          final remaining = max(0, totalSubcats - firstPageCapacity);
          final additional =
              remaining == 0 ? 0 : (remaining / otherPageCapacity).ceil();
          pages = 1 + additional;
        }

        if (_itemsPerRow != itemsPerRow ||
            _maxRows != maxRows ||
            _slotsPerPage != slotsPerPage ||
            _firstPageCapacity != firstPageCapacity ||
            _includeLeading != includeLeading) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            final idx = _indexOf(widget.selectedId);
            final targetPage = _pageOfIndexWithConfig(
              idx,
              includeLeading: includeLeading,
              firstPageCapacity: firstPageCapacity,
              slotsPerPage: slotsPerPage,
            );

            final safePages = pages == 0 ? 1 : pages;
            final clamped = targetPage.clamp(0, safePages - 1);
            final shouldJump = _current != clamped;
            setState(() {
              _itemsPerRow = itemsPerRow;
              _maxRows = maxRows;
              _slotsPerPage = slotsPerPage;
              _firstPageCapacity = firstPageCapacity;
              _includeLeading = includeLeading;

              _current = clamped;
            });
            if (shouldJump && _pageController.hasClients) {
              _pageController.jumpToPage(clamped);
            }
          });
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: gridHeight,
              child: PageView.builder(
                controller: _pageController,
                itemCount: pages,
                onPageChanged: (i) => setState(() => _current = i),
                itemBuilder: (ctx, pageIndex) {
                  final bool isFirstPage = pageIndex == 0;
                  final start = !includeLeading
                      ? pageIndex * otherPageCapacity
                      : isFirstPage
                          ? 0
                          : firstPageCapacity +
                              (pageIndex - 1) * otherPageCapacity;

                  final pageEntries = <_GridEntry?>[];
                  if (includeLeading && isFirstPage) {
                    pageEntries.add(
                      _GridEntry.leading(widget.leadingBuilder!),
                    );
                  }
                  final capacityForPage = !includeLeading
                      ? otherPageCapacity
                      : isFirstPage
                          ? firstPageCapacity
                          : otherPageCapacity;
                  var categoriesAdded = 0;
                  for (var i = 0; i < capacityForPage; i++) {
                    final absoluteIndex = start + i;
                    if (absoluteIndex >= totalSubcats) {
                      pageEntries.add(null);
                    } else {
                      categoriesAdded++;
                      pageEntries.add(
                        _GridEntry.category(widget.subcats[absoluteIndex]),
                      );
                    }
                  }
                  final consumedAllCategories =
                      start + categoriesAdded >= totalSubcats;
                  if (consumedAllCategories) {
                    while (pageEntries.length < slotsPerPage) {
                      pageEntries.add(null);
                    }
                  }
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: _hPad),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: List.generate(maxRows, (rowIndex) {
                        final rowStart = rowIndex * itemsPerRow;
                        final rowItems = pageEntries
                            .skip(rowStart)
                            .take(itemsPerRow)
                            .toList();
                        return Padding(
                          padding: EdgeInsets.only(
                              top: rowIndex == 0
                                  ? 0
                                  : _verticalSpacingBetweenRows),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: List.generate(itemsPerRow, (colIndex) {
                              final entry = rowItems.length > colIndex
                                  ? rowItems[colIndex]
                                  : null;
                              if (entry == null) {
                                return SizedBox(
                                    width: itemWidth, height: rowHeight);
                              }
                              if (entry.isLeading) {
                                return SizedBox(
                                  width: itemWidth,
                                  height: rowHeight,
                                  child: Align(
                                    alignment: Alignment.topCenter,
                                    child: SizedBox(
                                      width: itemWidth,
                                      child: entry.builder!(context),
                                    ),
                                  ),
                                );
                              }
                              final item = entry.category!;
                              final sel = item.id == widget.selectedId;
                              return SizedBox(
                                width: itemWidth,
                                height: rowHeight,
                                child: _SubcatCircle(
                                  label: item.name ?? '',
                                  brand: widget.brand,
                                  selected: sel,
                                  cardExtent: cardExtent,
                                  imageUrl: item.url,
                                  useImage: (item.url ?? '').isNotEmpty,
                                  onTap: () {
                                    // لا تغيّر الصفحة هنا — فقط نبلغ بالأكشن الصحيح
                                    widget.onTap(item.id);
                                    if (widget.isTopLevel) {
                                      widget.onTopCategoryPick(item);
                                    } else {
                                      widget.onSubcatPick(item);
                                    }
                                  },
                                ),
                              );
                            }),
                          ),
                        );
                      }),
                    ),
                  );
                },
              ),
            ),
            if (pages > 1)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: _DotsIndicator(
                  current: _current,
                  count: pages,
                  color: widget.brand,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _GridEntry {
  final CategoryModel? category;
  final WidgetBuilder? builder;

  const _GridEntry.category(this.category) : builder = null;

  const _GridEntry.leading(this.builder) : category = null;

  bool get isLeading => builder != null;
}

class _SubcatCircle extends StatelessWidget {
  static const Duration _animationDuration = Duration(milliseconds: 200);
  static const double _innerPadding = 6;

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color brand;

  final String? imageUrl;
  final bool useImage;
  final double cardExtent;

  const _SubcatCircle({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.brand,
    required this.cardExtent,
    this.imageUrl,
    this.useImage = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasImage = useImage && (imageUrl?.isNotEmpty ?? false);

    final borderColor = Colors.transparent;

    final innerRadius = (_subcatCardRadius - _innerPadding)
        .clamp(0.0, _subcatCardRadius)
        .toDouble();

    Widget buildFallbackAvatar() => Container(
          color: colorScheme.primaryColor,
          alignment: Alignment.center,
          child: Icon(
            Icons.category_rounded,
            color: colorScheme.textLightColor,
            size: cardExtent * 0.5,
          ),
        );

    final Widget avatar = ClipRRect(
      borderRadius: BorderRadius.circular(innerRadius),
      child: Stack(
        fit: StackFit.expand,
        children: [
          buildFallbackAvatar(),
          if (hasImage)
            CachedNetworkImage(
              imageUrl: imageUrl!,
              fit: BoxFit.cover,
              placeholder: (_, __) => buildFallbackAvatar(),
              errorWidget: (_, __, ___) => buildFallbackAvatar(),
            ),
        ],
      ),
    );

    final baseLabelStyle = theme.textTheme.labelMedium;
    final textColor =
        selected ? colorScheme.textDefaultColor : colorScheme.textLightColor;
    final titleStyle = baseLabelStyle?.copyWith(color: textColor) ??
        TextStyle(color: textColor);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(_subcatCardRadius),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // الصندوق الدائري مع إبراز الاختيار
          AnimatedContainer(
            duration: _animationDuration,
            curve: Curves.easeOut,
            width: cardExtent,
            height: cardExtent,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_subcatCardRadius),
              gradient: null,
              color: Colors.transparent,
              border: Border.all(color: borderColor, width: 0),
            ),
            padding: const EdgeInsets.all(_innerPadding),
            child: avatar,
          ),

          const SizedBox(height: 6),

          // العنوان + خط سفلي متحرك للمختار
          SizedBox(
            width: cardExtent + 12,
            height: 30,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _FittedOrMarquee(text: label, style: titleStyle),
                AnimatedContainer(
                  duration: _animationDuration,
                  curve: Curves.easeOut,
                  margin: const EdgeInsets.only(top: 4),
                  height: selected ? 3 : 0,
                  width: selected ? (cardExtent * 0.5) : 0,
                  decoration: BoxDecoration(
                    color: brand,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// يختار بين FittedText البسيط أو Marquee لو النص طويل
class _FittedOrMarquee extends StatelessWidget {
  final String text;
  final TextStyle style;

  const _FittedOrMarquee({required this.text, required this.style});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, cons) {
      final tp = TextPainter(
        text: TextSpan(text: text, style: style),
        maxLines: 1,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: cons.maxWidth);

      if (tp.width > cons.maxWidth) {
        return SizedBox(
          height: style.fontSize != null ? style.fontSize! * 1.25 : 14,
          child: Marquee(
            text: text,
            style: style,
            blankSpace: 24,
            velocity: 28,
            pauseAfterRound: const Duration(milliseconds: 800),
            startPadding: 8,
            accelerationDuration: const Duration(milliseconds: 400),
            decelerationDuration: const Duration(milliseconds: 300),
          ),
        );
      }
      return Text(text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style,
          textAlign: TextAlign.center);
    });
  }
}

class _DotsIndicator extends StatelessWidget {
  final int current;
  final int count;
  final Color color;

  const _DotsIndicator(
      {required this.current, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    final inactive = Theme.of(context).brightness == Brightness.dark
        ? Colors.grey.shade700
        : Colors.grey.shade300;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final sel = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: sel ? 18 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: sel ? color : inactive,
            borderRadius: BorderRadius.circular(20),
          ),
        );
      }),
    );
  }
}

/// كتلة “جلب مؤجّل + شيمر” للفئات الفرعية تحت السلايدر.
/// قبل التفعيل (enabled=false): شيمر فقط.
/// عند التحويل إلى true: يبدأ الجلب مرّة واحدة، ويستمر الشيمر حتى تجهز البيانات.
class SubcatsDeferredBlock extends StatefulWidget {
  /// فعل التحميل المؤجّل (لن يبدأ أي جلب ما لم تصبح true)
  final bool enabled;

  /// ضع فيها جلبك الحقيقي (Cubit/Repo). تُنادى مرّة واحدة فقط.
  final Future<void> Function()? onDeferLoad;

  /// يبني المحتوى الحقيقي بعد الجلب
  final Widget Function() builderWhenReady;

  /// شيمر مخصص (اختياري). إن تُركت null نستخدم شيمر افتراضي بنفس ارتفاع الشبكة.
  final Widget Function(BuildContext context, double rowHeight, int maxRows)?
      shimmerBuilder;

  /// حد أدنى لعرض الشيمر لتجنب “وميض” سريع
  final Duration minShimmer;

  /// لضبط ارتفاع الشيمر تمامًا مثل الشبكة (افتراضي 92 = 56 + 6 + 30)
  final double rowHeight;

  /// عدد الصفوف المفترض للشبكة (1 أو 2 عادةً).
  final int maxRows;

  const SubcatsDeferredBlock({
    super.key,
    required this.enabled,
    required this.builderWhenReady,
    this.onDeferLoad,
    this.shimmerBuilder,
    this.minShimmer = const Duration(milliseconds: 400),
    this.rowHeight = 92.0,
    this.maxRows = 1,
  });

  @override
  State<SubcatsDeferredBlock> createState() => SubcatsDeferredBlockState();
}

class SubcatsDeferredBlockState extends State<SubcatsDeferredBlock> {
  bool _started = false;
  bool _ready = false;
  DateTime? _t0;

  @override
  void initState() {
    super.initState();
    _kickoffIfNeeded();
  }

  @override
  void didUpdateWidget(covariant SubcatsDeferredBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    _kickoffIfNeeded();
  }

  void _kickoffIfNeeded() {
    if (!_started && widget.enabled) {
      _started = true;
      _t0 = DateTime.now();
      _defer();
    }
  }

  Future<void> _defer() async {
    try {
      if (widget.onDeferLoad != null) {
        await widget.onDeferLoad!();
      }
    } finally {
      final elapsed = DateTime.now().difference(_t0 ?? DateTime.now());
      final extra = elapsed >= widget.minShimmer
          ? Duration.zero
          : (widget.minShimmer - elapsed);
      if (extra > Duration.zero) {
        await Future.delayed(extra);
      }
      if (mounted) setState(() => _ready = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // قبل التفعيل أو أثناء الجلب الأول: شيمر
    if (!widget.enabled || !_ready) {
      return widget.shimmerBuilder
              ?.call(context, widget.rowHeight, widget.maxRows) ??
          _defaultShimmer(context, widget.rowHeight, widget.maxRows);
    }
    // جاهز: UI الحقيقي
    return widget.builderWhenReady();
  }

  /// إتاحة الشيمر الافتراضي للاستخدام الخارجي مع المحافظة على القيم الحالية.
  Widget buildDefaultShimmer(
    BuildContext context,
    double rowHeight,
    int rows,
  ) {
    return _defaultShimmer(context, rowHeight, rows);
  }

  // شيمر افتراضي: صف أفقي 4 عناصر بنفس ارتفاع الشبكة لتجنّب الاهتزاز
  Widget _defaultShimmer(BuildContext context, double rowHeight, int rows) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final shimmerBase = colorScheme.shimmerBaseColor;
    final shimmerHighlight = colorScheme.shimmerHighlightColor;
    final shimmerContent = colorScheme.shimmerContentColor;
    final cardRadius = BorderRadius.circular(_subcatCardRadius);

    // تفكيك الارتفاع: دائرة + فجوة + عنوان
    const gap = 6.0;
    const titleH = 30.0;
    const indicatorGap = 6.0;
    const indicatorHeight = 8.0;
    final circle = (rowHeight - gap - titleH).clamp(48.0, 64.0);
    final textWidth = circle + 12.0;
    final gridHeight =
        rowHeight * rows + _verticalSpacingBetweenRows * (rows - 1);
    final totalHeight = gridHeight + indicatorGap + indicatorHeight;

    return SizedBox(
      height: totalHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(rows, (rowIndex) {
                return Padding(
                  padding: EdgeInsets.only(
                      top: rowIndex == 0 ? 0 : _verticalSpacingBetweenRows),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(4, (_) {
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Shimmer.fromColors(
                            baseColor: shimmerBase,
                            highlightColor: shimmerHighlight,
                            period: const Duration(milliseconds: 1150),
                            child: Container(
                              width: circle,
                              height: circle,
                              decoration: BoxDecoration(
                                borderRadius: cardRadius,
                                color: shimmerContent,
                              ),
                            ),
                          ),
                          const SizedBox(height: gap),
                          SizedBox(
                            height: titleH,
                            width: textWidth,
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: Shimmer.fromColors(
                                baseColor: shimmerBase,
                                highlightColor: shimmerHighlight,
                                period: const Duration(milliseconds: 1150),
                                child: Container(
                                  height: 12,
                                  width: textWidth,
                                  decoration: BoxDecoration(
                                    color: shimmerContent,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                );
              }),
            ),
            const SizedBox(height: indicatorGap),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                final isActive = index == 0;
                final width = isActive ? 18.0 : 8.0;
                return Shimmer.fromColors(
                  baseColor: shimmerBase,
                  highlightColor: shimmerHighlight,
                  period: const Duration(milliseconds: 1150),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: width,
                    height: indicatorHeight,
                    decoration: BoxDecoration(
                      color: shimmerContent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
