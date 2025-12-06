import 'package:flutter/material.dart';
import 'package:marib/app/routes.dart';
import 'package:marib/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/app_icon.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/ui_utils.dart';

class AccountVerificationInfoScreen extends StatelessWidget {
  const AccountVerificationInfoScreen({super.key});

  static Route route(RouteSettings settings) {
    return BlurredRouter(builder: (_) => const AccountVerificationInfoScreen());
  }

  void _startVerification(BuildContext context) {
    Navigator.pushNamed(
      context,
      Routes.sellerVerificationScreen,
      arguments: {"isResubmitted": false},
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color accent = context.color.territoryColor;
    final Color surface = context.color.secondaryColor;
    final Color text = context.color.textDefaultColor;

    return Scaffold(
      backgroundColor: context.color.backgroundColor,
      appBar: UiUtils.buildAppBar(
        context,
        showBackButton: true,
        title: "توثيق الحساب",
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HeroCard(accent: accent),
            const SizedBox(height: 16),
            _SectionCard(
              title: "لماذا التوثيق؟",
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: const [
                  _BenefitChip("موثوقية أعلى لدى المشترين"),
                  _BenefitChip("شارة موثقة أمام اسمك"),
                  _BenefitChip("أولوية في نتائج البحث والإعلانات"),
                  _BenefitChip("معدل إبلاغ أقل وحماية لحسابك"),
                ],
              ),
            ),
            _SectionCard(
              title: "التكلفة وما يشمله التوثيق",
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "رسوم التوثيق تُحسب حسب سياسة المنصة وتشمل مراجعة البيانات الرسمية، التأكد من هوية المالك، والتواصل للتحقق من النشاط.",
                    style: TextStyle(
                      color: text.withOpacity(0.85),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.timer_outlined, size: 18, color: accent),
                      const SizedBox(width: 8),
                      Text(
                        "مدة المراجعة عادة من 1 إلى 3 أيام عمل.",
                        style: TextStyle(color: text.withOpacity(0.85)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            _SectionCard(
              title: "كيف يعمل التوثيق؟",
              child: Column(
                children: const [
                  _StepRow(
                    index: 1,
                    title: "إرسال الطلب",
                    subtitle: "نطلب منك رفع الهوية أو السجل التجاري وتعبئة بيانات المتجر.",
                  ),
                  _StepRow(
                    index: 2,
                    title: "مراجعة فريقنا",
                    subtitle: "يتم التحقق من المستندات ومطابقتها مع بيانات الحساب.",
                  ),
                  _StepRow(
                    index: 3,
                    title: "الحصول على الشارة",
                    subtitle: "ستظهر علامة التوثيق أمام اسمك في الإعلانات وصفحة البائع.",
                  ),
                ],
              ),
            ),
            _SectionCard(
              title: "المتطلبات الأساسية",
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  _RequirementRow("هوية وطنية أو سجل تجاري ساري"),
                  _RequirementRow("رقم جوال موثق قابل للتواصل"),
                  _RequirementRow("عنوان واضح يظهر في إدارة العناوين"),
                  _RequirementRow("حساب نشط خالٍ من المخالفات الكبيرة"),
                ],
              ),
            ),
            const SizedBox(height: 6),
            UiUtils.buildButton(
              context,
              onPressed: () => _startVerification(context),
              height: 48,
              radius: 12,
              buttonTitle: "طلب التوثيق",
            ),
            const SizedBox(height: 10),
            Center(
              child: Text(
                "ستتمكن من متابعة حالة الطلب وإرفاق أي ملاحظات إضافية من نفس الشاشة.",
                textAlign: TextAlign.center,
                style: TextStyle(color: text.withOpacity(0.8), height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final Color accent;

  const _HeroCard({required this.accent});

  @override
  Widget build(BuildContext context) {
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
          Container(
            height: 58,
            width: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withOpacity(0.12),
            ),
            alignment: Alignment.center,
            child: UiUtils.getSvg(
              AppIcons.userVerificationIcon,
              fit: BoxFit.none,
              color: accent,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "فعّل شارة التوثيق",
                  style: TextStyle(
                    color: context.color.textDefaultColor,
                    fontWeight: FontWeight.w800,
                    fontSize: context.font.large,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "أثبت هويتك وارفع ثقة عملائك مع شارة توثيق رسمية تظهر في كل إعلان.",
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

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: context.color.secondaryColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: context.color.textColorDark.withOpacity(0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: context.color.territoryColor
                      .withOpacity(isDark ? 0.15 : 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.verified, size: 16, color: context.color.territoryColor),
                    const SizedBox(width: 6),
                    Text(
                      title,
                      style: TextStyle(
                        color: context.color.territoryColor,
                        fontWeight: FontWeight.w700,
                        fontSize: context.font.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: context.color.secondaryColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: context.color.textColorDark.withOpacity(0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded,
              size: 16, color: context.color.territoryColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: context.color.textDefaultColor,
              fontWeight: FontWeight.w600,
              fontSize: context.font.small + 1,
            ),
          ),
        ],
      ),
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
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 28,
            width: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: context.color.territoryColor.withOpacity(0.14),
            ),
            alignment: Alignment.center,
            child: Text(
              "$index",
              style: TextStyle(
                color: context.color.territoryColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: context.color.textDefaultColor,
                    fontWeight: FontWeight.w700,
                    fontSize: context.font.normal,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: context.color.textLightColor,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}

class _RequirementRow extends StatelessWidget {
  final String text;

  const _RequirementRow(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Icon(Icons.check_circle_rounded,
              size: 18, color: context.color.territoryColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: context.color.textDefaultColor.withOpacity(0.9),
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
