// lib/ui/screens/item/add_item_screen/select_category.dart
//
// ملف المنطق فقط (Logic-Only)
// - الواجهة بالكامل في select_category_ui.dart
// - هذا الملف يحتوي الشاشات المنطقية + إدارة الجلب/التنقل/الـ Cubits فقط
//
// ملاحظات هامة:
// 1) تفعيل "الجلب عند الفتح" (Fetch-On-Open): لا نجلب البيانات إلا بعد فتح الصفحة (بعد أول فريم).
// 2) كل مستوى يجلب بياناته عند الحاجة فقط:
//    - واجهة اختيار الفئات الرئيسية: تجلب الفئات بعد فتح الصفحة.
//    - واجهة الفئات المتداخلة: تجلب الفئات الفرعية بعد فتح الصفحة.
// 3) تم إضافة BlocListener لطباعة لوجات تشخيصية (InProgress/Success/Failure) لتسهيل التتبّع.
// 4) فصل الواجهة عن المنطق كليًا: الواجهة تستقبل حالات وكولباكات فقط وتبني الـ UI.
//
// متطلبات:
// - يجب أن تتوفر الكيوبتس التالية كما في مشروعك:
//   FetchCategoryCubit / FetchCategoryState
//   FetchSubCategoriesCubit / FetchSubCategoriesState
//   FetchCustomFieldsCubit
//
// - الواجهة المرافقة: select_category_ui.dart تحتوي SelectCategoryUI و SelectNestedCategoryUI
//

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:marib/app/routes.dart';
import 'package:marib/data/cubits/category/fetch_category_cubit.dart';
import 'package:marib/data/cubits/category/fetch_sub_categories_cubit.dart';
import 'package:marib/data/cubits/custom_field/fetch_custom_fields_cubit.dart';

import 'package:marib/data/model/category_model.dart';
import 'package:marib/utils/cloudState/cloud_state.dart';
// isEndReached()
import 'package:marib/utils/touch_manager.dart';
import 'package:marib/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:marib/utils/hive_utils.dart';
// الواجهة المنفصلة (لا تحتوي أي منطق)
import 'package:marib/ui/screens/item/add_item_screen/select_category_ui.dart';
import 'package:marib/ui/screens/item/add_item_screen/scroll_extensions.dart';
import 'package:marib/utils/constant.dart';

// عدّاد اختياري يُستخدم عند التنقل التراكمي (كما في الكود الأصلي)

int screenStack = 0;

/// =======================================================================
/// SelectCategoryScreen (منطق فقط)
/// - تعرض قائمة الفئات (الجذرية أو حسب إعدادات الكيوبت لديك).
/// - الجلب يتم بعد فتح الصفحة (Post-Frame) لإيقاف التحميل المسبق.
/// - التمرير اللامنتهي مدعوم عبر ScrollController + hasMoreData().
/// =======================================================================
class SelectCategoryScreen extends StatefulWidget {
  const SelectCategoryScreen({super.key});

  /// ممرّ route مع مزوّدات محلية للكيوبتس اللازمة فقط لهذه الشاشة.
  static Route route(RouteSettings settings) {
    return BlurredRouter(
      builder: (context) {
        return MultiBlocProvider(
          providers: [
            // Cubit للفئات (لا تُوفره بشكل Global حتى لا يجلب قبل الفتح)
            BlocProvider(create: (_) => FetchCategoryCubit()),
            // Cubit للحقول المخصصة (يُستخدم عند الانتقال للتفاصيل)
            BlocProvider(create: (_) => FetchCustomFieldsCubit()),
          ],
          child: const SelectCategoryScreen(),
        );
      },
    );
  }

  @override
  CloudState<SelectCategoryScreen> createState() =>
      _SelectCategoryScreenState();
}

class _SelectCategoryScreenState extends CloudState<SelectCategoryScreen> {
  // متحكم التمرير لمتابعة الوصول لنهاية القائمة
  late final ScrollController controller = ScrollController();

  int? _delegateRootId;

  @override
  void initState() {
    setCloudData("breadCrumb", <CategoryModel>[]);

    clearCloudData('delegateRootId');

    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      _delegateRootId = HiveUtils.getDelegateRootCategoryId();
      if (_delegateRootId != null) {
        final root = _buildDelegateRootCategory(_delegateRootId!);
        setCloudData('delegateRootId', _delegateRootId!);
        setCloudData("breadCrumb", [root]);
        Navigator.pushReplacementNamed(
          context,
          Routes.selectNestedCategoryScreen,
          arguments: {"current": root},
        );
        return;
      }

      final bool wasDelegateBefore = HiveUtils.wasDelegateBefore();

      final int? t =
          HiveUtils.getUserDetails().userType; // 1 فردي, 2 عقاري, 3 تجاري
      int? rootId;
      if (t == 1) {
        rootId = Constant.publicRootCategoryId; // الفردي → CategoryPublic
      } else if (t == 2) {
        rootId =
            Constant.realEstateRootCategoryId; // العقاري → real_estate_services
      } else if (wasDelegateBefore) {
        rootId = Constant.publicRootCategoryId;
      }

      if (rootId != null) {
        final root = CategoryModel(
          id: rootId,
          name: '',
          children: const [],
          subcategoriesCount: 1,
        );
        setCloudData("breadCrumb", [root]);
        Navigator.pushReplacementNamed(
          context,
          Routes.selectNestedCategoryScreen,
          arguments: {"current": root},
        );
        return; // لا تجلب الجذور
      }

      // التجاري أو غير محدد → السلوك القديم
      await _fetchAllRootCategories();
    });
  }

  CategoryModel _buildDelegateRootCategory(int rootId) {
    return CategoryModel(
      id: rootId,
      name: '',
      children: const [],
      subcategoriesCount: 1,
    );
  }

  Future<void> _fetchAllRootCategories() async {
    final cubit = context.read<FetchCategoryCubit>();

    // اطلب الصفحة الأولى ثم انتظر وصول بيانات فعلية
    cubit.fetchCategories();
    var state = await cubit.stream.firstWhere((s) => s is FetchCategorySuccess);
    var prevLen = (state as FetchCategorySuccess).categories.length;

    // لو عندك صفحات إضافية: اطلب صفحة، ثم انتظر زيادة في الطول
    while (cubit.hasMoreData()) {
      cubit.fetchCategoriesMore();

      state = await cubit.stream.firstWhere(
        (s) => s is FetchCategorySuccess && (s).categories.length > prevLen,
        orElse: () => state,
      );

      final curLen = (state as FetchCategorySuccess).categories.length;
      if (curLen <= prevLen) break; // حماية من تكرار نفس الصفحة
      prevLen = curLen;

      if (!mounted) break;
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  /// مستمع نهاية الصفحة: عند الوصول للأسفل نحمّل المزيد إن وُجد
  void _pageScrollListen() {
    if (controller.isEndReached()) {
      final c = context.read<FetchCategoryCubit>();
      if (c.hasMoreData()) {
        debugPrint('[SelectCategory] fetchCategoriesMore(): load more');
        c.fetchCategoriesMore();
      }
    }
  }

  // جلب الحقول المخصصة ثم الانتقال لشاشة تفاصيل إضافة الإعلان

  Future<void> _navigateAfterCustomFieldsForList(
      List<CategoryModel> breadCrumbList) async {
    final ids = breadCrumbList.map((e) => e.id!).toList();

    context
        .read<FetchCustomFieldsCubit>()
        .fetchCustomFields(categoryIds: ids.join(','));

    await Future.delayed(const Duration(milliseconds: 100));

    Navigator.pushNamed(
      context,
      Routes.addMoreDetailsScreen,
      arguments: <String, dynamic>{
        "breadCrumbItems": breadCrumbList,
        "categoryIds": ids,
        "isEdit": false,
        "mainImage": null,
        "otherImage": null,
        // 👈 مهم
        "customFieldsCubit": context.read<FetchCustomFieldsCubit>(),
      },
    ).then((_) {
      setCloudData("breadCrumb", <CategoryModel>[]);
    });

    TouchManager.touchProcessed();
  }

  // عند الضغط على فئة من الشبكة الرئيسية

  void _onRootCategoryTap(CategoryModel category) {
    if (category.children!.isEmpty && category.subcategoriesCount == 0) {
      if (!TouchManager.canProcessTouch()) return;

      final bc = <CategoryModel>[category];
      setCloudData("breadCrumb", bc);
      _navigateAfterCustomFieldsForList(bc); // 👈 استدعِ الدالة الجديدة
    } else {
      // ... كما هو (الانتقال للمتداخلة)
      if (!TouchManager.canProcessTouch()) return;

      setCloudData("breadCrumb", [category]);
      screenStack++;
      Navigator.pushNamed(
        context,
        Routes.selectNestedCategoryScreen,
        arguments: {"current": category},
      ).then((_) {
        setCloudData("breadCrumb", <CategoryModel>[]);
      });
      Future.delayed(const Duration(seconds: 1), TouchManager.touchProcessed);
    }
  }

  @override
  Widget build(BuildContext context) {
    // نقرأ الحالة لتمريرها للواجهة
    final fetchCategoryState = context.watch<FetchCategoryCubit>().state;

    // BlocListener لوجات تشخيصية (لا يغيّر الواجهة)
    return BlocListener<FetchCategoryCubit, FetchCategoryState>(
      listener: (context, state) {
        if (state is FetchCategoryInProgress) {
          debugPrint('[SelectCategory] state=InProgress');
        } else if (state is FetchCategorySuccess) {
          debugPrint(
              '[SelectCategory] state=Success count=${state.categories.length} isLoadingMore=${state.isLoadingMore}');
        } else if (state is FetchCategoryFailure) {
          debugPrint(
              '[SelectCategory] state=Failure error=${state.errorMessage}');
        }
      },
      child: SelectCategoryUI(
        controller: controller,
        fetchCategoryState: fetchCategoryState,
        onBackToRoot: () => Navigator.of(context).popUntil((r) => r.isFirst),
        onLoadMoreRequested: _pageScrollListen,
        onCategoryTap: _onRootCategoryTap,
      ),
    );
  }
}

/// =======================================================================
/// SelectNestedCategory (منطق فقط)
/// - دائمًا نتجاهل children الجاهزة ونطلب الفئات الفرعية من الكيوبت عند الدخول.
/// - هذا يضمن Lazy Loading + ظهور شيمر عند فتح كل مستوى.
/// =======================================================================
class SelectNestedCategory extends StatefulWidget {
  const SelectNestedCategory({
    super.key,
    required this.current,
  });

  final CategoryModel current;

  /// route يزوّد FetchSubCategoriesCubit محليًا لهذه الشاشة فقط.
  static Route route(RouteSettings settings) {
    final args = settings.arguments as Map<String, dynamic>;
    final current = args['current'] as CategoryModel;

    return BlurredRouter(
      builder: (context) {
        return BlocProvider(
          create: (_) => FetchSubCategoriesCubit(),
          child: SelectNestedCategory(current: current),
        );
      },
    );
  }

  @override
  CloudState<SelectNestedCategory> createState() =>
      _SelectNestedCategoryState();
}

class _SelectNestedCategoryState extends CloudState<SelectNestedCategory> {
  // متحكم التمرير لمتابعة نهاية القائمة (Load More)
  late final ScrollController controller = ScrollController();

  // نسخة محلية من الـ Breadcrumb لسرعة التحديث البصري (إن لزم)
  List<CategoryModel> breadCrumbData = [];

  int? delegateRootId;

  @override
  void initState() {
    delegateRootId = getCloudData('delegateRootId') as int?;

    final bc = getCloudData('breadCrumb') ?? <CategoryModel>[];
    if (bc.isEmpty) {
      if (delegateRootId != null) {
        setCloudData("breadCrumb", [_buildDelegateRoot(delegateRootId!)]);
      } else {
        setCloudData("breadCrumb", [widget.current]);
      }
    }

    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _fetchAllSubCategories();
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _fetchAllSubCategories() async {
    final c = context.read<FetchSubCategoriesCubit>();

    final categoryId = _resolveCategoryIdForFetch();

    c.fetchSubCategories(categoryId: categoryId);

    var state =
        await c.stream.firstWhere((s) => s is FetchSubCategoriesSuccess);
    var prevLen = (state as FetchSubCategoriesSuccess).categories.length;

    while (c.hasMoreData()) {
      c.fetchSubCategories(categoryId: categoryId);

      state = await c.stream.firstWhere(
        (s) =>
            s is FetchSubCategoriesSuccess && (s).categories.length > prevLen,
        orElse: () => state,
      );

      final curLen = (state as FetchSubCategoriesSuccess).categories.length;
      if (curLen <= prevLen) break; // نفس الصفحة تكررت؟ اطلع
      prevLen = curLen;

      if (!mounted) break;
    }
  }

  /// مستمع نهاية الصفحة: تحميل المزيد عند الحاجة
  void _pageScrollListen() {
    if (controller.isEndReached()) {
      final c = context.read<FetchSubCategoriesCubit>();
      if (c.hasMoreData()) {
        final id = _resolveCategoryIdForFetch();

        debugPrint(
            '[SelectNestedCategory] fetchSubCategories(): load more id=${id}');
        c.fetchSubCategories(categoryId: id);
      }
    }
  }

  /// عند النقر على عنصر داخل الـ Breadcrumb
  void _onBreadCrumbItemTap(List<CategoryModel> list, int index) {
    final int popTimes = (list.length - 1) - index;

    // إزالة العناصر بعد المؤشر
    for (int i = list.length - 1; i >= index + 1; i--) {
      list.removeAt(i);
    }
    // الرجوع بعدد الشاشات المطلوبة
    for (int i = 0; i < popTimes; i++) {
      Navigator.pop(context);
    }
    setState(() {});
  }

  // جلب الحقول المخصصة ثم الانتقال لتفاصيل إضافة الإعلان

  Future<void> _navigateAfterCustomFieldsForCategory(
      CategoryModel category) async {
    final bc = (getCloudData('breadCrumb') ?? <CategoryModel>[])..add(category);
    setCloudData("breadCrumb", bc);

    final ids = bc.map((e) => e.id!).toList();

    context
        .read<FetchCustomFieldsCubit>()
        .fetchCustomFields(categoryIds: ids.join(','));

    await Future.delayed(const Duration(milliseconds: 100));

    Navigator.pushNamed(
      context,
      Routes.addMoreDetailsScreen,
      arguments: {
        "breadCrumbItems": bc,
        "categoryIds": ids,
        "isEdit": false,
        "mainImage": null,
        "otherImage": null,
        // 👈 مهم
        "customFieldsCubit": context.read<FetchCustomFieldsCubit>(),
      },
    ).then((_) {
      bc.remove(category);
      setCloudData("breadCrumb", bc);
    });

    TouchManager.touchProcessed();
  }

  /// الضغط على فئة ضمن القائمة (قد تكون نهائية أو لها أبناء)
  void _onNestedCategoryTap(CategoryModel category) {
    if (category.children!.isEmpty && category.subcategoriesCount == 0) {
      // فئة نهائية: ننتقل مباشرة بخطوة الحقول
      if (TouchManager.canProcessTouch()) {
        _fetchCustomFieldsAndNavigate(category);
      }
    } else {
      // فئة لها أبناء: ننتقل لمستوى أعمق (شاشة جديدة)
      if (!TouchManager.canProcessTouch()) return;

      final cloudData = (getCloudData("breadCrumb") as List<CategoryModel>);
      cloudData.add(category);
      setCloudData("breadCrumb", cloudData);

      screenStack++;
      Navigator.pushNamed(
        context,
        Routes.selectNestedCategoryScreen,
        arguments: {"current": category},
      ).then((value) {
        // عند العودة من المستوى الأعمق، ننظّف آخر عنصر
        if (value == true) {
          screenStack--;
          final List<CategoryModel> bcd = getCloudData("breadCrumb");
          bcd.remove(category);
          setCloudData("breadCrumb", bcd);
        }
      });

      // حارس اللمس
      Future.delayed(const Duration(seconds: 1), TouchManager.touchProcessed);
    }
  }

  /// عند رجوع النظام (Back) نزيل آخر عنصر من الـ Breadcrumb
  Future<void> _onSystemBackDidPop(bool didPop) async {
    if (didPop) {
      final bcd = getCloudData("breadCrumb") ?? <CategoryModel>[];
      if (bcd.isNotEmpty) {
        bcd.removeLast();
        setCloudData("breadCrumb", bcd);
      }
    }
  }

  int _resolveCategoryIdForFetch() {
    if (delegateRootId != null && widget.current.id == delegateRootId) {
      return delegateRootId!;
    }

    return widget.current.id!;
  }

  CategoryModel _buildDelegateRoot(int rootId) {
    return CategoryModel(
      id: rootId,
      name: '',
      children: const [],
      subcategoriesCount: 1,
    );
  }

  /// إعادة المحاولة عند الخطأ/لا بيانات
  void _retryFetchSubCategories() {
    final id = _resolveCategoryIdForFetch();

    debugPrint('[SelectNestedCategory] retry fetchSubCategories() id=${id}');
    context.read<FetchSubCategoriesCubit>().fetchSubCategories(
          categoryId: id,
        );
  }

  // غلاف للحفاظ على التوافق مع النداءات القديمة
  Future<void> _fetchCustomFieldsAndNavigate(CategoryModel category) {
    return _navigateAfterCustomFieldsForCategory(category);
  }

  @override
  Widget build(BuildContext context) {
    // مزامنة نسخة محلية من مسار التنقل (اختياري)
    breadCrumbData = getCloudData('breadCrumb');

    // نقرأ حالة الفئات الفرعية وتمريرها للواجهة
    final fetchSubState = context.watch<FetchSubCategoriesCubit>().state;

    // BlocListener لوجات تشخيصية (لا تغيّر الواجهة)
    return BlocListener<FetchSubCategoriesCubit, FetchSubCategoriesState>(
      listener: (context, state) {
        if (state is FetchSubCategoriesInProgress) {
          debugPrint('[SelectNestedCategory] state=InProgress');
        } else if (state is FetchSubCategoriesSuccess) {
          debugPrint(
              '[SelectNestedCategory] state=Success count=${state.categories.length} isLoadingMore=${state.isLoadingMore}');
        } else if (state is FetchSubCategoriesFailure) {
          debugPrint(
              '[SelectNestedCategory] state=Failure error=${state.errorMessage}');
        }
      },
      child: SelectNestedCategoryUI(
        controller: controller,
        current: widget.current,
        breadCrumbData: breadCrumbData,
        fetchSubCategoriesState: fetchSubState,

        // تنقّل علوي
        onHomeTap: () async {
          // الرجوع إلى البداية بعدد شاشات الـ breadcrumb
          await Future.delayed(const Duration(milliseconds: 5), () {
            for (int i = 0; i < breadCrumbData.length; i++) {
              Navigator.pop(context);
            }
          });
        },
        onBreadCrumbItemTap: _onBreadCrumbItemTap,

        // أزرار/نقرات
        onTapAllCurrent: () {
          if (TouchManager.canProcessTouch()) {
            _fetchCustomFieldsAndNavigate(widget.current);
          }
        },
        onCategoryTap: _onNestedCategoryTap,

        // تحميل/محاولة/رجوع
        onLoadMoreRequested: _pageScrollListen,
        onRetryFetchSubCategories: _retryFetchSubCategories,
        onSystemBackDidPop: _onSystemBackDidPop,
      ),
    );
  }
}
