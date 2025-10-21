
import 'dart:ui' show lerpDouble, ImageFilter;
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart' as lottie;

import '../lottie_helpers.dart';
import '../models/card_planet_data.dart';
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
    final Animation<double> fadeIn = Tween(begin: 0.0, end: 1.0)
        .chain(CurveTween(curve: const Interval(0.12, 1.0, curve: Curves.easeOut)))
        .animate(inAnim);
    final Animation<double> scaleIn = Tween(begin: 0.985, end: 1.0)
        .chain(CurveTween(curve: Curves.easeOutCubic))
        .animate(inAnim);
    final Animation<Offset> slideIn = Tween(begin: const Offset(0, 0.01), end: Offset.zero)
        .chain(CurveTween(curve: Curves.easeOutCubic))
        .animate(inAnim);

    // يغطي اللون تدريجيًا ليعطي إحساس مزج الخلفيات.
    final Animation<double> colorBlend = CurveTween(curve: const Interval(0.0, 0.85, curve: Curves.easeInOut)).animate(inAnim);

    // نعومة الحافة للخلفية المغطّاة (الصفحة تحت الصفحة الحالية): عندما secondaryAnimation يقترب من 1 → حواف أنعم.
    final Animation<double> edgeSoftness = Tween(begin: 0.0, end: 1.0)
        .chain(CurveTween(curve: Curves.easeInOutCubic))
        .animate(coverAnim);
    // طبقة الاهتزاز/التلاشي الخفيف للنصوص/الشعارات على الدخول (اختياري ومنضبط).
    final Animation<double> textFade = Tween(begin: 0.0, end: 1.0)
        .chain(CurveTween(curve: const Interval(0.18, 0.9, curve: Curves.easeOut)))
        .animate(inAnim);

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

class CardPlanet extends StatelessWidget {
  final CardPlanetData data;
  final double progress;
  final double contentProgress;
  final bool shouldAnimate;
  final Map<String, LottieComposition> compositions;

  const CardPlanet({
    required this.data,
    required this.progress,
    required this.contentProgress,
    required this.shouldAnimate,
    required this.compositions,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final double clampedProgress = progress.clamp(-1.0, 1.0).toDouble();
    final double normalized = contentProgress.clamp(0.0, 1.0).toDouble();
    final double eased = Curves.easeInOutCubic.transform(normalized);
    final double liftCurve = Curves.easeOutBack.transform(normalized);
    final double textCurve = Curves.easeOutCubic.transform(normalized);
    final double fadeCurve = Curves.easeOutCubic.transform(normalized);

    final double translateY = lerpDouble(80, 0, eased) ?? 0;
    final double translateXFactor = lerpDouble(
      MediaQuery.of(context).size.width * 0.24,
      0,
      eased,
    ) ??
        0;
    final double translateX = -clampedProgress * translateXFactor;
    final double scale = lerpDouble(0.92, 1.0, liftCurve) ?? 1.0;
    final double cardOpacity = shouldAnimate
        ? fadeCurve
        : (progress.abs() < 0.001 ? 1.0 : 0.0);
    final double parallax = clampedProgress * 36;
    final double overlayOpacity = lerpDouble(0.65, 0.28, eased) ?? 0.46;
    final double contentSlide = lerpDouble(32, 0, textCurve) ?? 0;

    final borderRadius = BorderRadius.circular(36);
    final List<Color> gradientColors = _resolveGradientColors(context);

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(24, 56, 24, 112),
      child: Opacity(
        opacity: _clampUnit(cardOpacity),
        child: Transform.translate(
          offset: Offset(translateX, translateY),
          child: Transform.scale(
            scale: scale,
            alignment: Alignment.center,
            child: _EdgeSoftener(
              softness: (1 - normalized) * 0.45,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: borderRadius,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.18 * cardOpacity),
                      blurRadius: lerpDouble(14, 32, eased) ?? 18,
                      offset: Offset(0, lerpDouble(18, 26, eased) ?? 22),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: borderRadius,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: gradientColors,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                      if (data.backgroundAnimationPath != null)
                        Positioned.fill(
                          child: Transform.translate(
                            offset: Offset(parallax * 0.45, parallax * 0.18),
                            child: _buildLottie(
                              data.backgroundAnimationPath,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withOpacity(overlayOpacity * 0.9),
                                Colors.black.withOpacity(overlayOpacity * 0.75),
                                Colors.black.withOpacity(overlayOpacity * 0.55),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding:
                        const EdgeInsetsDirectional.fromSTEB(28, 32, 28, 36),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Align(
                                alignment: Alignment.center,
                                child: _buildForeground(parallax, normalized),
                              ),
                            ),
                            const SizedBox(height: 24),
                            _TextSofter(
                              strength: (1 - normalized) * 0.06,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Transform.translate(
                                    offset: Offset(0, contentSlide),
                                    child: Opacity(
                                      opacity: Curves.easeInOut.transform(normalized),
                                      child: Text(
                                        data.title,
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineSmall
                                            ?.copyWith(
                                          color: data.titleColor,
                                          fontWeight: FontWeight.w800,
                                          height: 1.2,
                                        ) ??
                                            TextStyle(
                                              fontSize: 26,
                                              fontWeight: FontWeight.w800,
                                              height: 1.2,
                                              color: data.titleColor,
                                            ),
                                        textAlign: TextAlign.start,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Transform.translate(
                                    offset: Offset(0, contentSlide / 1.5),
                                    child: Opacity(
                                      opacity: Curves.easeIn.transform(normalized),
                                      child: Text(
                                        data.subtitle,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyLarge
                                            ?.copyWith(
                                          color: data.subtitleColor,
                                          height: 1.5,
                                        ) ??
                                            TextStyle(
                                              fontSize: 16,
                                              height: 1.5,
                                              color: data.subtitleColor,
                                            ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Color> _resolveGradientColors(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final List<Color> base = data.backgroundGradientColors;
    if (base.isEmpty) {
      return [scheme.surface, scheme.primaryContainer];
    }
    if (base.length == 1) {
      return [base.first, base.first];
    }
    return base;
  }

  Widget _buildForeground(double parallax, double normalized) {
    final Widget? animationWidget = _buildLottie(
      data.animationPath,
      fit: BoxFit.contain,
    );
    final Widget? imageWidget = data.image != null
        ? IgnorePointer(
      ignoring: true,
      child: RepaintBoundary(
        child: Image(
          image: data.image!,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
      ),
    )
        : null;

    final Widget? foreground = animationWidget ?? imageWidget;
    if (foreground == null) {
      return const SizedBox.shrink();
    }

    final double liftCurve = Curves.easeOutBack.transform(normalized);
    final double translateY = lerpDouble(36, -14, liftCurve) ?? 0;
    final double scale = lerpDouble(0.94, 1.0, liftCurve) ?? 1.0;
    final double opacity = Curves.easeOut.transform(normalized);

    return FractionallySizedBox(
      widthFactor: 0.82,
      child: Transform.translate(
        offset: Offset(parallax * 0.7, translateY),
        child: Transform.scale(
          scale: scale,
          alignment: Alignment.center,
          child: Opacity(
            opacity: _clampUnit(opacity),
            child: foreground,
          ),
        ),
      ),
    );
  }

  Widget? _buildLottie(
      String? path, {
        BoxFit fit = BoxFit.cover,
      }) {
    if (path == null) {
      return null;
    }

    final composition = compositions[path];
    final Widget widget = composition != null
        ? lottie.Lottie(
      composition: composition,
      fit: fit,
      animate: shouldAnimate,
      repeat: true,
    )
        : lottie.Lottie.asset(
      path,
      fit: fit,
      animate: shouldAnimate,
      repeat: true,
    );

    return IgnorePointer(
      ignoring: true,
      child: RepaintBoundary(child: widget),
    );
  }

  double _clampUnit(double value) => value.clamp(0.0, 1.0).toDouble();
}