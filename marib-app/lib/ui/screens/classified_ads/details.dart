// lib/ui/screens/classified_ads/details.dart
// -----------------------------------------------------------------------------
// ✅ تعديلات خطوة (1):
// - _computeAction: اكتشاف الحقول المخصّصة من has_custom_fields أو من وجود service_fields_schema
//   (نص/مصفوفة/خريطة) + اعتبار الدفع إذا is_paid=true أو price>0.
// - _openPayment: تمرير amount + currency + note إلى صفحة الدفع.
// - الإبقاء على AppHtml (موجود في details_ui.dart) وعدم تغيير مساراتك.
// -----------------------------------------------------------------------------

import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Clipboard إن احتجته
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';
import 'package:marib/data/repositories/my_services_repository.dart';

import 'package:marib/app/routes.dart';
import 'package:marib/data/cubits/chat/get_buyer_chat_users_cubit.dart';
import 'package:marib/data/cubits/chat/make_an_offer_item_cubit.dart';
import 'package:marib/data/cubits/chat/send_message.dart';
import 'package:marib/data/cubits/chat/load_chat_messages.dart';
import 'package:marib/data/cubits/chat/delete_message_cubit.dart';

import 'package:marib/data/model/classified_model.dart' show ClassifiedModel, ClassifiedSummary;
import 'package:marib/data/model/chat/chated_user_model.dart';

import 'package:marib/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:marib/ui/screens/chat/chat_screen.dart';

import 'package:marib/utils/api.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:marib/utils/hive_utils.dart';

import 'service_rating_page.dart' show ServiceRatingPage;
import 'widgets/report_service.dart';
import 'details_ui.dart';
import 'package:marib/utils/notification/notification_service.dart';

class ClassifiedDetails extends StatefulWidget {
  final ClassifiedModel? classified; // قد يمرّر من شاشة أخرى (كامل)
  final int? id;                     // أو id فقط
  final String? initialTitle;        // عنوان مبدئي أثناء التحميل

  const ClassifiedDetails({
    super.key,
    this.classified,
    this.id,
    this.initialTitle,
  });





  // دالة route مرنة تُستدعى من routes.dart: ClassifiedDetails.route(routeSettings)
  // - arguments: int / String(id) / ClassifiedSummary / ClassifiedModel / Map {id|item_id|model|title}

  static Route route(RouteSettings settings) {
    final dynamic args = settings.arguments;
    ClassifiedModel? model;
    int? id;
    String? initialTitle;

    int? _coerceId(dynamic raw) {
      if (raw == null) return null;
      if (raw is int) return raw;
      if (raw is String) return int.tryParse(raw);
      if (raw is ClassifiedModel) return raw.id;
      if (raw is ClassifiedSummary) return raw.id;
      if (raw is Map) {
        final m = raw as Map;
        final d = m['id'] ?? m['item_id'];
        if (d is int) return d;
        if (d is String) return int.tryParse(d);
      }
      return null;
    }

    if (args is ClassifiedModel) {
      model = args;
      id = model.id;
      initialTitle = model.title;
    } else if (args is ClassifiedSummary) {
      id = args.id;
      initialTitle = args.title;
    } else if (args is Map) {
      final Map map = args;
      final dynamic rawModel = map['model'];
      if (rawModel is ClassifiedModel) {
        model = rawModel;
        initialTitle = rawModel.title;
      } else if (rawModel is ClassifiedSummary) {
        id = rawModel.id;
        initialTitle = rawModel.title;
      } else if (rawModel is Map<String, dynamic>) {
        model = ClassifiedModel.fromJson(rawModel);
        initialTitle = model?.title;
      }
      id = _coerceId(map['id'] ?? map['item_id']) ?? id ?? model?.id;
      initialTitle = (map['title'] as String?) ?? initialTitle;
    } else {
      id = _coerceId(args);
    }

    return BlurredRouter(
      builder: (_) => ClassifiedDetails(
        classified: model,
        id: id,
        initialTitle: initialTitle,
      ),
    );
  }

  @override
  State<ClassifiedDetails> createState() => _ClassifiedDetailsState();
}


class _ApiAttempt {
  final Future<Map<String, dynamic>> Function() run;
  final bool requireServiceMarkers;

  const _ApiAttempt({
    required this.run,
    required this.requireServiceMarkers,
  });
}


class _ClassifiedDetailsState extends State<ClassifiedDetails> {
  // --------- State ----------
  ClassifiedModel? _data; // بيانات نهائية بعد الجلب
  bool _loading = true;   // شيمر حتى يكتمل الجلب
  bool _error = false;
  String? _errorMsg;
  bool _isProcessing = false; // لمنع تكرار النقر على زر الاستمرار
  bool _fabVisible = true;    // لإظهار/إخفاء زر المشاركة العائم
  bool _isReporting = false;
  final MyServicesRepository _ownerRepository = MyServicesRepository();
  bool _statusUpdating = false;
  bool _expiryUpdating = false;
  bool? _ownerStatusOverride;
  DateTime? _ownerExpiryOverride;
  String? get _initialTitle => widget.initialTitle ?? widget.classified?.title;




  int? _extractServiceId() {
    final int? direct = _data?.id;
    if (direct != null && direct > 0) return direct;

    int? parse(dynamic value) {
      if (value == null) return null;
      if (value is int) return value > 0 ? value : null;
      if (value is num) {
        final int intValue = value.toInt();
        return intValue > 0 ? intValue : null;
      }
      if (value is String) {
        final parsed = int.tryParse(value.trim());
        if (parsed != null && parsed > 0) return parsed;
      }
      return null;
    }

    final Map<String, dynamic>? json = _data?.toJson();
    if (json == null) return null;

    for (final key in const [
      'service_id',
      'serviceId',
      'id',
      'item_id',
      'items_id',
    ]) {
      if (!json.containsKey(key)) continue;
      final parsed = parse(json[key]);
      if (parsed != null) return parsed;
    }

    return null;
  }



  // --------- Regex للمساعدة ----------
  static final RegExp _htmlTagRe = RegExp(r'<[^>]+>');
  static final RegExp _telRe = RegExp(r'tel:\s*([0-9+]+)', caseSensitive: false);
  static final RegExp _waRe  = RegExp(r'(?:https?:)?\/\/wa\.me\/([0-9]+)', caseSensitive: false);
  static final RegExp _ratingRe = RegExp(r'([4-5](?:\.\d)?)\s*\((\d+)\s*تقييم', caseSensitive: false);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchDetails();
    });
  }




  // ===============================
  // جلب تفاصيل الخدمة
  // ===============================
  Future<void> _fetchDetails() async {
    final int? id = widget.id ?? widget.classified?.id;

    if (id == null) {
      setState(() {
        _loading = false;
        _error = true;
        _errorMsg = 'لا يوجد معرّف صالح لجلب التفاصيل.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = false;
      _errorMsg = null;
    });

    try {
      final fresh = await _fetchDetailsFromApi(id);
      if (!mounted) return;

      if (fresh == null) {
        setState(() {
          _loading = false;
          _error = true;
          _errorMsg = 'تعذّر جلب التفاصيل من الخادم.';
        });
        return;
      }

      setState(() {
        _data = fresh;
        _loading = false;
        _error = false;
        _errorMsg = null;
        _ownerStatusOverride = null;
        _ownerExpiryOverride = null;
        _statusUpdating = false;
        _expiryUpdating = false;
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











  bool _hasSchemaData(dynamic v) {
    if (v == null) return false;
    if (v is String) {
      final s = v.trim().toLowerCase();
      return s.isNotEmpty && s != '[]' && s != '{}' && s != 'null';
    }
    if (v is List) return v.isNotEmpty;
    if (v is Map)  return v.isNotEmpty;
    return true;
  }

  dynamic _findSchemaDeep(dynamic node) {
    // مفاتيح شائعة لسكيمة الحقول القادمة من اللوحة
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
      // جرّب مباشرة
      for (final k in keys) {
        final v = node[k];
        if (_hasSchemaData(v)) return v;
      }
      // نزول تكراري داخل القيم
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

  /// ترجع أول سكيمة صالحة من نموذج الخدمة (من toJson) أو null
  dynamic _pickServiceSchema() {
    // أولاً لو الموديل فيه خاصية عليا معروفة
    try {
      final direct = ( _data as dynamic ).serviceFieldsSchema;
      if (_hasSchemaData(direct)) return direct;
    } catch (_) {}
    // بعدها نفتّش في الـ JSON كامل
    final j = _data?.toJson() ?? {};
    return _findSchemaDeep(j);
  }














  /// محاولات مرنة: get-item ثم get-services (POST/GET) مع فلترة id
  Future<ClassifiedModel?> _fetchDetailsFromApi(int id) async {
    Map<String, dynamic>? resp;

    final tries = <_ApiAttempt>[
      _ApiAttempt(
        run: () => Api.get(
          url: Api.getServicesApi,
          queryParameters: {Api.id: id, 'limit': 1},
        ),
        requireServiceMarkers: true,
      ),
      _ApiAttempt(
        run: () => Api.get(
          url: Api.getServicesApi,
          queryParameters: {Api.itemId: id, 'limit': 1},
        ),
        requireServiceMarkers: true,
      ),

    ];

    for (final attempt in tries) {
      try {
        resp = await attempt.run();
        final m = _extractPayloadStrict(resp, wantedId: id);
        if (m == null) continue;
        if (attempt.requireServiceMarkers && !_containsServiceMarkers(m)) {
          continue;
        }
        return ClassifiedModel.fromJson(m);


      } catch (_) {
        // تجاهل وجرب التالية
      }
    }
    return null;
  }




  bool _containsServiceMarkers(Map<String, dynamic> data) {
    bool hasAnyKey(Iterable<String> keys) {
      for (final key in keys) {
        if (data.containsKey(key)) {
          return true;
        }
      }
      return false;
    }

    const markerKeys = [
      'service_uid',
      'serviceUid',
      'direct_to_user',
      'directToUser',
      'has_custom_fields',
      'hasCustomFields',
      'service_fields_schema',
      'serviceFieldsSchema',
      'service_type',
      'serviceType',
      'is_paid',
      'isPaid',
    ];

    if (hasAnyKey(markerKeys)) {
      return true;
    }

    // fallback: إذا كانت الخدمة ملفوفة داخل حقل فرعي يحتوي على العلامات السابقة
    for (final value in data.values) {
      if (value is Map<String, dynamic> && _containsServiceMarkers(value)) {
        return true;
      }
    }

    return false;

  }






  /// extractor صارم مع fallback آمن
  Map<String, dynamic>? _extractPayloadStrict(Map<String, dynamic>? resp, {required int wantedId}) {
    if (resp == null) return null;
    Map<String, dynamic>? asMap(dynamic v) => (v is Map) ? v.cast<String, dynamic>() : null;

    int? _readId(dynamic v) {
      if (v is Map) {
        final idAny = v['id'] ?? v[Api.id] ?? v['item_id'] ?? v[Api.itemId] ?? v['items_id'] ?? v[Api.itemsId] ?? v['service_id'];
        if (idAny is int) return idAny;
        if (idAny is String) return int.tryParse(idAny);
      }
      return null;
    }

    bool _idMatches(dynamic v) => _readId(v) == wantedId;

    dynamic _firstLayer(dynamic root) {
      if (root is Map) {
        return root[Api.item] ?? root['item'] ?? root[Api.data] ?? root['data'] ?? root['result'] ?? root['record'] ?? root['payload'] ?? root;
      }
      return root;
    }

    dynamic bucket = _firstLayer(resp);

    if (bucket is Map) {
      final inner = bucket[Api.item] ?? bucket['item'] ?? bucket[Api.data] ?? bucket['data'];
      if (inner != null) bucket = inner;
    }

    final directMap = asMap(bucket);
    if (directMap != null && _idMatches(directMap)) return directMap;

    if (bucket is Map) {
      for (final key in [Api.item, 'item', Api.data, 'data']) {
        final v = bucket[key];
        final m = asMap(v);
        if (m != null && _idMatches(m)) return m;
        if (v is List) {
          final match = v.firstWhere((e) => _idMatches(e), orElse: () => null);
          if (match is Map) return match.cast<String, dynamic>();
        }
      }
    }

    if (bucket is List) {
      final match = bucket.firstWhere((e) => _idMatches(e), orElse: () => null);
      if (match is Map) return match.cast<String, dynamic>();

    }

    if (_idMatches(resp)) return resp.cast<String, dynamic>();
    return null;
  }

  // -------- Helpers --------
  String _stripHtml(String s) => s.replaceAll(_htmlTagRe, ' ');
  String _truncate(String s, int max) => s.length <= max ? s : '${s.substring(0, max)}…';

  String? _firstTelFromHtml(String html) {
    final m = _telRe.firstMatch(html);
    return m != null ? m.group(1) : null;
  }

  String? _firstWaFromHtml(String html) {
    final m = _waRe.firstMatch(html);
    return m != null ? '+${m.group(1)!}' : null;
  }

  String _buildShareText(BuildContext context) {
    final title = ((_data?.title ?? '').trim());
    final desc  = _truncate(_stripHtml((_data?.description ?? '').trim()), 220);
    final date  = _data?.createdAt != null ? _data!.createdAt.toString().formatDate() : '';
    final tel   = _firstTelFromHtml(_data?.description ?? '');
    final wa    = _firstWaFromHtml(_data?.description ?? '');
    final lines = <String>[
      if (title.isNotEmpty) '📄 $title',
      if (date.isNotEmpty)  '🗓️ $date',
      if (desc.isNotEmpty)  '—\n$desc',
      if (tel != null)      '\n📞 اتصال: $tel',
      if (wa != null)       '💬 واتساب: $wa',
    ];
    return lines.where((e) => e.trim().isNotEmpty).join('\n');
  }

  Future<void> _share(BuildContext context) async {
    final text = _buildShareText(context);
    await Share.share(text, subject: ((_data?.title ?? 'إعلان').firstUpperCase()));
  }

  String? _extractRatingText(String html) {
    final m = _ratingRe.firstMatch(html);
    if (m != null) return '${m.group(1)} (${m.group(2)})';
    return null;
  }

  // ====== منطق زر المتابعة (مُحدّث) ======

  bool _asBoolFlex(dynamic v) {
    if (v == null) return false;
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final s = v.trim().toLowerCase();
      return s == '1' || s == 'true' || s == 'yes';
    }
    return false;
  }

  int? _asIntFlex(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('$v');
  }

  num? _asNumFlex(dynamic v) {
    if (v == null) return null;
    if (v is num) return v;
    if (v is String) return num.tryParse(v);
    return null;
  }

  _NextAction _computeAction() {
    final j = _data?.toJson() ?? {};

    // direct_to_user
    final direct = _asBoolFlex(j['direct_to_user']) || _asBoolFlex((_data as dynamic)?.directToUser);
    final directUserId = j['direct_user_id'] ?? (_data as dynamic)?.directUserId;

    // has_custom_fields + service_fields_schema (نص/مصفوفة/خريطة)
    final dynamic schemaRaw = j['service_fields_schema'] ?? (_data as dynamic)?.serviceFieldsSchema;
    bool schemaHasData = false;
    if (schemaRaw is String) {
      final s = schemaRaw.trim();
      schemaHasData = s.isNotEmpty && s != '[]' && s != '{}';
    } else if (schemaRaw is List) {
      schemaHasData = schemaRaw.isNotEmpty;
    } else if (schemaRaw is Map) {
      schemaHasData = schemaRaw.isNotEmpty;
    }
    final hasCF = _asBoolFlex(j['has_custom_fields']) ||
        _asBoolFlex((_data as dynamic)?.hasCustomFields) ||
        schemaHasData;

    // is_paid أو price>0
    final isPaidFlag = _asBoolFlex(j['is_paid']) || _asBoolFlex((_data as dynamic)?.isPaid);
    final priceNum = _asNumFlex(j['price']) ?? _asNumFlex((_data as dynamic)?.price) ?? 0;
    final isPaid = isPaidFlag || (priceNum > 0);

    if (direct && _asIntFlex(directUserId) != null) return _NextAction.chat;
    if (hasCF) return _NextAction.customFields;
    if (isPaid) return _NextAction.payment;
    return _NextAction.none;
  }

  Future<void> _handleContinue(BuildContext context) async {
    if (_data == null) return;

    // تحقق تسجيل الدخول وفق توقيع مشروعك (onNotGuest)
    var logged = false;
    UiUtils.checkUser(
      context: context,
      onNotGuest: () => logged = true,
    );
    if (!logged) return;

    switch (_computeAction()) {
      case _NextAction.chat:
        await _openChat(context);
        break;
      case _NextAction.customFields:
        await _openCustomFields(context);
        break;
      case _NextAction.payment:
        await _openPayment(context);
        break;
      case _NextAction.none:
      // UiUtils.showSnackBar(context, message: 'continue'.translate(context), type: SnackBarType.info);
        break;
    }
  }






  Future<void> _openCustomFields(BuildContext context) async {
    final id = _data?.id;
    if (id == null) return;

    final schema = _pickServiceSchema(); // ✅ التقط السكيمة من أي مفتاح/تعشيق

    Navigator.pushNamed(
      context,
      Routes.serviceAddMoreDetails,
      arguments: {
        'serviceId'          : id,
        'categoryId'         : _data?.categoryId,
        'serviceUid'         : _data?.serviceUid,
        'serviceTitle'       : _data?.title,
        'serviceFieldsSchema': schema, // ✅ مهم جدًا
      },
    );
  }






  Future<void> _openPayment(BuildContext context) async {
    final id = _data?.id;
    if (id == null) return;

    Navigator.pushNamed(
      context,
      Routes.servicePaymentPage,
      arguments: {
        'serviceId'   : id,
        'itemId'      : id,
        'amount'      : _data?.price,      // ✅ تمرير باسم amount
        'currency'    : _data?.currency,
        'note'        : _data?.priceNote,  // ✅ تمرير الملاحظة
        'serviceUid'  : _data?.serviceUid,
        'serviceTitle': _data?.title,
      },
    );
  }

  Future<void> _openChat(BuildContext context) async {
    final id = _data?.id;
    final advertiserId = _data?.directUserId;
    if (id == null || advertiserId == null) return;

    ChatedUser? existing;
    try {
      existing = context.read<GetBuyerChatListCubit>().getOfferForItem(id);
    } catch (_) {
      // تجاهل
    }

    if (existing == null) {
      try {
        await MakeAnOfferItemCubit().makeAnOfferItem(id: id, from: "chat");
      } catch (e) {
        // UiUtils.showSnackBar(context, message: e.toString(), type: SnackBarType.error);
        return;
      }
    }

    final int itemOfferId = existing?.itemOfferId ?? existing?.id ?? 0;
    final String conversationId =
        existing?.conversationId ?? existing?.id?.toString() ?? '';



    String? fallbackName;
    String? fallbackProfile;
    if (existing?.seller?.id == advertiserId) {
      fallbackName = existing?.seller?.name;
      fallbackProfile = existing?.seller?.profile;
    } else if (existing?.buyer?.id == advertiserId) {
      fallbackName = existing?.buyer?.name;
      fallbackProfile = existing?.buyer?.profile;
    }

    final List<ChatParticipant>? participants = existing?.participants ??
        NotificationService.getCachedParticipants(
          conversationId,
          itemOfferId: itemOfferId > 0 ? itemOfferId : null,
          senderId: advertiserId.toString(),
          itemId: (_data?.id ?? widget.id)?.toString(),
        ) ??
        NotificationService.buildParticipantsFromNotification(
          data: {
            'user_id': advertiserId,
            'user_name': fallbackName ??
                existing?.seller?.name ??
                existing?.buyer?.name ??
                _data?.title,
            'user_profile': fallbackProfile ??
                existing?.seller?.profile ??
                existing?.buyer?.profile,
            'conversation_id': conversationId,
            'item_offer_id': itemOfferId,
          },
        );



    Navigator.push(
      context,
      BlurredRouter(
        builder: (_) => MultiBlocProvider(
          providers: [
            BlocProvider(create: (_) => SendMessageCubit()),
            BlocProvider(create: (_) => LoadChatMessagesCubit()),
            BlocProvider(create: (_) => DeleteMessageCubit()),
          ],
          child: ChatScreen(
            userId: advertiserId.toString(),
            profilePicture: '',
            userName: _data?.title ?? '',
            from: "item",
            itemImage: _data?.image ?? '',
            itemId: (_data?.id ?? '').toString(),
            date: _data?.createdAt ?? '',
            itemTitle: _data?.title ?? '',
            itemOfferId: itemOfferId,
            conversationId: conversationId,
            itemPrice: _data?.price ?? 0,
            status: (_data?.status ?? '').toString(),
            buyerId: HiveUtils.getUserId(),
            isPurchased: 0,
            alreadyReview: false,
            participants: participants,
            currency: _data?.currency,
            currencySymbol: _data?.currency,
          ),
        ),
      ),
    );
  }





  // ===============================
  // أدوات مالك الخدمة
  // ===============================

  bool get _isServiceOwner {
    final int? ownerId = _data?.userId;
    if (ownerId == null) return false;

    final String? currentIdRaw = HiveUtils.getUserId();
    if (currentIdRaw == null || currentIdRaw.isEmpty) return false;
    final int? currentId = int.tryParse(currentIdRaw);
    if (currentId == null) return false;

    return currentId == ownerId;
  }

  bool _resolveOwnerStatus() {
    if (_ownerStatusOverride != null) return _ownerStatusOverride!;
    return _data?.status ?? true;
  }

  DateTime? _parseExpiryDate(String? raw) {
    if (raw == null) return null;
    final String trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    DateTime? parsed = DateTime.tryParse(trimmed);
    if (parsed != null) return parsed;

    parsed = DateTime.tryParse(trimmed.replaceFirst(' ', 'T'));
    return parsed;
  }

  DateTime? _resolveOwnerExpiry() {
    if (_ownerExpiryOverride != null) return _ownerExpiryOverride;
    return _parseExpiryDate(_data?.expiryDate);
  }

  Future<void> _toggleOwnerStatus(bool value) async {
    final ClassifiedModel? service = _data;
    if (service?.id == null || _statusUpdating) return;

    setState(() {
      _statusUpdating = true;
      _ownerStatusOverride = value;
    });

    try {
      final ClassifiedModel updated = await _ownerRepository.updateService(
        service!.id!,
        <String, dynamic>{'status': value},
      );

      if (!mounted) return;
      setState(() {
        _data = updated;
        _ownerStatusOverride = null;
        _statusUpdating = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _ownerStatusOverride = null;
        _statusUpdating = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذّر تحديث حالة الخدمة: $error')),
      );
    }
  }

  Future<void> _pickOwnerExpiry(BuildContext context) async {
    if (_data?.id == null || _expiryUpdating) return;

    final DateTime now = DateTime.now();
    final DateTime initial = _resolveOwnerExpiry() ?? now;
    final DateTime firstDate = DateTime(now.year, now.month, now.day);
    final DateTime adjustedInitial =
    initial.isBefore(firstDate) ? firstDate : initial;
    final DateTime lastDate = DateTime(now.year + 5, now.month, now.day);
    final DateTime cappedInitial =
    adjustedInitial.isAfter(lastDate) ? lastDate : adjustedInitial;

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: cappedInitial,
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (picked != null) {
      await _updateOwnerExpiry(picked);
    }
  }

  Future<void> _updateOwnerExpiry(DateTime picked) async {
    final ClassifiedModel? service = _data;
    if (service?.id == null) return;

    final DateTime normalized = DateTime(picked.year, picked.month, picked.day);
    setState(() {
      _expiryUpdating = true;
      _ownerExpiryOverride = normalized;
    });

    try {
      final ClassifiedModel updated = await _ownerRepository.updateService(
        service!.id!,
        <String, dynamic>{'expiry_date': normalized.toIso8601String()},
      );

      if (!mounted) return;
      setState(() {
        _data = updated;
        _ownerExpiryOverride = null;
        _expiryUpdating = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _ownerExpiryOverride = null;
        _expiryUpdating = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذّر تحديث تاريخ الانتهاء: $error')),
      );
    }
  }

  Widget? _buildOwnerPanel(BuildContext context) {
    if (!_isServiceOwner) return null;

    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool active = _resolveOwnerStatus();
    final DateTime? expiry = _resolveOwnerExpiry();
    final String expiryLabel = expiry != null
        ? expiry.toIso8601String().formatDate()
        : 'غير محدد';

    final TextStyle titleStyle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w600,
      color: scheme.onSurface,
    ) ??
        TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        );

    final TextStyle subtitleStyle = theme.textTheme.bodyMedium?.copyWith(
      color: scheme.onSurface.withOpacity(0.7),
    ) ??
        TextStyle(
          fontSize: 14,
          color: scheme.onSurface.withOpacity(0.7),
        );

    final TextStyle valueStyle = theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w600,
      color: scheme.primary,
    ) ??
        TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: scheme.primary,
        );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 12),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: scheme.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(10),
                child: Icon(
                  Icons.workspace_premium_rounded,
                  color: scheme.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('إدارة الخدمة', style: titleStyle),
                    const SizedBox(height: 4),
                    Text(
                      'يمكنك إيقاف الخدمة مؤقتًا أو ضبط تاريخ الانتهاء.',
                      style: subtitleStyle,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: scheme.onSurface.withOpacity(0.08), height: 1),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('تاريخ انتهاء الخدمة', style: subtitleStyle),
                    const SizedBox(height: 4),
                    Text(expiryLabel, style: valueStyle),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (_expiryUpdating)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                )
              else
                TextButton.icon(
                  onPressed: () => _pickOwnerExpiry(context),
                  icon: const Icon(Icons.edit_calendar_rounded, size: 20),
                  label: const Text('تعديل'),
                  style: TextButton.styleFrom(
                    foregroundColor: scheme.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    textStyle: theme.textTheme.labelLarge,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: scheme.onSurface.withOpacity(0.05), height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('الحالة الحالية', style: subtitleStyle),
                    const SizedBox(height: 4),
                    Text(
                      active ? 'نشطة' : 'متوقفة',
                      style: valueStyle.copyWith(
                        color: active ? scheme.primary : scheme.error,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: active,
                onChanged: _statusUpdating ? null : _toggleOwnerStatus,
                activeColor: scheme.primary,
              ),
            ],
          ),
          if (_statusUpdating)
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Text('جارٍ الحفظ...'),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }




  // ===============================
  // واجهة العرض (تفويض كامل إلى details_ui.dart)
  // ===============================
  @override
  Widget build(BuildContext context) {
    final bool hasImage   = ((_data?.image ?? '').isNotEmpty);
    final String html     = (_data?.description ?? '');
    final String appBarTitle = _loading ? (_initialTitle ?? '') : (_data?.title ?? '');
    final String buttonTitle = 'continue'.translate(context);
    final String ratingText = _extractRatingText(html) ?? 'التقييم';
    final String? dateLine = _data?.createdAt != null
        ? 'تمت اضافة الخدمة : ${_data!.createdAt.toString().formatDate()}'
        : null;
    final bool hideActionButton = _isServiceOwner;

    return ClassifiedDetailsUI(
      // الحالة/المعطيات
      loading: _loading,
      appBarTitle: appBarTitle,
      hasImage: hasImage,
      imageUrl: hasImage ? _data!.image! : null,
      html: html,
      dateLine: dateLine,
      ratingText: ratingText,
      directiveHidden: hideActionButton,
      buttonTitle: buttonTitle,
      fabVisible: _fabVisible,
      isReporting: _isReporting,
      ownerPanel: _buildOwnerPanel(context),

      // ردود الأفعال
      onBack: () => Navigator.of(context).maybePop(),
      onShare: () => _share(context),

      onReportTap: () async {
        final id = _data?.id ?? widget.id;
        if (id == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('لا يوجد معرّف خدمة صالح')),
          );
          return;
        }
        setState(() => _isReporting = true);
        try {
          await ReportService(context).openAndSubmit(
            itemId: id,
            type: 'service',
            serviceTitle: _data?.title,
            serviceUid: _data?.serviceUid,
          );
        } finally {
          if (mounted) setState(() => _isReporting = false);
        }
      },

      onRateTap: () {
        final int? serviceId = _extractServiceId();
        final String? serviceUid = _data?.serviceUid?.trim();
        if ((serviceId == null || serviceId <= 0) &&
            (serviceUid == null || serviceUid.isEmpty)) {


          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تعذّر تحديد الخدمة لعرض التقييمات.')),
          );
          return;
        }

        final sellerId = _data?.userId ?? _data?.directUserId;

        Navigator.of(context).push(
          BlurredRouter(
            builder: (_) => const ServiceRatingPage(),
            settings: RouteSettings(arguments: {
              'serviceTitle': _data?.title ?? 'بدون عنوان',
              'serviceId': serviceId,
              'itemId': serviceId ?? _data?.id,
              'sellerId': sellerId,
              if (serviceUid != null && serviceUid.isNotEmpty) 'serviceUid': serviceUid,

            }),
          ),
        );
      },

      onContinueTap: () async {
        if (_isProcessing) return;
        setState(() => _isProcessing = true);
        try {
          await _handleContinue(context);
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString())),
          );
        } finally {
          if (mounted) setState(() => _isProcessing = false);
        }
      },

      onFabVisibilityChange: (visible) {
        if (visible != _fabVisible) {
          setState(() => _fabVisible = visible);
        }
      },
    );
  }
}

enum _NextAction { chat, customFields, payment, none }
