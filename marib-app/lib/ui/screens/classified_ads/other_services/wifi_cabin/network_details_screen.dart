import 'package:flutter/material.dart';
import 'package:marib/data/model/wifi/wifi_network.dart';
import 'package:marib/data/model/wifi/wifi_plan.dart';
import 'package:marib/data/wifi/wifi_repository.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/errorFilter.dart';
import 'package:marib/utils/extensions/extensions.dart';


class WifiNetworkDetailsScreen extends StatefulWidget {
  const WifiNetworkDetailsScreen({super.key, required this.network});

  final WifiNetwork network;

  static Route route(WifiNetwork network) =>
      MaterialPageRoute(builder: (_) => WifiNetworkDetailsScreen(network: network));

  @override
  State<WifiNetworkDetailsScreen> createState() => _WifiNetworkDetailsScreenState();
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
                    return _PlanCategoryCard(plan: plan);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
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
  const _PlanCategoryCard({required this.plan});

  final WifiPlan plan;

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
        onTap: () {},
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
                      '${availableCodes.toString().padLeft(2, '0')}/${totalCodes.toString().padLeft(2, '0')}',
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colors.territoryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      plan.currency ?? '',
                      style: textTheme.bodySmall?.copyWith(
                        color: colors.textLightColor,
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
