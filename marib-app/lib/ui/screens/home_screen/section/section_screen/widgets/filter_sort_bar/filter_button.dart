// lib/ui/screens/home/section/Items_List/widgets/filter_sort_bar/filter_button.dart
//
// زر الفلترة + نافذة فلترة سفلية (محوّلة من FilterScreen الأصلية).
// - نفس المنطق السابق (يطبق الفلتر فعلياً كما كان).
// - عند الضغط "تطبيق" يُنشأ ItemFilterModel ويُمرر عبر onFilterChanged.
// - يعتمد FetchCustomFieldsCubit و CustomFieldBuilder كما في مشروعك.
// - يمكن تمرير categoryIds و categoryList للتهيئة كما في السابق.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marib/app/routes.dart';
import 'package:marib/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:marib/data/model/category_model.dart';
import 'package:marib/data/model/item_filter_model.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/constant.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/hive_utils.dart';
import 'package:marib/utils/responsiveSize.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:marib/utils/app_icon.dart';

import 'package:marib/data/cubits/custom_field/fetch_custom_fields_cubit.dart';


import 'package:marib/utils/api.dart';
import 'package:marib/ui/screens/home/widgets/categoryFilterScreen.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:marib/ui/screens/item/add_item_screen/custom_filed_structure/custom_field.dart';
import 'package:marib/ui/screens/widgets/dynamic_field/dynamic_field.dart';
import 'package:marib/ui/screens/settings/main_activity.dart';
import 'package:marib/ui/screens/settings/main_activity.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marib/data/cubits/category/fetch_category_cubit.dart';
import 'package:marib/data/cubits/item/fetch_item_from_category_cubit.dart';
import 'package:marib/data/model/category_model.dart';
import 'filter_memory.dart';
import 'advanced_search_button.dart';

import 'package:marib/data/cubits/category/fetch_category_cubit.dart';


// —————————————————————————————————————————————
// زر الفلترة داخل الشريط
// —————————————————————————————————————————————


class FilterButton extends StatelessWidget {
  final List<String> categoryIds;
  final Function(ItemFilterModel) onFilterChanged;

  String get _scopeKey => 'cats:' + categoryIds.join(',');

  // مبدئياً غير ضروريين، لكن نمررهم لو تحب التهيئة بنفس طريقة شاشة القديم:
  final List<CategoryModel>? categoryListInitial;
  final ItemFilterModel? currentFilter;
  final List<CategoryModel>? categoryList;

  final String? parentCategoryId; // ✅ لتحميل الفرعيات
  final Future<List<
      CategoryModel>> Function(String)? loadSubcategories; // ✅ لودر الفرعيات


  const FilterButton({
    super.key,
    required this.categoryIds,
    required this.onFilterChanged,
    this.categoryListInitial,
    this.currentFilter,
    this.categoryList,

    this.parentCategoryId, // ✅
    this.loadSubcategories, // ✅


  });




  @override
  Widget build(BuildContext context) {
    // ألوان/حدود الكبسولة حسب الثيم العام
    final bg = context.color.secondaryColor;         // الخلفية
    final fg = context.color.textDefaultColor;       // لون الأيقونة/النص
    final br = context.color.borderColor;            // لون الحدود

    return InkWell(
      onTap: () => _openFilterBottomSheet(context),
      borderRadius: BorderRadius.circular(12),
      splashColor: Theme.of(context).colorScheme.primary.withOpacity(0.14),
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: MediaQuery.of(context).size.height * 0.012,
          horizontal: MediaQuery.of(context).size.width * 0.02,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: br, width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            UiUtils.getSvg(
              AppIcons.filterByIcon,
              color: fg,
              height: 20,
              width: 20,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                "filterTitle".translate(context),
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w600, // نفس وزن الفرز
                  color: fg,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }





















  // يفتح الفلترة كـ BottomSheet (بديل عن التنقل لشاشة مستقلة)


  void _openFilterBottomSheet(BuildContext context) {
    // اجمع المصدرين (لو عندك alias باسم categoryList) أو استخدم categoryListInitial فقط
    final List<CategoryModel> initialCats =
    (categoryList ?? categoryListInitial ?? const <CategoryModel>[]);

    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (_) {
        return BlocProvider(
          create: (_) => FetchCustomFieldsCubit(),
          child: _FilterBottomSheet(
            scopeKey: _scopeKey,
            onSubmit: onFilterChanged,
            from: "itemsList",
            categoryIds: categoryIds,
            categoryListInitial: initialCats,
            // <-- استعمل المتغيّر هنا
            currentFilter: currentFilter,
            parentCategoryId: parentCategoryId,
            // إن كنت تمرّرهم
            loadSubcategories: loadSubcategories, // إن كنت تمرّرهم
          ),
        );
      },
    );
  }
}











/// —————————————————————————————————————————————
/// نافذة الفلترة (تحويل لـ FilterScreen إلى BottomSheet)
/// —————————————————————————————————————————————



class _FilterBottomSheet extends StatefulWidget {
  final Function(ItemFilterModel) onSubmit;
  final String from; // "itemsList" كما كنا نمررها

  final String scopeKey; // NEW

  final List<String> categoryIds;
  final List<CategoryModel> categoryListInitial;
  final ItemFilterModel? currentFilter;

  final String? parentCategoryId;
  final Future<List<CategoryModel>> Function(String)? loadSubcategories;


  const _FilterBottomSheet({
    required this.onSubmit,
    required this.from,
    required this.categoryIds,
    required this.categoryListInitial,
    this.currentFilter,

    required this.scopeKey,


    this.parentCategoryId,           // ✅
    this.loadSubcategories,          // ✅


  });

  @override
  State<_FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<_FilterBottomSheet> {
  // —— نفس الحالة/المتغيرات كما في FilterScreen —— //
  List<String> selectedCategories = [];

  late final TextEditingController minController;
  late final TextEditingController maxController;

  String selectedCurrency = "ريال يمني";

  dynamic city = "";
  dynamic area = "";
  dynamic areaId;
  dynamic radius;
  dynamic _state = "";
  dynamic country = "";
  dynamic latitude;
  dynamic longitude;

  List<CustomFieldBuilder> moreDetailDynamicFields = [];

  String postedOn = Constant.postedSince[0].value;

  late List<CategoryModel> categoryList;





// ---- Category Browser State ----
  final List<CategoryModel> _path = [];
  final Map<String, List<CategoryModel>> _subCache = {};
  bool _loadingCats = false;
  String? _catsError;
  List<CategoryModel> _currentCats = [];


// بحث الفئات
  String _catQuery = '';


  String? _pickedSubcatId;
  List<CategoryModel> _subcats = [];
  bool _loadingSubcats = false;
  String? _subcatsError;


  @override
  void initState() {
    super.initState();

    final fallback = FilterMemory.get(widget.scopeKey);
    final f = widget.currentFilter ?? fallback;

    minController = TextEditingController(text: f?.minPrice ?? '');
    maxController = TextEditingController(text: f?.maxPrice ?? '');
    selectedCurrency = f?.currency ?? "ريال يمني";
    postedOn = f?.postedSince ?? Constant.postedSince[0].value;

    city = f?.city ?? "";
    areaId = f?.areaId;
    radius = f?.radius;
    _state = f?.state ?? "";
    country = f?.country ?? "";
    latitude = f?.latitude;
    longitude = f?.longitude;

    categoryList = [...widget.categoryListInitial];
    _setCategories();


    if (selectedCategories.isNotEmpty) _getCustomFieldsData();
  }


  @override
  void dispose() {
    minController.dispose();
    maxController.dispose();
    super.dispose();
  }

  // ——— مساوية لـ setCategories في الأصل ———


  void _setCategories() {
    selectedCategories
      ..clear()
      ..addAll(widget.categoryIds);
    // إزالة أي تكرار احتياطيًا
    selectedCategories = selectedCategories.toSet().toList();

    categoryList = widget.categoryListInitial
        .where((c) => widget.categoryIds.contains(c.id.toString()))
        .toList();
  }


  int? get _pid {
    // نفس فكرة PcSlider: نحتاج int
    if (widget.parentCategoryId != null) {
      return int.tryParse(widget.parentCategoryId!);
    }
    // fallback بسيط إن ما توفر: جرّب أول id من scope لو كان رقمي
    if (widget.categoryIds.isNotEmpty) {
      return int.tryParse(widget.categoryIds.first);
    }
    return null;
  }


  // ——— جلب الحقول المخصّصة حسب selectedCategories ———
  void _getCustomFieldsData() {
    if (Constant.itemFilter == null) {
      AbstractField.fieldsData.clear();
    }
    if (selectedCategories.isEmpty) return; // ✅
    context.read<FetchCustomFieldsCubit>().fetchCustomFields(
      categoryIds: selectedCategories.join(','),
    );
  }


  // ——— يبني ItemFilterModel ويرسله للأب ———

  void _applyFilter() {
    final customFields = _convertToCustomFields(AbstractField.fieldsData);

    final model = ItemFilterModel(
      maxPrice: maxController.text,
      minPrice: minController.text,
      categoryId: selectedCategories.isNotEmpty ? selectedCategories.last : "",
      postedSince: postedOn,
      city: city,
      areaId: areaId,
      radius: radius,
      state: _state,
      country: country,
      longitude: longitude,
      latitude: latitude,
      currency: selectedCurrency,
      customFields: customFields,
    );

    FilterMemory.set(widget.scopeKey, model); // ✅ لكل قسم
    widget.onSubmit(model);
    Navigator.pop(context, true);
  }


  // ——— إعادة تعيين ———


  void _resetAll() {
    setState(() {
      postedOn = Constant.postedSince[0].value;
      FilterMemory.clear(widget.scopeKey);
      Constant.itemFilter = null;
      searchbody[Api.postedSince] = postedOn;

      city = "";
      areaId = null;
      radius = null;
      area = "";
      _state = "";
      country = "";
      latitude = null;
      longitude = null;

      minController.clear();
      maxController.clear();

      selectedCategories
        ..clear()
        ..addAll(widget.categoryIds);
      selectedCategories = selectedCategories.toSet().toList(); // ✅

      categoryList = widget.categoryListInitial
          .where((c) => widget.categoryIds.contains(c.id.toString()))
          .toList();

      moreDetailDynamicFields.clear();
      AbstractField.fieldsData.clear();
      AbstractField.files.clear();

      if (selectedCategories.isNotEmpty) _getCustomFieldsData();
    });
  }


  // ——— تحويل حقول الديناميك لصيغة custom_fields[ID]=VALUE ———
  Map<String, dynamic> _convertToCustomFields(
      Map<dynamic, dynamic> fieldsData) {
    return fieldsData.map((key, value) =>
        MapEntry('custom_fields[$key]', value));
    // الدالة في الريبو تتكفل بتحويل List إلى comma-separated
  }


  // ——— اختيار موقع (كما في الأصل) ———
  void _onTapChooseLocation() {
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator
        .pushNamed(
        context, Routes.nearbyLocationScreen, arguments: {"from": "filter"})
        .then((value) {
      if (value != null) {
        final Map<String, dynamic> location = value as Map<String, dynamic>;
        setState(() {
          area = location["area"] ?? "";
          city = location["city"] ?? "";
          areaId = location["area_id"] ?? null;
          radius = location["radius"] ?? null;
          country = location["country"] ?? "";
          _state = location["state"] ?? "";
          latitude = location["latitude"] ?? null;
          longitude = location["longitude"] ?? null;
        });
      }
    });
  }


  // ——— واجهات مساعدة (منسوخة/معدلة من الأصل) ———
  Widget _currencySelector(BuildContext context) {
    final currencies = ["ريال يمني", "ريال سعودي", "دولار أمريكي"];
    return InkWell(
      onTap: () async {
        final result = await showModalBottomSheet<String>(
          context: context,
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
          builder: (_) =>
              ListView.separated(
                shrinkWrap: true,
                itemCount: currencies.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (ctx, i) =>
                    ListTile(
                      title: Text(currencies[i]),
                      onTap: () => Navigator.pop(ctx, currencies[i]),
                    ),
              ),
        );
        if (result != null) setState(() => selectedCurrency = result);
      },
      child: Container(
        height: 55,
        decoration: BoxDecoration(
          color: context.color.secondaryColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: context.color.borderColor.darken(30), width: 1),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(
                selectedCurrency,
                style: TextStyle(
                    color: context.color.textDefaultColor.withOpacity(0.7)),
              ),
            ),
            UiUtils.getSvg(
                AppIcons.downArrow, color: context.color.textDefaultColor),
          ],
        ),
      ),
    );
  }


  Widget _locationWidget(BuildContext context) {
    return InkWell(
      onTap: _onTapChooseLocation,
      child: Padding(
        padding: const EdgeInsets.only(top: 10.0),
        child: Container(
          height: 55,
          decoration: BoxDecoration(
            color: context.color.secondaryColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: context.color.borderColor.darken(30), width: 1),
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.only(start: 14.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                UiUtils.getSvg(AppIcons.locationIcon,
                    color: context.color.textDefaultColor),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(start: 10.0),
                    child: [area, city, _state, country]
                        .where((e) =>
                    e != null && e
                        .toString()
                        .isNotEmpty)
                        .join(", ")
                        .toString()
                        .isNotEmpty
                        ? Text(
                      [area, city, _state, country]
                          .where((e) =>
                      e != null && e
                          .toString()
                          .isNotEmpty)
                          .join(", "),
                      overflow: TextOverflow.ellipsis,
                      softWrap: true,
                    )
                        : Text("اضغط لتحديد الموقع من الخريطة")
                        .color(context.color.textDefaultColor.withOpacity(0.5)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }




  Widget _budgetOption() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(child: _minMaxTFF("minLbl".translate(context))),
        const SizedBox(width: 10),
        Expanded(child: _minMaxTFF("maxLbl".translate(context))),
      ],
    );
  }


  Widget _minMaxTFF(String label) {
    final controller = (label == "minLbl".translate(context))
        ? minController
        : maxController;
    return Container(
      alignment: AlignmentDirectional.center,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(Radius.circular(10)),
        color: Theme
            .of(context)
            .colorScheme
            .secondaryColor,
      ),
      child: TextFormField(
        controller: controller,
        onChanged: (value) {
          final isEmpty = value
              .trim()
              .isEmpty;
          if (label == "minLbl".translate(context)) {
            if (isEmpty && searchbody.containsKey(Api.minPrice)) {
              searchbody.remove(Api.minPrice);
            } else {
              searchbody[Api.minPrice] = value;
            }
          } else {
            if (isEmpty && searchbody.containsKey(Api.maxPrice)) {
              searchbody.remove(Api.maxPrice);
            } else {
              searchbody[Api.maxPrice] = value;
            }
          }
        },
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          isDense: true,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: context.color.territoryColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: context.color.borderColor.darken(30)),
          ),
          labelStyle: TextStyle(
              color: context.color.textDefaultColor.withOpacity(0.5)),
          hintText: "00",
          label: Text(label),
          prefixText: '${Constant.currencySymbol} ',
          prefixStyle: TextStyle(color: Theme
              .of(context)
              .colorScheme
              .territoryColor),
          fillColor: Theme
              .of(context)
              .colorScheme
              .secondaryColor,
          border: const OutlineInputBorder(),
        ),
        keyboardType: TextInputType.number,
        style: TextStyle(color: Theme
            .of(context)
            .colorScheme
            .territoryColor),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      ),
    );
  }



  void _postedSinceUpdate(String value) => setState(() => postedOn = value);

  Future<void> _showPostedSinceSheet() async {
    final res = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) =>
          ListView.separated(
            shrinkWrap: true,
            itemCount: Constant.postedSince.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (ctx, i) {
              final opt = Constant.postedSince[i];
              final selected = opt.value == postedOn;
              return ListTile(
                title: Text(opt.status),
                trailing: selected
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : null,
                onTap: () => Navigator.pop(ctx, opt.value),
              );
            },
          ),
    );
    if (res != null) _postedSinceUpdate(res);
  }




  @override
  Widget build(BuildContext context) {
    final t       = Theme.of(context);
    final bg      = context.color.secondaryColor;
    final accent  = context.color.territoryColor;
    final onBg    = t.colorScheme.onSurface;
    final int parentIdForAdvanced = int.tryParse(widget.parentCategoryId ?? '') ??
        (widget.categoryIds.isNotEmpty ? int.tryParse(widget.categoryIds.first) : null) ??
        0;


    // فاصل بصري أنيق بين الأقسام
    Widget separator(String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(child: Divider(color: t.dividerColor)),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: t.colorScheme.surface.withOpacity(.6),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: t.dividerColor),
            ),
            child: Text(
              text,
              style: t.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: onBg.withOpacity(.8),
              ),
            ),
          ),
          Expanded(child: Divider(color: t.dividerColor)),
        ],
      ),
    );

    return FractionallySizedBox(
      heightFactor: 0.94,
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 12,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                height: 5, width: 56,
                decoration: BoxDecoration(
                  color: t.dividerColor.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 6),

              // رأس النافذة (عنوان + إعادة تعيين + إغلاق)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.filter_alt_rounded, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      "filterTitle".translate(context),
                      style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _resetAll,
                      icon: const Icon(Icons.restart_alt, size: 18),
                      label: Text("reset".translate(context)),
                      style: TextButton.styleFrom(
                        foregroundColor: onBg,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                      tooltip: 'إغلاق',
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: t.dividerColor),

              // الجسم قابل للتمرير
              Expanded(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      separator('الموقع'),
                      Text("ابحث في موقع ونطاق محدد")
                          .bold(weight: FontWeight.w600)
                          .color(context.color.textDefaultColor),
                      const SizedBox(height: 5),
                      _locationWidget(context),

                      separator('العملة والميزانية'),
                      Text("اختر عملة البحث")
                          .bold(weight: FontWeight.w600)
                          .color(context.color.textDefaultColor),
                      const SizedBox(height: 10),
                      _currencySelector(context),

                      const SizedBox(height: 15),
                      Text('budgetLbl'.translate(context))
                          .bold(weight: FontWeight.w600)
                          .color(context.color.textDefaultColor),
                      const SizedBox(height: 15),


                      _budgetOption(),
                      separator('النشر'),
                      Text('postedSinceLbl'.translate(context))
                          .bold(weight: FontWeight.w600)
                          .color(context.color.textDefaultColor),
                      const SizedBox(height: 5),
                      _postedSinceOption(context),


                      const SizedBox(height: 5),

                      separator('البحث المتقدم'),
                      // زر بحث متقدم (مطابق لشكلنا الجديد)
                      AdvancedSearchButton(
                        parentId: parentIdForAdvanced, // ← غير nullable الآن
                        initiallySelected: categoryList.isNotEmpty ? categoryList.first : null,
                        initialSaved: AbstractField.fieldsData.isNotEmpty,
                        onSaved: (picked) {
                          if (picked != null) {
                            setState(() {
                              selectedCategories = [picked.id.toString()];
                              categoryList = [picked];
                            });
                          }
                          try {
                            UiUtils.showSoftSnackBar(context,
                                message: 'تم حفظ التخصيص — اضغط "تطبيق" لتفعيله');
                          } catch (_) {}
                        },
                      ),

                      const SizedBox(height: 28),
                    ],
                  ),
                ),
              ),

              // أزرار سفلية ثابتة (مطابقة لستايل الشيت الآخر)
              Container(
                decoration: BoxDecoration(
                  color: bg,
                  border: Border(top: BorderSide(color: t.dividerColor)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      // إلغاء/إعادة الضبط
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _resetAll,
                          icon: const Icon(Icons.restart_alt),
                          label: Text("reset".translate(context)),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            side: BorderSide(color: t.colorScheme.outline.withOpacity(.5)),
                            foregroundColor: onBg,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // تطبيق الفلتر
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _applyFilter,
                          icon: const Icon(Icons.done_all_rounded),
                          label: Text("applyFilter".translate(context)),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            elevation: 2,
                            backgroundColor: accent,
                            foregroundColor: t.colorScheme.onPrimary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
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









  Widget _postedSinceOption(BuildContext context) {
    final t = Theme.of(context);
    final index = Constant.postedSince.indexWhere((e) => e.value == postedOn);
    final label = Constant.postedSince[index >= 0 ? index : 0].status;

    return InkWell(
      onTap: _showPostedSinceSheet, // ✅ بدل التنقل لنافذة سفلية
      child: Padding(
        padding: const EdgeInsets.only(top: 10.0),
        child: Container(
          height: 55,
          width: double.infinity,
          decoration: BoxDecoration(
            color: context.color.secondaryColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: context.color.borderColor.darken(30), width: 1),
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.only(start: 14.0, end: 14.0),
            child: Row(
              children: [
                UiUtils.getSvg(AppIcons.sinceIcon, color: context.color.textDefaultColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(label)
                      .color(context.color.textDefaultColor.withOpacity(0.85)),
                ),
                UiUtils.getSvg(AppIcons.downArrow, color: context.color.textDefaultColor),
              ],
            ),
          ),
        ),
      ),
    );
  }





}
