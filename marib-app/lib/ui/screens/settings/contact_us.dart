import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shimmer/shimmer.dart';

import 'package:marib/app/app_theme.dart';
import 'package:marib/data/cubits/company_cubit.dart';
import 'package:marib/data/cubits/system/app_theme_cubit.dart';
import 'package:marib/ui/screens/widgets/blurred_dialoge_box.dart';
import 'package:marib/ui/theme/theme.dart';

import 'package:marib/utils/app_icon.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/responsiveSize.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:marib/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:marib/ui/screens/widgets/custom_text_form_field.dart';

class ContactUs extends StatefulWidget {
  const ContactUs({super.key});

  @override
  ContactUsState createState() => ContactUsState();

  static Route route(RouteSettings routeSettings) {
    return BlurredRouter(builder: (_) => const ContactUs());
  }
}

/// زر يضغط بسلاسة (سكيل) + Haptic + Ripple — واجهة فقط
class _PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final double pressedScale;
  final Duration duration;
  final BorderRadius? radius;

  const _PressableScale({
    required this.child,
    required this.onTap,
    this.radius,
  });

  @override
  State<_PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<_PressableScale> {
  bool _down = false;

  void _setDown(bool v) {
    if (_down == v) return;
    setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: widget.radius ?? BorderRadius.circular(14),
      onTap: () async {
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      onTapDown: (_) => _setDown(true),
      onTapCancel: () => _setDown(false),
      onTapUp: (_) => _setDown(false),
      child: AnimatedScale(
        scale: _down ? widget.pressedScale : 1.0,
        duration: widget.duration,
        child: widget.child,
      ),
    );
  }
}

/// بطاقة افتتاحية: عنوان + الملاحظة داخل بطاقة أنيقة
class _IntroCard extends StatelessWidget {
  const _IntroCard();

  @override
  Widget build(BuildContext context) {
    final isDark =
        context.watch<AppThemeCubit>().state.appTheme == AppTheme.dark;
    final border = Border.all(color: context.color.borderColor.withOpacity(.4));
    final bg = isDark
        ? context.color.secondaryColor.withOpacity(.6)
        : context.color.secondaryColor;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: border,
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  blurRadius: 10,
                  spreadRadius: 0,
                  offset: const Offset(0, 6),
                  color: Colors.black.withOpacity(.06),
                )
              ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // أيقونة في فقاعة لون أساسي
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: context.color.territoryColor.withOpacity(.12),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: FittedBox(
              fit: BoxFit.none,
              child: UiUtils.getSvg(AppIcons.message,
                  color: context.color.territoryColor),
            ),
          ),
          SizedBox(width: 12.rw(context)),
          // نصوص
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("howCanWeHelp".translate(context))
                    .color(context.color.textColorDark)
                    .size(context.font.larger)
                    .bold(weight: FontWeight.w700),
                SizedBox(height: 8.rh(context)),
                // << الملاحظة داخل البطاقة >>
                Text("itLooksLikeYouHasError".translate(context))
                    .size(context.font.small)
                    .color(context.color.textLightColor),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// تايل تواصل احترافي (واجهة فقط)
class _ContactActionTile extends StatelessWidget {
  final String title;
  final String svgIcon;
  final VoidCallback onTap;
  final String? subtitle;

  const _ContactActionTile({
    required this.title,
    required this.svgIcon,
    required this.onTap,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);
    final isDark =
        context.watch<AppThemeCubit>().state.appTheme == AppTheme.dark;

    final container = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? context.color.secondaryColor.withOpacity(.65)
            : context.color.secondaryColor,
        borderRadius: radius,
        border: Border.all(
            color: context.color.borderColor.withOpacity(.45), width: 1),
      ),
      child: Row(
        children: [
          // أيقونة داخل فقاعة
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: context.color.territoryColor.withOpacity(.12),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: FittedBox(
              fit: BoxFit.none,
              child:
                  UiUtils.getSvg(svgIcon, color: context.color.territoryColor),
            ),
          ),
          SizedBox(width: 14.rw(context)),
          // عنوان + سطر فرعي (اختياري)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title)
                    .bold(weight: FontWeight.w700)
                    .color(context.color.textColorDark),
                if (subtitle != null) ...[
                  SizedBox(height: 4),
                  Text(subtitle!)
                      .size(context.font.small)
                      .color(context.color.textLightColor),
                ],
              ],
            ),
          ),
          // سهم أنيق
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: context.color.secondaryColor.withOpacity(.10),
              border: Border.all(color: context.color.borderColor, width: 1.2),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: FittedBox(
              fit: BoxFit.none,
              child: SizedBox(
                width: 9,
                height: 16,
                child: UiUtils.getSvg(
                  AppIcons.arrowRight,
                  color: context.color.textColorDark,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    return Material(
      color: Colors.transparent,
      child: _PressableScale(
        radius: radius,
        onTap: onTap,
        child: container,
      ),
    );
  }
}

class ContactUsState extends State<ContactUs> {
  @override
  void initState() {
    super.initState();
    // لا تعديل منطقي — فقط ضمان الجلب عند الحاجة
    Future.delayed(Duration.zero, () {
      final st = context.read<CompanyCubit>().state;
      if (st is CompanyInitial || st is CompanyFetchFailure) {
        context.read<CompanyCubit>().fetchCompany(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.color.backgroundColor,
      appBar: UiUtils.buildAppBar(
        context,
        title: "contactUs".translate(context),
        showBackButton: true,
      ),
      body: BlocBuilder<CompanyCubit, CompanyState>(
        builder: (context, state) {
          if (state is CompanyFetchProgress) {
            return _ContactShimmer(context);
          } else if (state is CompanyFetchSuccess) {
            final company = state.companyData;
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: SingleChildScrollView(
                key: const ValueKey('contactBody'),
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _IntroCard(),
                    SizedBox(height: 18.rh(context)),

                    // بطاقات التواصل
                    _ContactActionTile(
                      title: "callBtnLbl".translate(context),
                      subtitle: "chooseNumber".translate(context),
                      svgIcon: AppIcons.call,
                      onTap: () async {
                        final number1 = company.companyTel1;
                        final number2 = company.companyTel2;

                        UiUtils.showBlurredDialoge(
                          context,
                          dialoge: BlurredDialogBox(
                            title: "chooseNumber".translate(context),
                            showCancleButton: false,
                            barrierDismissable: true,
                            acceptTextColor: context.color.buttonColor,
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                ListTile(
                                  title: Text(number1.toString())
                                      .centerAlign()
                                      .bold(),
                                  onTap: () async {
                                    await launchUrl(Uri.parse("tel:$number1"));
                                  },
                                ),
                                if (number2 != null)
                                  ListTile(
                                    title: Text(number2.toString())
                                        .centerAlign()
                                        .bold(),
                                    onTap: () async {
                                      await launchUrl(
                                          Uri.parse("tel:$number2"));
                                    },
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                    SizedBox(height: 14.rh(context)),

                    // (اختياري) تفعيل البريد — واجهة فقط وتستخدم الدالة الموجودة
                    if ((company.companyEmail ?? '').toString().isNotEmpty)
                      _ContactActionTile(
                        title: "companyEmailLbl".translate(context),
                        subtitle: "sendEmail".translate(context),
                        svgIcon: AppIcons.message,
                        onTap: () {
                          showEmailDialoge(company.companyEmail);
                        },
                      ),

                    SizedBox(height: 8.rh(context)),
                  ],
                ),
              ),
            );
          } else if (state is CompanyFetchFailure) {
            return Center(child: Text(state.errmsg));
          } else {
            return const SizedBox.shrink();
          }
        },
      ),
    );
  }

  // فتح واجهة البريد — (موجودة مسبقًا)
  void showEmailDialoge(email) {
    Navigator.push(
      context,
      BlurredRouter(
        builder: (context) => EmailSendWidget(email: email),
      ),
    );
  }

  // شيمر محسّن: بطاقة + تايلين
  Widget _ContactShimmer(BuildContext context) {
    final isDark =
        context.watch<AppThemeCubit>().state.appTheme == AppTheme.dark;
    final base =
        isDark ? Colors.white.withOpacity(.06) : Colors.black.withOpacity(.06);
    final highlight =
        isDark ? Colors.white.withOpacity(.14) : Colors.black.withOpacity(.12);

    Widget bar({double h = 14, double w = double.infinity, double r = 10}) =>
        Container(
          height: h,
          width: w,
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(r)),
        );

    Widget tile() => Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.color.secondaryColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: context.color.borderColor.withOpacity(.5), width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(child: bar(h: 16, r: 6)),
              const SizedBox(width: 14),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ],
          ),
        );

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Shimmer.fromColors(
        baseColor: base,
        highlightColor: highlight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // بطاقة المقدمة
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.color.secondaryColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: context.color.borderColor.withOpacity(.4)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        bar(h: 20, w: 180, r: 8),
                        const SizedBox(height: 8),
                        bar(h: 14, w: 240, r: 6),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            tile(),
            const SizedBox(height: 14),
            tile(),
          ],
        ),
      ),
    );
  }
}

// ===========================
// واجهة إرسال البريد (UI فقط)
// ===========================
class EmailSendWidget extends StatefulWidget {
  final String email;

  const EmailSendWidget({
    super.key,
    required this.email,
  });

  @override
  State<EmailSendWidget> createState() => _EmailSendWidgetState();
}

class _EmailSendWidgetState extends State<EmailSendWidget> {
  final TextEditingController _subject = TextEditingController();
  late final TextEditingController _email =
      TextEditingController(text: widget.email);
  final TextEditingController _text = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final isDark =
        context.watch<AppThemeCubit>().state.appTheme == AppTheme.dark;

    return Scaffold(
      backgroundColor: Colors.white.withOpacity(0.0),
      body: Center(
        child: Container(
          clipBehavior: Clip.antiAlias,
          width: MediaQuery.of(context).size.width - 40,
          decoration: BoxDecoration(
            boxShadow: isDark
                ? null
                : [
                    const BoxShadow(
                      blurRadius: 6,
                      offset: Offset(0, 2),
                      color: ui.Color.fromARGB(255, 201, 201, 201),
                    ),
                  ],
            color: context.color.secondaryColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: 40,
                            height: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: context.color.territoryColor
                                  .withOpacity(0.06),
                              shape: BoxShape.circle,
                            ),
                            child: Directionality(
                              textDirection: Directionality.of(context),
                              child: RotatedBox(
                                quarterTurns: Directionality.of(context) ==
                                        TextDirection.rtl
                                    ? 2
                                    : 0,
                                child: UiUtils.getSvg(AppIcons.arrowLeft),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                  SizedBox(height: 16.rh(context)),
                  Text("sendEmail".translate(context))
                      .bold(weight: FontWeight.w700)
                      .color(context.color.textColorDark),
                  SizedBox(height: 12.rh(context)),
                  CustomTextFormField(
                    controller: _subject,
                    hintText: "subject".translate(context),
                  ),
                  SizedBox(height: 12.rh(context)),
                  CustomTextFormField(
                    controller: _email,
                    isReadOnly: true,
                    hintText: "companyEmailLbl".translate(context),
                  ),
                  SizedBox(height: 12.rh(context)),
                  CustomTextFormField(
                    controller: _text,
                    maxLine: 100,
                    minLine: 5,
                    hintText: "writeSomething".translate(context),
                  ),
                  SizedBox(height: 16.rh(context)),
                  UiUtils.buildButton(
                    context,
                    onPressed: () async {
                      final redirecturi = Uri(
                        scheme: 'mailto',
                        path: _email.text,
                        query: 'subject=${_subject.text}&body=${_text.text}',
                      );
                      await launchUrl(redirecturi);
                    },
                    height: 50.rh(context),
                    buttonTitle: "sendEmail".translate(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
