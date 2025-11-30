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

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'الفئات',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colors.textDefaultColor,
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: mutating ? null : onAddPlan,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.territoryColor,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.add),
                label: const Text('إضافة فئة جديدة'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (plans.isEmpty)
            Text(
              'لا توجد فئات بعد.',
              style:
                  textTheme.bodyMedium?.copyWith(color: colors.textLightColor),
            )
          else
            Column(
              children: plans.map((plan) {
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
                            const SizedBox(height: 4),
                            Text(
                              '${plan.price} ${plan.currency ?? ''}',
                              style: textTheme.bodySmall?.copyWith(
                                color: colors.textLightColor,
                              ),
                            ),
                          ],
                        ),
                      ),
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
    );
  }
}
