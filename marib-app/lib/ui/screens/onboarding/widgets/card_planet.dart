// fluid_page_transitions.dart
// انتقالات سلسة "خرافية" بدون حواف حادة: تلاشي متداخل + مزيج لوني تدريجي + إحساس
// أن العناصر تتحرك داخل نفس الصفحة. لا حزم إضافية.
// للاستخدام:
// 1) ضع هذا الملف في مشروعك.
// 2) في MaterialApp theme:
//    theme: ThemeData(
//      pageTransitionsTheme: const PageTransitionsTheme(builders: {
//        TargetPlatform.android: FluidSharedFadeTransitionsBuilder(),
//        TargetPlatform.iOS:     FluidSharedFadeTransitionsBuilder(),
//        TargetPlatform.linux:   FluidSharedFadeTransitionsBuilder(),
//        TargetPlatform.macOS:   FluidSharedFadeTransitionsBuilder(),
//        TargetPlatform.windows: FluidSharedFadeTransitionsBuilder(),
//      }),
//    )
// 3) (اختياري) لف الشعارات/النصوص المشتركة بـ SeamlessHero لانتقال عنصر مشترك.

import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';

/// بطل مشترك جاهز مع Shuttle سلس (تفادي الوميض/القفز)
class SeamlessHero extends StatelessWidget {
  final Object tag;
  final Widget child;
  final bool transitionOnUserGestures;
  const SeamlessHero({
    required this.tag,
    required this.child,
    this.transitionOnUserGestures = true,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: tag,
      transitionOnUserGestures: transitionOnUserGestures,
      flightShuttleBuilder: (ctx, anim, flightDir, fromCtx, toCtx) {
        // نعطي إحساس مزج/تلاشي ناعم بدل قفز.
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeInOutCubic);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.98, end: 1).animate(curved),
            child: toCtx.widget,
          ),
        );
      },
      child: child,
    );
  }
}

/// قناع ينعّم حواف الصفحة (لا حواف حادة)، يكشف ما تحتها تدريجيًا أثناء الانتقال.
class _EdgeSoftener extends StatelessWidget {
  final Widget child;
  final double softness; // 0..1
  const _EdgeSoftener({required this.child, required this.softness});

  @override
  Widget build(BuildContext context) {
    if (softness <= 0) return child;
    return ShaderMask(
      shaderCallback: (Rect bounds) {
        // تدرج شعاعي من المركز، شفاف نحو الحواف.
        final double inner = lerpDouble(0.90, 0.70, softness)!.clamp(0.0, 1.0);
        final double outer = lerpDouble(0.99, 0.95, softness)!.clamp(0.0, 1.0);
        return RadialGradient(
          center: Alignment.center,
          radius: 1.12,
          colors: const [
            Color(0xFFFFFFFF), // يعرض كامل المحتوى في الداخل
            Color(0xFFFFFFFF),
            Color(0x00FFFFFF), // يتلاشى قرب الحواف
          ],
          stops: [inner, outer, 1.0],
        ).createShader(bounds);
      },
      blendMode: BlendMode.dstIn,
      child: child,
    );
  }
}

/// مزج لوني رقيق فوق الصفحة (يعطي إحساس تغير لون الخلفية تدريجيًا).
class _ColorBlendOverlay extends StatelessWidget {
  final Animation<double> animation; // 0..1
  final double intensity; // 0..1
  const _ColorBlendOverlay({required this.animation, this.intensity = 0.22});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).colorScheme;
    // نختار لونين من الـTheme كي لا نعتمد على صفحة بعينها.
    final Color from = theme.surface;
    final Color to = theme.primaryContainer;
    final Animatable<Color?> tween = ColorTween(begin: from.withOpacity(0.0), end: to.withOpacity(intensity));
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final c = tween.evaluate(animation)!;
          return DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  c.withOpacity((0.6 * intensity).clamp(0, 1)),
                  c.withOpacity((0.9 * intensity).clamp(0, 1)),
                ],
              ),
            ),
            child: const SizedBox.expand(),
          );
        },
      ),
    );
  }
}

/// الانتقال الرئيسي: مزيج بين Fade-through + Edge soften + Color blend
class FluidSharedFadeTransitionsBuilder extends PageTransitionsBuilder {
  const FluidSharedFadeTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
      PageRoute<T> route,
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      Widget child,
      ) {
    // عندما تكون الصفحة ليست الحالية، لا نُشغّل جزء "الدخول" حتى لا تتحرك الشاشات الأعمق.
    final bool isCurrent = route.isCurrent;
    final Animation<double> inAnim = isCurrent ? CurvedAnimation(parent: animation, curve: Curves.easeOutCubic) : const AlwaysStoppedAnimation(1);

    // يُستعمل لتمييع حواف الصفحة عندما تغطيها صفحة جديدة فوقها أو تكشف عنها (push/pop).
    final Animation<double> coverAnim = CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeInOutCubic);

    // دخل الصفحة: تلاشي متداخل + تكبير بسيط + انزياح بسيط (يشعر أنها نفس الصفحة تتغيّر).
    final Animation<double> fadeIn = Tween(begin: 0.0, end: 1.0).animate(CurveTween(curve: const Interval(0.12, 1.0, curve: Curves.easeOut))).animate(inAnim);
    final Animation<double> scaleIn = Tween(begin: 0.985, end: 1.0).animate(CurveTween(curve: Curves.easeOutCubic).animate(inAnim));
    final Animation<Offset> slideIn = Tween(begin: const Offset(0, 0.01), end: Offset.zero).animate(CurveTween(curve: Curves.easeOutCubic).animate(inAnim));

    // يغطي اللون تدريجيًا ليعطي إحساس مزج الخلفيات.
    final Animation<double> colorBlend = CurveTween(curve: const Interval(0.0, 0.85, curve: Curves.easeInOut)).animate(inAnim);

    // نعومة الحافة للخلفية المغطّاة (الصفحة تحت الصفحة الحالية): عندما secondaryAnimation يقترب من 1 → حواف أنعم.
    final Animation<double> edgeSoftness = Tween(begin: 0.0, end: 1.0).animate(CurveTween(curve: Curves.easeInOutCubic).animate(coverAnim));

    // طبقة الاهتزاز/التلاشي الخفيف للنصوص/الشعارات على الدخول (اختياري ومنضبط).
    final Animation<double> textFade = Tween(begin: 0.0, end: 1.0).animate(CurveTween(curve: const Interval(0.18, 0.9, curve: Curves.easeOut))).animate(inAnim);

    return _EdgeSoftener(
      softness: edgeSoftness.value * 0.9, // 90% أقصى نعومة عند تغطية الصفحة
      child: Stack(
        fit: StackFit.expand,
        children: [
          // محتوى الصفحة القادم:
          FadeTransition(
            opacity: fadeIn,
            child: SlideTransition(
              position: slideIn,
              child: ScaleTransition(
                scale: scaleIn,
                child: _TextSofter(
                  strength: (1 - textFade.value) * 0.08, // تكاد لا تُلحظ، فقط لتجانس الحركة
                  child: child,
                ),
              ),
            ),
          ),
          // مزج لوني رقيق فوق الطفل (يقل تدريجيًا):
          _ColorBlendOverlay(animation: colorBlend, intensity: 0.20),
        ],
      ),
    );
  }
}

/// يطبّق Gaussian blur طفيف + خفض تباين لا متناظر على النصوص في أول لحظات الدخول لإحساس دمج ناعم.
class _TextSofter extends StatelessWidget {
  final Widget child;
  final double strength; // 0..0.15
  const _TextSofter({required this.child, this.strength = 0});

  @override
  Widget build(BuildContext context) {
    if (strength <= 0) return child;
    final double sigma = lerpDouble(0, 1.2, strength * 6.0) ?? 0;
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
      child: Opacity(
        opacity: (1 - strength).clamp(0.85, 1.0),
        child: child,
      ),
    );
  }
}

/// راوت جاهز (بديل لتغيير الـTheme) لو أردت استعماله في push يدويًا.
class FluidPageRoute<T> extends PageRoute<T> {
  final WidgetBuilder builder;
  final Duration duration;
  final Duration reverseDuration;
  FluidPageRoute({
    required this.builder,
    this.duration = const Duration(milliseconds: 420),
    this.reverseDuration = const Duration(milliseconds: 360),
    super.settings,
  });

  @override
  bool get opaque => false; // يسمح للتلاشي المتداخل أن يُظهر ما تحت الصفحة

  @override
  bool get barrierDismissible => false;

  @override
  Color get barrierColor => Colors.transparent;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => duration;

  @override
  Duration get reverseTransitionDuration => reverseDuration;

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    return builder(context);
  }

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    const builder = FluidSharedFadeTransitionsBuilder();
    return builder.buildTransitions(this, context, animation, secondaryAnimation, child);
  }
}

/// امتداد مريح لـ push بانتقال FluidPageRoute.
extension FluidNavigator on BuildContext {
  Future<T?> pushFluid<T>(Widget page) {
    return Navigator.of(this).push<T>(FluidPageRoute<T>(builder: (_) => page));
  }
}
