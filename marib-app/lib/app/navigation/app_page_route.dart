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
        reverseCurve: Curves.easeInQuart,
      );

      final horizontalSlide = Tween<Offset>(
        begin: const Offset(0.05, 0),
        end: Offset.zero,
      ).animate(curvedAnimation);

      final verticalSlide = Tween<Offset>(
        begin: const Offset(0, 0.08),
        end: Offset.zero,
      ).animate(curvedAnimation);

      final scaleAnimation = Tween<double>(
        begin: 0.96,
        end: 1,
      ).animate(curvedAnimation);


      Widget current = child;
      current = SlideTransition(
        position: horizontalSlide,
        child: SlideTransition(
          position: verticalSlide,
          child: current,
        ),
      );
      current = ScaleTransition(
        scale: scaleAnimation,
        child: current,
      );

      return current;
    },
  );
}