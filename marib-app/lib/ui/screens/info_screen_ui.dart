import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/data/model/social_link_model.dart';
import 'package:marib/utils/app_icon.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/responsiveSize.dart';
import 'package:marib/utils/ui_utils.dart';

/// واجهة شاشة المعلومات/حول - مفصولة بالكامل عن المنطق.
class InfoScreenUI extends StatelessWidget {
  const InfoScreenUI({
    super.key,
    required this.onGuideTap,
    required this.onFaqsTap,
    required this.onShareTap,
    required this.onContactUsTap,
    required this.onAboutUsTap,
    required this.onTermsTap,
    required this.onPrivacyTap,
    this.socialLinks = const <SocialLink>[],
  });

  final VoidCallback onGuideTap;
  final VoidCallback onFaqsTap;
  final VoidCallback onShareTap;
  final VoidCallback onContactUsTap;
  final VoidCallback onAboutUsTap;
  final VoidCallback onTermsTap;
  final VoidCallback onPrivacyTap;
  final List<SocialLink> socialLinks;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion(
      value: UiUtils.getSystemUiOverlayStyle(
        context: context,
        statusBarColor: context.color.secondaryColor,
      ),
      child: Scaffold(
        backgroundColor: context.color.primaryColor,
        appBar: UiUtils.buildAppBar(
          context,
          title: "aboutUs".translate(context),
          bottomHeight: 12,
          showBackButton: true,
        ),
        body: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Padding(
            // نحافظ على العناصر في أعلى الصفحة
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // الأزرار (صغيرة + فاصلة 10px بين كل زر)
                _CustomTile(title: "guide".translate(context),        svgImagePath: AppIcons.guide,   onTap: onGuideTap),
                const SizedBox(height: 8),
                _CustomTile(title: "faqsLbl".translate(context),       svgImagePath: AppIcons.faqsIcon,onTap: onFaqsTap),
                const SizedBox(height: 8),
                _CustomTile(title: "shareApp".translate(context),      svgImagePath: AppIcons.shareApp,onTap: onShareTap),
                const SizedBox(height: 8),
                _CustomTile(title: "contactUs".translate(context),     svgImagePath: AppIcons.contactUs,onTap: onContactUsTap),
                const SizedBox(height: 8),
                _CustomTile(title: "aboutUs".translate(context),       svgImagePath: AppIcons.aboutUs, onTap: onAboutUsTap),
                const SizedBox(height: 8),
                _CustomTile(title: "termsConditions".translate(context),svgImagePath: AppIcons.terms,  onTap: onTermsTap),
                const SizedBox(height: 8),
                _CustomTile(title: "privacyPolicy".translate(context), svgImagePath: AppIcons.privacy, onTap: onPrivacyTap),

                const SizedBox(height: 30),

                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _SocialIcon(AppIcons.facebook,  onTap: () { /* افتح فيسبوك */ }),
                      const SizedBox(width: 10),
                      _SocialIcon(AppIcons.Instagram, onTap: () { /* افتح إنستجرام */ }),
                      const SizedBox(width: 10),
                      _SocialIcon(AppIcons.whatsapp,  onTap: () { /* افتح واتساب */ }),
                    ],
                  )

                ),


              ],
            ),
          ),
        ),
      ),
    );
  }
}




// ========================= Tiles صغيرة مع شريط جانبي متدرج =========================


class _CustomTile extends StatelessWidget {
  const _CustomTile({
    required this.title,
    required this.svgImagePath,
    required this.onTap,
    this.isSwitchBox,
    this.switchValue,
    this.onTapSwitch,
  });

  final String title;
  final String svgImagePath;
  final VoidCallback onTap;

  final bool? isSwitchBox;
  final bool? switchValue;
  final ValueChanged<bool>? onTapSwitch;

  @override
  Widget build(BuildContext context) {
    final accent = context.color.territoryColor;

    // شريط أهدأ من لون الهوية (نفس الهيو، تشبّع أقل + إضاءة أعلى قليلًا)
    final hsl = HSLColor.fromColor(accent);
    final barBase = hsl
        .withSaturation((hsl.saturation * 0.45).clamp(0.0, 1.0))
        .withLightness((hsl.lightness * 1.05).clamp(0.0, 1.0))
        .toColor();

    final bool withSwitch = isSwitchBox == true;

    return _Pressable(
      onTap: withSwitch ? null : onTap, // لو فيه سويتش: الضغط عبر السويتش فقط
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12), // أصغر قليلاً
        child: Container(
          // ارتفاع نهائي ~56px
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: context.color.secondaryColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.color.textDefaultColor.withOpacity(0.06)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          // الشريط الجانبي جزء من الزر (أنحف + أهدأ حتى لا يغطي الأيقونة)

          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.centerRight,
              end: Alignment.centerLeft,
              colors: [
                barBase.withOpacity(0.25), // كان 0.40 → أهدأ
                barBase.withOpacity(0.12), // كان 0.18
                Colors.transparent,
              ],
              stops: const [0.0, 0.10, 0.20], // شريط أنحف يناسب المقاس الصغير
            ),
          ),
          child: Row(
            textDirection: TextDirection.ltr, // الأيقونة يمين دائماً
            children: [
              // يسار: سهم أو سويتش (صغير)
              if (!withSwitch)
                Container(
                  width: 26, height: 26,
                  decoration: BoxDecoration(
                    color: context.color.backgroundColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Transform.rotate(
                    angle: Directionality.of(context) == ui.TextDirection.rtl ? 3.14159 : 0,
                    child: UiUtils.getSvg(
                      AppIcons.arrowRight,
                      color: context.color.textColorDark,
                    ),
                  ),
                )
              else
                SizedBox(
                  height: 26, width: 42,
                  child: CupertinoSwitch(
                    activeColor: accent,
                    value: switchValue ?? false,
                    onChanged: (v) => onTapSwitch?.call(v),
                  ),
                ),

              const SizedBox(width: 10),

              // العنوان في الوسط
              Expanded(
                child: Text(title, textAlign: TextAlign.center)
                    .bold(weight: FontWeight.w700)
                    .color(context.color.textColorDark),
              ),

              const SizedBox(width: 10),

              // يمين: كبسولة الأيقونة (مصغّرة)
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: context.color.textDefaultColor.withOpacity(0.06)),
                ),
                alignment: Alignment.center,
                child: UiUtils.getSvg(
                  svgImagePath,
                  height: 18, width: 18,
                  color: accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}



// ========================= أيقونات تواصل مصغّرة وواضحة =========================

class _SocialIcon extends StatelessWidget {
  const _SocialIcon(this.svgAsset, {this.onTap, this.size = 56});
  final String svgAsset;
  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final radius = 14.0; // زوايا ناعمة (قريبة من الدائرة)

    return _Pressable(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: context.color.secondaryColor,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: context.color.textDefaultColor.withOpacity(0.10),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          clipBehavior: Clip.hardEdge, // يقص أي تسريب خارج الحواف
          child: AspectRatio(
            aspectRatio: 1, // مربّع 1:1 موحّد
            child: SvgPicture.asset(
              svgAsset,
              fit: BoxFit.cover,                 // يملأ كامل المربّع ويقص الزوائد
              alignment: Alignment.center,       // تمركز
              allowDrawingOutsideViewBox: true,  // يتجاوز الـviewBox لو فيه حواف داخلية
            ),
          ),
        ),
      ),
    );
  }
}




// ========= تأثير ضغط بسيط (Scale) — ضعه هنا إن لم يكن مستورداً =========
class _Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scaleDown;
  const _Pressable({Key? key, required this.child, this.onTap, this.scaleDown = 0.96}) : super(key: key);

  @override
  State<_Pressable> createState() => _PressableState();
}
class _PressableState extends State<_Pressable> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => setState(() => _down = true),
      onPointerUp: (_) => setState(() => _down = false),
      onPointerCancel: (_) => setState(() => _down = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          scale: _down ? widget.scaleDown : 1.0,
          child: widget.child,
        ),
      ),
    );
  }
}
