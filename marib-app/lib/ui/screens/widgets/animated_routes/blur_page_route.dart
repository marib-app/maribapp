import 'dart:ui';
import 'package:flutter/material.dart';

class BlurredRouter<T> extends PageRoute<T> {
  final WidgetBuilder builder;
  final double? sigmaX;
  final double? sigmaY;
  final bool? barrierDismiss;

  BlurredRouter({
    required this.builder,
    this.barrierDismiss,
    this.sigmaX,
    this.sigmaY,
    super.settings,
  }) : super(fullscreenDialog: false);

  @override
  bool get opaque => false;

  @override
  bool get barrierDismissible => barrierDismiss ?? false;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 120); // سريع

  @override
  Color get barrierColor => Colors.black.withOpacity(0.2);

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
    return FadeTransition(
      opacity: animation,
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: sigmaX ?? 5,
          sigmaY: sigmaY ?? 10,
        ),
        child: child,
      ),
    );
  }
}


