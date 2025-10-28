import 'dart:ui';

import 'package:animations/animations.dart';
import 'package:flutter/material.dart';

import 'motion/route_motion.dart';


class AppPageRoute {
  AppPageRoute._();

  static const Duration _defaultDuration = Duration(milliseconds: 200);
  static const Duration _defaultBlurDuration = Duration(milliseconds: 180);

  static Duration _durationForTransition(AppPageRouteTransition transition) {
    switch (transition) {
      case AppPageRouteTransition.motion:
      case AppPageRouteTransition.custom:
        return _defaultDuration;
      case AppPageRouteTransition.fadeBlur:
        return _defaultBlurDuration;
    }
  }

  static PageRoute<T> build<T>({
    required WidgetBuilder builder,
    RouteSettings? settings,
    bool fullscreenDialog = false,
    bool barrierDismissible = false,
    Color? barrierColor,
    String? barrierLabel,
    Duration? duration,
    Duration? forwardDuration,
    Curve curve = Curves.easeOutQuart,
    bool maintainState = true,
    bool? opaque,
    AppMotionPattern motionPattern = AppMotionPattern.sharedAxis,
    SharedAxisTransitionType sharedAxisType = SharedAxisTransitionType.scaled,
    bool? reduceMotion,
    Duration? reverseDuration,
    Duration? refreshDuration,
    Curve? popCurve,
    Curve? refreshCurve,
    AppPageRouteTransition transition = AppPageRouteTransition.motion,
    RouteTransitionsBuilder? fadeTransitionBuilder,
    RouteTransitionsBuilder? customTransitionsBuilder,

  }) {
    final baseDuration =
        forwardDuration ?? duration ?? _durationForTransition(transition);
    final baseReverseDuration = reverseDuration ?? baseDuration;
    final baseRefreshDuration = refreshDuration ?? baseDuration;

    switch (transition) {
      case AppPageRouteTransition.motion:
        final composer = RouteMotionComposer(
          pattern: motionPattern,
          sharedAxisType: sharedAxisType,
          pushDuration: baseDuration,
          popDuration: baseReverseDuration,
          refreshDuration: baseRefreshDuration,
          pushCurve: curve,
          popCurveOverride: popCurve,
          refreshCurveOverride: refreshCurve,
          modal: fullscreenDialog || barrierDismissible,
          reducedMotion: reduceMotion ??
              RouteMotionComposer.platformPrefersReducedMotion(),
        );

        return _MotionPageRoute<T>(
          builder: builder,
          settings: settings,
          fullscreenDialog: fullscreenDialog,
          barrierDismissible: barrierDismissible,
          barrierColor: barrierColor,
          barrierLabel: barrierLabel,
          maintainState: maintainState,
          opaque: opaque ?? !barrierDismissible,
          composer: composer,
        );
      case AppPageRouteTransition.fadeBlur:
        return _FadeBlurPageRoute<T>(
          builder: builder,
          settings: settings,
          fullscreenDialog: fullscreenDialog,
          barrierDismissible: barrierDismissible,
          barrierColor: barrierColor,
          barrierLabel: barrierLabel,
          maintainState: maintainState,
          opaque: opaque ?? !barrierDismissible,
          forwardDuration: baseDuration,
          reverseDuration: baseReverseDuration,
          customTransitionsBuilder: fadeTransitionBuilder,
        );
      case AppPageRouteTransition.custom:
        if (customTransitionsBuilder  == null) {
          throw ArgumentError(
            'A custom transitionsBuilder must be provided when using '
                'AppPageRouteTransition.custom.',
          );
        }
        return _CustomPageRoute<T>(
          builder: builder,
          settings: settings,
          fullscreenDialog: fullscreenDialog,
          barrierDismissible: barrierDismissible,
          barrierColor: barrierColor,
          barrierLabel: barrierLabel,
          maintainState: maintainState,
          opaque: opaque ?? !barrierDismissible,
          forwardDuration: baseDuration,
          reverseDuration: baseReverseDuration,
          transitionsBuilder: customTransitionsBuilder ,
        );
    }
  }



  static PageRoute<T> buildOverlay<T>({
    required WidgetBuilder builder,
    RouteSettings? settings,
    bool barrierDismissible = false,
    Duration? forwardDuration,
    Duration? reverseDuration,
    Color? barrierColor,
  }) {
    return AppPageRoute.build(
      builder: builder,
      settings: settings,
      transition: AppPageRouteTransition.fadeBlur,
      forwardDuration:
      forwardDuration ?? const Duration(milliseconds: 180),
      reverseDuration: reverseDuration,
      barrierDismissible: barrierDismissible,
      barrierColor: barrierColor ?? Colors.black.withOpacity(0.2),
      opaque: false,
    );
  }

}

enum AppPageRouteTransition { motion, fadeBlur, custom }


class _MotionPageRoute<T> extends PageRouteBuilder<T> {
  _MotionPageRoute({
    required WidgetBuilder builder,
    RouteSettings? settings,
    required bool fullscreenDialog,
    required bool barrierDismissible,
    Color? barrierColor,
    String? barrierLabel,
    required RouteMotionComposer composer,
    required bool maintainState,
    required bool opaque,
  }) : super(
    settings: settings,
    fullscreenDialog: fullscreenDialog,
    barrierDismissible: barrierDismissible,
    barrierColor: barrierColor,
    barrierLabel: barrierLabel,
    maintainState: maintainState,
    opaque: opaque,
    transitionDuration: composer.effectivePushDuration,
    reverseTransitionDuration: composer.effectivePopDuration,
    pageBuilder: (context, animation, secondaryAnimation) {
      return builder(context);
    },
    transitionsBuilder:
        (context, animation, secondaryAnimation, child) {
          final route = ModalRoute.of(context);
          if (animation.status == AnimationStatus.reverse) {
            return composer.buildForPop(
              context,
              animation,
              secondaryAnimation,
              child,
              route: route is PageRoute<dynamic> ? route : null,
            );
          }

          if (secondaryAnimation.status == AnimationStatus.forward &&
              animation.status == AnimationStatus.forward) {
            return composer.buildForRefresh(
              context,
              animation,
              secondaryAnimation,
              child,
              route: route is PageRoute<dynamic> ? route : null,
            );
          }

          return composer.buildForPush(
            context,
            animation,
            secondaryAnimation,
            child,
            route: route is PageRoute<dynamic> ? route : null,
      );
    },
  );



}

class _FadeBlurPageRoute<T> extends PageRouteBuilder<T> {
  _FadeBlurPageRoute({
    required WidgetBuilder builder,
    RouteSettings? settings,
    required bool fullscreenDialog,
    required bool barrierDismissible,
    Color? barrierColor,
    String? barrierLabel,
    required bool maintainState,
    required bool opaque,
    required Duration forwardDuration,
    required Duration reverseDuration,
    RouteTransitionsBuilder? customTransitionsBuilder,
  }) : super(
    settings: settings,
    fullscreenDialog: fullscreenDialog,
    barrierDismissible: barrierDismissible,
    barrierColor: barrierColor,
    barrierLabel: barrierLabel,
    maintainState: maintainState,
    opaque: opaque,
    transitionDuration: forwardDuration,
    reverseTransitionDuration: reverseDuration,
    pageBuilder: (context, animation, secondaryAnimation) {
      return builder(context);
    },
    transitionsBuilder: customTransitionsBuilder ??
            (context, animation, secondaryAnimation, child) {
          final bool isPushing =
              animation.status != AnimationStatus.reverse;
          final Animation<double> progress = isPushing
              ? animation
              : ReverseAnimation(animation);

          final CurvedAnimation eased = CurvedAnimation(
            parent: progress,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );

          final Animation<double> fade = Tween<double>(
            begin: isPushing ? 0.0 : 1.0,
            end: isPushing ? 1.0 : 0.0,
          ).animate(eased);

          final Animation<Offset> slide = Tween<Offset>(
            begin: isPushing
                ? const Offset(0.0, 0.035)
                : Offset.zero,
            end: isPushing
                ? Offset.zero
                : const Offset(0.0, 0.02),
          ).animate(eased);

          final Animation<double> scale = Tween<double>(
            begin: isPushing ? 0.98 : 1.0,
            end: isPushing ? 1.0 : 0.985,
          ).animate(eased);

          return FadeTransition(
            opacity: fade,
            child: SlideTransition(
              position: slide,
              child: ScaleTransition(
                scale: scale,
                child: child,
              ),
            ),
          );

        },
  );



  @override
  Widget buildTransitions(
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      Widget child,
      ) {
    final Widget transitionedChild = super.buildTransitions(
      context,
      animation,
      secondaryAnimation,
      child,
    );

    if (opaque) {
      return transitionedChild;
    }

    final bool isPushing = animation.status != AnimationStatus.reverse;
    final Animation<double> progress =
    isPushing ? animation : ReverseAnimation(animation);
    final CurvedAnimation eased = CurvedAnimation(
      parent: progress,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    return AnimatedBuilder(
      animation: eased,
      child: transitionedChild,
      builder: (context, animatedChild) {
        final double backdropStrength =
        ((1 - eased.value).clamp(0.0, 1.0)).toDouble();
        final double blurSigma = 6.0 * backdropStrength;
        final Color baseBarrierColor = (barrierColor ?? Colors.black);
        final double baseBarrierOpacity = barrierColor?.opacity ?? 0.12;
        final double overlayOpacity = baseBarrierOpacity * backdropStrength;

        Widget backdrop = Container(
          color: baseBarrierColor.withOpacity(overlayOpacity),
        );

        if (blurSigma > 0) {
          backdrop = ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: blurSigma,
                sigmaY: blurSigma,
              ),
              child: backdrop,
            ),
          );
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            backdrop,
            animatedChild ?? const SizedBox.shrink(),
          ],
        );
      },
    );
  }
}

class _CustomPageRoute<T> extends PageRouteBuilder<T> {
  _CustomPageRoute({
    required WidgetBuilder builder,
    RouteSettings? settings,
    required bool fullscreenDialog,
    required bool barrierDismissible,
    Color? barrierColor,
    String? barrierLabel,
    required bool maintainState,
    required bool opaque,
    required Duration forwardDuration,
    required Duration reverseDuration,
    required RouteTransitionsBuilder transitionsBuilder,
  }) : super(
    settings: settings,
    fullscreenDialog: fullscreenDialog,
    barrierDismissible: barrierDismissible,
    barrierColor: barrierColor,
    barrierLabel: barrierLabel,
    maintainState: maintainState,
    opaque: opaque,
    transitionDuration: forwardDuration,
    reverseTransitionDuration: reverseDuration,
    pageBuilder: (context, animation, secondaryAnimation) {
      return builder(context);
    },
    transitionsBuilder: transitionsBuilder,
  );
}