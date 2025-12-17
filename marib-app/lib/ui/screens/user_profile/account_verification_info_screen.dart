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
import 'package:marib/utils/merchant_display_helper.dart';
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
        'accountVerificationFieldsUnavailable'.translate(context),
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
          title: 'accountVerificationTitle'.translate(context),
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
              const _DynamicPlanSection(),
              const SizedBox(height: 16),
              _SectionCard(
                title: 'accountVerificationWhyTitle'.translate(context),
                child: Text(
                  'accountVerificationWhyDescription'.translate(context),
                  style: TextStyle(
                    color: context.color.textDefaultColor.withOpacity(0.9),
                    height: 1.5,
                  ),
                ),
              ),
              _SectionCard(
                title: 'accountVerificationCostTitle'.translate(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'accountVerificationCostDescription'.translate(context),
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
                          'accountVerificationReviewTimeline'.translate(context),
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
                title: 'accountVerificationHowTitle'.translate(context),
                child: Column(
                  children: [
                    _StepRow(
                      index: 1,
                      title: 'accountVerificationStepSubmitTitle'
                          .translate(context),
                      subtitle: 'accountVerificationStepSubmitSubtitle'
                          .translate(context),
                    ),
                    _StepRow(
                      index: 2,
                      title: 'accountVerificationStepReviewTitle'
                          .translate(context),
                      subtitle: 'accountVerificationStepReviewSubtitle'
                          .translate(context),
                    ),
                    _StepRow(
                      index: 3,
                      title: 'accountVerificationStepBadgeTitle'
                          .translate(context),
                      subtitle: 'accountVerificationStepBadgeSubtitle'
                          .translate(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              UiUtils.buildButton(
                context,
                onPressed: () => _startVerificationFlow(context),
                height: 48,
                radius: 12,
                buttonTitle: 'accountVerificationCta'.translate(context),
              ),
              const SizedBox(height: 10),
              Center(
                child: Text(
                  'accountVerificationFollowupNote'.translate(context),
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
    final bool isRejected = (model.status ?? '').toLowerCase().trim() == 'rejected';
    final String? rejectionReason = model.rejectionReason?.trim();
    final String statusHint = isRejected
        ? 'accountVerificationRejectedHint'.translate(context)
        : 'accountVerificationValidityHint'.translate(context);

    final Color statusColor = expired
        ? context.color.error
        : _statusColor(model.status, context);
    final String statusText =
        expired ? 'expired'.translate(context) : _statusLabel(model.status, context);

    return _SectionCard(
      title: 'accountVerificationCurrentStatusTitle'.translate(context),
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
                      statusHint,
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
          if (isRejected) ...[
            Text(
              'accountVerificationRejectionReason'.translate(context),
              style: TextStyle(
                color: context.color.textColorDark,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              (rejectionReason != null && rejectionReason.isNotEmpty)
                  ? rejectionReason
                  : 'accountVerificationNoReason'.translate(context),
              style: TextStyle(
                color: context.color.textDefaultColor,
                height: 1.4,
              ),
            ),
          ] else ...[
            _InfoRow(
              icon: Icons.event_available_rounded,
              label: 'accountVerificationActivatedOn'.translate(context),
              value: approvedAt != null ? dateFmt.format(approvedAt.toLocal()) : '-',
            ),
            _InfoRow(
              icon: Icons.event_busy_rounded,
              label: 'accountVerificationExpiresOn'.translate(context),
              value: expiresAt != null ? dateFmt.format(expiresAt.toLocal()) : '-',
              valueColor: expired ? context.color.error : null,
            ),
            _InfoRow(
              icon: Icons.schedule_rounded,
              label: 'accountVerificationTimeRemaining'.translate(context),
              value: _remainingLabel(context, expiresAt),
            ),
          ],
        ],
      ),
    );
  }

  String _remainingLabel(BuildContext context, DateTime? expiresAt) {
    if (expiresAt == null) {
      return 'notAvailable'.translate(context);
    }
    final Duration diff = expiresAt.difference(DateTime.now());
    if (diff.isNegative) {
      return 'expired'.translate(context);
    }

    final int days = diff.inDays;
    final int hours = diff.inHours.remainder(24);
    final int minutes = diff.inMinutes.remainder(60);
    final List<String> parts = [];

    if (days > 0) {
      parts.add(
          '$days ${days == 1 ? 'dayLabel'.translate(context) : 'daysLabel'.translate(context)}');
    }
    if (hours > 0) {
      parts.add(
          '$hours ${hours == 1 ? 'hourLabel'.translate(context) : 'hoursLabel'.translate(context)}');
    }
    if (parts.isEmpty) {
      parts.add(
          '$minutes ${minutes == 1 ? 'minuteLabel'.translate(context) : 'minutesLabel'.translate(context)}');
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
          return _SectionCard(
            title: 'accountVerificationCurrentStatusTitle'.translate(context),
            child: const Center(child: CircularProgressIndicator(strokeWidth: 2.2)),
          );
        }

        if (state is FetchVerificationRequestFail) {
          return _SectionCard(
            title: 'accountVerificationCurrentStatusTitle'.translate(context),
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
          title: 'accountVerificationCurrentStatusTitle'.translate(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'accountVerificationNoRequestTitle'.translate(context),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: context.color.textColorDark,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'accountVerificationNoRequestSubtitle'.translate(context),
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
  const _DynamicPlanSection();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FetchSellerVerificationFieldsCubit,
        FetchSellerVerificationFieldState>(
      builder: (context, state) {
        if (state is FetchSellerVerificationFieldInProgress ||
            state is FetchSellerVerificationFieldInitial) {
          return _SectionCard(
            title: 'accountVerificationPlanDetailsTitle'.translate(context),
            child: const Center(child: CircularProgressIndicator(strokeWidth: 2.2)),
          );
        }

        if (state is FetchSellerVerificationFieldFail) {
          return _SectionCard(
            title: 'accountVerificationPlanDetailsTitle'.translate(context),
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
                  label: Text('retry'.translate(context)),
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
        final double? amount = offering?.pricing?.amount;
        final int durationDays = offering?.pricing?.durationDays ?? 30;
        final String currency = (offering?.pricing?.currency?.isNotEmpty == true)
            ? offering!.pricing!.currency!
            : 'currencyYemeniRial'.translate(context);

        final String priceLabel = (amount != null && amount > 0)
            ? '${amount % 1 == 0 ? amount.toStringAsFixed(0) : amount.toStringAsFixed(2)} $currency'
            : 'X $currency';

        final String descriptionTemplate =
            'accountVerificationPlanDescription'.translate(context);
        final String description = descriptionTemplate
            .replaceFirst('{price}', priceLabel)
            .replaceFirst('{days}', durationDays.toString());

        return _SectionCard(
          title: 'accountVerificationPlanDetailsTitle'.translate(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                description,
                style: TextStyle(
                  color: context.color.textDefaultColor,
                  height: 1.5,
                ),
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
    final user = HiveUtils.getUserDetails();
    final bool isMerchant = (user.userType ?? 0) == 3;
    final String? profileImage = MerchantDisplayHelper.resolveProfileImage(
      isMerchant: isMerchant,
      store: user.store,
      fallbackImage: user.profile,
    );

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
          _ProfilePreview(accent: accent, profileImage: profileImage),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'accountVerificationHeroTitle'.translate(context),
                  style: TextStyle(
                    color: context.color.textDefaultColor,
                    fontWeight: FontWeight.w800,
                    fontSize: context.font.large,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'accountVerificationHeroSubtitle'.translate(context),
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

class _ProfilePreview extends StatelessWidget {
  final Color accent;
  final String? profileImage;

  const _ProfilePreview({required this.accent, required this.profileImage});

  @override
  Widget build(BuildContext context) {
    final bool hasImage = profileImage != null && profileImage!.trim().isNotEmpty;

    final Widget avatar = Container(
      height: 62,
      width: 62,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: accent.withOpacity(0.18)),
        color: context.color.backgroundColor,
      ),
      child: ClipOval(
        child: hasImage
            ? UiUtils.getImage(
                profileImage!,
                height: 62,
                width: 62,
                fit: BoxFit.cover,
              )
            : Container(
                color: accent.withOpacity(0.08),
                alignment: Alignment.center,
                child: UiUtils.getSvg(
                  AppIcons.defaultPersonLogo,
                  fit: BoxFit.none,
                  color: accent,
                ),
              ),
      ),
    );

    return SizedBox(
      width: 78,
      height: 70,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            top: 4,
            child: avatar,
          ),
          Positioned(
            right: 2,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: context.color.secondaryColor,
                shape: BoxShape.circle,
                border: Border.all(color: accent.withOpacity(0.7)),
                boxShadow: [
                  BoxShadow(
                    color: accent.withOpacity(0.28),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: UiUtils.getSvg(
                AppIcons.verifiedIcon,
                width: 16,
                height: 16,
                color: accent,
              ),
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
