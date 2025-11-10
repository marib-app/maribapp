import 'package:flutter/material.dart';
import 'package:marib/data/model/wifi/wifi_network.dart';
import 'package:marib/data/model/wifi/wifi_plan.dart';
import 'package:marib/data/wifi/wifi_repository.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/errorFilter.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:marib/utils/hive_utils.dart';
import 'package:marib/utils/payment/bank_transfer_args.dart';
import 'package:marib/utils/payment/bank_transfer_screen.dart';

class WifiNetworkDetailsScreen extends StatefulWidget {
  const WifiNetworkDetailsScreen({super.key, required this.network});

  final WifiNetwork network;

  static Route route(WifiNetwork network) => MaterialPageRoute(
      builder: (_) => WifiNetworkDetailsScreen(network: network));

  @override
  State<WifiNetworkDetailsScreen> createState() =>
      _WifiNetworkDetailsScreenState();
}

class _WifiNetworkDetailsScreenState extends State<WifiNetworkDetailsScreen> {
  final WifiRepository _repository = const WifiRepository();
  late Future<List<WifiPlan>> _plansFuture;

  @override
  void initState() {
    super.initState();
    _plansFuture = _repository.fetchNetworkPlans(widget.network.id);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.color;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.network.name),
      ),
      backgroundColor: colors.backgroundColor,
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {
            _plansFuture = _repository.fetchNetworkPlans(widget.network.id);
          });
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _NetworkSummaryCard(network: widget.network),
            const SizedBox(height: 16),
            Text(
              'الخطط المتاحة',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: colors.textDefaultColor,
              ),
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<WifiPlan>>(
              future: _plansFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return _WifiPlaceholder(
                    icon: Icons.error_outline,
                    title: 'تعذر تحميل الخطط',
                    subtitle: ErrorFilter.check(snapshot.error).error,
                    actionLabel: 'إعادة المحاولة',
                    onActionPressed: () {
                      setState(() {
                        _plansFuture =
                            _repository.fetchNetworkPlans(widget.network.id);
                      });
                    },
                  );
                }
                final plans = snapshot.data ?? const <WifiPlan>[];
                if (plans.isEmpty) {
                  return const _WifiPlaceholder(
                    icon: Icons.inventory_2_outlined,
                    title: 'لا توجد خطط مسجلة',
                    subtitle:
                        'لم يتم نشر أي فئات لهذه الشبكة حتى الآن. عُد لاحقاً.',
                  );
                }

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.78,
                  ),
                  itemCount: plans.length,
                  itemBuilder: (context, index) {
                    final plan = plans[index];
                    return _PlanCategoryCard(
                      plan: plan,
                      onTap: () => _openPlanDetails(plan),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openPlanDetails(WifiPlan plan) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PlanDetailSheet(
        plan: plan,
        networkName: widget.network.name,
        onPurchase: () async {
          Navigator.of(context).pop();
          await _navigateToPayment(plan);
        },
      ),
    );
  }

  Future<void> _navigateToPayment(WifiPlan plan) async {
    final double amount = plan.price.toDouble();
    final String? currency = plan.currency;

    if (currency == null || currency.isEmpty || amount <= 0) {
      HelperUtils.showSnackBarMessage(
        context,
        'لا يمكن متابعة الدفع لهذه الخطة حالياً.',
      );
      return;
    }

    final String token = HiveUtils.getJWT();
    if (token.trim().isEmpty) {
      HelperUtils.showSnackBarMessage(
        context,
        'الرجاء تسجيل الدخول لمتابعة الدفع.',
      );
      return;
    }

    final BankTransferArgs args = BankTransferArgs(
      token: token,
      packageId: plan.id,
      amount: amount,
      currency: currency,
      packageType: 'wifi_plan',
      itemId: plan.id,
      purpose: 'wifi_plan',
      wifiPlanId: plan.id,
      serviceTitle: '${plan.name} - ${widget.network.name}',
      priceNote:
          plan.description ?? 'خطة ${plan.name} لشبكة ${widget.network.name}',
      allowedGateways: const [
        BankTransferGateway.wallet,
        BankTransferGateway.eastYemenBank,
      ],
      initialGateway: BankTransferGateway.wallet,
    );

    await BankTransferScreen.show(context, args);
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.borderColor.withOpacity(.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: colors.textLightColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.textLightColor,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }
}

class _WifiPlaceholder extends StatelessWidget {
  const _WifiPlaceholder({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onActionPressed,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onActionPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.color;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 44,
            backgroundColor: colors.territoryColor.withOpacity(.12),
            child: Icon(icon, size: 36, color: colors.territoryColor),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colors.textDefaultColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: colors.textLightColor,
            ),
          ),
          if (actionLabel != null && onActionPressed != null) ...[
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onActionPressed,
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

class _NetworkSummaryCard extends StatelessWidget {
  const _NetworkSummaryCard({required this.network});

  final WifiNetwork network;

  @override
  Widget build(BuildContext context) {
    final colors = context.color;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.borderColor.withOpacity(.35)),
        color: colors.secondaryColor,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            network.name,
            style: textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: colors.textDefaultColor,
            ),
          ),
          if (network.address?.isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                network.address!,
                style: textTheme.bodyMedium?.copyWith(
                  color: colors.textLightColor,
                ),
              ),
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (network.coverageKm != null)
                _InfoChip(
                  icon: Icons.radar_rounded,
                  label: '${network.coverageKm!.toStringAsFixed(1)} كم مدى',
                ),
              if (network.currencies.isNotEmpty)
                _InfoChip(
                  icon: Icons.payments_outlined,
                  label: network.currencies.join(' • '),
                ),
              if (network.contacts.isNotEmpty)
                _InfoChip(
                  icon: Icons.phone_in_talk_rounded,
                  label: network.contacts.first,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlanCategoryCard extends StatelessWidget {
  const _PlanCategoryCard({required this.plan, required this.onTap});

  final WifiPlan plan;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.color;
    final textTheme = Theme.of(context).textTheme;
    final int totalCodes =
        plan.codeBatches.fold(0, (sum, batch) => sum + batch.totalCodes);
    final int availableCodes =
        plan.codeBatches.fold(0, (sum, batch) => sum + batch.availableCodes);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: colors.borderColor.withOpacity(.4)),
                  color: colors.secondaryColor,
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      plan.price.toStringAsFixed(2),
                      style: textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: colors.textDefaultColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      plan.currency ?? '',
                      style: textTheme.bodySmall?.copyWith(
                        color: colors.textLightColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${availableCodes.toString().padLeft(2, '0')}/${totalCodes.toString().padLeft(2, '0')}',
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colors.territoryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              plan.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colors.textDefaultColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanDetailSheet extends StatelessWidget {
  const _PlanDetailSheet({
    required this.plan,
    required this.networkName,
    required this.onPurchase,
  });

  final WifiPlan plan;
  final String networkName;
  final VoidCallback onPurchase;

  @override
  Widget build(BuildContext context) {
    final colors = context.color;
    final textTheme = Theme.of(context).textTheme;
    final Map<String, dynamic> meta = plan.meta ?? const <String, dynamic>{};
    final int totalCodes =
        plan.codeBatches.fold(0, (sum, batch) => sum + batch.totalCodes);
    final int availableCodes =
        plan.codeBatches.fold(0, (sum, batch) => sum + batch.availableCodes);

    final String? speedLabel = _resolveSpeed(meta);
    final String? quotaLabel = _resolveQuota(plan, meta);
    final String? validityLabel = _resolveValidity(plan, meta);

    final List<_PlanSpec> specs = <_PlanSpec>[
      if (speedLabel != null)
        _PlanSpec(
          icon: Icons.speed_rounded,
          title: 'سرعة الكرت',
          value: speedLabel,
        ),
      if (quotaLabel != null)
        _PlanSpec(
          icon: Icons.data_usage_rounded,
          title: 'السعة المتاحة',
          value: quotaLabel,
        ),
      if (validityLabel != null)
        _PlanSpec(
          icon: Icons.schedule_rounded,
          title: 'مدة الصلاحية',
          value: validityLabel,
        ),
      if (totalCodes > 0)
        _PlanSpec(
          icon: Icons.qr_code_2_rounded,
          title: 'الأكواد المتوفرة',
          value: '$availableCodes / $totalCodes',
        ),
    ];

    final List<String> benefits = plan.benefits;
    final String? description =
        plan.description != null && plan.description!.trim().isNotEmpty
            ? plan.description!.trim()
            : null;

    final bool canPurchase = availableCodes > 0;

    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: colors.backgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  height: 4,
                  width: 48,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: colors.borderColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              Text(
                plan.name,
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colors.textDefaultColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                networkName,
                style: textTheme.bodyMedium?.copyWith(
                  color: colors.textLightColor,
                ),
              ),
              const SizedBox(height: 16),
              _PriceCard(
                plan: plan,
                availableCodes: availableCodes,
                totalCodes: totalCodes,
              ),
              const SizedBox(height: 20),
              if (specs.isNotEmpty) ...[
                Text(
                  'تفاصيل الخطة',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colors.textDefaultColor,
                  ),
                ),
                const SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: specs.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 2.9,
                  ),
                  itemBuilder: (context, index) =>
                      _PlanSpecTile(spec: specs[index]),
                ),
                const SizedBox(height: 20),
              ],
              if (description != null) ...[
                Text(
                  'نبذة عن الفئة',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colors.textDefaultColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colors.textLightColor,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
              ],
              if (benefits.isNotEmpty) ...[
                Text(
                  'المزايا',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colors.textDefaultColor,
                  ),
                ),
                const SizedBox(height: 8),
                Column(
                  children: benefits
                      .map(
                        (benefit) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.check_circle_rounded,
                                size: 18,
                                color: colors.territoryColor,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  benefit,
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: colors.textDefaultColor,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 20),
              ],
              FilledButton(
                onPressed: canPurchase ? onPurchase : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  backgroundColor: colors.territoryColor,
                  disabledBackgroundColor: colors.borderColor.withOpacity(.4),
                ),
                child: Text(
                  canPurchase ? 'شراء الآن' : 'نفدت الأكواد مؤقتاً',
                  style: textTheme.titleMedium?.copyWith(
                    color: colors.secondaryColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (!canPurchase)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'عند إضافة دفعة أكواد جديدة سنقوم بتنشيط هذا الخيار تلقائياً.',
                    style: textTheme.bodySmall?.copyWith(
                      color: colors.textLightColor,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String? _resolveSpeed(Map<String, dynamic> meta) {
    final dynamic label =
        meta['speed_label'] ?? meta['speed_text'] ?? meta['speed'];
    if (label != null && label.toString().trim().isNotEmpty) {
      return label.toString().trim();
    }

    final num? speed =
        _asNum(meta['speed_mbps'] ?? meta['speedMbps'] ?? meta['speedMb']);
    if (speed != null && speed > 0) {
      final bool isInt = speed % 1 == 0;
      final String value =
          isInt ? speed.toInt().toString() : speed.toStringAsFixed(1);
      return '$value ميجابت/ث';
    }

    return null;
  }

  String? _resolveQuota(WifiPlan plan, Map<String, dynamic> meta) {
    if (plan.isUnlimited) {
      return 'استخدام غير محدود';
    }

    if (plan.dataCapGb != null) {
      final num cap = plan.dataCapGb!;
      final bool isInt = cap % 1 == 0;
      final String formatted =
          isInt ? cap.toInt().toString() : cap.toStringAsFixed(1);
      return '$formatted جيجابايت';
    }

    final dynamic label =
        meta['data_allowance_label'] ?? meta['data_cap_label'] ?? meta['quota'];
    if (label != null && label.toString().trim().isNotEmpty) {
      return label.toString();
    }

    final num? allowanceMb = _asNum(meta['data_allowance_mb']);
    if (allowanceMb != null) {
      final double gb = allowanceMb / 1024;
      return gb >= 1
          ? '${gb.toStringAsFixed(1)} جيجابايت'
          : '$allowanceMb ميجابايت';
    }

    return null;
  }

  String? _resolveValidity(WifiPlan plan, Map<String, dynamic> meta) {
    if (plan.durationDays != null && plan.durationDays! > 0) {
      final int days = plan.durationDays!;
      return days == 1 ? 'يوم واحد' : '$days يوم';
    }

    final dynamic label =
        meta['validity_label'] ?? meta['duration_label'] ?? meta['duration'];
    if (label != null && label.toString().trim().isNotEmpty) {
      return label.toString();
    }

    final num? durationHours = _asNum(meta['duration_hours']);
    if (durationHours != null && durationHours > 0) {
      if (durationHours >= 24) {
        final double days = durationHours / 24;
        final int rounded = days.ceil();
        return rounded == 1 ? 'يوم واحد' : '$rounded يوم';
      }
      return '${durationHours.toStringAsFixed(0)} ساعة';
    }

    return null;
  }

  num? _asNum(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value;
    }
    return num.tryParse(value.toString());
  }
}

class _PlanSpec {
  const _PlanSpec({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;
}

class _PlanSpecTile extends StatelessWidget {
  const _PlanSpecTile({required this.spec});

  final _PlanSpec spec;

  @override
  Widget build(BuildContext context) {
    final colors = context.color;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: colors.secondaryColor,
        border: Border.all(color: colors.borderColor.withOpacity(.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(spec.icon, size: 20, color: colors.territoryColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  spec.title,
                  style: textTheme.bodySmall?.copyWith(
                    color: colors.textLightColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  spec.value,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colors.textDefaultColor,
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

class _PriceCard extends StatelessWidget {
  const _PriceCard({
    required this.plan,
    required this.availableCodes,
    required this.totalCodes,
  });

  final WifiPlan plan;
  final int availableCodes;
  final int totalCodes;

  @override
  Widget build(BuildContext context) {
    final colors = context.color;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: colors.secondaryColor,
        border: Border.all(color: colors.borderColor.withOpacity(.45)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.territoryColor.withOpacity(.15),
            ),
            child: Icon(Icons.sell_outlined, color: colors.territoryColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${plan.price.toStringAsFixed(2)} ${plan.currency ?? ''}',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colors.textDefaultColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  totalCodes > 0
                      ? 'الأكواد المتاحة: $availableCodes من $totalCodes'
                      : 'سيتم إرسال الكود عبر التطبيق بعد الدفع',
                  style: textTheme.bodySmall?.copyWith(
                    color: colors.textLightColor,
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
