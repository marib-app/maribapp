import 'package:flutter/material.dart';
import 'package:marib/utils/extensions/extensions.dart';

import 'package:marib/ui/theme/theme.dart';

class RadiusSheet extends StatelessWidget {
  final double radiusKm;
  final ValueChanged<double> onChanged;
  final VoidCallback onDisable;
  final VoidCallback onApply;

  const RadiusSheet({
    super.key,
    required this.radiusKm,
    required this.onChanged,
    required this.onDisable,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    final brand = context.color.territoryColor;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.36,
      minChildSize: 0.28,
      maxChildSize: 0.6,
      builder: (_, controller) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          ),
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).dividerColor.withOpacity(.4),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'حدد نطاق البحث (كم)',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              Slider(
                value: radiusKm.clamp(1, 50),
                onChanged: onChanged,
                min: 1,
                max: 50,
                divisions: 49,
                label: '${radiusKm.toStringAsFixed(0)} كم',
                activeColor: brand,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '1 كم',
                    style: TextStyle(color: Theme.of(context).hintColor),
                  ),
                  Text(
                    '${radiusKm.toStringAsFixed(0)} كم',
                    style: TextStyle(fontWeight: FontWeight.bold, color: brand),
                  ),
                  Text(
                    '50 كم',
                    style: TextStyle(color: Theme.of(context).hintColor),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onDisable,
                      child: const Text('تعطيل'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onApply,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: brand,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('تطبيق'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}