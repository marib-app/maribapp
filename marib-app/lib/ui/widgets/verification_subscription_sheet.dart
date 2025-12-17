import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:marib/app/routes.dart';

import 'package:marib/data/cubits/seller/fetch_verification_request_cubit.dart';
import 'package:marib/data/model/verification_request_model.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';

Future<void> showVerificationSubscriptionSheet(
  BuildContext context, {
  String? status,
  DateTime? expiresAt,
  bool? isVerified,
}) async {
  final cubit = BlocProvider.of<FetchVerificationRequestsCubit>(context);
  // Always refresh before showing to ensure latest status/expiry.
  cubit.fetchVerificationRequests();

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: false,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return BlocProvider.value(
        value: cubit,
        child: _VerificationSubscriptionSheet(
          status: status,
          expiresAt: expiresAt,
          isVerified: isVerified,
        ),
      );
    },
  );
}

class _VerificationSubscriptionSheet extends StatefulWidget {
  final String? status;
  final DateTime? expiresAt;
  final bool? isVerified;

  const _VerificationSubscriptionSheet({
    this.status,
    this.expiresAt,
    this.isVerified,
  });

  @override
  State<_VerificationSubscriptionSheet> createState() =>
      _VerificationSubscriptionSheetState();
}

class _VerificationSubscriptionSheetState
    extends State<_VerificationSubscriptionSheet> {
  FetchVerificationRequestsCubit get _cubit =>
      BlocProvider.of<FetchVerificationRequestsCubit>(context);

  @override
  void initState() {
    super.initState();
    _cubit.fetchVerificationRequests();
  }

  @override
  Widget build(BuildContext context) {
    final Color surface = context.color.secondaryColor;

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            12,
            16,
            16 + MediaQuery.of(context).padding.bottom,
          ),
          child: BlocBuilder<FetchVerificationRequestsCubit,
              FetchVerificationRequestState>(
            bloc: _cubit,
            builder: (context, state) {
              Widget content;
              if (state is FetchVerificationRequestInProgress ||
                  state is FetchVerificationRequestInitial) {
                content = _buildLoading(context);
              } else if (state is FetchVerificationRequestFail) {
                content = _hasSnapshot()
                    ? _buildSnapshot(context)
                    : _buildNoRequest(context, message: state.error.toString());
              } else if (state is FetchVerificationRequestSuccess) {
                content = _buildDetails(context, state.data);
              } else if (_hasSnapshot()) {
                content = _buildSnapshot(context);
              } else {
                content = _buildError(context, 'Something went wrong');
              }

              return _wrapScrollable(content);
            },
          ),
        ),
      ),
    );
  }

  Widget _wrapScrollable(Widget child) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: constraints.maxWidth,
              maxWidth: constraints.maxWidth,
            ),
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildHandle(BuildContext context) {
    return Center(
      child: Container(
        width: 42,
        height: 4,
        decoration: BoxDecoration(
          color: context.color.textDefaultColor.withOpacity(0.2),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }

  Widget _buildLoading(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildHandle(context),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                valueColor:
                    AlwaysStoppedAnimation<Color>(context.color.territoryColor),
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                'جاري تحديث حالة التوثيق...',
                style: TextStyle(
                  color: context.color.textColorDark,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ).bold(weight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildError(BuildContext context, String message) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildHandle(context),
        const SizedBox(height: 14),
                Icon(Icons.warning_amber_rounded, color: context.color.error, size: 30),
        const SizedBox(height: 8),
        Text(
          message.isNotEmpty ? message : 'حدث خطأ أثناء جلب البيانات',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: context.color.textColorDark,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _cubit.fetchVerificationRequests,
          child: Text('إعادة المحاولة',
                style: TextStyle(
              color: context.color.territoryColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  bool _hasSnapshot() {
    return widget.status != null ||
        widget.expiresAt != null ||
        (widget.isVerified ?? false);
  }

  Widget _buildNoRequest(BuildContext context, {String? message}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildHandle(context),
        const SizedBox(height: 14),
        Icon(Icons.verified_user_outlined,
            color: context.color.territoryColor, size: 32),
        const SizedBox(height: 10),
        Text(
          message?.isNotEmpty == true
              ? message!
              : _local(
                  context,
                  ar: 'لا يوجد طلب توثيق حتى الآن', en: 'No verification request submitted yet',
                ),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: context.color.textColorDark,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _local(
            context,
            ar: 'ابدأ طلبك للتحقق من حسابك.', en: 'Start your request to verify your account.',
          ),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: context.color.textDefaultColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildSnapshot(BuildContext context) {
    final normalized = (widget.status ?? '').trim().toLowerCase();
    final bool expired =
        widget.expiresAt != null && widget.expiresAt!.isBefore(DateTime.now());
    final bool effectiveVerified =
        ((widget.isVerified ?? false) && !expired) || normalized == 'approved';

    if (!effectiveVerified && normalized.isEmpty) {
      return _buildNoRequest(context);
    }

    final VerificationRequestModel model = VerificationRequestModel(
      status: effectiveVerified ? 'approved' : normalized,
      expiresAt: widget.expiresAt,
    );

    return _buildDetails(context, model);
  }

  Widget _buildDetails(BuildContext context, VerificationRequestModel model) {
    final locale = Localizations.maybeLocaleOf(context);
    final String localeName = locale != null ? locale.toLanguageTag() : 'en_US';
    final DateFormat dateFmt = DateFormat('y/MM/dd - h:mm a', localeName);

    final DateTime now = DateTime.now();
    final DateTime? expiresAt = model.expiresAt;
    final DateTime? approvedAt = model.approvedAt;
    final bool expired = expiresAt != null && expiresAt.isBefore(now);
    final String normalizedStatus =
        (model.status ?? '').trim().toLowerCase();
    final bool isRejected = normalizedStatus == 'rejected';

    final Color statusColor =
        expired ? context.color.error : _statusColor(model.status, context);
    final String statusText = expired
        ? _local(context, ar: 'منتهي', en: 'Expired')
        : _statusLabel(model.status, context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHandle(context),
        const SizedBox(height: 14),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: context.color.territoryColor.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.verified, color: context.color.territoryColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _local(
                      context,
                      ar: 'حالة التوثيق والصلاحية', en: 'Verification status & expiry',
                    ),
                  ).bold(weight: FontWeight.w700).size(context.font.large),
                  const SizedBox(height: 4),
                  Text(
                    _local(
                      context,
                      ar: 'صلاحية التوثيق الحالية والوقت المتبقي', en: 'Current verification validity and remaining time',
                    ),
                  )
                      .size(context.font.small)
                      .color(context.color.textDefaultColor),
                ],
              ),
            ),
            _StatusChip(label: statusText, color: statusColor),
          ],
        ),
        const SizedBox(height: 16),
        _InfoRow(
          icon: Icons.event_available_rounded,
          label: _local(context, ar: 'تاريخ التفعيل', en: 'Activated on'),
          value:
              approvedAt != null ? dateFmt.format(approvedAt.toLocal()) : '-',
        ),
        _InfoRow(
          icon: Icons.event_busy_rounded,
          label: _local(context, ar: 'تاريخ الانتهاء', en: 'Expires on'),
          value: expiresAt != null ? dateFmt.format(expiresAt.toLocal()) : '-',
          valueColor: expired ? context.color.error : null,
        ),
        _InfoRow(
          icon: Icons.schedule_rounded,
          label: _local(context, ar: 'الوقت المتبقي', en: 'Time remaining'),
          value: _remainingLabel(context, expiresAt),
        ),
        if (isRejected) ...[
          const SizedBox(height: 12),
          _RejectionReason(
            label: _local(context, ar: 'سبب الرفض', en: 'Rejection reason'),
            reason: model.rejectionReason,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                final navigator = Navigator.of(context);
                navigator.pop();
                Future.microtask(
                  () => navigator.pushNamed(Routes.accountVerificationInfo),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: context.color.territoryColor,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                _local(context, ar: '????? ???????', en: 'Resubmit request'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
        const SizedBox(height: 8),
      ],
    );
  }

  String _remainingLabel(BuildContext context, DateTime? expiresAt) {
    if (expiresAt == null) {
      return _local(context, ar: 'غير متوفر', en: 'Not available');
    }
    final Duration diff = expiresAt.difference(DateTime.now());
    if (diff.isNegative) {
      return _local(context, ar: 'منتهي', en: 'Expired');
    }

    final int days = diff.inDays;
    final int hours = diff.inHours.remainder(24);
    final int minutes = diff.inMinutes.remainder(60);
    final List<String> parts = [];

    if (days > 0) {
      parts.add(
          '$days ${_local(context, ar: days == 1 ? 'يوم' : 'أيام', en: days == 1 ? 'day' : 'days')}');
    }
    if (hours > 0) {
      parts.add(
          '$hours ${_local(context, ar: hours == 1 ? 'ساعة' : 'ساعات', en: hours == 1 ? 'hour' : 'hours')}');
    }
    if (parts.isEmpty) {
      parts.add(
          '$minutes ${_local(context, ar: 'دقيقة', en: minutes == 1 ? 'minute' : 'minutes')}');
    }
    return parts.join(' ');
  }

  String _statusLabel(String? status, BuildContext context) {
    final normalized = (status ?? '').trim().toLowerCase();
    switch (normalized) {
      case 'approved':
        return 'approved'.translate(context);
      case 'rejected':
        return 'rejected'.translate(context);
      case 'resubmitted':
        return 'resubmitted'.translate(context);
      case 'pending':
      default:
        return 'underReview'.translate(context);
    }
  }

  Color _statusColor(String? status, BuildContext context) {
    final normalized = (status ?? '').trim().toLowerCase();
    switch (normalized) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return context.color.error;
      case 'resubmitted':
        return Colors.amber.shade700;
      case 'pending':
      default:
        return Colors.orange;
    }
  }

  String _local(BuildContext context,
      {required String ar, required String en}) {
    final locale = Localizations.maybeLocaleOf(context);
    if ((locale?.languageCode ?? 'ar').toLowerCase().startsWith('ar')) {
      return ar;
    }
    return en;
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            height: 34,
            width: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: context.color.territoryColor.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon,
                size: 18, color: context.color.territoryColor.withOpacity(0.9)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label)
                    .bold(weight: FontWeight.w600)
                    .size(context.font.small)
                    .color(context.color.textDefaultColor),
                const SizedBox(height: 2),
                Text(
                  value.isEmpty ? '-' : value,
                  style: TextStyle(
                    color: valueColor ?? context.color.textColorDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 10, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _RejectionReason extends StatelessWidget {
  final String label;
  final String? reason;

  const _RejectionReason({required this.label, required this.reason});

  @override
  Widget build(BuildContext context) {
    final String display =
        (reason == null || reason!.trim().isEmpty) ? '-' : reason!.trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.color.error.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.color.error.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: context.color.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: context.color.error,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  display,
                  style: TextStyle(
                    color: context.color.textColorDark,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}













