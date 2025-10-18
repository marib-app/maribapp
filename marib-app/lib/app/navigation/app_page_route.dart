import 'package:flutter/material.dart';

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
  }) {
    return _LayeredPageRoute<T>(
      builder: builder,
      settings: settings,
      fullscreenDialog: fullscreenDialog,
      barrierDismissible: barrierDismissible,
      barrierColor: barrierColor,
      barrierLabel: barrierLabel,
      duration: duration ?? _defaultDuration,
      curve: curve,
      maintainState: maintainState,
      opaque: opaque ?? !barrierDismissible,
    );
  }
}

class _LayeredPageRoute<T> extends PageRouteBuilder<T> {
  _LayeredPageRoute({
    required WidgetBuilder builder,
    RouteSettings? settings,
    required bool fullscreenDialog,
    required bool barrierDismissible,
    Color? barrierColor,
    String? barrierLabel,
    required Duration duration,
    required Curve curve,
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
    transitionDuration: duration,
    reverseTransitionDuration: duration,
    pageBuilder: (context, animation, secondaryAnimation) {
      return builder(context);
    },
    transitionsBuilder:
        (context, animation, secondaryAnimation, child) {
      final curvedAnimation = CurvedAnimation(
        parent: animation,
        curve: curve,
        reverseCurve: curve.flipped,
      );



      final scaleAnimation = Tween<double>(
        begin: 0.96,
        end: 1,
      ).animate(curvedAnimation);

      const baseTranslation = Offset(0.015, 0.012);

      return AnimatedBuilder(
        animation: curvedAnimation,
        child: ScaleTransition(
          scale: scaleAnimation,
          child: child,
        ),
        builder: (context, scaleChild) {
          final progress = 1 - curvedAnimation.value;
          final verticalDirection =
          animation.status == AnimationStatus.reverse ? -1.0 : 1.0;
          final translation = Offset(
            baseTranslation.dx * progress,
            baseTranslation.dy * progress * verticalDirection,
          );

          return FractionalTranslation(
            translation: translation,
            child: scaleChild,
          );
        },
      );
    },
  );
}