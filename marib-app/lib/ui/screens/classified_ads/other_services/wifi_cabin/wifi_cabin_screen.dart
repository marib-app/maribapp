import 'package:flutter/material.dart';
import 'package:marib/app/app_scroll_behavior.dart';
import 'package:marib/app/navigation/app_page_route.dart';
import 'package:marib/app/navigation/motion/route_motion.dart';
import 'package:marib/app/routes.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/ui_utils.dart';

class WifiCabinScreen extends StatefulWidget {
  const WifiCabinScreen({super.key});

  static Route route(RouteSettings settings) {
    return AppPageRoute.build(
      builder: (_) => const WifiCabinScreen(),
      settings: settings,
      maintainState: true,
      motionPattern: AppMotionPattern.glide,
    );
  }

  @override
  State<WifiCabinScreen> createState() => _WifiCabinScreenState();
}

class _WifiCabinScreenState extends State<WifiCabinScreen> {
  final List<_WifiStat> _stats = const [
    _WifiStat(
      title: 'الشبكات المفعّلة',
      value: '48+',
      description: 'تعمل حالياً في 9 محافظات',
      icon: Icons.router_rounded,
    ),
    _WifiStat(
      title: 'عدد المستخدمين',
      value: '12K',
      description: 'مستخدم نشط خلال آخر 30 يوم',
      icon: Icons.people_alt_rounded,
    ),
    _WifiStat(
      title: 'متوسط العمولة',
      value: '18%',
      description: 'تُخصم فقط بعد تحصيل المبيعات',
      icon: Icons.paid_rounded,
    ),
  ];

  final List<_WifiBenefit> _benefits = const [
    _WifiBenefit(
      title: 'تقارير فورية',
      description: 'لوحة تحكم مركزية توضح الأداء، السعة والبلاغات لحظة بلحظة.',
      icon: Icons.insights_rounded,
    ),
    _WifiBenefit(
      title: 'إدارة الأكواد',
      description:
          'رفع الدفعات، تتبع الأرصدة، والربط بين الأكواد والخطط بسهولة.',
      icon: Icons.qr_code_rounded,
    ),
    _WifiBenefit(
      title: 'تسوية ذكية',
      description:
          'تسويات مالية تلقائية بين المالك والمزود مع إشعارات بالعمولة المستحقة.',
      icon: Icons.swap_horiz_rounded,
    ),
    _WifiBenefit(
      title: 'دعم تشغيلي',
      description: 'فريق مخصّص لمساعدتك في ضبط الشبكة وحل أي بلاغ ميداني.',
      icon: Icons.support_agent_rounded,
    ),
  ];

  final List<String> _steps = const [
    'املأ نموذج طلب الشبكة مع تفاصيل التغطية والطاقة الاستيعابية.',
    'يعمل فريق التشغيل على تفعيل الحساب والتحقق من الأجهزة.',
    'احصل على لوحة التحكم وروابط البيع وابدأ إدارة الأكواد.',
  ];

  @override
  Widget build(BuildContext context) {
    final background = context.color.backgroundColor;

    return Scaffold(
      appBar: UiUtils.buildAppBar(
        context,
        showBackButton: true,
        title: 'wifiCabin'.translate(context),
      ),
      backgroundColor: background,
      body: DecoratedBox(
        decoration: BoxDecoration(color: background),
        child: SafeArea(
          bottom: false,
          child: CustomScrollView(
            physics: AppScrollBehavior.defaultPhysics,
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
                sliver: SliverList(
                  delegate: SliverChildListDelegate(
                    [
                      _buildHero(context),
                      const SizedBox(height: 24),
                      _buildSectionTitle(
                        context,
                        'لماذا شبكة Marib Wi‑Fi؟',
                      ),
                      const SizedBox(height: 12),
                      _buildStats(context),
                      const SizedBox(height: 24),
                      _buildSectionTitle(context, 'ماذا ستحصل عليه؟'),
                      const SizedBox(height: 12),
                      _buildBenefits(context),
                      const SizedBox(height: 24),
                      _buildSectionTitle(context, 'طريقة الربط'),
                      const SizedBox(height: 12),
                      _buildSteps(context),
                      const SizedBox(height: 24),
                      _buildSupportCard(context),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _WifiBottomCta(
        onAddNetwork: () => Navigator.pushNamed(context, Routes.contactUs),
        onViewGuidelines: () => UiUtils.launchURL(
          'https://maribservices.com/network-guidelines',
        ),
      ),
    );
  }

  Widget _buildHero(BuildContext context) {
    final colors = context.color;
    final textTheme = Theme.of(context).textTheme;

    return Container(
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
            color: colors.territoryColor.withOpacity(.2),
            blurRadius: 18,
            offset: const Offset(0, 10), 
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'أطلق شبكتك اللاسلكية مع Marib',
                      style: textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'حل متكامل لإدارة الأكواد، مراقبة المبيعات، والتواصل مع عملائك من مكان واحد.',
                      style: textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withOpacity(.9),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Icon(
                Icons.wifi_tethering_rounded,
                color: Colors.white,
                size: 52,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            alignment: WrapAlignment.start,
            spacing: 12,
            runSpacing: 12,
            children: const [
              _WifiBadge(label: 'سيرفرات مستقرة'),
              _WifiBadge(label: 'تقارير تلقائية'),
              _WifiBadge(label: 'دعم على مدار الساعة'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    final textTheme = Theme.of(context).textTheme;
    return Text(
      title,
      style: textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: context.color.textDefaultColor,
      ),
    );
  }

  Widget _buildStats(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;
        final crossAxisCount = isWide
            ? 3
            : constraints.maxWidth >= 480
                ? 2
                : 1;
        final itemWidth = (constraints.maxWidth - ((crossAxisCount - 1) * 12)) /
            crossAxisCount;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _stats
              .map(
                (stat) => SizedBox(
                  width: itemWidth,
                  child: _WifiStatCard(stat: stat),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildBenefits(BuildContext context) {
    return Column(
      children: _benefits
          .map((benefit) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _WifiBenefitCard(benefit: benefit),
              ))
          .toList(),
    );
  }

  Widget _buildSteps(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = context.color;

    return Column(
      children: _steps.asMap().entries.map((entry) {
        final index = entry.key + 1;
        final text = entry.value;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colors.borderColor.withOpacity(.5)),
            color: colors.secondaryColor,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: colors.territoryColor.withOpacity(.15),
                child: Text(
                  '$index',
                  style: textTheme.titleMedium?.copyWith(
                    color: colors.territoryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: textTheme.bodyMedium?.copyWith(
                    height: 1.5,
                    color: colors.textDefaultColor,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSupportCard(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = context.color;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.borderColor.withOpacity(.4)),
        color: colors.secondaryColor,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 52,
            width: 52,
            decoration: BoxDecoration(
              color: colors.territoryColor.withOpacity(.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.headset_mic_rounded,
              color: colors.territoryColor,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'نرافقك في كل خطوة',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colors.textDefaultColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'يمكنك التواصل مع فريق الدعم الفني لتخصيص العروض، مراجعة التغطية، أو متابعة التفعيل الميداني.',
                  style: textTheme.bodyMedium?.copyWith(
                    height: 1.5,
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

class _WifiStatCard extends StatelessWidget {
  const _WifiStatCard({required this.stat});

  final _WifiStat stat;

  @override
  Widget build(BuildContext context) {
    final colors = context.color;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.borderColor.withOpacity(.6)),
        color: colors.secondaryColor,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(stat.icon, color: colors.territoryColor),
          const SizedBox(height: 10),
          Text(
            stat.value,
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: colors.textDefaultColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            stat.title,
            style: textTheme.titleSmall?.copyWith(
              color: colors.textDefaultColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            stat.description,
            style: textTheme.bodySmall?.copyWith(
              color: colors.textLightColor,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _WifiBenefitCard extends StatelessWidget {
  const _WifiBenefitCard({required this.benefit});

  final _WifiBenefit benefit;

  @override
  Widget build(BuildContext context) {
    final colors = context.color;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.borderColor.withOpacity(.35)),
        color: colors.secondaryColor,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 46,
            width: 46,
            decoration: BoxDecoration(
              color: colors.territoryColor.withOpacity(.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(benefit.icon, color: colors.territoryColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  benefit.title,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colors.textDefaultColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  benefit.description,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colors.textLightColor,
                    height: 1.5,
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

class _WifiBottomCta extends StatelessWidget {
  const _WifiBottomCta({
    required this.onAddNetwork,
    required this.onViewGuidelines,
  });

  final VoidCallback onAddNetwork;
  final VoidCallback onViewGuidelines;

  @override
  Widget build(BuildContext context) {
    final colors = context.color;
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              backgroundColor: colors.territoryColor,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.add_circle_outline_rounded),
            label: Text(
              'إضافة شبكة الآن',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            onPressed: onAddNetwork,
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              foregroundColor: colors.textDefaultColor,
              side: BorderSide(color: colors.borderColor.withOpacity(.6)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            onPressed: onViewGuidelines,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.menu_book_rounded,
                    size: 20, color: colors.textDefaultColor),
                const SizedBox(width: 6),
                Text(
                  'عرض دليل ومتطلبات الخدمة',
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
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

class _WifiBadge extends StatelessWidget {
  const _WifiBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.15),
        borderRadius: BorderRadius.circular(40),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _WifiStat {
  final String title;
  final String value;
  final String description;
  final IconData icon;

  const _WifiStat({
    required this.title,
    required this.value,
    required this.description,
    required this.icon,
  });
}

class _WifiBenefit {
  final String title;
  final String description;
  final IconData icon;

  const _WifiBenefit({
    required this.title,
    required this.description,
    required this.icon,
  });
}
