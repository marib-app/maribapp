import 'package:flutter/material.dart';

/// Provides a gentle yet responsive transition when navigating between pages.
///
/// The animation combines a subtle fade, slide, and scale to make route
/// changes feel more polished compared to the default platform transitions.
class SmoothPageTransitionsBuilder extends PageTransitionsBuilder {
  const SmoothPageTransitionsBuilder();

  static final Tween<Offset> _incomingSlideTween = Tween<Offset>(
    begin: const Offset(0.08, 0),
    end: Offset.zero,
  );

  static final Tween<Offset> _outgoingSlideTween = Tween<Offset>(
    begin: Offset.zero,
    end: const Offset(-0.02, 0),
  );

  static final Tween<double> _scaleTween = Tween<double>(
    begin: 0.97,
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

    final incomingSlideAnimation =
    _incomingSlideTween.animate(curvedAnimation);
    final scaleAnimation = _scaleTween.animate(curvedAnimation);
    final secondaryCurve = CurvedAnimation(
      parent: _secondaryAnimation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    final outgoingSlideAnimation =
    _outgoingSlideTween.animate(secondaryCurve);

    return SlideTransition(
      position: outgoingSlideAnimation,
      child: SlideTransition(
        position: incomingSlideAnimation,
        child: ScaleTransition(
          scale: scaleAnimation,
          child: child,
        ),
      ),
    );
  }
}