import 'package:flutter/material.dart';
import 'package:marib/data/model/wifi/wifi_plan.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';

class ManagePlansTab extends StatelessWidget {
  const ManagePlansTab({
    super.key,
    required this.plans,
    required this.onAddPlan,
    required this.onDeletePlan,
    required this.mutating,
  });

  final List<WifiPlan> plans;
  final VoidCallback onAddPlan;
  final void Function(WifiPlan) onDeletePlan;
  final bool mutating;

  @override
  Widget build(BuildContext context) {
    final colors = context.color;
    final textTheme = Theme.of(context).textTheme;

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'الفئات المتاحة',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colors.textDefaultColor,
                ),
              ),
              const SizedBox(height: 12),
              if (plans.isEmpty)
                Text(
                  'لا توجد فئات مضافة حتى الآن.',
                  style: textTheme.bodyMedium
                      ?.copyWith(color: colors.textLightColor),
                )
              else
                Column(
                  children: plans.map((plan) {
                    final int totalCodes =
                        plan.codeBatches.fold<int>(0, (sum, b) => sum + b.totalCodes);
                    final int availableCodes =
                        plan.codeBatches.fold<int>(0, (sum, b) => sum + b.availableCodes);
                    final String counter = '$availableCodes/$totalCodes';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: colors.borderColor.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  plan.name,
                                  style: textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: colors.textDefaultColor,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${plan.price} ${plan.currency ?? ''}',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colors.textLightColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                counter,
                                style: textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: colors.textDefaultColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'متاح / إجمالي',
                                style: textTheme.bodySmall?.copyWith(
                                  color: colors.textLightColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 100),
                          IconButton(
                            onPressed: mutating ? null : () => onDeletePlan(plan),
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.redAccent),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: mutating ? null : onAddPlan,
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.territoryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 2,
              ),
              icon: const Icon(Icons.add),
              label: const Text('إضافة فئة جديدة'),
            ),
          ),
        ),
      ],
    );
  }
}
