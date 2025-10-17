// lib/ui/screens/item/add_item_screen/more_details.dart
//
// AddMoreDetailsScreen (Logic-Only)
// - يمنع الجلب المزدوج ويعالج Success المسبقة.
// - يمرّر حقل اللون (color + مرادفاته) ويثبّت key=id إن غاب.
// - التخزين الموحد: CustomField.fieldsData / CustomField.files.
// - بذر قيم التعديل (prefill) بنفس المفتاح.
// - عند عدم وجود حقول “قابلة للبناء”: ننتقل مباشرةً لشاشة التفاصيل.
//

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:marib/app/routes.dart';
import 'package:marib/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:marib/utils/cloudState/cloud_state.dart';
import 'package:marib/utils/helper_utils.dart';

import 'package:marib/data/cubits/custom_field/fetch_custom_fields_cubit.dart';
import 'package:marib/data/model/custom_field/custom_field_model.dart';
import 'package:marib/data/model/item/item_model.dart';
import 'package:marib/data/model/category_model.dart';

// ✅ منظومة الحقول لديك
import 'package:marib/ui/screens/item/add_item_screen/custom_filed_structure/custom_field.dart';

import 'more_details_ui.dart';
import 'package:marib/ui/screens/widgets/dynamic_field/dynamic_field.dart';
import 'package:marib/data/constants/color_catalog.dart';




int screenStack = 0;

class AddMoreDetailsScreen extends StatefulWidget {
  final List<CategoryModel>? breadCrumbItems;
  final List<int>? categoryIds;
  final bool? isEdit;
  final File? mainImage;
  final List<File>? otherImage;
  final ItemModel? editingItem;

  const AddMoreDetailsScreen({
    super.key,
    this.breadCrumbItems,
    this.categoryIds,
    this.isEdit,
    this.mainImage,
    this.otherImage,
    this.editingItem,
  });

  static BlurredRouter route(RouteSettings settings) {
    final Map? args = settings.arguments as Map?;

    List<int>? resolvedCatIds;
    if (args?['categoryIds'] is List<int>) {
      resolvedCatIds = args?['categoryIds'] as List<int>;
    } else if (args?['categoryId'] is int) {
      resolvedCatIds = [args?['categoryId'] as int];
    }

    final ItemModel? editingItem =
        (args?['model'] as ItemModel?) ?? (args?['item'] as ItemModel?);

    final FetchCustomFieldsCubit? injected =
    args?['customFieldsCubit'] as FetchCustomFieldsCubit?;

    return BlurredRouter(
      builder: (context) {
        FetchCustomFieldsCubit? existing = injected;
        if (existing == null) {
          try {
            existing = context.read<FetchCustomFieldsCubit>();
          } catch (_) {
            existing = null;
          }
        }

        final screen = AddMoreDetailsScreen(
          breadCrumbItems: args?['breadCrumbItems'] as List<CategoryModel>?,
          categoryIds: resolvedCatIds,
          isEdit: args?['isEdit'] == true,
          mainImage: args?['mainImage'] as File?,
          otherImage: args?['otherImage'] as List<File>?,
          editingItem: editingItem,
        );

        if (existing != null) {
          return BlocProvider.value(value: existing, child: screen);
        } else {
          return BlocProvider(create: (_) => FetchCustomFieldsCubit(), child: screen);
        }
      },
    );
  }

  @override
  CloudState<AddMoreDetailsScreen> createState() =>
      _AddMoreDetailsScreenState();
}

class _AddMoreDetailsScreenState extends CloudState<AddMoreDetailsScreen> {
  final _scrollController = ScrollController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  List<CustomFieldBuilder> moreDetailDynamicFields = [];

  bool _fieldsBuiltOnce = false;
  bool _navigatedOnEmpty = false;
  String _targetIds = '';
  String _lastFetchedIds = '';

  bool _rebuildScheduled = false;

  @override
  void initState() {
    super.initState();

    _clearFieldCaches();

    if (widget.breadCrumbItems != null && widget.isEdit != true) {
      setCloudData("breadCrumb", widget.breadCrumbItems);
    }

    _prepareTargetIdsAndFetchSafely();
    _scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant AddMoreDetailsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final changedCats =
        (widget.categoryIds?.join(',') ?? '') != (oldWidget.categoryIds?.join(',') ?? '');
    final changedEdit = (widget.isEdit ?? false) != (oldWidget.isEdit ?? false);
    if (changedCats || changedEdit) {
      _fieldsBuiltOnce = false;
      _navigatedOnEmpty = false;
      moreDetailDynamicFields = [];
      _prepareTargetIdsAndFetchSafely();
      if (mounted) setState(() {});
    }
  }

  // -------------------- Helpers: IDs & Values --------------------

  String _normalizeIdsCsv(Object? source) {
    if (source == null) return '';
    if (source is int) return source.toString();
    if (source is List) {
      final ids = <String>{};
      for (final e in source) {
        final s = _normalizeIdsCsv(e);
        if (s.isNotEmpty) ids.addAll(s.split(','));
      }
      ids.removeWhere((e) => e.trim().isEmpty);
      return ids.join(',');
    }
    final s = source.toString();
    final matches = RegExp(r'\d+').allMatches(s).map((m) => m.group(0)!).toList();
    if (matches.isEmpty) return '';
    final seen = <String>{};
    final cleaned = <String>[];
    for (final id in matches) {
      if (seen.add(id)) cleaned.add(id);
    }
    return cleaned.join(',');
  }

  String _bestIdsForEdit(ItemModel item) {
    if (widget.categoryIds != null && widget.categoryIds!.isNotEmpty) {
      return _normalizeIdsCsv(widget.categoryIds);
    }
    final fromAll = _normalizeIdsCsv(item.allCategoryIds);
    if (fromAll.isNotEmpty) return fromAll;
    final single = _normalizeIdsCsv(item.categoryId) +
        (item.category?.id != null ? ',${_normalizeIdsCsv(item.category?.id)}' : '');
    return _normalizeIdsCsv(single);
  }

  String _idStr(dynamic id) => id?.toString() ?? '';

  dynamic _normalizePrevValue(dynamic v) {
    if (v is String) {
      final s = v.trim();
      if ((s.startsWith('[') && s.endsWith(']')) ||
          (s.startsWith('{') && s.endsWith('}'))) {
        try {
          return json.decode(s);
        } catch (_) {
          return v;
        }
      }
      return v;
    }
    return v;
  }

  /// تطبيع النوع لدعم مرادفات اللون
  String _normType(dynamic t) {
    final s = (t ?? '').toString().toLowerCase().trim();
    switch (s) {
      case 'colors':
      case 'colour':
      case 'color_picker':
        return 'color';
      default:
        return s;
    }
  }

  /// الأنواع المدعومة فقط
  bool _isLikelySupportedType(String t) {
    const known = <String>{
      'text', 'textarea', 'number', 'select', 'radio', 'checkbox',
      'switch', 'file', 'image', 'date', 'time',
      'color',
    };
    return known.contains(t);
  }

  // -------------------------- Fetching --------------------------

  void _prepareTargetIdsAndFetchSafely() {
    final cubit = context.read<FetchCustomFieldsCubit>();

    if (widget.isEdit == true) {
      ItemModel? item = getCloudData('edit_request') as ItemModel?;
      item ??= widget.editingItem;

      if (item != null) {
        setCloudData('edit_request', item);
        _targetIds = _bestIdsForEdit(item);
      } else {
        _targetIds = _normalizeIdsCsv(widget.categoryIds);
      }
    } else {
      _targetIds = _normalizeIdsCsv(widget.categoryIds);
    }

    if (_targetIds.isEmpty) {
      debugPrint('[AddMoreDetails] Skip fetch: targetIds empty');
      return;
    }

    final bool idsChanged = _lastFetchedIds != _targetIds;

    if (cubit.state is FetchCustomFieldInProgress && !idsChanged) {
      debugPrint('[AddMoreDetails] InProgress & ids same, skip');
      return;
    }

    if (idsChanged || cubit.state is! FetchCustomFieldSuccess) {
      _lastFetchedIds = _targetIds;
      debugPrint('[AddMoreDetails] fetchCustomFields($_targetIds)');
      cubit.fetchCustomFields(categoryIds: _targetIds);
    } else {
      debugPrint('[AddMoreDetails] Success & ids same, skip refetch');
    }
  }

  void _onScroll() {
    if (_scrollController.position.atEdge &&
        _scrollController.position.pixels != 0) {
      FocusScope.of(context).unfocus();
    }
  }

  // ---------------------------- Next ----------------------------

  void _onNextPressed() {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      HelperUtils.showSnackBarMessage(context, "أكمل الحقول المطلوبة أولًا.");
      return;
    }


    if (AbstractField.fieldsData.isNotEmpty) {
      AbstractField.fieldsData.forEach((key, value) {
        final keyStr = key.toString();
        if (!CustomField.fieldsData.containsKey(keyStr)) {
          CustomField.fieldsData[keyStr] =
          value is List ? List.from(value) : value;
        }
      });
    }

    if (AbstractField.files.isNotEmpty) {
      AbstractField.files.forEach((key, value) {
        final keyStr = key.toString();
        CustomField.files.putIfAbsent(keyStr, () => value);
      });
    }



    // ✅ استخدم CustomField (وليس AbstractField)
    final Map<String, dynamic> customFieldsData = {
      'custom_fields': json.encode(CustomField.fieldsData),
    };
    customFieldsData.addAll(CustomField.files);
    addCloudData("more_details_data", customFieldsData);

    // (اختياري للتأكد أثناء التطوير)
    // debugPrint('[CF] ${CustomField.fieldsData}');

    screenStack++;
    Navigator.pushNamed(
      context,
      Routes.addItemDetails,
      arguments: {
        "breadCrumbItems": widget.breadCrumbItems ?? getCloudData("breadCrumb"),
        "isEdit": widget.isEdit == true,
      },
    ).then((value) {
      screenStack--;
      if (value == "success") {
        screenStack = 0;
        _clearFieldCaches();
      }
    });
  }

  // -------------------- Prefill & Builders ----------------------

  void _seedFieldData(dynamic keyOrId, dynamic prevValRaw,
      {bool isColor = false}) {

    try {
      final key = _idStr(keyOrId);
      if (key.isEmpty) return;
      final prevVal = _normalizePrevValue(prevValRaw);
      if (prevVal == null) return;
      final hexRegExp = RegExp(r'^[0-9A-F]{6}$');

      if (prevVal is List) {
        if (isColor) {

          final bool hasColorMaps = prevVal.any((element) {
            if (element is Map) {
              final dynamic code = element['code'] ?? element['hex'] ?? element['value'];
              if (code is String && hexRegExp.hasMatch(ColorCatalog.sanitizeHex(code))) {
                return true;
              }
            }
            return false;
          });

          if (hasColorMaps) {
            CustomField.fieldsData[key] = prevVal;
            return;
          }

          final hexes = prevVal
              .map((e) => ColorCatalog.sanitizeHex((e ?? '').toString()))
              .where((hex) => hexRegExp.hasMatch(hex))
              .toSet()
              .toList();
          if (hexes.isEmpty) return;
          CustomField.fieldsData[key] = hexes;
        } else {
          CustomField.fieldsData[key] = List.from(prevVal);
        }

      } else {
        if (isColor) {
          if (prevVal is Map) {
            CustomField.fieldsData[key] = [prevVal];
            return;
          }

          final hex = ColorCatalog.sanitizeHex(prevVal.toString());
          if (!hexRegExp.hasMatch(hex)) return;
          CustomField.fieldsData[key] = [hex];
        } else {
          CustomField.fieldsData[key] = [prevVal];
        }


      }
    } catch (_) {}
  }

  void _buildFieldsFrom(List<CustomFieldModel> fields) {
    if (_fieldsBuiltOnce) return;

    final Map? args = ModalRoute.of(context)?.settings.arguments as Map?;
    final ItemModel? item =
        (getCloudData('edit_request') as ItemModel?) ??
            (args?['model'] as ItemModel?) ??
            (args?['item'] as ItemModel?) ??
            widget.editingItem;

    final Map<String, dynamic> prevById = <String, dynamic>{};
    if (widget.isEdit == true &&
        item != null &&
        (item.customFields?.isNotEmpty ?? false)) {
      for (final cf in item.customFields!) {
        prevById[_idStr(cf.id)] = _normalizePrevValue(cf.value);
      }
    }

    final List<CustomFieldBuilder> built = [];

    for (final field in fields) {
      final Map<String, dynamic> data = field.toMap();
      data['isEdit'] = widget.isEdit == true;

      final type = _normType(data['type']);
      data['type'] = type;

      if (!_isLikelySupportedType(type)) {
        debugPrint('[AddMoreDetails] Skip unsupported field type: $type (id=${field.id})');
        continue;
      }

      final String fid = _idStr(field.id);

      // ✅ حقل اللون: ثبّت key=id إن لم يأتِ من السيرفر
      if (type == 'color') {
        if (data['key'] == null || data['key'].toString().trim().isEmpty) {
          data['key'] = fid.isNotEmpty ? fid : 'colors';
        }
      }

      // تمرير/بذر قيم التعديل السابقة
      if (fid.isNotEmpty && prevById.containsKey(fid)) {
        final prevVal = prevById[fid];
        data['value'] = prevVal;

        final seedKey =
        (type == 'color') ? (data['key']?.toString() ?? fid) : fid;

        _seedFieldData(seedKey, prevVal, isColor: type == 'color');
      }

      final builder = CustomFieldBuilder(data)
        ..stateUpdater(_throttledParentSetState)
        ..init();

      built.add(builder);
    }

    moreDetailDynamicFields = built;
    _fieldsBuiltOnce = true;
  }

  void _throttledParentSetState([dynamic _]) {
    if (_rebuildScheduled || !mounted) return;
    _rebuildScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _rebuildScheduled = false;
      setState(() {});
    });
  }

  void _clearFieldCaches() {
    try {
      CustomField.fieldsData.clear();
      CustomField.files.clear();
      AbstractField.fieldsData.clear();
      AbstractField.files.clear();
    } catch (_) {}
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // ----------------------------- Build --------------------------

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<FetchCustomFieldsCubit, FetchCustomFieldState>(
      listenWhen: (prev, curr) => curr is FetchCustomFieldSuccess,
      buildWhen: (prev, curr) => prev.runtimeType != curr.runtimeType,
      listener: (context, state) {
        if (state is FetchCustomFieldSuccess) {
          if (state.fields.isEmpty) {
            // إعادة محاولة IDs بديلة في التعديل
            if (widget.isEdit == true) {
              final ItemModel? item =
                  (getCloudData('edit_request') as ItemModel?) ??
                      widget.editingItem;

              final fallback = _normalizeIdsCsv(
                widget.categoryIds?.isNotEmpty == true
                    ? widget.categoryIds
                    : (item?.categoryId ?? item?.category?.id),
              );

              if (fallback.isNotEmpty && fallback != _targetIds) {
                debugPrint(
                    '[AddMoreDetails] Empty fields in edit, retry with fallback IDs: $fallback');
                _targetIds = fallback;
                _lastFetchedIds = '';
                _fieldsBuiltOnce = false;
                _navigatedOnEmpty = false;
                moreDetailDynamicFields = [];
                _prepareTargetIdsAndFetchSafely();
                return;
              }
            }

            // فعليًا لا توجد حقول → انتقل للتفاصيل
            if (_fieldsBuiltOnce || _navigatedOnEmpty) return;
            _navigatedOnEmpty = true;
            if (!mounted) return;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              Navigator.pushReplacementNamed(
                context,
                Routes.addItemDetails,
                arguments: {
                  "breadCrumbItems":
                  widget.breadCrumbItems ?? getCloudData("breadCrumb"),
                  "isEdit": widget.isEdit == true,
                },
              );
            });
          } else {
            _buildFieldsFrom(state.fields);

            // لو كل الحقول غير مدعومة
            if (moreDetailDynamicFields.isEmpty) {
              if (_navigatedOnEmpty) return;
              _navigatedOnEmpty = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                Navigator.pushReplacementNamed(
                  context,
                  Routes.addItemDetails,
                  arguments: {
                    "breadCrumbItems":
                    widget.breadCrumbItems ?? getCloudData("breadCrumb"),
                    "isEdit": widget.isEdit == true,
                  },
                );
              });
              return;
            }

            if (mounted) setState(() {});
          }
        }
      },
      builder: (context, state) {
        if (state is FetchCustomFieldSuccess &&
            !_fieldsBuiltOnce &&
            state.fields.isNotEmpty) {
          _buildFieldsFrom(state.fields);
        }
        return MoreDetailsUI(
          formKey: _formKey,
          scrollController: _scrollController,
          state: state,
          fields: moreDetailDynamicFields,
          onNextPressed: _onNextPressed,
        );
      },
    );
  }
}
