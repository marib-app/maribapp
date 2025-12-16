import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import 'package:marib/app/routes.dart';
import 'package:marib/data/cubits/seller/fetch_seller_verification_field.dart';
import 'package:marib/data/cubits/seller/fetch_verification_request_cubit.dart';
import 'package:marib/data/model/custom_field/custom_field_model.dart';
import 'package:marib/data/model/verification_metadata.dart';
import 'package:marib/data/model/verification_request_model.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/hive_utils.dart';
import 'package:marib/utils/helper_utils.dart';

Future<void> showVerificationSubscriptionSheet(
  BuildContext context, {
  String? status,
  DateTime? expiresAt,
  bool? isVerified,
}) async {
  final cubit = BlocProvider.of<FetchVerificationRequestsCubit>(context);
  FetchSellerVerificationFieldsCubit? fieldsCubit;
  try {
    fieldsCubit = BlocProvider.of<FetchSellerVerificationFieldsCubit>(context);
  } catch (_) {
    fieldsCubit = null;
  }
  // Always refresh before showing to ensure latest status/expiry.
  cubit.fetchVerificationRequests();
  fieldsCubit ??= FetchSellerVerificationFieldsCubit();
  fieldsCubit.fetchSellerVerificationFields(
    accountType: HiveUtils.getAccountTypeLower(),
    forceRefresh: true,
  );

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: false,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return MultiBlocProvider(
        providers: [
          BlocProvider.value(value: cubit),
          BlocProvider.value(value: fieldsCubit!),
        ],
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
  FetchSellerVerificationFieldsCubit get _fieldsCubit =>
      BlocProvider.of<FetchSellerVerificationFieldsCubit>(context);

  @override
  void initState() {
    super.initState();
    _cubit.fetchVerificationRequests();
    _fieldsCubit.fetchSellerVerificationFields(
      accountType: HiveUtils.getAccountTypeLower(),
      forceRefresh: true,
    );
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
              child: Text('تحميل تفاصيل الاشتراك...',
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
        Icon(Icons.warning_amber_rounded,
            color: context.color.error, size: 30),
        const SizedBox(height: 8),
        Text(
          message.isNotEmpty ? message : 'تعذر جلب بيانات التوثيق',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: context.color.textColorDark,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _cubit.fetchVerificationRequests,
          child: Text(
            'إعادة المحاولة',
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
    final String accountType = HiveUtils.getAccountTypeLower();
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
                  ar: 'لم تقم بتقديم طلب توثيق بعد',
                  en: 'No verification request submitted yet',
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
            ar: 'ابدأ الطلب الآن لاستكمال توثيق حسابك',
            en: 'Start your request to verify your account.',
          ),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: context.color.textDefaultColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 16),
        BlocBuilder<FetchSellerVerificationFieldsCubit,
            FetchSellerVerificationFieldState>(
          builder: (context, state) {
            final bool isLoading =
                state is FetchSellerVerificationFieldInProgress ||
                    state is FetchSellerVerificationFieldInitial;
            return FilledButton.icon(
              onPressed: isLoading
                  ? null
                  : () => _startVerificationFlow(context, accountType: accountType),
              icon: const Icon(Icons.verified_user_outlined),
              label: Text(
                _local(
                  context,
                  ar: 'تقديم طلب توثيق',
                  en: 'Submit verification request',
                ),
              ),
            );
          },
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
    final String localeName =
        locale != null ? locale.toLanguageTag() : 'en_US';
    final DateFormat dateFmt = DateFormat('y/MM/dd - h:mm a', localeName);

    final DateTime now = DateTime.now();
    final DateTime? expiresAt = model.expiresAt;
    final DateTime? approvedAt = model.approvedAt;
    final bool expired = expiresAt != null && expiresAt.isBefore(now);

    final Color statusColor = expired
        ? context.color.error
        : _statusColor(model.status, context);
    final String statusText = expired
        ? _local(context, ar: 'انتهى الاشتراك', en: 'Expired')
        : _statusLabel(model.status, context);

    return BlocBuilder<FetchSellerVerificationFieldsCubit,
        FetchSellerVerificationFieldState>(
      bloc: _fieldsCubit,
      builder: (context, fieldState) {
        final bool hasSuccessState =
            fieldState is FetchSellerVerificationFieldSuccess;
        final List<VerificationFieldModel> allFields = hasSuccessState
            ? fieldState.fields
            : const <VerificationFieldModel>[];
        final Map<int, VerificationFieldValues> filledValues = {
          for (final value
              in model.verificationFieldValues ?? const <VerificationFieldValues>[])
            if (value.verificationFieldId != null)
              value.verificationFieldId!: value,
        };
        final String accountType = hasSuccessState
            ? fieldState.accountType
            : HiveUtils.getAccountTypeLower();
        final List<VerificationFieldModel> typeFields = hasSuccessState
            ? fieldState.fields
            : _filterFieldsForAccountType(allFields, accountType);
        final VerificationOffering? offering = hasSuccessState
            ? fieldState.metadata.findForAccountType(accountType)
            : null;

        final VerificationPricing? pricing = offering?.pricing;

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
                  child:
                      Icon(Icons.verified, color: context.color.territoryColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _local(
                          context,
                          ar: 'تفاصيل التوثيق والاشتراك',
                          en: 'Verification subscription details',
                        ),
                      )
                          .bold(weight: FontWeight.w700)
                          .size(context.font.large),
                      const SizedBox(height: 4),
                      Text(
                        _local(
                          context,
                          ar: 'عرض حالة التوثيق وموعد الانتهاء الحالي',
                          en: 'Current verification status and expiry',
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
              value:
                  expiresAt != null ? dateFmt.format(expiresAt.toLocal()) : '-',
              valueColor: expired ? context.color.error : null,
            ),
            _InfoRow(
              icon: Icons.schedule_rounded,
              label: _local(context, ar: 'الوقت المتبقي', en: 'Time remaining'),
              value: _remainingLabel(context, expiresAt),
            ),
            if (pricing?.durationDays != null ||
                pricing?.amount != null ||
                model.durationDays != null ||
                model.price != null) ...[
              const SizedBox(height: 12),
              _PlanTile(
                amount: pricing?.amount ?? model.price,
                currency: pricing?.currency ?? model.currency,
                durationDays: pricing?.durationDays ?? model.durationDays,
              ),
            ],
            const SizedBox(height: 12),
            _BenefitsList(features: _buildBenefits(model, offering: offering)),
            const SizedBox(height: 12),
            _FieldChecklist(
              fields: typeFields,
              filledValues: filledValues,
              accountType: accountType,
            ),
            const SizedBox(height: 4),
            if (model.status == null || model.status!.isEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () =>
                      _startVerificationFlow(context, accountType: accountType),
                  icon: const Icon(Icons.edit_document),
                  label: Text(
                    _local(
                      context,
                      ar: 'إكمال الطلب الآن',
                      en: 'Complete request now',
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  Future<void> _startVerificationFlow(BuildContext context,
      {required String accountType}) async {
    final state = _fieldsCubit.state;
    if (state is FetchSellerVerificationFieldFail) {
      HelperUtils.showSnackBarMessage(context, state.error.toString());
      _fieldsCubit.fetchSellerVerificationFields(accountType: accountType);
      return;
    }

    if (state is! FetchSellerVerificationFieldSuccess) {
      _fieldsCubit.fetchSellerVerificationFields(accountType: accountType);
      return;
    }

    final List<VerificationFieldModel> fields = state.fields;
    if (fields.isEmpty) {
      HelperUtils.showSnackBarMessage(
          context,
          _local(context,
              ar: 'لا توجد حقول مطلوبة من الخادم حالياً',
              en: 'No verification fields available from server.'));
      return;
    }

    Navigator.of(context).pop();
    Navigator.of(context).pushNamed(
      Routes.sellerVerificationScreen,
      arguments: {
        "isResubmitted": false,
        "accountType": accountType,
      },
    );
  }

  List<String> _buildBenefits(VerificationRequestModel model,
      {VerificationOffering? offering}) {
    final List<String> collected = [];
    if (offering?.benefits.isNotEmpty == true) {
      collected.addAll(offering!.benefits);
    }

    if (collected.isEmpty) {
      collected.addAll([
        _local(context,
            ar: 'شارة موثقة أمام اسمك',
            en: 'Verified badge across your profile'),
        _local(context,
            ar: 'ثقة أعلى لدى المشترين', en: 'Higher trust with buyers'),
        _local(context,
            ar: 'أولوية في البحث والإعلانات',
            en: 'Priority placement in search and ads'),
      ]);
    }

    final VerificationPricing? pricing = offering?.pricing;
    final int? duration = pricing?.durationDays ?? model.durationDays;
    final double? price = pricing?.amount ?? model.price;
    final String? currency = pricing?.currency ?? model.currency;

    if (duration != null) {
      collected.add(
        _local(
          context,
          ar: 'صلاحية التوثيق $duration يوم',
          en: 'Verification valid for $duration days',
        ),
      );
    }

    if (price != null && price != 0) {
      final priceLabel = '${price.toStringAsFixed(2)} ${currency ?? ''}'.trim();
      collected.add(
        _local(
          context,
          ar: 'رسوم الاشتراك: $priceLabel',
          en: 'Subscription fee: $priceLabel',
        ),
      );
    }

    return collected;
  }

  List<VerificationFieldModel> _filterFieldsForAccountType(
      List<VerificationFieldModel> fields, String accountType) {
    final normalized = accountType.toLowerCase();
    return fields.where((field) {
      if (field.status == 0) return false;

      final String type = (field.type ?? '').toLowerCase();
      final String name = (field.name ?? '').toLowerCase();
      if (type.contains(normalized) || name.contains(normalized)) {
        return true;
      }
      return true;
    }).toList();
  }

  String _remainingLabel(BuildContext context, DateTime? expiresAt) {
    if (expiresAt == null) {
      return _local(context, ar: 'غير محدد', en: 'Not available');
    }
    final Duration diff = expiresAt.difference(DateTime.now());
    if (diff.isNegative) {
      return _local(context, ar: 'انتهى الاشتراك', en: 'Expired');
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

class _PlanTile extends StatelessWidget {
  final double? amount;
  final String? currency;
  final int? durationDays;

  const _PlanTile({this.amount, this.currency, this.durationDays});

  @override
  Widget build(BuildContext context) {
    final String priceLabel =
        amount != null ? '${amount!.toStringAsFixed(2)} ${currency ?? ''}' : '-';
    final String durationLabel = durationDays != null
        ? '$durationDays ${'days'.translate(context)}'
        : '-';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: context.color.secondaryColor,
        border: Border.all(
          color: context.color.textDefaultColor.withOpacity(0.08),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.workspace_premium,
              color: context.color.territoryColor, size: 26),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'subscription'.translate(context),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: context.color.textColorDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${'fee'.translate(context)}: $priceLabel • ${'duration'.translate(context)}: $durationLabel',
                  style: TextStyle(
                    fontSize: context.font.small,
                    color: context.color.textDefaultColor,
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

class _BenefitsList extends StatelessWidget {
  final List<String> features;

  const _BenefitsList({required this.features});

  @override
  Widget build(BuildContext context) {
    if (features.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'المزايا',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: context.color.textColorDark,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: features
              .map(
                (feature) => Chip(
                  label: Text(
                    feature,
                    style: TextStyle(
                      color: context.color.textColorDark,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  backgroundColor:
                      context.color.territoryColor.withOpacity(0.1),
                  side: BorderSide(
                    color: context.color.territoryColor.withOpacity(0.3),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _FieldChecklist extends StatelessWidget {
  final List<VerificationFieldModel> fields;
  final Map<int, VerificationFieldValues> filledValues;
  final String accountType;

  const _FieldChecklist({
    required this.fields,
    required this.filledValues,
    required this.accountType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.assignment_turned_in_outlined,
                size: 20, color: context.color.territoryColor),
            const SizedBox(width: 6),
            Text(
              'الحقول المطلوبة (${_accountLabel(context, accountType)})',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: context.color.textColorDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (fields.isEmpty)
          Text(
            'لا توجد حقول مطلوبة حاليًا',
            style: TextStyle(color: context.color.textDefaultColor),
          )
        else
          Column(
            children: fields.map((field) {
              final VerificationFieldValues? value = field.id != null
                  ? filledValues[field.id!]
                  : null;
              final bool isRequired = (field.required ?? 0) == 1;
              final bool hasValue =
                  value != null && (value.value?.toString().isNotEmpty ?? false);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      hasValue ? Icons.check_circle : Icons.radio_button_unchecked,
                      color:
                          hasValue ? Colors.green : context.color.textDefaultColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        field.name ?? '-',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: context.color.textColorDark,
                        ),
                      ),
                    ),
                    if (isRequired)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: context.color.error.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'إلزامي',
                          style: TextStyle(
                            color: context.color.error,
                            fontSize: context.font.small,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  String _accountLabel(BuildContext context, String accountType) {
    final normalized = accountType.toLowerCase();
    if (normalized.contains('real')) {
      return 'حساب عقاري';
    }
    if (normalized.contains('business') || normalized.contains('merchant')) {
      return 'حساب تجاري';
    }
    return 'حساب فردي';
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
