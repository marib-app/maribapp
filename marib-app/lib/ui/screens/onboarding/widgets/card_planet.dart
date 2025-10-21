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
