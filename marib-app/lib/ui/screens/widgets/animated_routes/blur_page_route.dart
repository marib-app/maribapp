import 'dart:ui';
import 'package:flutter/material.dart';

class BlurredRouter<T> extends PageRoute<T> {
  final WidgetBuilder builder;
  final AxisDirection axisDirection;
  final Duration? duration;
  final bool? barrierDismiss;
  final double? barrierOpacity;

  BlurredRouter({
    required this.builder,
    this.barrierDismiss,
    this.axisDirection = AxisDirection.down,
    this.duration,
    this.barrierOpacity,
    super.settings,
  }) : super(fullscreenDialog: false);

  @override
  bool get opaque => false;

  @override
  bool get barrierDismissible => barrierDismiss ?? false;

  @override
  Duration get transitionDuration => duration ?? const Duration(milliseconds: 200);

  @override
  Duration get reverseTransitionDuration => duration ?? const Duration(milliseconds: 180);

  @override
  Color get barrierColor => Colors.black.withOpacity(barrierOpacity ?? 0.2);

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    return builder(context);
  }

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    final Offset entryOffset = _offsetForDirection(axisDirection);

    final Animation<Offset> slideAnimation = animation.drive(
      TweenSequence<Offset>(
        <TweenSequenceItem<Offset>>[
          TweenSequenceItem<Offset>(
            tween: Tween<Offset>(
              begin: entryOffset,
              end: entryOffset * 0.2,
            ).chain(CurveTween(curve: Curves.easeOut)),
            weight: 60,
          ),
          TweenSequenceItem<Offset>(
            tween: Tween<Offset>(
              begin: entryOffset * 0.2,
              end: Offset.zero,
            ).chain(CurveTween(curve: Curves.easeOutBack)),
            weight: 40,
          ),
        ],
      ),
    );

    final Animation<double> scaleAnimation = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeIn,
    ).drive(Tween<double>(begin: 0.92, end: 1));

    return SlideTransition(
      position: slideAnimation,
      child: ScaleTransition(
        scale: scaleAnimation,
        child: child,
      ),
    );
  }
  Offset _offsetForDirection(AxisDirection direction) {
    switch (direction) {
      case AxisDirection.up:
        return const Offset(0, -0.18);
      case AxisDirection.right:
        return const Offset(0.2, 0);
      case AxisDirection.down:
        return const Offset(0, 0.2);
      case AxisDirection.left:
        return const Offset(-0.2, 0);
    }
  }
}


