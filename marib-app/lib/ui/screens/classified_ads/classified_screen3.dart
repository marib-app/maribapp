// lib/new_code/ui/classified_ads/classified_screen3.dart

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:marib/app/routes.dart';
import 'package:marib/data/cubits/fetch_services_cubit.dart';
import 'package:marib/data/cubits/slider_cubit.dart';
import 'package:marib/data/model/category_model.dart';
import 'package:marib/data/model/classified_model.dart' show ClassifiedSummary;
import 'package:marib/ui/screens/sliders/slider_widget.dart';
import 'package:marib/ui/screens/home/widgets/home_shimmers.dart';
import 'package:marib/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:marib/ui/screens/widgets/errors/no_data_found.dart';
import 'package:marib/ui/screens/widgets/errors/no_internet.dart';
import 'package:marib/ui/screens/widgets/errors/something_went_wrong.dart';
import 'package:marib/ui/screens/widgets/intertitial_ads_screen.dart';
import 'package:marib/ui/screens/widgets/shimmerLoadingContainer.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/api.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/responsiveSize.dart';
import 'package:marib/utils/screen_scaler.dart';
import 'package:marib/utils/ui_utils.dart';



import 'dart:ui' show ImageFilter;
import 'package:marib/utils/slider_interface_mapper.dart';

class ClassifiedScreen3 extends StatefulWidget {
  final String categoryId, categoryName, interfaceType;

  const ClassifiedScreen3({
    super.key,
    required this.categoryId,
    required this.categoryName,
    required this.interfaceType,
  });

  static Route route(RouteSettings routeSettings) {
    final Map? args = routeSettings.arguments as Map?;
    return BlurredRouter(
      builder: (_) => ClassifiedScreen3(
        categoryId: args?['catID'] as String,
        categoryName: args?['catName'] as String,
        interfaceType: args?['interfaceType'] as String,
      ),
    );
  }

  @override
  State<ClassifiedScreen3> createState() => _ClassifiedScreen3State();
}

class _ClassifiedScreen3State extends State<ClassifiedScreen3> {
  final ScrollController _scroll = ScrollController();

  bool _showSlider = true;
  bool _adShownOnce = false;
  bool _isPaging = false;

  @override
  void initState() {
    super.initState();

    AdHelper.loadInterstitialAd();

    // Fetch-on-open + عرض الإعلان بعد أول فريم
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context
          .read<FetchServicesCubit>()
          .fetchServices(categoryId: int.tryParse(widget.categoryId));

      if (!_adShownOnce) {
        _adShownOnce = true;
        AdHelper.showInterstitialAd();
      }
    });

    _scroll.addListener(_onEndReached);
  }

  Future<void> _onEndReached() async {
    if (_scroll.position.pixels < _scroll.position.maxScrollExtent - 24) return;

    final cubit = context.read<FetchServicesCubit>();
    if (!cubit.hasMoreData()) return;
    if (_isPaging) return;

    _isPaging = true;
    try {
      await cubit.fetchMoreServices(categoryId: int.tryParse(widget.categoryId));
    } finally {
      _isPaging = false;
    }
  }

  @override
  void dispose() {
    _scroll.removeListener(_onEndReached);
    _scroll.dispose();
    super.dispose();
  }

  // زر سياقي مع معالجة موحّدة لتدفّق "إضافة خدمة" (كل الخدمات -> صفحة رئيسية من السيرفر)
  Widget? _buildContextualAction(BuildContext context) {
    final String normalizedType =
        SliderInterfaceMapper.normalize(widget.interfaceType) ??
            widget.interfaceType.toLowerCase().trim();


    // لا زر في واجهة "اطلب إعلانك"
    if (normalizedType == 'request_ad') return null;

    // الأنواع المدعومة التي تذهب لنفس شاشة التفاصيل الرئيسية
    const supportedTypes = {
      'services_local',
      'services_medical',
      'services_student',
      'jobs',
      'events_offers',
      'marib_lost',
      'marib_guide',
    };

    if (!supportedTypes.contains(normalizedType)) return null;

    IconData _iconForType(String t) {
      if (t == 'jobs') return Icons.work_outline;
      if (t == 'events_offers') return Icons.event_available_outlined;
      if (t == 'marib_lost') return Icons.search_off_outlined;
      if (t == 'marib_guide') return Icons.local_library_outlined;
      return Icons.add_circle_outline; // المحلية/الطلابية/الطبية
    }

    String _labelForType(String t) {
      if (t == 'jobs') return 'أضف وظيفة';
      if (t == 'events_offers') return 'أضف فعالية/عرض';
      if (t == 'marib_lost') return 'أضف مفقودة';
      if (t == 'marib_guide') return 'أضف إلى الدليل';
      return 'أضف خدمة'; // المحلية/الطلابية/الطبية
    }

    TextButton _btn(IconData icon, String label, VoidCallback onTap) {
      final fg = Theme.of(context).appBarTheme.foregroundColor
          ?? Theme.of(context).colorScheme.onSurface
          ?? context.color.textColorDark;
      return TextButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 20),
        label: Text(label, maxLines: 1, overflow: TextOverflow.fade),
        style: TextButton.styleFrom(
          foregroundColor: fg,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      );
    }

    return _btn(
        _iconForType(normalizedType),
        _labelForType(normalizedType),
            () {
          final state = context.read<FetchServicesCubit>().state;

          if (state is! FetchServicesSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("loadingDataPleaseTryAgain".translate(context))),
            );
            return;
          }

          // نلتقط الخدمة الرئيسية (ملخص)
          final main = state.servicesList.firstWhere(
                (s) => s.isMain == true,
            orElse: () => const ClassifiedSummary(
                id: 0, title: null, image: null, isMain: true, status: true),
        );
          if (main.id == null || main.id == 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('تعذّر تحديد الصفحة الرئيسية لهذه الخدمة')),
            );
            return;
          }

          final category = CategoryModel(
            id: int.tryParse(widget.categoryId) ?? 0,
            name: widget.categoryName,
        );
          // نمرّر id + title + category — والجلب يتم داخل MainServiceDetails
          Navigator.pushNamed(
            context,
            Routes.mainServiceDetailsRoute,
            arguments: {
              "id": main.id,
              "title": main.title,
              "category": category,
            },
          );
            },
    );
  }

  @override
  Widget build(BuildContext context) {
    ScreenScaler.init(context);

    final contextualAction = _buildContextualAction(context);

    return RefreshIndicator(
      color: context.color.territoryColor,
      onRefresh: () async {
        await context
            .read<FetchServicesCubit>()
            .fetchServices(categoryId: int.tryParse(widget.categoryId));
      },
      child: Scaffold(
        backgroundColor: context.color.primaryColor,
        appBar: UiUtils.buildAppBar(
          context,
          showBackButton: true,
          title: widget.categoryName,
          actions: [
            if (contextualAction != null) contextualAction,
          ],
        ),
        body: BlocBuilder<FetchServicesCubit, FetchServicesState>(
          builder: (context, state) {
            // ===== Loading =====
            if (state is FetchServicesInProgress) {
              return Column(
                children: [
                  _buildSliderShimmer(context),
                  Expanded(child: _buildShimmerList(context)),
                ],
              );
            }

            // ===== Error =====
            if (state is FetchServicesFailure) {
              if (state.errorMessage is ApiException &&
                  state.errorMessage.toString().contains("no-internet")) {
                return NoInternet(
                  onRetry: () {
                    context.read<FetchServicesCubit>().fetchServices(
                      categoryId: int.tryParse(widget.categoryId),
                    );
                  },
                );
              }
              return const SomethingWentWrong();
            }

            // ===== Success =====
            if (state is FetchServicesSuccess) {
              final items = state.servicesList
                  .where((e) => e.status == true && e.isMain != true)
                  .toList();

              if (items.isEmpty) return const NoDataFound();

              return Column(
                children: [
                  // السلايدر: يختفي عند التمرير لفوق ويظهر عند النزول
                  ClipRect(
                    child: AnimatedSize(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                      child: _showSlider
                          ? Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: ScreenScaler.s(6),
                        ),
                        child: SliderWidget(
                          interfaceType: widget.interfaceType,
                          margin: EdgeInsets.zero,
                        ),
                      )
                          : const SizedBox.shrink(),
                    ),
                  ),

                  // القائمة مع مراقبة اتجاه التمرير
                  Expanded(
                    child: NotificationListener<UserScrollNotification>(
                      onNotification: (n) {
                        if (n.direction == ScrollDirection.reverse && _showSlider) {
                          setState(() => _showSlider = false);
                        } else if (n.direction == ScrollDirection.forward && !_showSlider) {
                          setState(() => _showSlider = true);
                        }
                        return false;
                      },
                      child: ListView.builder(
                        controller: _scroll,
                          padding: EdgeInsets.fromLTRB(
                          ScreenScaler.s(10),
                          ScreenScaler.s(8),
                          ScreenScaler.s(10),
                          ScreenScaler.s(10),
                        ),
                        itemCount: items.length +
                            (state.hasMore && state.isLoadingMore ? 1 : 0) +
                            (state.loadingMoreError ? 1 : 0),
                        itemBuilder: (context, index) {
                          // مؤشر تحميل آخر القائمة
                          if (state.hasMore &&
                              state.isLoadingMore &&
                              index == items.length) {
                            return Padding(
                              padding: EdgeInsets.all(ScreenScaler.s(12)),
                              child: const Center(child: CircularProgressIndicator()),
                            );
                          }

                          // عنصر خطأ التحميل الإضافي
                          if (state.loadingMoreError &&
                              index ==
                                  items.length +
                                      (state.hasMore && state.isLoadingMore ? 1 : 0)) {
                            return Padding(
                              padding: EdgeInsets.all(ScreenScaler.s(12)),
                              child: Center(
                                child: Text(
                                  "somethingWentWrng".translate(context),
                                  style: TextStyle(
                                    color: context.color.textColorDark,
                                  ),
                                ),
                              ),
                            );
                          }

                          final ClassifiedSummary model = items[index];
                          return _BlurCardListItem(
                            model: model,
                            categoryId: int.tryParse(widget.categoryId) ?? 0,
                            categoryName: widget.categoryName,
                          );
                        },
                      ),
                    ),
                  ),
                ],
              );
            }

            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  // ====== Shimmer للسلايدر ======
  Widget _buildSliderShimmer(BuildContext context) {
    ScreenScaler.init(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: ScreenScaler.s(6)),
      child: SizedBox(
        height: ScreenScaler.s(140),
        child: ListView.separated(
          padding: EdgeInsets.symmetric(horizontal: ScreenScaler.s(10)),
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 4,
          separatorBuilder: (_, __) => SizedBox(width: ScreenScaler.s(10)),
          itemBuilder: (_, __) => ClipRRect(
            borderRadius: BorderRadius.circular(ScreenScaler.s(12)),
            child: SizedBox(
              width: ScreenScaler.s(260),
              child: const CustomShimmer(width: double.infinity, height: double.infinity),
            ),
          ),
        ),
      ),
    );
  }

  // ====== Shimmer للقائمة ======
  Widget _buildShimmerList(BuildContext context) {
    ScreenScaler.init(context);
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        ScreenScaler.s(10),
        ScreenScaler.s(8),
        ScreenScaler.s(10),
        ScreenScaler.s(10),
      ),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Padding(
          padding: EdgeInsets.symmetric(vertical: ScreenScaler.s(6)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(ScreenScaler.s(16)),
            child: Container(
              height: ScreenScaler.s(140),
              decoration: BoxDecoration(
                color: context.color.secondaryColor,
                border: Border.all(color: context.color.borderColor.darken(90)),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const CustomShimmer(width: double.infinity, height: double.infinity),
                  Positioned.fill(
                    child: Container(color: Colors.black.withOpacity(.08)),
                  ),
                  Align(
                    alignment: Alignment.bottomLeft,
                    child: Padding(
                      padding: EdgeInsets.all(ScreenScaler.s(12)),
                      child: const CustomShimmer(
                        width: 180,
                        height: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// كرت بقائمة: خلفية صورة تغطي الكرت بالكامل + بلور خفيف + عنوان فوق الصورة + تأثير ضغط
class _BlurCardListItem extends StatefulWidget {
  final ClassifiedSummary model; // ← Summary
  final int categoryId;
  final String categoryName;

  const _BlurCardListItem({
    required this.model,
    required this.categoryId,
    required this.categoryName,
  });

  @override
  State<_BlurCardListItem> createState() => _BlurCardListItemState();
}

class _BlurCardListItemState extends State<_BlurCardListItem> {
  bool _pressed = false;

  void _go() {
    final m = widget.model;

    if (m.isMain == true) {
      Navigator.pushNamed(
        context,
        Routes.mainServiceDetailsRoute,
        arguments: {
          "id": m.id,
          "title": m.title,
          "category": CategoryModel(id: widget.categoryId, name: widget.categoryName),
        },
      );
      return;
    }

    final id = m.id;
    if (id == null || id == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يمكن فتح التفاصيل: مُعرّف الخدمة غير صالح')),
      );
      return;
    }

    Navigator.pushNamed(
      context,
      Routes.classifiedDetailsScreenRoute,
      arguments: {
        "id": id,
        "title": m.title, // يظهر بالـAppBar أثناء الشيمر
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    ScreenScaler.init(context);

    final String imageUrl = widget.model.image ?? '';

    return Padding(
      padding: EdgeInsets.symmetric(vertical: ScreenScaler.s(6)),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        scale: _pressed ? 0.98 : 1.0,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(ScreenScaler.s(16)),
            onTapDown: (_) => setState(() => _pressed = true),
            onTapCancel: () => setState(() => _pressed = false),
            onTapUp: (_) => setState(() => _pressed = false),
            onTap: _go,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(ScreenScaler.s(16)),
              child: Container(
                height: ScreenScaler.s(140),
                decoration: BoxDecoration(
                  color: context.color.secondaryColor,
                  border: Border.all(color: context.color.borderColor.darken(90)),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    UiUtils.getImage(
                      imageUrl,
                      fit: BoxFit.fill,
                      width: double.infinity,
                      height: double.infinity,
                    ),

                    // طبقة بلور وتعتيـم خفيف
                    Positioned.fill(
                      child: ImageFiltered(
                        imageFilter: ImageFilter.blur(sigmaX: 2.5, sigmaY: 2.5),
                        child: Container(color: Colors.black.withOpacity(0.15)),
                      ),
                    ),

                    // تدرّج سفلي لتحسين قراءة العنوان
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.center,
                            colors: [
                              Colors.black.withOpacity(0.35),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),

                    // العنوان + سهم
                    Positioned(
                      left: ScreenScaler.s(12),
                      right: ScreenScaler.s(12),
                      bottom: ScreenScaler.s(12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              (widget.model.title ?? "").firstUpperCase()._safeTruncate(60),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: ScreenScaler.s(16),
                                fontWeight: FontWeight.w700,
                                shadows: const [
                                  Shadow(color: Colors.black54, offset: Offset(0, 1), blurRadius: 2),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(width: ScreenScaler.s(8)),
                          Container(
                            padding: EdgeInsets.all(ScreenScaler.s(6)),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(.2),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withOpacity(.35)),
                            ),
                            child: const Icon(Icons.chevron_left, color: Colors.white, size: 22),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// قص آمن للنصوص
extension _SafeTruncate on String {
  String _safeTruncate(int max) {
    if (runes.length <= max) return this;
    return String.fromCharCodes(runes.take(max)) + '…';
  }
}
