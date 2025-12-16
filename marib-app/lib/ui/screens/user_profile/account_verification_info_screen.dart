import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:marib/app/routes.dart';
import 'package:marib/data/cubits/seller/fetch_seller_verification_field.dart';
import 'package:marib/data/cubits/seller/fetch_verification_request_cubit.dart';
import 'package:marib/data/model/custom_field/custom_field_model.dart';
import 'package:marib/data/model/verification_metadata.dart';
import 'package:marib/data/model/verification_request_model.dart';
import 'package:marib/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/app_icon.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:marib/utils/hive_utils.dart';
import 'package:marib/utils/ui_utils.dart';

class AccountVerificationInfoScreen extends StatefulWidget {
  const AccountVerificationInfoScreen({super.key});

  static Route route(RouteSettings settings) {
    return BlurredRouter(builder: (_) => const AccountVerificationInfoScreen());
  }

  @override
  State<AccountVerificationInfoScreen> createState() =>
      _AccountVerificationInfoScreenState();
}

class _AccountVerificationInfoScreenState
    extends State<AccountVerificationInfoScreen> {
  late final FetchSellerVerificationFieldsCubit _fieldsCubit;
  late final FetchVerificationRequestsCubit _requestsCubit;

  @override
  void initState() {
    super.initState();
    _fieldsCubit = FetchSellerVerificationFieldsCubit();
    _requestsCubit = FetchVerificationRequestsCubit();

    final accountType = HiveUtils.getAccountTypeLower();
    _fieldsCubit.fetchSellerVerificationFields(
      accountType: accountType,
      forceRefresh: true,
    );
    _requestsCubit.fetchVerificationRequests();
  }

  @override
  void dispose() {
    _fieldsCubit.close();
    _requestsCubit.close();
    super.dispose();
  }

  Future<void> _startVerificationFlow(BuildContext context) async {
    final state = _fieldsCubit.state;
    if (state is FetchSellerVerificationFieldFail) {
      HelperUtils.showSnackBarMessage(context, state.error.toString());
      _fieldsCubit.fetchSellerVerificationFields(
        accountType: HiveUtils.getAccountTypeLower(),
      );
      return;
    }

    if (state is! FetchSellerVerificationFieldSuccess) {
      _fieldsCubit.fetchSellerVerificationFields(
        accountType: HiveUtils.getAccountTypeLower(),
      );
      return;
    }

    final List<VerificationFieldModel> fields = state.fields;
    if (fields.isEmpty) {
      HelperUtils.showSnackBarMessage(
        context,
        _local(
          context,
          ar: 'لا توجد حقول مطلوبة من الخادم حالياً',
          en: 'No verification fields available from server.',
        ),
      );
      return;
    }

    Navigator.pushNamed(
      context,
      Routes.sellerVerificationScreen,
      arguments: {
        "isResubmitted": false,
        "accountType": state.accountType,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color accent = context.color.territoryColor;

    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _fieldsCubit),
        BlocProvider.value(value: _requestsCubit),
      ],
      child: Scaffold(
        backgroundColor: context.color.backgroundColor,
        appBar: UiUtils.buildAppBar(
          context,
          showBackButton: true,
          title: "توثيق الحساب",
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HeroCard(accent: accent),
              const SizedBox(height: 12),
              _StatusSection(buildStatusCard: _buildStatusCard),
              const SizedBox(height: 12),
              _DynamicPlanSection(
                onStart: () => _startVerificationFlow(context),
                buildBenefits: _buildBenefits,
              ),
              const SizedBox(height: 16),
              _SectionCard(
                title: "لماذا التوثيق؟",
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: const [
                    _BenefitChip("موثوقية أعلى لدى المشترين"),
                    _BenefitChip("شارة موثقة أمام اسمك"),
                    _BenefitChip("أولوية في نتائج البحث والإعلانات"),
                    _BenefitChip("معدل إبلاغ أقل وحماية لحسابك"),
                  ],
                ),
              ),
              _SectionCard(
                title: "التكلفة وما يشمله التوثيق",
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "رسوم التوثيق تُحسب حسب سياسة المنصة وتشمل مراجعة البيانات الرسمية، التأكد من هوية المالك، والتواصل للتحقق من النشاط.",
                      style: TextStyle(
                        color: context.color.textDefaultColor.withOpacity(0.85),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(Icons.timer_outlined, size: 18, color: accent),
                        const SizedBox(width: 8),
                        Text(
                          "مدة المراجعة عادة من 1 إلى 3 أيام عمل.",
                          style: TextStyle(
                            color: context.color.textDefaultColor.withOpacity(0.85),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _SectionCard(
                title: "كيف يعمل التوثيق؟",
                child: Column(
                  children: const [
                    _StepRow(
                      index: 1,
                      title: "إرسال الطلب",
                      subtitle: "نطلب منك رفع الهوية أو السجل التجاري وتعبئة بيانات المتجر.",
                    ),
                    _StepRow(
                      index: 2,
                      title: "مراجعة فريقنا",
                      subtitle: "يتم التحقق من المستندات ومطابقتها مع بيانات الحساب.",
                    ),
                    _StepRow(
                      index: 3,
                      title: "الحصول على الشارة",
                      subtitle: "ستظهر علامة التوثيق أمام اسمك في الإعلانات وصفحة البائع.",
                    ),
                  ],
                ),
              ),
              _SectionCard(
                title: "المتطلبات الأساسية",
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    _RequirementRow("هوية وطنية أو سجل تجاري ساري"),
                    _RequirementRow("رقم جوال موثق قابل للتواصل"),
                    _RequirementRow("عنوان واضح يظهر في إدارة العناوين"),
                    _RequirementRow("حساب نشط خالٍ من المخالفات الكبيرة"),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              UiUtils.buildButton(
                context,
                onPressed: () => _startVerificationFlow(context),
                height: 48,
                radius: 12,
                buttonTitle: "طلب التوثيق",
              ),
              const SizedBox(height: 10),
              Center(
                child: Text(
                  "ستتمكن من متابعة حالة الطلب وإرفاق أي ملاحظات إضافية من نفس الشاشة.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: context.color.textDefaultColor.withOpacity(0.8),
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard(VerificationRequestModel model) {
    final locale = Localizations.maybeLocaleOf(context);
    final String localeName = locale != null ? locale.toLanguageTag() : 'en_US';
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

    return _SectionCard(
      title: _local(
        context,
        ar: 'حالة التوثيق الحالية',
        en: 'Current verification status',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusText,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: statusColor,
                        fontSize: context.font.large,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _local(
                        context,
                        ar: 'يمكنك الإطلاع على صلاحية التوثيق وزمن انتهاءه.',
                        en: 'See your verification validity and expiry timeline.',
                      ),
                      style: TextStyle(
                        color: context.color.textDefaultColor,
                        fontSize: context.font.small,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusChip(label: statusText, color: statusColor),
            ],
          ),
          const SizedBox(height: 12),
          _InfoRow(
            icon: Icons.event_available_rounded,
            label: _local(context, ar: 'تاريخ التفعيل', en: 'Activated on'),
            value: approvedAt != null ? dateFmt.format(approvedAt.toLocal()) : '-',
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
        ],
      ),
    );
  }

  List<String> _buildBenefits({VerificationOffering? offering}) {
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
    final int? duration = pricing?.durationDays;
    final double? price = pricing?.amount;
    final String? currency = pricing?.currency;

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

  String _local(BuildContext context, {required String ar, required String en}) {
    final locale = Localizations.maybeLocaleOf(context);
    if ((locale?.languageCode ?? 'ar').toLowerCase().startsWith('ar')) {
      return ar;
    }
    return en;
  }
}

class _StatusSection extends StatelessWidget {
  final Widget Function(VerificationRequestModel model) buildStatusCard;

  const _StatusSection({required this.buildStatusCard});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FetchVerificationRequestsCubit, FetchVerificationRequestState>(
      builder: (context, state) {
        if (state is FetchVerificationRequestInProgress ||
            state is FetchVerificationRequestInitial) {
          return const _SectionCard(
            title: 'حالة التوثيق الحالية',
            child: Center(child: CircularProgressIndicator(strokeWidth: 2.2)),
          );
        }

        if (state is FetchVerificationRequestFail) {
          return _SectionCard(
            title: 'حالة التوثيق الحالية',
            child: Text(
              state.error.toString(),
              style: TextStyle(color: context.color.error),
            ),
          );
        }

        if (state is FetchVerificationRequestSuccess && state.data != null) {
          return buildStatusCard(state.data!);
        }

        return _SectionCard(
          title: 'حالة التوثيق الحالية',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'لم تقم بتقديم طلب توثيق بعد',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: context.color.textColorDark,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'يمكنك إرسال طلب جديد من الأسفل لبدء عملية التوثيق.',
                style: TextStyle(color: context.color.textDefaultColor),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DynamicPlanSection extends StatelessWidget {
  final VoidCallback onStart;
  final List<String> Function({VerificationOffering? offering}) buildBenefits;

  const _DynamicPlanSection({
    required this.onStart,
    required this.buildBenefits,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FetchSellerVerificationFieldsCubit,
        FetchSellerVerificationFieldState>(
      builder: (context, state) {
        if (state is FetchSellerVerificationFieldInProgress ||
            state is FetchSellerVerificationFieldInitial) {
          return const _SectionCard(
            title: 'تفاصيل الاشتراك',
            child: Center(child: CircularProgressIndicator(strokeWidth: 2.2)),
          );
        }

        if (state is FetchSellerVerificationFieldFail) {
          return _SectionCard(
            title: 'تفاصيل الاشتراك',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.error.toString(),
                  style: TextStyle(color: context.color.error),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => BlocProvider.of<FetchSellerVerificationFieldsCubit>(
                    context,
                  ).fetchSellerVerificationFields(
                        accountType: HiveUtils.getAccountTypeLower(), forceRefresh: true),
                  icon: const Icon(Icons.refresh),
                  label: const Text('إعادة المحاولة'),
                ),
              ],
            ),
          );
        }

        if (state is! FetchSellerVerificationFieldSuccess) {
          return const SizedBox.shrink();
        }

        final VerificationOffering? offering =
            state.metadata.findForAccountType(state.accountType);
        final List<VerificationFieldModel> fields = state.fields;
        final Map<int, VerificationFieldValues> filledValues = const {};

        return _SectionCard(
          title: 'تفاصيل الاشتراك',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (offering?.pricing != null)
                _PlanTile(
                  amount: offering?.pricing.amount,
                  currency: offering?.pricing.currency,
                  durationDays: offering?.pricing.durationDays,
                ),
              const SizedBox(height: 10),
              _BenefitsList(features: buildBenefits(offering: offering)),
              const SizedBox(height: 12),
              _FieldChecklist(
                fields: fields,
                filledValues: filledValues,
                accountType: state.accountType,
              ),
              const SizedBox(height: 10),
              UiUtils.buildButton(
                context,
                onPressed: onStart,
                buttonTitle: 'بدء تقديم الطلب',
                height: 44,
                radius: 12,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HeroCard extends StatelessWidget {
  final Color accent;

  const _HeroCard({required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: context.color.secondaryColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            height: 58,
            width: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withOpacity(0.12),
            ),
            alignment: Alignment.center,
            child: UiUtils.getSvg(
              AppIcons.userVerificationIcon,
              fit: BoxFit.none,
              color: accent,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "فعّل شارة التوثيق",
                  style: TextStyle(
                    color: context.color.textDefaultColor,
                    fontWeight: FontWeight.w800,
                    fontSize: context.font.large,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "أثبت هويتك وارفع ثقة عملائك مع شارة توثيق رسمية تظهر في كل إعلان.",
                  style: TextStyle(
                    color: context.color.textLightColor,
                    height: 1.4,
                    fontSize: context.font.small + 1,
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

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: context.color.secondaryColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.color.textDefaultColor.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: context.color.textColorDark,
              fontWeight: FontWeight.w800,
              fontSize: context.font.large,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _BenefitChip extends StatelessWidget {
  final String label;
  const _BenefitChip(this.label);

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(
        label,
        style: TextStyle(
          color: context.color.textColorDark,
          fontWeight: FontWeight.w600,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      backgroundColor: context.color.territoryColor.withOpacity(0.1),
      side: BorderSide(color: context.color.territoryColor.withOpacity(0.3)),
    );
  }
}

class _StepRow extends StatelessWidget {
  final int index;
  final String title;
  final String subtitle;

  const _StepRow({
    required this.index,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: context.color.territoryColor.withOpacity(0.12),
            child: Text(
              index.toString(),
              style: TextStyle(
                color: context.color.territoryColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: context.color.textColorDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: context.color.textDefaultColor,
                    height: 1.4,
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

class _RequirementRow extends StatelessWidget {
  final String label;
  const _RequirementRow(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: context.color.textDefaultColor),
            ),
          ),
        ],
      ),
    );
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
