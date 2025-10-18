import 'package:animations/animations.dart';
import 'package:flutter/material.dart';

enum AppMotionPattern { sharedAxis, fadeThrough, platform }

enum _RouteMotionPhase { push, pop, refresh }

class RouteMotionComposer {
   RouteMotionComposer({
    required this.pattern,
    this.sharedAxisType = SharedAxisTransitionType.scaled,
    Duration? pushDuration,
    Duration? popDuration,
    Duration? refreshDuration,
    Curve pushCurve = Curves.easeOutCubic,
    Curve? popCurveOverride,
    Curve? refreshCurveOverride,
    Curve? pushReverseCurveOverride,
    Curve? popReverseCurveOverride,
    Curve? refreshReverseCurveOverride,
    this.modal = false,
    this.reducedMotion = false,
  })  : pushDuration = pushDuration ?? const Duration(milliseconds: 200),
        popDuration = popDuration ?? pushDuration ?? const Duration(milliseconds: 200),
        refreshDuration =
            refreshDuration ?? pushDuration ?? const Duration(milliseconds: 200),
        pushCurve = pushCurve,
        pushReverseCurve =
            pushReverseCurveOverride ?? pushCurve.flipped,
        popCurve =
            popCurveOverride ?? pushReverseCurveOverride ?? pushCurve.flipped,
        popReverseCurve = popReverseCurveOverride ??
            popCurveOverride ??
            pushCurve,
        refreshCurve = refreshCurveOverride ?? pushCurve,
        refreshReverseCurve = refreshReverseCurveOverride ??
            refreshCurveOverride ??
            pushCurve.flipped;

  final AppMotionPattern pattern;
  final SharedAxisTransitionType sharedAxisType;
  final Duration pushDuration;
  final Duration popDuration;
  final Duration refreshDuration;
  final Curve pushCurve;
  final Curve pushReverseCurve;
  final Curve popCurve;
  final Curve popReverseCurve;
  final Curve refreshCurve;
  final Curve refreshReverseCurve;
  final bool modal;
  final bool reducedMotion;

  static bool platformPrefersReducedMotion() {
    final WidgetsBinding? binding = WidgetsBinding.instance;
    if (binding == null) {
      return false;
    }
    final dispatcher = binding.platformDispatcher;
    final features = dispatcher.accessibilityFeatures;
    return features.disableAnimations ||
        features.reduceMotion ||
        features.accessibleNavigation;
  }

  RouteMotionComposer withReducedMotion([bool value = true]) {
    if (value == reducedMotion) {
      return this;
    }

    return RouteMotionComposer(
      pattern: pattern,
      sharedAxisType: sharedAxisType,
      pushDuration: pushDuration,
      popDuration: popDuration,
      refreshDuration: refreshDuration,
      pushCurve: pushCurve,
      popCurveOverride: popCurve,
      refreshCurveOverride: refreshCurve,
      pushReverseCurveOverride: pushReverseCurve,
      popReverseCurveOverride: popReverseCurve,
      refreshReverseCurveOverride: refreshReverseCurve,
      modal: modal,
      reducedMotion: value,
    );
  }

  Duration get effectivePushDuration =>
      reducedMotion ? Duration.zero : pushDuration;

  Duration get effectivePopDuration =>
      reducedMotion ? Duration.zero : popDuration;

  Duration get effectiveRefreshDuration =>
      reducedMotion ? Duration.zero : refreshDuration;

  Widget buildForPush(
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      Widget child, {
        PageRoute<dynamic>? route,
      }) {
    return _buildTransition(
      context,
      animation,
      secondaryAnimation,
      child,
      _RouteMotionPhase.push,
      route: route,
    );
  }

  Widget buildForPop(
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      Widget child, {
        PageRoute<dynamic>? route,
      }) {
    return _buildTransition(
      context,
      animation,
      secondaryAnimation,
      child,
      _RouteMotionPhase.pop,
      route: route,
    );
  }

  Widget buildForRefresh(
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      Widget child, {
        PageRoute<dynamic>? route,
      }) {
    return _buildTransition(
      context,
      animation,
      secondaryAnimation,
      child,
      _RouteMotionPhase.refresh,
      route: route,
    );
  }

  Widget _buildTransition(
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      Widget child,
      _RouteMotionPhase phase, {
        PageRoute<dynamic>? route,
      }) {
    if (_shouldReduceMotion(context)) {
      return child;
    }

    if (modal) {
      return FadeScaleTransition(
        animation: _primaryAnimation(animation, phase),
        child: child,
      );
    }

    switch (pattern) {
      case AppMotionPattern.sharedAxis:
        return SharedAxisTransition(
          animation: _primaryAnimation(animation, phase),
          secondaryAnimation: _secondaryAnimation(secondaryAnimation, phase),
          transitionType: sharedAxisType,
          child: child,
        );
      case AppMotionPattern.fadeThrough:
        return FadeThroughTransition(
          animation: _primaryAnimation(animation, phase),
          secondaryAnimation: _secondaryAnimation(secondaryAnimation, phase),
          child: child,
        );
      case AppMotionPattern.platform:
        final routeForTransition = route ??
            ModalRoute.of(context);
        final pageRoute = routeForTransition is PageRoute<dynamic>
            ? routeForTransition
            : null;
        if (pageRoute != null) {
          return Theme.of(context).pageTransitionsTheme.buildTransitions(
            pageRoute,
            context,
            _primaryAnimation(animation, phase),
            _secondaryAnimation(secondaryAnimation, phase),
            child,
          );
        }
        return child;
    }
  }

  Animation<double> _primaryAnimation(
      Animation<double> animation,
      _RouteMotionPhase phase,
      ) {
    switch (phase) {
      case _RouteMotionPhase.push:
        return CurvedAnimation(
          parent: animation,
          curve: pushCurve,
          reverseCurve: pushReverseCurve,
        );
      case _RouteMotionPhase.pop:
        return CurvedAnimation(
          parent: animation,
          curve: popCurve,
          reverseCurve: popReverseCurve,
        );
      case _RouteMotionPhase.refresh:
        return CurvedAnimation(
          parent: animation,
          curve: refreshCurve,
          reverseCurve: refreshReverseCurve,
        );
    }
  }

  Animation<double> _secondaryAnimation(
      Animation<double> animation,
      _RouteMotionPhase phase,
      ) {
    switch (phase) {
      case _RouteMotionPhase.push:
        return CurvedAnimation(
          parent: animation,
          curve: popCurve,
          reverseCurve: popReverseCurve,
        );
      case _RouteMotionPhase.pop:
        return CurvedAnimation(
          parent: animation,
          curve: pushCurve,
          reverseCurve: pushReverseCurve,
        );
      case _RouteMotionPhase.refresh:
        return CurvedAnimation(
          parent: animation,
          curve: refreshCurve,
          reverseCurve: refreshReverseCurve,
        );
    }
  }

  bool _shouldReduceMotion(BuildContext context) {
    if (reducedMotion) {
      return true;
    }

    final mediaQuery = MediaQuery.maybeOf(context);
    if (mediaQuery == null) {
      return false;
    }

    return mediaQuery.disableAnimations || mediaQuery.accessibleNavigation;
  }
}