import 'package:flutter/material.dart';

import 'route_motion.dart';

/// Global controller responsible for providing [RouteMotionComposer] instances
/// according to the application's motion preferences.
class MotionSettingsController {
  MotionSettingsController._()
      : _defaultComposer = const RouteMotionComposer(
    pattern: AppMotionPattern.sharedAxis,
  );

  static final MotionSettingsController instance =
  MotionSettingsController._();

  RouteMotionComposer _defaultComposer;
  AppMotionPattern? _preferredPattern;
  SharedAxisTransitionType? _preferredSharedAxisType;
  bool? _prefersReducedMotion;

  /// Stores the baseline [RouteMotionComposer] built from theme defaults.
  void configureDefaults(RouteMotionComposer composer) {
    _defaultComposer = composer;
  }

  /// Updates the global motion preferences.
  void updatePreferences({
    AppMotionPattern? pattern,
    SharedAxisTransitionType? sharedAxisType,
    bool? prefersReducedMotion,
  }) {
    if (pattern != null) {
      _preferredPattern = pattern;
    }
    if (sharedAxisType != null) {
      _preferredSharedAxisType = sharedAxisType;
    }
    if (prefersReducedMotion != null) {
      _prefersReducedMotion = prefersReducedMotion;
    }
  }

  /// Clears any overrides applied via [updatePreferences].
  void clearOverrides() {
    _preferredPattern = null;
    _preferredSharedAxisType = null;
    _prefersReducedMotion = null;
  }

  /// Restores the controller to its initial state.
  void reset() {
    _defaultComposer = const RouteMotionComposer(
      pattern: AppMotionPattern.sharedAxis,
    );
    clearOverrides();
  }

  /// Resolves the effective [RouteMotionComposer] for the given [route].
  RouteMotionComposer resolveComposer({
    required PageRoute<dynamic> route,
    RouteMotionComposer? defaults,
  }) {
    if (defaults != null) {
      _defaultComposer = defaults;
    }

    final RouteMotionComposer base = defaults ?? _defaultComposer;

    return RouteMotionComposer(
      pattern: _preferredPattern ?? base.pattern,
      sharedAxisType: _preferredSharedAxisType ?? base.sharedAxisType,
      pushDuration: base.pushDuration,
      popDuration: base.popDuration,
      refreshDuration: base.refreshDuration,
      pushCurve: base.pushCurve,
      popCurveOverride: base.popCurve,
      refreshCurveOverride: base.refreshCurve,
      pushReverseCurveOverride: base.pushReverseCurve,
      popReverseCurveOverride: base.popReverseCurve,
      refreshReverseCurveOverride: base.refreshReverseCurve,
      modal: route.fullscreenDialog,
      reducedMotion: _prefersReducedMotion ?? base.reducedMotion,
    );
  }
}

/// A [PageTransitionsBuilder] that leverages [RouteMotionComposer] to build
/// consistent page transitions according to global motion preferences.
class MotionPageTransitionsBuilder extends PageTransitionsBuilder {
  const MotionPageTransitionsBuilder({
    this.defaultPattern = AppMotionPattern.sharedAxis,
    this.sharedAxisType = SharedAxisTransitionType.scaled,
    this.pushDuration = const Duration(milliseconds: 200),
    Duration? popDuration,
    Duration? refreshDuration,
    this.pushCurve = Curves.easeOutCubic,
    this.popCurve,
    this.refreshCurve,
    this.controller,
  })  : popDuration = popDuration ?? pushDuration,
        refreshDuration = refreshDuration ?? pushDuration;

  final AppMotionPattern defaultPattern;
  final SharedAxisTransitionType sharedAxisType;
  final Duration pushDuration;
  final Duration popDuration;
  final Duration refreshDuration;
  final Curve pushCurve;
  final Curve? popCurve;
  final Curve? refreshCurve;
  final MotionSettingsController? controller;

  MotionSettingsController get _controller =>
      controller ?? MotionSettingsController.instance;

  RouteMotionComposer _defaults({required bool modal}) {
    return RouteMotionComposer(
      pattern: defaultPattern,
      sharedAxisType: sharedAxisType,
      pushDuration: pushDuration,
      popDuration: popDuration,
      refreshDuration: refreshDuration,
      pushCurve: pushCurve,
      popCurveOverride: popCurve,
      refreshCurveOverride: refreshCurve,
      modal: modal,
      reducedMotion: false,
    );
  }

  @override
  Widget buildTransitions<T>(
      PageRoute<T> route,
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      Widget child,
      ) {
    if (route.settings.name == Navigator.defaultRouteName) {
      return child;
    }

    final MotionSettingsController controller = _controller;

    controller.configureDefaults(_defaults(modal: false));

    final RouteMotionComposer composer = controller.resolveComposer(
      route: route,
      defaults: _defaults(modal: route.fullscreenDialog),
    );

    if (animation.status == AnimationStatus.reverse) {
      return composer.buildForPop(
        context,
        animation,
        secondaryAnimation,
        child,
        route: route,
      );
    }

    if (secondaryAnimation.status == AnimationStatus.forward &&
        animation.status == AnimationStatus.forward) {
      return composer.buildForRefresh(
        context,
        animation,
        secondaryAnimation,
        child,
        route: route,
      );
    }

    return composer.buildForPush(
      context,
      animation,
      secondaryAnimation,
      child,
      route: route,
    );
  }
}