import 'dart:ui';
import 'package:flutter/material.dart';

class BlurredRouter<T> extends PageRoute<T> {
  final WidgetBuilder builder;
  final double? sigmaX;
  final double? sigmaY;
  final bool? barrierDismiss;
  final double? barrierOpacity;

  BlurredRouter({
    required this.builder,
    this.barrierDismiss,
    this.sigmaX,
    this.sigmaY,
    this.barrierOpacity,
    super.settings,
  }) : super(fullscreenDialog: false);

  @override
  bool get opaque => false;

  @override
  bool get barrierDismissible => barrierDismiss ?? false;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 280);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 280);

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

    final curvedAnimation = CurvedAnimation(
      parent: animation,
      curve: Curves.easeInOut,
      reverseCurve: Curves.easeInOut,
    );

    final curvedSecondaryAnimation = CurvedAnimation(
      parent: secondaryAnimation,
      curve: Curves.easeInOut,
      reverseCurve: Curves.easeInOut,
    );

    final slideInAnimation = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(curvedAnimation);

    final slideOutAnimation = Tween<Offset>(
      begin: const Offset(0, 0.02),
      end: Offset.zero,
    ).animate(curvedSecondaryAnimation);


    return FadeTransition(
      opacity: curvedAnimation,
      child: SlideTransition(
        position: slideInAnimation,
        child: SlideTransition(
          position: slideOutAnimation,
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: sigmaX ?? 5,
              sigmaY: sigmaY ?? 10,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}



/*
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';

///This router will be show blurred transations
///this will provide fade transiton also.
///this is also being use to show background blur dialoge boxes
class BlurredRouter extends PageRoute<void> {
  final double? sigmaX;
  final double? sigmaY;
  final bool? barrierDismiss;
  BlurredRouter(
      {required this.builder,
      this.barrierDismiss,
      super.settings,
      this.sigmaX,
      this.sigmaY})
      : super(fullscreenDialog: false);

  final WidgetBuilder builder;

  @override
  bool get opaque => false;
  @override
  Color get barrierColor => Colors.transparent;
  @override
  bool get barrierDismissible => barrierDismiss ?? super.barrierDismissible;

  @override
  String get barrierLabel => "blurred";

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 350);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation) {
    final result = builder(context);
// Tween<int> tween = Tween(begin: 0,end: 0);

    ///We have to show swipe gesture in ios wo we are making condition here
    if (Platform.isIOS) {
      var theme = Theme.of(context).pageTransitionsTheme;

      return theme.buildTransitions(
        this,
        context,
        animation,
        Animation.fromValueListenable(ValueNotifier(0)),
        BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: sigmaX ?? 5,
            sigmaY: sigmaY ?? 10,
          ),
          child: result,
        ),
      );
    }
    return FadeTransition(
      opacity: Tween<double>(begin: 0, end: 1).animate(animation),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: sigmaX ?? 5,
          sigmaY: sigmaY ?? 10,
        ),
        child: result,
      ),
    );
  }
}
*/