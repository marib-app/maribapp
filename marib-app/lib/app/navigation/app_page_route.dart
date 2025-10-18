import 'package:flutter/material.dart';
import 'package:animations/animations.dart';
import 'motion/route_motion.dart';




class AppPageRoute {
  AppPageRoute._();

  static const Duration _defaultDuration = Duration(milliseconds: 200);

  static PageRoute<T> build<T>({
    required WidgetBuilder builder,
    RouteSettings? settings,
    bool fullscreenDialog = false,
    bool barrierDismissible = false,
    Color? barrierColor,
    String? barrierLabel,
    Duration? duration,
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

  }) {
    final baseDuration = duration ?? _defaultDuration;
    final baseReverseDuration = reverseDuration ?? baseDuration;
    final baseRefreshDuration = refreshDuration ?? baseDuration;

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
  }
}

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