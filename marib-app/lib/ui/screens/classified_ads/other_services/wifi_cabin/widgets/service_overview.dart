import 'package:flutter/material.dart';

  import 'package:marib/utils/extensions/extensions.dart';

  class WifiServiceOverview extends StatelessWidget {
  const WifiServiceOverview({super.key});

  @override
  Widget build(BuildContext context) {
    final color = context.color;

    final TextStyle headingStyle = TextStyle(
      color: color.textDefaultColor,
      fontWeight: FontWeight.w700,
      fontSize: 16,
    );
    final TextStyle bodyStyle = TextStyle(
      color: color.textDefaultColor.withOpacity(0.85),
      height: 1.5,
    );

    final List<WifiOverviewPoint> points =  <WifiOverviewPoint>[
      WifiOverviewPoint('بوابة بيع تعمل على مدار 24 ساعة لطلبات الاشتراك.'),
      WifiOverviewPoint('إشعارات فورية لكل طلب جديد وتحديثات الحالة.'),
      WifiOverviewPoint('تحويل العوائد إلى محفظتك داخل التطبيق بسهولة.'),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.secondaryColor.withOpacity(0.18),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('كيف تعمل خدمة الشبكات؟', style: headingStyle),
          const SizedBox(height: 8),
          Text(
            'أضف شبكتك ليتم عرضها للباحثين عن الإنترنت المنزلي، وتابع الطلبات من مكان واحد.',
            style: bodyStyle,
          ),
          const SizedBox(height: 12),
          ...points.map((point) => WifiOverviewRow(point: point, color: color)),
          const SizedBox(height: 12),
          Text(
            'الرسوم تستقطع بعد اكتمال البيع فقط، ويمكنك سحب أرباحك في أي وقت.',
            style: bodyStyle,
          ),
        ],
      ),
    );
  }
}

class WifiOverviewPoint {
  const WifiOverviewPoint(this.text);

  final String text;
}

class WifiOverviewRow extends StatelessWidget {
  const WifiOverviewRow({super.key, required this.point, required this.color});

  final WifiOverviewPoint point;
  final ColorScheme color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Icon(
              Icons.check_circle_outline,
              size: 18,
              color: color.primaryColor,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              point.text,
              style: TextStyle(
                color: color.textDefaultColor.withOpacity(0.9),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}