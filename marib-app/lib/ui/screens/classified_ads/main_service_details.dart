import 'package:flutter/material.dart';
import 'package:marib/app/routes.dart';
import 'package:marib/data/model/category_model.dart';
import 'package:marib/data/model/classified_model.dart';
import 'package:marib/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/responsiveSize.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:marib/ui/screens/widgets/shimmerLoadingContainer.dart';
import 'package:marib/utils/api.dart';
import 'package:marib/ui/screens/item/add_item_screen/more_details.dart';


class MainServiceDetails extends StatefulWidget {
  final ClassifiedModel? service; // قد تأتي كاملة
  final CategoryModel? category;  // مطلوب لزر المتابعة
  final int? id;                  // أو id فقط
  final String? titleHint;        // للـAppBar أثناء التحميل

  const MainServiceDetails({
    Key? key,
    this.service,
    this.category,
    this.id,
    this.titleHint,
  }) : super(key: key);

  static Route route(RouteSettings settings) {
    final args = settings.arguments;

    return BlurredRouter(
      builder: (context) {
        ClassifiedModel? service;
        CategoryModel? category;
        int? id;
        String? titleHint;

        if (args is Map) {
          final map = Map<String, dynamic>.from(args);

          // قد يمرّر service كـ Object أو Map
          final s = map['service'];
          if (s is ClassifiedModel) {
            service = s;
          } else if (s is Map) {
            service = ClassifiedModel.fromJson(Map<String, dynamic>.from(s));
          }

          // category كـ Object أو Map
          final c = map['category'];
          if (c is CategoryModel) {
            category = c;
          } else if (c is Map) {
            final m = Map<String, dynamic>.from(c);
            int _toInt(dynamic v) => v is int ? v : int.tryParse('$v') ?? 0;
            category = CategoryModel(
              id: _toInt(m['id'] ?? m['category_id']),
              name: (m['name'] ?? m['category_name'])?.toString(),
            );
          }

          // id + title (لو تم تمريرهم فقط)
          int? _asInt(dynamic v) => v == null ? null : (v is int ? v : int.tryParse('$v'));
          id = _asInt(map['id']);
          titleHint = map['title']?.toString();
        }

        return MainServiceDetails(
          service: service,
          category: category,
          id: id ?? service?.id,
          titleHint: titleHint ?? service?.title,
        );
      },
    );
  }

  @override
  State<MainServiceDetails> createState() => _MainServiceDetailsState();
}

class _MainServiceDetailsState extends State<MainServiceDetails> {
  ClassifiedModel? _data;
  bool _loading = true;
  bool _error = false;
  String? _errorMsg;

  CategoryModel? get _category => widget.category;



  bool _hasSchemaData(dynamic value) {
    if (value == null) return false;
    if (value is String) {
      final s = value.trim().toLowerCase();
      return s.isNotEmpty && s != '[]' && s != '{}' && s != 'null';
    }
    if (value is List) return value.isNotEmpty;
    if (value is Map) return value.isNotEmpty;
    return true;
  }

  dynamic _findSchemaDeep(dynamic node) {
    const keys = [
      'serviceFieldsSchema',
      'service_fields_schema',
      'service_fields',
      'custom_fields_schema',
      'custom_fields',
      'fields',
      'schema',
      'data',
    ];

    if (node is Map) {
      for (final k in keys) {
        final v = node[k];
        if (_hasSchemaData(v)) return v;
      }
      for (final v in node.values) {
        final found = _findSchemaDeep(v);
        if (_hasSchemaData(found)) return found;
      }
    } else if (node is List) {
      for (final e in node) {
        final found = _findSchemaDeep(e);
        if (_hasSchemaData(found)) return found;
      }
    }
    return null;
  }

  dynamic _extractServiceSchema(ClassifiedModel service) {
    final direct = service.serviceFieldsSchema;
    if (_hasSchemaData(direct)) return direct;
    try {
      final json = service.toJson();
      final found = _findSchemaDeep(json);
      if (_hasSchemaData(found)) return found;
    } catch (_) {}
    return null;
  }




  @override
  void initState() {
    super.initState();
    // لو جتنا خدمة كاملة وفيها وصف، نعرضها مباشرة
    final s = widget.service;
    if (s != null && (s.description?.isNotEmpty ?? false)) {
      _data = s;
      _loading = false;
      _error = false;
      return;
    }
    // غير ذلك: نجلب من السيرفر باستخدام id
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetch());
  }

  Future<void> _fetch() async {
    final id = widget.id ?? widget.service?.id;
    if (id == null || id == 0) {
      setState(() {
        _loading = false;
        _error = true;
        _errorMsg = 'لا يوجد معرّف صالح لجلب الصفحة الرئيسية لهذه الخدمة.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = false;
      _errorMsg = null;
    });

    try {
      final fresh = await _fetchServiceDetails(id);
      if (!mounted) return;
      if (fresh == null) {
        setState(() {
          _loading = false;
          _error = true;
          _errorMsg = 'تعذّر جلب تفاصيل الصفحة من الخادم.';
        });
        return;
      }
      setState(() {
        _data = fresh;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = true;
        _errorMsg = e.toString();
      });
    }
  }

// جلب تفاصيل "الخدمة الرئيسية" من get-services بالـ id (مع محاولات مرنة)
  Future<ClassifiedModel?> _fetchServiceDetails(int id) async {
    // إن كانت Api.id / Api.itemId ليست ثوابت compile-time فاستخدم النصوص مباشرة
    final List<String> attempts = <String>['id', 'item_id'];
    // لو كانت ثوابت const يمكنك: final attempts = <String>[Api.id, Api.itemId];

    for (final String key in attempts) {
      try {
        final resp = await Api.get(
          url: Api.getServicesApi,
          queryParameters: <String, dynamic>{
            key: id,
            'limit': 1,
          },
        );
        final m = _extractById(resp, id);
        if (m != null) return ClassifiedModel.fromJson(m);
      } on ApiHttpException catch (e) {
        if (e.statusCode == 404) continue;
        rethrow;
      }
    }
    return null;
  }


  Map<String, dynamic>? _extractById(Map<String, dynamic>? resp, int wantedId) {
    if (resp == null) return null;

    Map<String, dynamic>? asMap(dynamic v) =>
        (v is Map) ? v.cast<String, dynamic>() : null;

    int? _readId(dynamic v) {
      if (v is Map) {
        final idAny = v['id'] ?? v[Api.id] ?? v['item_id'] ?? v[Api.itemId] ?? v['items_id'] ?? v[Api.itemsId];
        if (idAny is int) return idAny;
        if (idAny is String) return int.tryParse(idAny);
      }
      return null;
    }

    bool _match(dynamic v) => _readId(v) == wantedId;

    dynamic bucket = resp[Api.data] ?? resp['data'] ?? resp['item'] ?? resp[Api.item] ?? resp['result'] ?? resp;

    // لو Map مباشر
    final dm = asMap(bucket);
    if (dm != null && _match(dm)) return dm;

    // داخل مفاتيح شائعة
    if (bucket is Map) {
      for (final k in [Api.data, 'data', Api.item, 'item', 'payload', 'record']) {
        final v = bucket[k];
        final m = asMap(v);
        if (m != null && _match(m)) return m;
        if (v is List) {
          final hit = v.cast<dynamic>().firstWhere((e) => _match(e), orElse: () => null);
          if (hit is Map) return hit.cast<String, dynamic>();
        }
      }
    }

    // لو List مباشرة
    if (bucket is List) {
      final hit = bucket.cast<dynamic>().firstWhere((e) => _match(e), orElse: () => null);
      if (hit is Map) return hit.cast<String, dynamic>();
    }

    return null;
  }

  String stripHtmlTags(String htmlString) {
    final exp = RegExp(r"<[^>]*>", multiLine: true, caseSensitive: true);
    return htmlString.replaceAll(exp, '');
  }

  @override
  Widget build(BuildContext context) {
    final titleForBar = _loading
        ? (widget.titleHint ?? widget.service?.title ?? '')
        : (_data?.title ?? '');

    return Scaffold(
      backgroundColor: context.color.primaryColor,
      appBar: AppBar(
        backgroundColor: context.color.primaryColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () {
            Navigator.of(context).maybePop(); // رجوع سريع
          },
        ),
        title: Text(
          titleForBar,
          style: TextStyle(color: context.color.textColorDark),
        ),
      ),

      body: Padding(
        padding: const EdgeInsets.all(5.0),
        child: _loading
            ? _buildShimmer(context)
            : _error
            ? _buildError(context)
            : _buildContent(context),
      ),

      // زر ثابت بأسفل الصفحة: شيمر أثناء التحميل، وبعدها زر (ومع الخطأ يكون Disabled)
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: _loading
              ? ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: const SizedBox(
              height: 54,
              child: CustomShimmer(
                width: double.infinity,
                height: double.infinity,
              ),
            ),
          )
              : UiUtils.buildButton(
            context,
            onPressed: () {
              if (_error) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تعذر تحميل الخدمة')),
                );
                return;
              }
              final service = _data ?? widget.service;
              if (service == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('لا توجد خدمة متاحة للمتابعة')),
                );
                return;
              }

              final serviceId = service.id ?? widget.id;
              if (serviceId == null || serviceId == 0) {

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('لا يوجد معرّف صالح لبدء إضافة التفاصيل')),
                );
                return;
              }


              final serviceTitle = (service.title ?? widget.titleHint)?.trim();
              final price = service.price;
              final currency = service.currency?.trim();

              final args = <String, dynamic>{
                'serviceId': serviceId,
                if (serviceTitle?.isNotEmpty ?? false) 'serviceTitle': serviceTitle,
                if (price != null) 'amount': price,
                if (currency?.isNotEmpty ?? false) 'currency': currency,
              };

              final schema = _extractServiceSchema(service);
              if (_hasSchemaData(schema)) {
                args['service_fields_schema'] = schema;
              }

              final category = _category;
              if (category != null) {
                args['categoryId'] = category.id;
                args['breadCrumbItems'] = [category];
              }

              Navigator.pushNamed(
                context,

                Routes.serviceAddMoreDetails,
                arguments: args,

              );
            },
            buttonTitle: "createServiceContinue".translate(context),
            radius: 10,
            height: 54,
            disabledColor: const Color.fromARGB(255, 104, 102, 106),
          ),
        ),
      ),

    );
  }







  Widget _buildShimmer(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(5.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12), // كان 10
            child: SizedBox(
              width: double.infinity,
              child: AspectRatio(
                aspectRatio: 395 / 150, // ✅ نفس السلايدر
                child: const CustomShimmer(
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
            ),
          ),

          SizedBox(height: 15.rh(context)),
          Container(width: 120, height: 10, color: context.color.secondaryColor),
          const SizedBox(height: 12),
          Container(width: 220, height: 16, color: context.color.secondaryColor),
          const SizedBox(height: 14),
          for (int i = 0; i < 6; i++)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              width: double.infinity,
              height: 12,
              color: context.color.secondaryColor,
            ),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _errorMsg?.isNotEmpty == true
                  ? 'حدث خطأ أثناء جلب الصفحة:\n${_errorMsg!}'
                  : 'حدث خطأ أثناء جلب الصفحة',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.color.textColorDark),
            ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _fetch, child: const Text('إعادة المحاولة')),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final service = _data ?? widget.service!;
    final detailImage = service.image?.trim();
    final detailIcon = service.icon?.trim();
    final hasDetailImage = detailImage?.isNotEmpty == true;
    final hasIconImage = detailIcon?.isNotEmpty == true;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(5.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasDetailImage)
              ClipRRect(
                clipBehavior: Clip.antiAlias,
                borderRadius: BorderRadius.circular(12), // كان 10
                child: SizedBox(
                  width: double.infinity,
                  child: AspectRatio(
                    aspectRatio: 395 / 150, // ✅ نفس مقاس السلايدر
                    child: UiUtils.getImage(
                      detailImage!,
                      fit: BoxFit.cover, // ❗ نفس منطقك الأصلي
                    ),
                  ),
                ),
              ),
            if (!hasDetailImage && hasIconImage)

              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12), // كان 10
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: 395 / 150, // ✅ نفس مقاس السلايدر
                    child: UiUtils.getImage(
                      detailIcon!,
                      fit: BoxFit.fill, // ❗ نفس منطقك الأصلي
                    ),
                  ),
                ),

              ),
            SizedBox(height: 15.rh(context)),
            if (service.createdAt != null)
              Text(service.createdAt.toString().formatDate())
                  .size(context.font.smaller)
                  .color(context.color.textColorDark.withOpacity(0.5)),
            const SizedBox(height: 12),
            Text((service.title ?? "").firstUpperCase())
                .size(context.font.large)
                .color(context.color.textColorDark),
            const SizedBox(height: 14),
            if ((service.description ?? '').isNotEmpty)
              HtmlWidget(service.description!),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

}
