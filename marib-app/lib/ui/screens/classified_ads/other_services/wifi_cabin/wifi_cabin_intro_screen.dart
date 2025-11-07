import 'package:flutter/material.dart';
import 'package:marib/ui/screens/classified_ads/other_services/wifi_cabin/wifi_cabin_request_screen.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/ui_utils.dart';

class WifiCabinIntroScreen extends StatelessWidget {
  const WifiCabinIntroScreen({super.key});

  Future<void> _openRequestFlow(BuildContext context) async {
    final bool? submitted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const WifiCabinRequestScreen()),
    );
    if (submitted == true && context.mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.color;
    final textTheme = Theme.of(context).textTheme;

    const List<_IntroHighlight> highlights = <_IntroHighlight>[
      _IntroHighlight(
        title: 'إدارة متكاملة للأكواد',
        description:
            'ارفع دفعات الأكواد، تتبع الرصيد المتبقي، وفعّل التنبيهات الذكية عند انخفاض المخزون.',
        icon: Icons.qr_code_scanner_rounded,
      ),
      _IntroHighlight(
        title: 'تقارير تشغيل دقيقة',
        description:
            'تابع المبيعات، البلاغات، وفاعلية الخطط في لوحة واحدة مرتبطة مباشرة بالتطبيق.',
        icon: Icons.timeline_rounded,
      ),
      _IntroHighlight(
        title: 'دعم تشغيلي وتسويقي',
        description:
            'فريق متخصص يساعدك في معايرة الشبكة، ضبط الأسعار، وصياغة العروض الترويجية.',
        icon: Icons.support_agent_rounded,
      ),
    ];

    return Scaffold(
      appBar: UiUtils.buildAppBar(
        context,
        showBackButton: true,
        title: 'شبكة Marib Wi-Fi',
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  colors: [
                    colors.headingAccentColor,
                    colors.territoryColor.withOpacity(.85),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: colors.territoryColor.withOpacity(.25),
                    blurRadius: 24,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'حوّل شبكتك اللاسلكية إلى مصدر دخل متكرر',
                    style: textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'اربط شبكتك بلوحة Marib لإدارة الأكواد، تسوية العمولات، ومراقبة الأداء من هاتفك مباشرة.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withOpacity(.92),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: const [
                      _IntroBadge(label: 'تقارير فورية'),
                      _IntroBadge(label: 'تنبيهات مخزون'),
                      _IntroBadge(label: 'أتمتة التسويات'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'لماذا يتم اختيار Marib؟',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: colors.textDefaultColor,
              ),
            ),
            const SizedBox(height: 12),
            ...highlights.map(
              (highlight) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _IntroHighlightCard(highlight: highlight),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: colors.borderColor.withOpacity(.35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'كيف تعمل الخدمة؟',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colors.textDefaultColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _IntroStep(
                    index: 1,
                    text:
                        'أرسل تفاصيل الشبكة (الموقع، التغطية، الشعار، حسابات التواصل).',
                  ),
                  _IntroStep(
                    index: 2,
                    text:
                        'أضف فئات الكروت وارفع ملف الأكواد لكل فئة بصيغة CSV أو XLSX.',
                  ),
                  _IntroStep(
                    index: 3,
                    text:
                        'يتم مراجعة الطلب خلال ساعات العمل وإبلاغك فور الربط مع لوحة التحكم.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            onPressed: () => _openRequestFlow(context),
            child: const Text(
              'أضف شبكتك الآن',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ),
      ),
    );
  }
}

class _IntroHighlight {
  const _IntroHighlight({
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final IconData icon;
}

class _IntroHighlightCard extends StatelessWidget {
  const _IntroHighlightCard({required this.highlight});

  final _IntroHighlight highlight;

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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: colors.territoryColor.withOpacity(.12),
            ),
            child: Icon(highlight.icon, color: colors.territoryColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  highlight.title,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colors.textDefaultColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  highlight.description,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colors.textLightColor,
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

class _IntroBadge extends StatelessWidget {
  const _IntroBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(40),
        color: Colors.white.withOpacity(.18),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _IntroStep extends StatelessWidget {
  const _IntroStep({required this.index, required this.text});

  final int index;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.color;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: colors.territoryColor.withOpacity(.12),
            child: Text(
              '$index',
              style: textTheme.titleSmall?.copyWith(
                color: colors.territoryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: textTheme.bodyMedium?.copyWith(
                color: colors.textDefaultColor,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
