import 'package:animations/animations.dart';
import 'package:flutter/material.dart';

import 'motion/route_motion.dart';

class AppPageRoute {
  AppPageRoute._();

  static const Duration _defaultDuration = Duration(milliseconds: 220);
  static const Duration _defaultBlurDuration = Duration(milliseconds: 220);

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
    AppMotionPattern motionPattern = AppMotionPattern.hero,
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
          pushCurve: curve,
          popCurve: popCurve ?? Curves.easeInCubic,
          customTransitionsBuilder: fadeTransitionBuilder,
        );
      case AppPageRouteTransition.custom:
        if (customTransitionsBuilder == null) {
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
          transitionsBuilder: customTransitionsBuilder,
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
      forwardDuration: forwardDuration ?? const Duration(milliseconds: 220),
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
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
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
    Curve pushCurve = Curves.easeOutCubic,
    Curve? popCurve,
    RouteTransitionsBuilder? customTransitionsBuilder,
  })  : _pushCurve = pushCurve,
        _popCurve = popCurve ?? Curves.easeInCubic,
        _customTransitionsBuilder = customTransitionsBuilder,
        super(
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
          transitionsBuilder:
              customTransitionsBuilder ?? _passThroughTransitionsBuilder,
        );

  final RouteTransitionsBuilder? _customTransitionsBuilder;
  final Curve _pushCurve;
  final Curve _popCurve;

  static Widget _passThroughTransitionsBuilder(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (_customTransitionsBuilder != null) {
      return _customTransitionsBuilder!(
        context,
        animation,
        secondaryAnimation,
        child,
      );
    }

    final CurvedAnimation primaryCurve = CurvedAnimation(
      parent: animation,
      curve: _pushCurve,
      reverseCurve: _popCurve,
    );

    Widget transitionedChild = SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.05),
        end: Offset.zero,
      ).animate(primaryCurve),
      child: child,
    );

    if (secondaryAnimation.status != AnimationStatus.dismissed ||
        secondaryAnimation.value > 0.0) {
      final CurvedAnimation secondaryCurve = CurvedAnimation(
        parent: secondaryAnimation,
        curve: _pushCurve,
        reverseCurve: _popCurve,
      );
      transitionedChild = SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -0.02),
          end: Offset.zero,
        ).animate(secondaryCurve),
        child: transitionedChild,
      );
    }

    return transitionedChild;
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
