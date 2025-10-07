// lib/new_code/ui/classified_ads/classified_screen2.dart

import 'package:marib/app/routes.dart';
import 'package:marib/data/cubits/fetch_services_cubit.dart';
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
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marib/utils/screen_scaler.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:marib/utils/slider_interface_mapper.dart';

class ClassifiedScreen2 extends StatefulWidget {
  final String categoryId, categoryName, interfaceType;

  const ClassifiedScreen2({
    super.key,
    required this.categoryId,
    required this.categoryName,
    required this.interfaceType,
  });

  static Route route(RouteSettings routeSettings) {
    final Map? args = routeSettings.arguments as Map?;
    return BlurredRouter(
      builder: (_) => ClassifiedScreen2(
        categoryId: args?['catID'] as String,
        categoryName: args?['catName'] as String,
        interfaceType: args?['interfaceType'] as String,
      ),
    );
  }

  @override
  State<ClassifiedScreen2> createState() => _ClassifiedScreen2State();
}

class _ClassifiedScreen2State extends State<ClassifiedScreen2> {
  final ScrollController _scroll = ScrollController();

  bool _adShownOnce = false;
  bool _isPaging = false;

  @override
  void initState() {
    super.initState();

    AdHelper.loadInterstitialAd();

    // نؤجل الجلب + إظهار الإعلان لأول فريم
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context
          .read<FetchServicesCubit>()
          .fetchServices(categoryId: int.tryParse(widget.categoryId));

      if (!_adShownOnce) {
        _adShownOnce = true;
        AdHelper.showInterstitialAd();
      }
    });

    _scroll.addListener(_onScroll);
  }

  Future<void> _onScroll() async {
    if (!_scroll.isEndReached()) return;

    final cubit = context.read<FetchServicesCubit>();
    if (!cubit.hasMoreData()) return;
    if (_isPaging) return;

    _isPaging = true;
    try {
      await cubit.fetchMoreServices(
          categoryId: int.tryParse(widget.categoryId));
    } finally {
      _isPaging = false;
    }
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  // زر سياقي (نفس منطق شاشة ClassifiedScreen)
  Widget? _buildContextualAction(BuildContext context) {
    final String normalizedType =
        SliderInterfaceMapper.normalize(widget.interfaceType) ??
            widget.interfaceType.toLowerCase().trim();

    if (normalizedType == 'request_ad') return null;

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
      final fg = Theme.of(context).appBarTheme.foregroundColor ??
          Theme.of(context).colorScheme.onSurface ??
          context.color.textColorDark;
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
            SnackBar(
                content: Text("loadingDataPleaseTryAgain".translate(context))),
          );
          return;
        }

        // نلتقط الخدمة الرئيسية من قائمة الملخصات
        final main = state.servicesList.firstWhere(
          (s) => s.isMain == true,
          orElse: () => const ClassifiedSummary(
              id: 0, title: null, image: null, isMain: true, status: true),
        );
        if (main.id == 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('تعذّر تحديد الصفحة الرئيسية لهذه الخدمة')),
          );
          return;
        }

        final category = CategoryModel(
          id: int.tryParse(widget.categoryId) ?? 0,
          name: widget.categoryName,
        );
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
            if (state is FetchServicesInProgress) {
              return Column(
                children: [
                  const SliderShimmer(),
                  Expanded(child: _buildShimmerList(context)),
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
              // استبعاد الخدمة الرئيسية والعناصر غير الفعّالة
              final items = state.servicesList
                  .where((e) => e.status == true && e.isMain != true)
                  .toList();

              if (items.isEmpty) return const NoDataFound();

              return Column(
                children: [
                  SliderWidget(interfaceType: widget.interfaceType),
                  Expanded(
                    child: ListView.builder(
                      controller: _scroll,
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.symmetric(
                        vertical: ScreenScaler.s(6),
                        horizontal: ScreenScaler.s(8),
                      ),
                      itemCount: items.length +
                          (state.hasMore && state.isLoadingMore ? 1 : 0) +
                          (state.loadingMoreError ? 1 : 0),
                      itemBuilder: (context, index) {
                        // مؤشر تحميل المزيد
                        if (state.hasMore &&
                            state.isLoadingMore &&
                            index == items.length) {
                          return Padding(
                            padding: EdgeInsets.all(ScreenScaler.s(12)),
                            child: const Center(
                                child: CircularProgressIndicator()),
                          );
                        }

                        // عنصر خطأ التحميل الإضافي
                        if (state.loadingMoreError &&
                            index ==
                                items.length +
                                    (state.hasMore && state.isLoadingMore
                                        ? 1
                                        : 0)) {
                          return Padding(
                            padding: EdgeInsets.all(ScreenScaler.s(12)),
                            child: Center(
                              child: Text(
                                "somethingWentWrng".translate(context),
                                style: TextStyle(
                                    color: context.color.textColorDark),
                              ),
                            ),
                          );
                        }

                        final ClassifiedSummary model = items[index];
                        return _ClassifiedListItem(
                          model: model,
                          categoryId: int.parse(widget.categoryId),
                          categoryName: widget.categoryName,
                          interfaceType: widget.interfaceType,
                        );
                      },
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

/// عنصر القائمة (كرت طولي مناسب للفعاليات/العروض/الدليل)
class _ClassifiedListItem extends StatelessWidget {
  final ClassifiedSummary model; // ← Summary
  final int categoryId;
  final String categoryName;
  final String interfaceType;

  const _ClassifiedListItem({
    required this.model,
    required this.categoryId,
    required this.categoryName,
    required this.interfaceType,
  });

  @override
  Widget build(BuildContext context) {
    ScreenScaler.init(context);

    final String typeBadge = _resolveTypeBadge(interfaceType);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: ScreenScaler.s(6)),
      child: InkWell(
        borderRadius: BorderRadius.circular(ScreenScaler.s(12)),
        onTap: () => _onTap(context),
        child: Container(
          decoration: BoxDecoration(
            color: context.color.secondaryColor,
            borderRadius: BorderRadius.circular(ScreenScaler.s(12)),
            border: Border.all(color: context.color.borderColor.darken(90)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // صورة يسار (ClassifiedSummary لا يحتوي icon، نستخدم image فقط)
              ClipRRect(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(ScreenScaler.s(12)),
                  bottomLeft: Radius.circular(ScreenScaler.s(12)),
                ),
                child: SizedBox(
                  width: ScreenScaler.s(110),
                  height: ScreenScaler.s(110),
                  child: UiUtils.getImage(
                    model.image ?? '',
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
              ),

              // نصوص يمين
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(ScreenScaler.s(10)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // العنوان + الشارة
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              (model.title ?? "").firstUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: context.color.textColorDark,
                                fontSize: ScreenScaler.s(15),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (typeBadge.isNotEmpty) ...[
                            SizedBox(width: ScreenScaler.s(6)),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: ScreenScaler.s(8),
                                vertical: ScreenScaler.s(3),
                              ),
                              decoration: BoxDecoration(
                                color: context.color.territoryColor
                                    .withOpacity(.12),
                                borderRadius:
                                    BorderRadius.circular(ScreenScaler.s(20)),
                                border: Border.all(
                                  color:
                                      context.color.territoryColor.darken(10),
                                ),
                              ),
                              child: Text(
                                typeBadge,
                                style: TextStyle(
                                  fontSize: ScreenScaler.s(10.5),
                                  color: context.color.territoryColor.darken(5),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),

                      SizedBox(height: ScreenScaler.s(8)),

                      // وصف مختصر (اختياري لاحقًا من HTML)
                      // if ((model.description ?? '').isNotEmpty)
                      //   Text(
                      //     _stripHtml(model.description!).truncateAt(120),
                      //     maxLines: 2,
                      //     overflow: TextOverflow.ellipsis,
                      //     style: TextStyle(
                      //       color: context.color.textColorDark.withOpacity(.7),
                      //       fontSize: ScreenScaler.s(12.5),
                      //     ),
                      //   ),

                      SizedBox(height: ScreenScaler.s(10)),

                      // شريط معلومات سفلي (اسم القسم + سهم)
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              categoryName,
                              style: TextStyle(
                                fontSize: ScreenScaler.s(11.5),
                                color: Colors.grey,
                              ),
                            ),
                          ),
                          SizedBox(width: ScreenScaler.s(6)),
                          Icon(
                            Icons.chevron_left,
                            size: ScreenScaler.s(20),
                            color: context.color.textColorDark.withOpacity(.8),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onTap(BuildContext context) {
    // في هذه الشاشة استبعدنا isMain من القائمة، نخلي الحارس للاحتياط
    if (model.isMain == true) {
      final category = CategoryModel(id: categoryId, name: categoryName);
      Navigator.pushNamed(
        context,
        Routes.mainServiceDetailsRoute,
        arguments: {
          "id": model.id,
          "title": model.title,
          "category": category,
        },
      );
      return;
    }

    final id = model.id;
    if (id == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('لا يمكن فتح التفاصيل: مُعرّف الخدمة غير صالح')),
      );
      return;
    }

    Navigator.pushNamed(
      context,
      Routes.classifiedDetailsScreenRoute,
      arguments: {
        "id": id,
        "title": model.title, // للـAppBar أثناء الشيمر
      },
    );
  }

  String _resolveTypeBadge(String interfaceType) {
    final t = interfaceType.toLowerCase();
    if (t.contains('event')) return "فعاليات";
    if (t.contains('offer')) return "عروض";
    if (t.contains('guide')) return "دليل";
    return "";
  }
}

/// Shimmer لقائمة الكروت
Widget _buildShimmerList(BuildContext context) {
  ScreenScaler.init(context);
  return ListView.separated(
    physics: const NeverScrollableScrollPhysics(),
    padding: EdgeInsets.symmetric(
      vertical: ScreenScaler.s(6),
      horizontal: ScreenScaler.s(8),
    ),
    itemCount: 8,
    separatorBuilder: (_, __) => SizedBox(height: ScreenScaler.s(6)),
    itemBuilder: (context, index) {
      return Container(
        decoration: BoxDecoration(
          color: context.color.secondaryColor,
          borderRadius: BorderRadius.circular(ScreenScaler.s(12)),
          border: Border.all(color: context.color.borderColor.darken(90)),
        ),
        child: Row(
          children: [
            // صورة
            ClipRRect(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(ScreenScaler.s(12)),
                bottomLeft: Radius.circular(ScreenScaler.s(12)),
              ),
              child: SizedBox(
                width: ScreenScaler.s(110),
                height: ScreenScaler.s(110),
                child: const CustomShimmer(
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
            ),
            // نصوص
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(ScreenScaler.s(10)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomShimmer(
                      width: ScreenScaler.s(160),
                      height: ScreenScaler.s(14),
                    ),
                    SizedBox(height: ScreenScaler.s(8)),
                    CustomShimmer(
                      width: ScreenScaler.s(220),
                      height: ScreenScaler.s(10),
                    ),
                    SizedBox(height: ScreenScaler.s(6)),
                    CustomShimmer(
                      width: ScreenScaler.s(140),
                      height: ScreenScaler.s(10),
                    ),
                    SizedBox(height: ScreenScaler.s(10)),
                    Row(
                      children: [
                        CustomShimmer(
                          width: ScreenScaler.s(60),
                          height: ScreenScaler.s(10),
                        ),
                        const Spacer(),
                        CustomShimmer(
                          width: ScreenScaler.s(60),
                          height: ScreenScaler.s(10),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}
