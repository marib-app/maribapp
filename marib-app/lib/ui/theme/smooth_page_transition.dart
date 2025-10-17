import 'package:flutter/material.dart';

/// Provides a gentle yet responsive transition when navigating between pages.
///
/// The animation combines a subtle fade, slide, and scale to make route
/// changes feel more polished compared to the default platform transitions.
class SmoothPageTransitionsBuilder extends PageTransitionsBuilder {
  const SmoothPageTransitionsBuilder();

  static final Tween<Offset> _slideTween = Tween<Offset>(
    begin: const Offset(0.05, 0),
    end: Offset.zero,
  );

  static final Tween<double> _scaleTween = Tween<double>(
    begin: 0.98,
    end: 1,
  );

  static final Tween<double> _fadeTween = Tween<double>(
    begin: 0,
    end: 1,
  );

  @override
  Widget buildTransitions<T>(
      PageRoute<T> route,
      BuildContext context,
      Animation<double> animation,
      Animation<double> _secondaryAnimation,
      Widget child,
      ) {
    // Do not animate the very first route.
    if (route.settings.name == Navigator.defaultRouteName) {
      return child;
    }

    final curvedAnimation = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    return FadeTransition(
      opacity: _fadeTween.animate(curvedAnimation),
      child: SlideTransition(
        position: _slideTween.animate(curvedAnimation),
        child: ScaleTransition(
          scale: _scaleTween.animate(curvedAnimation),
          child: child,
        ),
      ),
    );
  }
}