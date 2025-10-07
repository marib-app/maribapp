// زر بحث متقدم

// lib/ui/screens/home/section/Items_List/widgets/filter_sort_bar/advanced_search_button.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marib/data/cubits/category/fetch_category_cubit.dart';
import 'package:marib/data/cubits/custom_field/fetch_custom_fields_cubit.dart';
import 'package:marib/data/model/category_model.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:marib/utils/app_icon.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/constant.dart';
import 'package:marib/ui/screens/item/add_item_screen/custom_filed_structure/custom_field.dart';
import 'package:marib/ui/screens/widgets/dynamic_field/dynamic_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:marib/utils/extensions/extensions.dart';




class AdvancedSearchButton extends StatefulWidget {
  final int parentId;                         // ← إلزامي وغير nullable
  final CategoryModel? initiallySelected;
  final ValueChanged<CategoryModel?> onSaved;
  final bool initialSaved;                    // إظهار "محفوظ" مبدئيًا (إن وُجد تخصيص سابق)

  const AdvancedSearchButton({
    Key? key,
    required this.parentId,                   // ← required
    this.initiallySelected,
    required this.onSaved,
    this.initialSaved = false,
  }) : super(key: key);

  @override
  State<AdvancedSearchButton> createState() => _AdvancedSearchButtonState();
}

class _AdvancedSearchButtonState extends State<AdvancedSearchButton> {
  bool _hasSaved = false;

  @override
  void initState() {
    super.initState();
    _hasSaved = widget.initialSaved;
  }

  void _softSnack(BuildContext ctx, String msg) {
    try {
      UiUtils.showSoftSnackBar(ctx, message: msg);
    } catch (_) {
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t        = Theme.of(context);
    final accent   = context.color.territoryColor;     // لون مطابق للثيم
    final isSaved  = _hasSaved;
    final label    = isSaved ? 'بحث متقدم • محفوظ' : 'بحث متقدم';
    final icon     = isSaved
        ? const Icon(Icons.check_circle_rounded, color: Colors.green) // ✅ أخضر عند الحفظ
        : Icon(Icons.tune_rounded, color: t.colorScheme.onPrimary);

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: icon,
        label: Text(label),
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: accent,
          foregroundColor: t.colorScheme.onPrimary,
          minimumSize: const Size.fromHeight(46),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: () {
          // نعيد استخدام نفس الـ cubits الموجودة
          final cfields = context.read<FetchCustomFieldsCubit>();
          final cats    = context.read<FetchCategoryCubit>();

          showModalBottomSheet(
            context: context,
            useSafeArea: true,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => MultiBlocProvider(
              providers: [
                BlocProvider.value(value: cats),
                BlocProvider.value(value: cfields),
              ],
              // IMPORTANT: مرر parentId غير nullable
              child: _AdvancedSearchSheet(parentId: widget.parentId),
            ),
          ).then((val) {
            if (val is CategoryModel? Function()) {
              final selected = val();
              widget.onSaved(selected);
              if (mounted) {
                setState(() => _hasSaved = true);
                _softSnack(context, 'تم حفظ التخصيص');
              }
            }
          });
        },
      ),
    );
  }
}







class _AdvancedSearchSheet extends StatefulWidget {
  final int parentId; // إلزامي
  const _AdvancedSearchSheet({Key? key, required this.parentId}) : super(key: key);

  @override
  State<_AdvancedSearchSheet> createState() => _AdvancedSearchSheetState();
}

class _AdvancedSearchSheetState extends State<_AdvancedSearchSheet> {
  // تصفّح هرمي للفئات
  final List<CategoryModel> _path = [];
  List<CategoryModel> _currentCats = [];
  CategoryModel? _treeRoot;          // جذر القسم المحدّد
  CategoryModel? _pickedLeaf;        // الورقة المختارة

  // حالة التحميل والبحث
  bool _loadingCats = false;
  String? _catsError;
  String _catQuery = '';

  // حقول مخصّصة
  List<CustomFieldBuilder> _moreDetailDynamicFields = [];

  bool get canSave => _pickedLeaf != null || AbstractField.fieldsData.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _ensureCategoriesLoaded();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initTree());
  }

  // يتأكد أن الكاتيجوريز محمّلة
  void _ensureCategoriesLoaded() {
    final cubit = context.read<FetchCategoryCubit>();
    if (cubit.state is! FetchCategorySuccess) cubit.fetchCategories();
  }

  // يهيّئ الشجرة بحيث تبدأ من parentId فقط (بدون عرض باقي الأقسام)
  void _initTree() {
    final s = context.read<FetchCategoryCubit>().state;
    if (s is! FetchCategorySuccess) {
      // انتظر أول نجاح ثم أعد التهيئة
      final cubit = context.read<FetchCategoryCubit>();
      cubit.stream.firstWhere((st) => st is FetchCategorySuccess).then((_) {
        if (mounted) _initTree();
      });
      return;
    }

    _treeRoot = _findInTree(s.categories, widget.parentId);

    if (_treeRoot == null) {
      // لا نعرض كل الأقسام إن لم نجد الجذر
      setState(() => _currentCats = const []);
      return;
    }

    _path
      ..clear()
      ..add(_treeRoot!);

    setState(() => _currentCats = _treeRoot!.children ?? const []);
  }

  // ابحث عن عقدة داخل الشجرة
  CategoryModel? _findInTree(List<CategoryModel> nodes, int id) {
    for (final n in nodes) {
      if (_safeId(n) == id) return n;
      final child = _findInTree(n.children ?? const [], id);
      if (child != null) return child;
    }
    return null;
  }

  // احصل على أبناء عقدة من الكيوبت (ضمن الجذر المحدّد فقط)
  List<CategoryModel> _childrenFromCubit(int parentId) {
    final s = context.read<FetchCategoryCubit>().state;
    if (s is! FetchCategorySuccess) return [];

    // لو في جذر محدّد نبحث داخله فقط؛ وإلا لا شيء
    final CategoryModel rootWrapper =
        _treeRoot ?? CategoryModel(children: const []);
    final parent = _findInTree(rootWrapper.children ?? const [], parentId);
    return parent?.children ?? const [];
  }

  // تحميل أبناء رقمياً (محليًا من الحالة)
  Future<void> _loadChildrenInt(int parentId) async {
    setState(() {
      _loadingCats = true;
      _catsError = null;
    });
    try {
      final kids = _childrenFromCubit(parentId);
      setState(() => _currentCats = kids);
    } catch (e) {
      setState(() => _catsError = e.toString());
    } finally {
      if (mounted) setState(() => _loadingCats = false);
    }
  }

  // آمن لاستخراج id كـ int
  int _safeId(CategoryModel n) {
    final v = n.id;
    if (v is int) return v;
    final s = v?.toString();
    return int.tryParse(s ?? '') ?? -1;
  }

  // النزول لمستوى أدنى
  Future<void> _goDeeper(CategoryModel node) async {
    final pid = _safeId(node);
    if (pid <= 0) return;
    _path.add(node);
    _catQuery = '';
    await _loadChildrenInt(pid);
  }

  // الصعود لمستوى معيّن (أو إلى الجذر -1)
  Future<void> _goToDepth(int depthIndexInclusive) async {
    while (_path.length > depthIndexInclusive + 1) {
      _path.removeLast();
    }
    _catQuery = '';

    if (_path.isEmpty) {
      // العودة لبداية الشجرة الخاصة بالقسم فقط
      if (_treeRoot != null) {
        _path.add(_treeRoot!);
        setState(() => _currentCats = _treeRoot!.children ?? const []);
      } else {
        setState(() => _currentCats = const []);
      }
    } else {
      final pid = _safeId(_path.last);
      if (pid > 0) await _loadChildrenInt(pid);
    }
    setState(() {});
  }

  // اختيار ورقة أو الغوص لأبناءها
  Future<void> _selectOrDive(CategoryModel node) async {
    final pid = _safeId(node);
    if (pid <= 0) return;

    final kids = _childrenFromCubit(pid);
    if (kids.isEmpty) {
      // Leaf
      setState(() {
        _pickedLeaf = node;
        _catQuery = '';
      });

      // صفّر القديم
      AbstractField.fieldsData.clear();
      AbstractField.files.clear();
      _moreDetailDynamicFields.clear();

      // حمّل الحقول الخاصة
      try {
        UiUtils.showSoftSnackBar(context, message: 'تم اختيار: ${node.name ?? ''}');
      } catch (_) {}
      context.read<FetchCustomFieldsCubit>().fetchCustomFields(
        categoryIds: pid.toString(),
      );
    } else {
      await _goDeeper(node);
    }
  }

  // واجهة معرض الفئات + البحث + Breadcrumbs
  Widget _categoryBrowser(BuildContext context) {
    final list = _currentCats.where((c) {
      if (_catQuery.isEmpty) return true;
      return (c.name ?? '').toLowerCase().contains(_catQuery.toLowerCase());
    }).toList();

    final t = Theme.of(context);
    final double boxH =
    ((MediaQuery.of(context).size.height) * 0.32).clamp(180.0, 360.0) as double;

    // breadcrumbs
    final crumbs = <Widget>[
      InkWell(
        onTap: () async {
          if (_treeRoot != null) {
            _path
              ..clear()
              ..add(_treeRoot!);
            setState(() => _currentCats = _treeRoot!.children ?? const []);
          } else {
            await _goToDepth(-1);
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 6),
          child: Text(_treeRoot?.name ?? 'جميع الفئات')
              .color(context.color.territoryColor),
        ),
      ),
      for (int i = 0; i < _path.length; i++) ...[
        const Icon(Icons.chevron_right, size: 18),
        InkWell(
          onTap: () async => _goToDepth(i),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 6),
            child: Text(_path[i].name ?? '-')
                .color(context.color.territoryColor),
          ),
        ),
      ],
    ];

    Widget body;
    if (_loadingCats) {
      body = const Padding(
        padding: EdgeInsets.symmetric(vertical: 12.0),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (_catsError != null) {
      body = Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Text(_catsError!, textAlign: TextAlign.center)
            .color(t.colorScheme.error),
      );
    } else if (list.isEmpty) {
      body = Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Text('لا توجد فئات مطابقة')
            .color(context.color.textDefaultColor.withOpacity(0.6)),
      );
    } else {
      body = SizedBox(
        height: boxH,
        child: GridView.builder(
          padding: const EdgeInsets.only(top: 4),
          physics: const ClampingScrollPhysics(),
          itemCount: list.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisExtent: 92,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemBuilder: (_, i) {
            final c = list[i];
            final isPicked = _pickedLeaf?.id == c.id;
            return InkWell(
              onTap: () => _selectOrDive(c),
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: context.color.secondaryColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isPicked
                            ? context.color.territoryColor
                            : context.color.borderColor.darken(30),
                        width: isPicked ? 2 : 1,
                      ),
                    ),
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (c.url != null)
                          UiUtils.getImage(
                            c.url!,
                            height: 28,
                            width: 28,
                            fit: BoxFit.contain,
                          )
                        else
                          UiUtils.getSvg(
                            AppIcons.categoryIcon,
                            color: context.color.textDefaultColor,
                          ),
                        const SizedBox(height: 8),
                        Text(
                          c.name ?? '-',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  if (isPicked)
                    PositionedDirectional(
                      top: 6,
                      end: 6,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        padding: const EdgeInsets.all(3),
                        child: const Icon(Icons.check, size: 14, color: Colors.white),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('اختر الفئة')
            .bold(weight: FontWeight.w600)
            .color(context.color.textDefaultColor),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: crumbs),
        ),
        const SizedBox(height: 8),
        TextField(
          onChanged: (v) => setState(() => _catQuery = v.trim()),
          decoration: InputDecoration(
            hintText: 'ابحث داخل الفئات...',
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            prefixIcon: const Icon(Icons.search, size: 20),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(height: 8),
        body,
      ],
    );
  }

  // بناء الحقول الخاصة بناءً على الكيوبت
  Widget _customFields() {
    return BlocConsumer<FetchCustomFieldsCubit, FetchCustomFieldState>(
      listener: (context, state) {
        if (state is FetchCustomFieldSuccess) {
          final fetched = context.read<FetchCustomFieldsCubit>().getFields();
          _moreDetailDynamicFields = fetched
              .where((f) =>
          f.type != "fileinput" && f.type != "textbox" && f.type != "number")
              .map((f) {
            final data = f.toMap();
            if (Constant.itemFilter?.customFields != null) {
              final k = 'custom_fields[${data['id']}]';
              if (Constant.itemFilter!.customFields!.containsKey(k)) {
                data['value'] = Constant.itemFilter!.customFields![k];
                data['isEdit'] = true;
              }
            }
            final b = CustomFieldBuilder(data)..stateUpdater(setState);
            b.init();
            return b;
          }).toList();
          setState(() {});
        }
      },
      builder: (context, state) {
        if (_moreDetailDynamicFields.isEmpty) {
          if (state is FetchCustomFieldInProgress) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (state is! FetchCustomFieldSuccess) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('تعذّر تحميل الحقول المخصّصة'),
            );
          }
        }

        if (_moreDetailDynamicFields.isEmpty) return const SizedBox();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            Text('حقول هذه الفئة')
                .bold(weight: FontWeight.w600)
                .color(context.color.textDefaultColor),
            const SizedBox(height: 8),
            ..._moreDetailDynamicFields.map(
                  (f) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 9.0),
                child: f.build(context),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final bg = context.color.secondaryColor;
    final onBg = t.colorScheme.onSurface;
    final accent = context.color.territoryColor;

    // فاصل بصري أنيق
    Widget separator(String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(child: Divider(color: t.dividerColor)),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                height: 5,
                width: 56,
                decoration: BoxDecoration(
                  color: t.dividerColor.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 6),

              // رأس الشيت
              Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.tune_rounded, size: 20, color: onBg),
                    const SizedBox(width: 8),
                    Text('بحث متقدم',
                        style: t.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    const Spacer(),
                    IconButton(
                      tooltip: 'إغلاق',
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close_rounded, color: onBg),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: t.dividerColor),

              // الجسم
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // مساعدة
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: t.colorScheme.surface.withOpacity(.5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: t.dividerColor),
                        ),
                        child: Text(
                          'باختيار فئة محددة ستظهر لك الحقول الخاصة بها (إن وُجدت) في الأسفل لتخصيص بحثك بدقة.',
                          style: t.textTheme.bodyMedium
                              ?.copyWith(color: onBg.withOpacity(.85)),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // الفئات + البحث
                      _categoryBrowser(context),

                      // فاصل بصري
                      separator('تفاصيل الفئة'),

                      // الحقول الخاصة
                      _customFields(),
                    ],
                  ),
                ),
              ),

              // أزرار سفلية
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
                      // إلغاء
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.close_rounded),
                          label: const Text('إلغاء'),
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: BorderSide(
                              color: t.colorScheme.outline.withOpacity(.5),
                            ),
                            foregroundColor: onBg,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // حفظ التخصيص
                      Expanded(
                        child: ElevatedButton(
                          onPressed: canSave
                              ? () => Navigator.pop(context, () => _pickedLeaf)
                              : null,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            elevation: canSave ? 2 : 0,
                            backgroundColor: canSave
                                ? accent
                                : t.disabledColor.withOpacity(.12),
                            foregroundColor:
                            canSave ? Colors.white : t.disabledColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('حفظ التخصيص'),
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
}

