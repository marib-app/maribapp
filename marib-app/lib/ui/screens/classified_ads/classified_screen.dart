import 'package:marib/app/routes.dart';
import 'package:marib/data/cubits/fetch_services_cubit.dart';
import 'package:marib/data/cubits/slider_cubit.dart';
import 'package:marib/data/model/category_model.dart';
import 'package:marib/data/model/classified_model.dart' show ClassifiedSummary; // ← نستخدم النسخة الخفيفة
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
import 'package:marib/utils/ui_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marib/utils/screen_scaler.dart';
import 'package:marquee/marquee.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:marib/data/model/classified_model.dart' show ClassifiedSummary, ClassifiedSummaryX;
import 'package:marib/utils/slider_interface_mapper.dart';

/// ---------------------------------------------------------------------------
/// ClassifiedScreen (نسخة محسّنة الأداء بدون أي تغيير مرئي على الواجهة)
/// ---------------------------------------------------------------------------

class ClassifiedScreen extends StatefulWidget {
  final String categoryId, categoryName, interfaceType;

  const ClassifiedScreen({
    super.key,
    required this.categoryId,
    required this.categoryName,
    required this.interfaceType,
  });

  @override
  _ClassifiedScreenState createState() => _ClassifiedScreenState();

  static Route route(RouteSettings routeSettings) {
    final Map? arguments = routeSettings.arguments as Map?;
    return BlurredRouter(
      builder: (_) => ClassifiedScreen(
        categoryId: arguments?['catID'] as String,
        categoryName: arguments?['catName'],
        interfaceType: arguments?['interfaceType'],
      ),
    );
  }
}



class _ClassifiedScreenState extends State<ClassifiedScreen> {
  final ScrollController _pageScrollController = ScrollController();

  bool _adShownOnce = false; // عرض الإعلان مرة واحدة
  bool _isPaging = false;    // حارس تحميل المزيد

  @override
  void initState() {
    super.initState();

    AdHelper.loadInterstitialAd();

    // تأجيل الجلب + عرض الإعلان لما بعد أول فريم
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FetchServicesCubit>().fetchServices(
        categoryId: int.tryParse(widget.categoryId),
      );

      if (!_adShownOnce) {
        _adShownOnce = true;
        AdHelper.showInterstitialAd();
      }
    });

    _pageScrollController.addListener(_pageScrollListen);
  }

  Future<void> _pageScrollListen() async {
    if (!_pageScrollController.isEndReached()) return;

    final cubit = context.read<FetchServicesCubit>();
    if (!cubit.hasMoreData()) return;
    if (_isPaging) return;

    _isPaging = true;
    try {
      await cubit.fetchMoreServices(
        categoryId: int.tryParse(widget.categoryId),
      );
    } finally {
      _isPaging = false;
    }
  }

  @override
  void dispose() {
    _pageScrollController.removeListener(_pageScrollListen);
    _pageScrollController.dispose();
    super.dispose();
  }



// زر سياقي مع معالجة موحّدة لتدفّق "إضافة خدمة" (كل الخدمات -> صفحة رئيسية من السيرفر)
  Widget? _buildContextualAction(BuildContext context) {
    final String normalizedType =
        SliderInterfaceMapper.normalize(widget.interfaceType) ??
            widget.interfaceType.toLowerCase().trim();

    // لا زر في واجهة "اطلب إعلانك"
    if (normalizedType == 'request_ad') return null;

    // الأنواع التي نُظهر لها الزر وتذهب كلها لنفس شاشة التفاصيل الرئيسية من السيرفر
    const supportedTypes = {
      'services_local',
      'services_medical',
      'services_student',
      'jobs',
      'events_offers',
      'marib_lost',
      'marib_guide',
    };

    // أي نوع خارج القائمة المدعومة -> بدون زر
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
      // المحلية/الطلابية/الطبية
      return 'أضف خدمة';
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

          // نلتقط الخدمة الرئيسية (ملخّص) من القائمة
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
    ScreenScaler.init(context); // مرة واحدة هنا

    final contextualAction = _buildContextualAction(context);

    return RefreshIndicator(
      color: context.color.territoryColor,
      onRefresh: () async {
        await context.read<FetchServicesCubit>().fetchServices(
          categoryId: int.tryParse(widget.categoryId),
        );
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
            if (state is FetchServicesInProgress) {
              return Column(
                children: [
                  const SliderShimmer(),
                  Expanded(child: buildClassifiedShimmerGrid(context)),
                ],
              );
            }

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

            if (state is FetchServicesSuccess) {
              // Summary خفيف
              final activeServices = state.servicesList
                  .where((s) => s.status == true && s.isMain != true)
                  .toList();

              if (activeServices.isEmpty) {
                return const NoDataFound();
              }

              return Column(
                children: [
                  SliderWidget(interfaceType: widget.interfaceType),


                  Expanded(
                    child: GridView.custom(
                      controller: _pageScrollController,
                      cacheExtent: 400,

                      // ✅ نفس padding الشيمر
                      padding: EdgeInsets.all(ScreenScaler.s(8)),

                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: ScreenScaler.s(8),
                        mainAxisSpacing: ScreenScaler.s(8),
                        childAspectRatio: 0.54, // مطابق للشيمر
                      ),
                      childrenDelegate: SliverChildBuilderDelegate(
                            (context, index) {
                          // مؤشر “تحميل المزيد”
                          if (state.hasMore && state.isLoadingMore &&
                              index == activeServices.length) {
                            return const Center(child: CircularProgressIndicator());
                          }

                          // عنصر خطأ التحميل الإضافي
                          if (state.loadingMoreError &&
                              index == activeServices.length +
                                  (state.hasMore && state.isLoadingMore ? 1 : 0)) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text("somethingWentWrng".translate(context)),
                              ),
                            );
                          }

                          final ClassifiedSummary service = activeServices[index];
                          return RepaintBoundary(
                            child: ClassifiedCardWithEffect(
                              classified: service,
                              categoryId: int.tryParse(widget.categoryId) ?? 0,
                              categoryName: widget.categoryName,
                            ),
                          );
                        },
                        childCount: activeServices.length +
                            (state.hasMore && state.isLoadingMore ? 1 : 0) +
                            (state.loadingMoreError ? 1 : 0),
                        addAutomaticKeepAlives: false,
                        addRepaintBoundaries: true,
                        addSemanticIndexes: false,
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
}



class ClassifiedCardWithEffect extends StatefulWidget {
  final ClassifiedSummary classified; // ← Summary
  final int categoryId;
  final String categoryName;

  const ClassifiedCardWithEffect({
    super.key,
    required this.classified,
    required this.categoryId,
    required this.categoryName,
  });

  @override
  State<ClassifiedCardWithEffect> createState() => _ClassifiedCardWithEffectState();
}

class _ClassifiedCardWithEffectState extends State<ClassifiedCardWithEffect> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _isPressed ? 0.97 : 1.0,
      duration: const Duration(milliseconds: 120),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(ScreenScaler.s(20)),
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) => setState(() => _isPressed = false),
          onTapCancel: () => setState(() => _isPressed = false),
          onTap: () {
            if (widget.classified.isMain == true) {
              // كما هي لديك...
            } else {
              final id = widget.classified.id;
              if (id == 0 || id == null) {
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
                  "title": widget.classified.title, // للـAppBar أثناء الشيمر
                },
              );
            }
          },

          child: buildClassifiedCard(
            context,
            widget.classified,
            widget.categoryId,
            widget.categoryName,
          ),
        ),
      ),
    );
  }
}




// بطاقة الخدمة (بدون أي تغيير بصري)

Widget buildClassifiedCard(
    BuildContext context,
    ClassifiedSummary classified,
    int categoryId,
    String categoryName,
    ) {
  final double r = ScreenScaler.s(16);     // نصف قطر البطاقة
  final double bw = 1;                     // سُمك الإطار
  final double titleH = ScreenScaler.s(20);
  final double gap = ScreenScaler.s(6);

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // ✅ قص كل شيء (الصورة + الإطار + الـInk splash) بنفس نصف القطر
      Expanded(
        child: ClipRRect(
          clipBehavior: Clip.antiAlias,
          borderRadius: BorderRadius.circular(r),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              // قص السبلش بنفس نصف القطر
              customBorder: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(r),
              ),
              onTap: () {
                if (classified.isMain == true) {
                  // نفس منطقك لو فيه تعامل خاص للـ main
                } else {
                  final id = classified.id;
                  if (id == 0 || id == null) {
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
                      "title": classified.title, // للـAppBar أثناء الشيمر
                    },
                  );
                }
              },
                child: Builder(
                    builder: (context) {
                      final preferredThumb =
                      (classified.thumbnailUrl?.trim().isNotEmpty ?? false)
                          ? classified.thumbnailUrl
                          : null;
                      final fallbackThumb =
                      (classified.thumbnailFallbackUrl?.trim().isNotEmpty ?? false)
                          ? classified.thumbnailFallbackUrl
                          : classified.image;
                      final resolvedThumb =
                          preferredThumb ?? fallbackThumb ?? classified.image ?? '';

                      return Ink( // ✅ Ink لسبلاش متوافق مع الديكور
                        decoration: BoxDecoration(
                          color: context.color.secondaryColor,
                          borderRadius: BorderRadius.circular(r),
                          border: Border.all(
                            width: bw,
                            color: context.color.borderColor.darken(90),
                      ),
                    ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ✅ الصورة مرِنة ومقصوصة بنفس حافة الأعلى (مطابقة تمامًا للإطار)
                            Expanded(
                              child: ClipRRect(
                                clipBehavior: Clip.antiAlias,
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(r - bw), // تطابق الإطار
                                ),
                                child: UiUtils.getImage(
                                  resolvedThumb,
                                  fit: BoxFit.fill,
                                  width: double.infinity,
                                  fallbackUrl: fallbackThumb,
                                  cacheWidth: 200,
                                  cacheHeight: 200,
                                ),
                              ),
                            ),
                            // العنوان مع نفس المقاسات
                            Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: ScreenScaler.s(10),
                                vertical: ScreenScaler.s(8),
                              ),
                              child: SizedBox(
                                height: titleH,
                                child: (classified.title ?? "").length < 20
                                    ? Text(
                                  (classified.title ?? "").firstUpperCase(),
                                  style: TextStyle(
                                    color: context.color.textColorDark,
                                    fontSize: ScreenScaler.s(14),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                )
                                    : Marquee(
                                  text: (classified.title ?? "").firstUpperCase(),
                                  style: TextStyle(
                                    color: context.color.textColorDark,
                                    fontSize: ScreenScaler.s(14),
                                  ),
                                  scrollAxis: Axis.horizontal,
                                  blankSpace: 30.0,
                                  velocity: 30.0,
                                  pauseAfterRound: const Duration(seconds: 2),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                ),
              ),
            ),
          ),
      ),

      // مسافة صغيرة أسفل البطاقة
      SizedBox(height: gap),

      // التقييم خارج البطاقة
      Padding(
        padding: EdgeInsets.only(left: ScreenScaler.s(4)),
        child: Row(
          children: [
            const Icon(Icons.star, size: 16, color: Colors.amber),
            SizedBox(width: ScreenScaler.s(4)),
            Text(
              "${classified.rating ?? 0.0}",
              style: TextStyle(
                fontSize: ScreenScaler.s(12),
                color: context.color.textColorDark,
              ),
            ),
            SizedBox(width: ScreenScaler.s(4)),
            Text(
              "(${classified.totalRatings ?? 0})",
              style: TextStyle(
                fontSize: ScreenScaler.s(12),
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}





// شبكة الشيمر (كما هي لديك)
Widget buildClassifiedShimmerGrid(BuildContext context) {
  return GridView.builder(
    itemCount: 6,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    padding: EdgeInsets.all(ScreenScaler.s(8)),
    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 3,
      crossAxisSpacing: ScreenScaler.s(6),
      mainAxisSpacing: ScreenScaler.s(8),
      childAspectRatio: 0.54,
    ),
    itemBuilder: (context, index) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: context.color.secondaryColor,
              borderRadius: BorderRadius.circular(ScreenScaler.s(10)),
              border: Border.all(
                color: context.color.borderColor.darken(90),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(ScreenScaler.s(1)),
                  ),
                  child: AspectRatio(
                    aspectRatio: 3 / 4,
                    child: const CustomShimmer(
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: ScreenScaler.s(10),
                    vertical: ScreenScaler.s(8),
                  ),
                  child: CustomShimmer(
                    width: ScreenScaler.s(80),
                    height: ScreenScaler.s(14),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.only(
              top: ScreenScaler.s(6),
              left: ScreenScaler.s(8),
              right: ScreenScaler.s(8),
            ),
            child: Row(
              children: [
                Container(
                  width: ScreenScaler.s(16),
                  height: ScreenScaler.s(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: ScreenScaler.s(6)),
                CustomShimmer(
                  width: ScreenScaler.s(24),
                  height: ScreenScaler.s(10),
                ),
                SizedBox(width: ScreenScaler.s(6)),
                CustomShimmer(
                  width: ScreenScaler.s(36),
                  height: ScreenScaler.s(10),
                ),
              ],
            ),
          ),
        ],
      );
    },
  );
}




