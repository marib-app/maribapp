import 'package:flutter/material.dart';

/// Provides a gentle yet responsive transition when navigating between pages.
///
/// The animation combines a subtle fade, slide, and scale to make route
/// changes feel more polished compared to the default platform transitions.
class SmoothPageTransitionsBuilder extends PageTransitionsBuilder {
  const SmoothPageTransitionsBuilder();

  static final Tween<Offset> _slideTween = Tween<Offset>(
    begin: const Offset(0.08, 0.02),
    end: Offset.zero,
  );

  static final Tween<double> _scaleTween = Tween<double>(
    begin: 0.96,
    end: 1,
  );

  static final Tween<double> _stretchTween = Tween<double>(
    begin: 1.04,
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

    final slideAnimation = _slideTween.animate(curvedAnimation);
    final scaleAnimation = _scaleTween.animate(curvedAnimation);
    final stretchAnimation = _stretchTween.animate(curvedAnimation);

    return SlideTransition(
      position: slideAnimation,
      child: AnimatedBuilder(
        animation: curvedAnimation,
        child: child,
        builder: (context, child) {
          final scale = scaleAnimation.value;
          final stretch = stretchAnimation.value;

          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..scale(scale, stretch),
            child: child,
          );
        },
      ),
    );
  }
}