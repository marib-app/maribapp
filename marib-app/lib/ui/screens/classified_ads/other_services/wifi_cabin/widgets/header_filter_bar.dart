part of 'package:marib/ui/screens/classified_ads/other_services/wifi_cabin/wifi_cabin_screen.dart';

class _HeaderFilterBar extends StatelessWidget {
  const _HeaderFilterBar({
    required this.locDenied,
    required this.maxKm,
    required this.onEnableLocation,
    required this.onKmChanged,
  });

  final bool locDenied;
  final double maxKm;
  final VoidCallback onEnableLocation;
  final ValueChanged<double> onKmChanged;

  @override
  Widget build(BuildContext context) {
    final color = context.color;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.secondaryColor.withOpacity(0.25),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.wifi_tethering, color: color.textDefaultColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  locDenied
                      ? 'عطّل الموقع — عرض نتائج عامة'
                      : 'اعرض الشبكات الأقرب لموقعك',
                  style: TextStyle(
                    color: color.textDefaultColor,
                    fontSize: 13,
                  ),
                ),
              ),
              if (locDenied)
                TextButton(
                  onPressed: onEnableLocation,
                  child: const Text('تشغيل الموقع'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'النطاق: ${maxKm.toStringAsFixed(0)} كم',
            style: TextStyle(color: color.textDefaultColor),
          ),
          Slider(
            value: maxKm.clamp(1, 50),
            min: 1,
            max: 50,
            divisions: 49,
            label: '${maxKm.toStringAsFixed(0)} كم',
            onChanged: onKmChanged,
          ),
        ],
      ),
    );
  }
}
