import 'dart:ui' show lerpDouble, ImageFilter;
import 'package:flutter/material.dart';

class SeamlessHero extends StatelessWidget {
  final Object tag;
  final Widget child;
  final bool transitionOnUserGestures;
  const SeamlessHero({required this.tag, required this.child, this.transitionOnUserGestures = true, super.key});
  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: tag,
      transitionOnUserGestures: transitionOnUserGestures,
      flightShuttleBuilder: (ctx, anim, flightDir, fromCtx, toCtx) {
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

class _EdgeSoftener extends StatelessWidget {
  final Widget child;
  final double softness;
  const _EdgeSoftener({required this.child, required this.softness});
  @override
  Widget build(BuildContext context) {
    if (softness <= 0) return child;
    return ShaderMask(
      shaderCallback: (Rect bounds) {
        final double inner = lerpDouble(0.90, 0.70, softness)!.clamp(0.0, 1.0);
        final double outer = lerpDouble(0.99, 0.95, softness)!.clamp(0.0, 1.0);
        return RadialGradient(
          center: Alignment.center,
          radius: 1.12,
          colors: const [Color(0xFFFFFFFF), Color(0xFFFFFFFF), Color(0x00FFFFFF)],
          stops: [inner, outer, 1.0],
        ).createShader(bounds);
      },
      blendMode: BlendMode.dstIn,
      child: child,
    );
  }
}

class _ColorBlendOverlay extends StatelessWidget {
  final Animation<double> animation;
  final double intensity;
  const _ColorBlendOverlay({required this.animation, this.intensity = 0.22});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).colorScheme;
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
                colors: [c.withOpacity((0.6 * intensity).clamp(0, 1)), c.withOpacity((0.9 * intensity).clamp(0, 1))],
              ),
            ),
            child: const SizedBox.expand(),
          );
        },
      ),
    );
  }
}

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
    final bool isCurrent = route.isCurrent;
    final Animation<double> inAnim = isCurrent ? CurvedAnimation(parent: animation, curve: Curves.easeOutCubic) : const AlwaysStoppedAnimation(1);
    final Animation<double> coverAnim = CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeInOutCubic);
    final Animation<double> fadeIn = Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: const Interval(0.12, 1.0, curve: Curves.easeOut))).animate(inAnim);
    final Animation<double> scaleIn = Tween(begin: 0.985, end: 1.0).chain(CurveTween(curve: Curves.easeOutCubic)).animate(inAnim);
    final Animation<Offset> slideIn = Tween(begin: const Offset(0, 0.01), end: Offset.zero).chain(CurveTween(curve: Curves.easeOutCubic)).animate(inAnim);
    final Animation<double> colorBlend = CurveTween(curve: const Interval(0.0, 0.85, curve: Curves.easeInOut)).animate(inAnim);
    final Animation<double> edgeSoftness = Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeInOutCubic)).animate(coverAnim);
    final Animation<double> textFade = Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: const Interval(0.18, 0.9, curve: Curves.easeOut))).animate(inAnim);
    return _EdgeSoftener(
      softness: edgeSoftness.value * 0.9,
      child: Stack(
        fit: StackFit.expand,
        children: [
          FadeTransition(
            opacity: fadeIn,
            child: SlideTransition(
              position: slideIn,
              child: ScaleTransition(
                scale: scaleIn,
                child: _TextSofter(
                  strength: (1 - textFade.value) * 0.08,
                  child: child,
                ),
              ),
            ),
          ),
          _ColorBlendOverlay(animation: colorBlend, intensity: 0.20),
        ],
      ),
    );
  }
}

class _TextSofter extends StatelessWidget {
  final Widget child;
  final double strength;
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

class FluidPageRoute<T> extends PageRoute<T> {
  final WidgetBuilder builder;
  final Duration duration;
  final Duration reverseDuration;
  FluidPageRoute({required this.builder, this.duration = const Duration(milliseconds: 420), this.reverseDuration = const Duration(milliseconds: 360), super.settings});
  @override
  bool get opaque => false;
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

extension FluidNavigator on BuildContext {
  Future<T?> pushFluid<T>(Widget page) {
    return Navigator.of(this).push<T>(FluidPageRoute<T>(builder: (_) => page));
  }
}










class CardPlanet extends StatelessWidget {
  final CardPlanetData data;
  final Map<String, LottieComposition> compositions;
  final bool shouldAnimate;
  final double progress;
  final double contentProgress;
  const CardPlanet({
    required this.data,
    required this.shouldAnimate,
    required this.compositions,
    required this.progress,
    required this.contentProgress,
    super.key,
  });
  LottieComposition? _compositionFor(String? path) {
    if (path == null) return null;
    return compositions[path];
  }
  @override
  Widget build(BuildContext context) {
    final double clampedProgress = progress.clamp(-1.0, 1.0).toDouble();
    final double verticalOffset = 60.0 * clampedProgress;
    final double clampedContent = contentProgress.clamp(0.0, 1.0);
    final double backgroundShift = 30.0 * clampedProgress;
    double staggered(double value, {double begin = 0.0, double end = 1.0, Curve curve = Curves.easeInOut}) {
      if (begin >= end) return value >= end ? 1.0 : 0.0;
      final double normalized = ((value - begin) / (end - begin)).clamp(0.0, 1.0);
      return curve.transform(normalized);
    }
    final double titleProgress = staggered(clampedContent, begin: 0.0, end: 0.35, curve: Curves.easeOutCubic);
    final double subtitleProgress = staggered(clampedContent, begin: 0.12, end: 0.55, curve: Curves.easeInOut);
    final double secondaryProgress = staggered(clampedContent, begin: 0.35, end: 0.9, curve: Curves.easeInOut);
    final double backgroundProgress = staggered(clampedContent, begin: 0.25, end: 1.0, curve: Curves.easeInOut);
    final titleColor = Color.lerp(data.titleColor.withOpacity(0.0), data.titleColor, titleProgress) ?? data.titleColor;
    final subtitleColor = Color.lerp(data.subtitleColor.withOpacity(0.0), data.subtitleColor, subtitleProgress) ?? data.subtitleColor;
    final subtleOverlayColor = data.backgroundGradientColors.isEmpty
        ? null
        : Color.lerp(Colors.transparent, data.backgroundGradientColors.first.withOpacity(0.18), backgroundProgress);
    Widget animatedEntry({
      required Widget child,
      required double progress,
      double vertical = 0,
      double initialOffset = 40,
      double minScale = 0.94,
      Curve curve = Curves.easeInOut,
      Duration duration = const Duration(milliseconds: 360),
    }) {
      return TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: progress),
        duration: duration,
        curve: curve,
        child: child,
        builder: (context, value, child) {
          final double translateY = vertical + (1 - value) * initialOffset;
          final double scale = lerpDouble(minScale, 1.0, value)!;
          return Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, translateY),
              child: Transform.scale(
                scale: scale,
                child: child,
              ),
            ),
          );
        },
      );
    }
    return Stack(
      children: [
        Positioned.fill(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
            color: subtleOverlayColor,
          ),
        ),
        if (data.backgroundAnimationPath != null)
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: backgroundProgress),
            duration: const Duration(milliseconds: 520),
            curve: Curves.easeInOut,
            child: () {
              final cached = _compositionFor(data.backgroundAnimationPath);
              if (cached != null) {
                return Lottie(
                  composition: cached,
                  fit: BoxFit.cover,
                  animate: shouldAnimate,
                  repeat: shouldAnimate,
                );
              }
              return Lottie.asset(
                data.backgroundAnimationPath!,
                fit: BoxFit.cover,
                animate: shouldAnimate,
                repeat: shouldAnimate,
              );
            }(),
            builder: (context, value, child) {
              final double opacity = (0.15 + 0.35 * value).clamp(0.0, 1.0);
              return Transform.translate(
                offset: Offset(backgroundShift * value, 0),
                child: Opacity(
                  opacity: opacity,
                  child: child,
                ),
              );
            },
          ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),
              if (data.animationPath != null)
                Flexible(
                  flex: 20,
                  child: animatedEntry(
                    progress: secondaryProgress,
                    vertical: verticalOffset,
                    initialOffset: 80,
                    minScale: 0.88,
                    curve: Curves.easeOutCubic,
                    duration: const Duration(milliseconds: 420),
                    child: () {
                      final cached = _compositionFor(data.animationPath);
                      final double height = MediaQuery.of(context).size.height * 0.45;
                      if (cached != null) {
                        return Lottie(
                          composition: cached,
                          height: height,
                          fit: BoxFit.contain,
                          animate: shouldAnimate,
                          repeat: shouldAnimate,
                        );
                      }
                      return Lottie.asset(
                        data.animationPath!,
                        height: height,
                        fit: BoxFit.contain,
                        animate: shouldAnimate,
                        repeat: shouldAnimate,
                      );
                    }(),
                  ),
                ),
              if (data.image != null)
                Flexible(
                  flex: 20,
                  child: animatedEntry(
                    progress: secondaryProgress,
                    vertical: verticalOffset,
                    initialOffset: 70,
                    minScale: 0.92,
                    curve: Curves.easeOutCubic,
                    duration: const Duration(milliseconds: 420),
                    child: Image(image: data.image!),
                  ),
                ),
              const Spacer(flex: 2),
              Directionality(
                textDirection: TextDirection.rtl,
                child: Column(
                  children: [
                    animatedEntry(
                      progress: titleProgress,
                      vertical: verticalOffset / 2,
                      initialOffset: 30,
                      minScale: 0.94,
                      curve: Curves.easeInOut,
                      duration: const Duration(milliseconds: 320),
                      child: Text(
                        data.title,
                        style: GoogleFonts.tajawal(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: titleColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 12),
                    animatedEntry(
                      progress: subtitleProgress,
                      vertical: verticalOffset / 2,
                      initialOffset: 24,
                      minScale: 0.96,
                      curve: Curves.easeInOut,
                      duration: const Duration(milliseconds: 360),
                      child: Text(
                        data.subtitle,
                        style: GoogleFonts.tajawal(
                          fontSize: 16,
                          height: 1.6,
                          color: subtitleColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(flex: 5),
            ],
          ),
        )
      ],
    );
  }
}
