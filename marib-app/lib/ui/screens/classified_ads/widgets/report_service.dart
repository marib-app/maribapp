import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/api.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/helper_utils.dart';

/// نافذة البلاغات لخدمات الإعلانات المصنفة.
class ReportService {
  final BuildContext context;
  ReportService(this.context);

  bool get _isRtl => Directionality.of(context) == TextDirection.rtl;
  String _t(String ar, String en) => _isRtl ? ar : en;

  static List<_Reason>? _cache;
  static DateTime? _cacheAt;
  static const _ttl = Duration(minutes: 10);

  Future<bool> openAndSubmit({
    required int itemId,
    String type = 'service',
    String? serviceTitle,
    String? serviceUid,
  }) async {
    final initial = _loadCachedReasons();
    final refresh = _fetchReasons();

    final result = await _showSheet(
      title: serviceTitle ?? _t('الإبلاغ عن الخدمة', 'Report service'),
      initialReasons: initial,
      refreshFuture: refresh,
    );
    if (result == null) return false;

    final ok = await _submitReport(
      itemId: itemId,
      type: type,
      serviceUid: serviceUid,
      reasonId: result.reasonId,
      reasonText: result.reasonLabel,
      details: result.details,
    );
    if (ok) {
      _toast(_t('تم إرسال البلاغ بنجاح', 'Report submitted successfully'),
          MessageType.success);
      HapticFeedback.lightImpact();
    }
    return ok;
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  Future<_ReportForm?> _showSheet({
    required String title,
    required List<_Reason> initialReasons,
    Future<List<_Reason>?>? refreshFuture,
  }) async {
    final controller = TextEditingController();
    List<_Reason> reasons = List<_Reason>.from(initialReasons);
    int selectedId = 0;
    String selectedLabel = '';
    bool isSubmitting = false;

    return showModalBottomSheet<_ReportForm>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.color.primaryColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetCtx) {
        final bottomInset = MediaQuery.of(sheetCtx).viewInsets.bottom;

        if (refreshFuture != null) {
          refreshFuture.then((fresh) {
            if (fresh == null || fresh.isEmpty) return;
            if (_listEquals(reasons, fresh)) return;
            final hasSelected = fresh.any((r) => r.id == selectedId);
            reasons = fresh;
            if (!hasSelected && reasons.isNotEmpty) {
              selectedId = reasons.first.id;
              selectedLabel = reasons.first.label;
            }
            if (sheetCtx.mounted) (sheetCtx as Element).markNeedsBuild();
          });
        }

        final note = _t(
          'عزيزي العميل، تأكد أننا نأخذ آراءكم وشكاواكم على محمل الجد، فكن منصفاً.',
          'Dear customer, we take your feedback seriously. Please be fair.',
        );
        final subNote = _t(
          'اختر سبباً يتعلق بالخدمة أو مقدم الخدمة، ويمكنك إضافة تفاصيل اختيارية.',
          'Choose a reason about the service or provider, and add optional details.',
        );
        final String detailsHint =
            _t('تفاصيل إضافية (اختياري)', 'Additional details (optional)');
        final String submitText = _t('إرسال البلاغ', 'Submit report');
        final String loadingText =
            _t('جارٍ تحميل الأسباب...', 'Loading reasons...');
        final String otherRequiredText =
            _t('رجاء كتابة سبب البلاغ', 'Please type the reason');
        final highlight = context.color.territoryColor;

        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: SafeArea(
            top: false,
            child: StatefulBuilder(
              builder: (ctx, setState) => SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 46,
                        height: 5,
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: context.color.borderColor.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          height: 44,
                          width: 44,
                          decoration: BoxDecoration(
                            color: context.color.secondaryColor.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.flag_rounded,
                            color: context.color.secondaryColor.darken(40),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: context.font.larger,
                                  fontWeight: FontWeight.w700,
                                  color: context.color.textColorDark,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                note,
                                style: TextStyle(
                                  fontSize: context.font.small,
                                  color: context.color.textColorDark.withOpacity(0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      subNote,
                      style: TextStyle(
                        fontSize: context.font.normal,
                        color: context.color.textColorDark.withOpacity(0.75),
                      ),
                    ),
                    const SizedBox(height: 12),

                    if (reasons.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: context.color.secondaryColor.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                loadingText,
                                style: TextStyle(
                                  color: context.color.textColorDark.withOpacity(0.75),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    ...reasons.map((r) {
                      final selected = r.id == selectedId;
                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          color: selected
                              ? highlight.withOpacity(0.14)
                              : context.color.secondaryColor.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected
                                ? highlight
                                : context.color.borderColor.withOpacity(0.35),
                            width: selected ? 1.3 : 1,
                          ),
                        ),
                        child: RadioListTile<int>(
                          value: r.id,
                          groupValue: selectedId,
                          onChanged: (v) {
                            setState(() {
                              selectedId = v ?? r.id;
                              selectedLabel = r.label;
                            });
                          },
                          title: Text(
                            r.label,
                            style: TextStyle(
                              color: selected
                                  ? highlight.darken(10)
                                  : context.color.textColorDark,
                              fontWeight:
                                  selected ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                          activeColor: highlight,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 10),
                        ),
                      );
                    }),

                    const SizedBox(height: 12),
                    TextField(
                      controller: controller,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: detailsHint,
                        hintStyle: TextStyle(
                          color: context.color.textColorDark.withOpacity(0.6),
                        ),
                        filled: true,
                        fillColor: context.color.secondaryColor.withOpacity(0.08),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: context.color.borderColor.withOpacity(0.5),
                            width: 1,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: context.color.secondaryColor,
                            width: 1.2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                      style: TextStyle(color: context.color.textColorDark),
                      textInputAction: TextInputAction.newline,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: highlight,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        onPressed: (selectedId == 0 || isSubmitting)
                            ? null
                            : () async {
                                final textVal = controller.text.trim();
                                final isOther = _isOther(selectedLabel);
                                if (isOther && textVal.isEmpty) {
                                  HelperUtils.showSnackBarMessage(
                                    ctx,
                                    otherRequiredText,
                                    type: MessageType.error,
                                  );
                                  return;
                                }
                                setState(() => isSubmitting = true);
                                Navigator.of(ctx).pop(
                                  _ReportForm(
                                    reasonId: selectedId,
                                    reasonLabel: selectedLabel,
                                    details: textVal,
                                  ),
                                );
                              },
                        child: isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Text(
                                submitText,
                                style: TextStyle(
                                  color: context.color.textDefaultColor,
                                  fontWeight: FontWeight.w700,
                                  fontSize: context.font.normal,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  bool _isOther(String label) {
    final l = label.trim().toLowerCase();
    return l == 'other' ||
        l.contains('other') ||
        l.contains('akhra') ||
        l.contains('اخرى') ||
        l.contains('أخرى') ||
        l.contains('اخري');
  }

  // ---------------------------------------------------------------------------
  // Data / cache
  // ---------------------------------------------------------------------------

  List<_Reason> _loadCachedReasons() {
    final now = DateTime.now();
    if (_cache != null &&
        _cacheAt != null &&
        now.difference(_cacheAt!) < _ttl &&
        _cache!.isNotEmpty) {
      return List<_Reason>.from(_cache!);
    }
    return _fallbackReasons();
  }

  Future<List<_Reason>?> _fetchReasons() async {
    try {
      final resp = await Api.get(url: Api.getReportReasonsApi);
      final raw = resp[Api.data];
      final List list = (raw is List)
          ? raw
          : (raw is Map && raw['list'] is List)
              ? raw['list']
              : const [];
      final parsed = list
          .map((e) {
            final m =
                (e is Map) ? e.cast<String, dynamic>() : <String, dynamic>{};
            final id = int.tryParse(
                  (m['id'] ?? m['value'] ?? m['key'] ?? '0').toString(),
                ) ??
                0;
            final title =
                (m['title'] ?? m['name'] ?? m['reason'] ?? '').toString().trim();
            return _Reason(id: id, label: title);
          })
          .where((r) => r.id > 0 && r.label.isNotEmpty)
          .toList();

      if (parsed.isNotEmpty) {
        _cache = parsed;
        _cacheAt = DateTime.now();
        return parsed;
      }
    } catch (_) {
      // ignore
    }
    return null;
  }

  List<_Reason> _fallbackReasons() {
    return [
      _Reason(
        id: 1,
        label: _t('مشكلة في وصف الخدمة', 'Service description issue'),
      ),
      _Reason(
        id: 2,
        label: _t('تأخير أو إلغاء غير مبرر', 'Delay or unjustified cancelation'),
      ),
      _Reason(
        id: 3,
        label: _t('تعامل غير احترافي من مقدم الخدمة', 'Unprofessional provider'),
      ),
      _Reason(
        id: 4,
        label: _t('جودة الخدمة لا تطابق المتفق عليه', 'Quality mismatch'),
      ),
      _Reason(id: 5, label: _t('أخرى', 'Other')),
    ];
  }

  // ---------------------------------------------------------------------------
  // Network
  // ---------------------------------------------------------------------------

  Future<bool> _submitReport({
    required int itemId,
    required String type,
    int? reasonId,
    String? reasonText,
    String? details,
    String? serviceUid,
  }) async {
    try {
      final String reasonTextNorm = (reasonText ?? '').trim();
      final String detailsNorm = (details ?? '').trim();

      final Map<String, dynamic> payload = {
        Api.itemId: itemId,
        Api.type: type,
        Api.itemType: type,
        'department': type == 'service' ? 'services' : type,
        'report_to': type == 'service' ? 'services' : type,
        if ((reasonId ?? 0) > 0) 'report_reason_id': reasonId,
        if ((reasonId ?? 0) > 0) 'reason_id': reasonId,
      };

      if (reasonTextNorm.isNotEmpty) {
        payload[Api.reportReason] = reasonTextNorm;
        payload['reason'] = reasonTextNorm;
        payload['report_reason_text'] = reasonTextNorm;
      }
      if (detailsNorm.isNotEmpty) {
        payload[Api.message] = detailsNorm;
        payload['details'] = detailsNorm;
        payload['report_message'] = detailsNorm;
      }
      if (!payload.containsKey('report_reason_id') &&
          !payload.containsKey(Api.message)) {
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
          (resp['status'] == 'ok') ||
          (resp['code'] == 200) ||
          (resp['error'] == false);
      if (!ok) {
        final rawMsg = resp[Api.message]?.toString() ?? '';
        final mapped = rawMsg.contains('Unable to determine the department')
            ? _t('لم نتمكن من توجيه البلاغ حالياً، يرجى المحاولة لاحقاً.',
                'Unable to route your report right now, please try again later.')
            : (rawMsg.isNotEmpty
                ? rawMsg
                : _t('حدث خطأ أثناء إرسال البلاغ', 'Failed to submit report'));
        _toast(mapped, MessageType.error);
      }
      return ok;
    } catch (e) {
      _toast(e.toString(), MessageType.error);
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  bool _listEquals(List<_Reason> a, List<_Reason> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id || a[i].label != b[i].label) return false;
    }
    return true;
  }

  void _toast(String msg, [MessageType type = MessageType.error]) {
    HelperUtils.showSnackBarMessage(
      context,
      msg,
      type: type,
    );
  }
}

class _ReportForm {
  final int reasonId;
  final String reasonLabel;
  final String details;
  _ReportForm({
    required this.reasonId,
    required this.reasonLabel,
    required this.details,
  });
}

class _Reason {
  final int id;
  final String label;
  const _Reason({required this.id, required this.label});
}
