// lib/new_code/services/report_service.dart
import 'package:flutter/material.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:marib/utils/api.dart';
import 'package:marib/utils/extensions/extensions.dart';



// lib/new_code/services/report_service.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:marib/utils/api.dart';

/// خدمة الإبلاغ — تظهر الشيت فورًا (بدون انتظار الشبكة) وتحدّث نفسها لاحقًا.
/// - تدعم cache للأسباب لتسريع الفتح.
/// - تعالج خيار "أخرى": ترسل نص المستخدم بدلاً من كلمة "أخرى".
class ReportService {
  final BuildContext context;
  const ReportService(this.context);

  // --- Cache للأسباب (10 دقائق) ---
  static List<_Reason>? _reasonsCache;
  static DateTime? _reasonsCachedAt;
  static const Duration _cacheTtl = Duration(minutes: 10);

  /// فتح الشيت ثم إرسال البلاغ. يرجّع true عند نجاح الإرسال.
  Future<bool> openAndSubmit({
    required int itemId,
    String type = 'service',
    String? serviceTitle,
    String? serviceUid,

  }) async {
    // 1) جهّز أسباب فورية (Cache أو Fallback) — لعرض الشيت مباشرة
    final initialReasons = _loadReasonsFast();

    // 2) ابدأ طلب الشبكة بالتوازي لتحديث القائمة لاحقًا
    final refreshFuture = _loadReasonsFromServer(); // قد تُعيد null عند الفشل

    // 3) افتح الشيت فورًا
    final form = await _openSheetWithAsyncRefresh(
      initialReasons: initialReasons,
      title: serviceTitle ?? 'الإبلاغ عن خدمة',
      refreshFuture: refreshFuture,
    );
    if (form == null) return false;

    // 4) التقط بيانات الشيت
    final int   reasonId    = int.tryParse(form['reason_id'] ?? '') ?? 0;
    final String reasonText = (form['reason_label'] ?? '').trim();
    final String details    = (form['details'] ?? '').trim();

    if (reasonId <= 0 && reasonText.isEmpty && details.isEmpty) {
      _toast('اختر سببًا أو اكتب تفاصيل البلاغ');
      return false;
    }

    // 5) لودر حاظر واضح
    _showBlockingLoader();

    final ok = await _submitReport(
      itemId: itemId,
      type: type,
      reasonId: reasonId > 0 ? reasonId : null,
      reasonText: reasonText,
      details: details,
      serviceUid: serviceUid,

    );

    Navigator.of(context, rootNavigator: true).maybePop(); // إغلاق اللودر
    if (ok) {
      _toast('تم إرسال البلاغ بنجاح');
      HapticFeedback.lightImpact();
    }
    return ok;
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  // يظهر الشيت فورًا بـ initialReasons، ثم يحدّث نفسه عند اكتمال refreshFuture
  Future<Map<String, String>?> _openSheetWithAsyncRefresh({
    required List<_Reason> initialReasons,
    required String title,
    Future<List<_Reason>?>? refreshFuture,
  }) async {
    final controller = TextEditingController();
    List<_Reason> reasons = List<_Reason>.from(initialReasons);

    // اختيار افتراضي
    int selectedId = reasons.isNotEmpty ? reasons.first.id : 0;
    String selectedLabel = reasons.isNotEmpty ? reasons.first.label : '';

    bool _isOtherLabel(String s) {
      final l = s.trim().toLowerCase();
      return l == 'other' || l == 'others' || l.contains('أخرى') || l.contains('اخرى');
    }

    final bg   = context.color.primaryColor;
    final text = context.color.textColorDark;
    final accent = context.color.secondaryColor;

    return showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;

        // حدّث القائمة لاحقًا عندما تجهز من السيرفر
        if (refreshFuture != null) {
          refreshFuture.then((serverReasons) {
            if (serverReasons == null || serverReasons.isEmpty) return;
            // حدّث فقط لو تغيّرت عن الحالية
            final same = _listEqualsById(reasons, serverReasons);
            if (same) return;
            // حافظ على الاختيار الحالي قدر الإمكان
            final hasOld = serverReasons.any((e) => e.id == selectedId);
            reasons = serverReasons;
            if (!hasOld && reasons.isNotEmpty) {
              selectedId = reasons.first.id;
              selectedLabel = reasons.first.label;
            }
            if (ctx.mounted) (ctx as Element).markNeedsBuild();
          });
        }

        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: SafeArea(
            top: false,
            child: StatefulBuilder(
              builder: (ctx, setSt) => Directionality(
                textDirection: TextDirection.rtl,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Handle
                      Center(
                        child: Container(
                          width: 40, height: 4,
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: text.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      // Title
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: context.font.larger,
                          fontWeight: FontWeight.w700,
                          color: text,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('اختر سبب البلاغ', style: TextStyle(color: text.withOpacity(0.75))),
                      const SizedBox(height: 8),

                      if (reasons.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: accent.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: const [
                              SizedBox(
                                width: 18, height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              SizedBox(width: 10),
                              Text('جاري تحميل الأسباب...'),
                            ],
                          ),
                        ),

                      ...reasons.map((r) {
                        final selected = selectedId == r.id;
                        return Container(
                          margin: const EdgeInsetsDirectional.only(bottom: 4),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: selected ? text.withOpacity(0.25) : Colors.transparent,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: RadioListTile<int>(
                            value: r.id,
                            groupValue: selectedId,
                            onChanged: (v) {
                              setSt(() {
                                selectedId = v ?? r.id;
                                selectedLabel = r.label;
                              });
                            },
                            title: Text(
                              r.label,
                              style: TextStyle(
                                color: text,
                                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                              ),
                            ),
                            activeColor: text,
                            contentPadding:
                            const EdgeInsetsDirectional.only(start: 8, end: 8),
                          ),
                        );
                      }),

                      const SizedBox(height: 8),

                      // تفاصيل
                      TextField(
                        controller: controller,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'تفاصيل إضافية (اختياري)',
                          hintStyle: TextStyle(color: text.withOpacity(0.6)),
                          filled: true,
                          fillColor: accent.withOpacity(0.08),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.all(12),
                        ),
                        style: TextStyle(color: text),
                        textInputAction: TextInputAction.newline,
                      ),
                      const SizedBox(height: 12),

                      // زر إرسال
                      UiUtils.buildButton(
                        ctx,
                        buttonTitle: 'إرسال البلاغ',
                        radius: 12,
                        height: 48,
                        onPressed: () {
                          final textVal = controller.text.trim();

                          // إن كان السبب "أخرى" ويُوجد نص، اجعل نص السبب هو النص المكتوب
                          final String reasonLabelToSend =
                          (_isOtherLabel(selectedLabel) && textVal.isNotEmpty)
                              ? textVal
                              : selectedLabel;

                          // نفرض كتابة سبب عند اختيار "أخرى" بدون نص
                          if (_isOtherLabel(selectedLabel) && textVal.isEmpty) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(content: Text('اذكر سبب البلاغ')),
                            );
                            return;
                          }

                          Navigator.of(ctx).pop({
                            'reason_id'   : '$selectedId',
                            'reason_label': reasonLabelToSend,
                            if (textVal.isNotEmpty) 'details': textVal,
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showBlockingLoader() {
    final bg   = context.color.primaryColor;
    final text = context.color.textColorDark;
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.20),
      builder: (_) => Center(
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12)],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Text('جارٍ الإرسال...', style: TextStyle(color: text)),
            ],
          ),
        ),
      ),
    );
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ---------------------------------------------------------------------------
  // Data — أسباب الإبلاغ
  // ---------------------------------------------------------------------------

  /// تُرجع فورًا: Cache صالح أو Fallback (بدون شبكات)
  List<_Reason> _loadReasonsFast() {
    final now = DateTime.now();
    if (_reasonsCache != null &&
        _reasonsCachedAt != null &&
        now.difference(_reasonsCachedAt!) < _cacheTtl &&
        _reasonsCache!.isNotEmpty) {
      return List<_Reason>.from(_reasonsCache!);
    }
    return const [
      _Reason(id: 1, label: 'احتيال/طلب مبالغ مشبوهة'),
      _Reason(id: 2, label: 'معلومات مضللة/خاطئة'),
      _Reason(id: 3, label: 'محتوى مسيء/مخالف'),
      _Reason(id: 4, label: 'نشاط غير قانوني'),
      _Reason(id: 5, label: 'أخرى'),
    ];
  }

  /// تحميل من السيرفر (غير حاجز لواجهة المستخدم)
  Future<List<_Reason>?> _loadReasonsFromServer() async {
    try {
      final resp = await Api.get(url: Api.getReportReasonsApi);
      final raw = resp[Api.data];
      final List list = (raw is List)
          ? raw
          : (raw is Map && raw['list'] is List)
          ? raw['list']
          : const [];

      final parsed = list.map((e) {
        final m = (e is Map) ? e.cast<String, dynamic>() : <String, dynamic>{};
        final id = int.tryParse((m['id'] ?? m['value'] ?? m['key'] ?? '0').toString()) ?? 0;
        final title = (m['title'] ?? m['name'] ?? m['reason'] ?? 'سبب').toString();
        return _Reason(id: id, label: title);
      }).where((r) => r.id > 0 || r.label.trim().isNotEmpty).toList();

      if (parsed.isNotEmpty) {
        _reasonsCache = parsed;
        _reasonsCachedAt = DateTime.now();
        return parsed;
      }
    } catch (_) {/* ignore */}
    return null;
  }

  // ---------------------------------------------------------------------------
  // Network — إرسال البلاغ
  // ---------------------------------------------------------------------------

  Future<bool> _submitReport({
    required int itemId,
    required String type,
    int?    reasonId,    // رقم السبب
    String? reasonText,  // نص السبب (قد يكون نص المستخدم عند "أخرى")
    String? details,     // نص المستخدم (تفاصيل)
    String? serviceUid,

  }) async {
    try {
      final String reasonTextNorm = (reasonText ?? '').trim();
      final String detailsNorm    = (details ?? '').trim();

      bool _isOtherLabel(String s) {
        final l = s.trim().toLowerCase();
        return l == 'other' || l == 'others' || l.contains('أخرى') || l.contains('اخرى');
      }

      final Map<String, dynamic> payload = {
        // معرف العنصر المطلوب الإبلاغ عنه
        Api.itemId: itemId,

        // نوع البلاغ
        Api.type: type,
        Api.itemType: type,

        // السبب (رقمي) — هذا ما تربطه أغلب اللوحات بجدول الأسباب
        if ((reasonId ?? 0) > 0) 'report_reason_id': reasonId,
        if ((reasonId ?? 0) > 0) 'reason_id': reasonId,
      };

      // لو "أخرى" ومعنا نص => اعتبر نص السبب هو نص المستخدم
      if (_isOtherLabel(reasonTextNorm) && detailsNorm.isNotEmpty) {
        payload[Api.reportReason]      = detailsNorm; // report_reason
        payload['reason']              = detailsNorm;
        payload['report_reason_text']  = detailsNorm;
      } else if (reasonTextNorm.isNotEmpty) {
        // غير "أخرى": أرسل النص كما هو (اختياري)
        payload[Api.reportReason]      = reasonTextNorm;
        payload['reason']              = reasonTextNorm;
        payload['report_reason_text']  = reasonTextNorm;
      }

      // الرسالة/الوصف من المستخدم (إن وُجد)
      if (detailsNorm.isNotEmpty) {
        payload[Api.message]      = detailsNorm; // message
        payload['details']        = detailsNorm;
        payload['report_message'] = detailsNorm;
        payload[Api.description]  = detailsNorm; // description
        payload['other_message']  = detailsNorm;
      }

      // منع required_without: إن لم يوجد سبب ID ولا رسالة، أرسل رسالة افتراضية
      final hasReasonId = payload.containsKey('report_reason_id') || payload.containsKey('reason_id');
      final hasMessage  = payload.containsKey(Api.message) || payload.containsKey('details') || payload.containsKey('report_message');
      if (!hasReasonId && !hasMessage) {
        payload[Api.message] = 'Report from app';
      }

      final uid = serviceUid?.trim();
      if (uid != null && uid.isNotEmpty) {
        payload['service_uid'] = uid;
        payload['uid'] = uid;
      }

      if (kDebugMode) debugPrint('REPORT payload => $payload');

      final resp = await Api.post(url: Api.addReportsApi, parameter: payload);
      final ok = (resp['success'] == true) ||
          (resp['status']  == 'ok')  ||
          (resp['code']    == 200)   ||
          (resp['error']   == false);

      if (!ok) {
        _toast(resp[Api.message]?.toString() ?? 'تعذّر إرسال البلاغ');
      }
      return ok;
    } catch (e) {
      _toast(e.toString());
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  bool _listEqualsById(List<_Reason> a, List<_Reason> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id || a[i].label != b[i].label) return false;
    }
    return true;
  }


}

// نموذج السبب (id رقمي + عنوان)
class _Reason {
  final int id;
  final String label;
  const _Reason({required this.id, required this.label});
}
