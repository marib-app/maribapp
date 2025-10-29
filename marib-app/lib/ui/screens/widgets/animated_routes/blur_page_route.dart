import 'package:flutter/material.dart';
import 'package:marib/app/navigation/app_page_route.dart';
import 'package:marib/app/navigation/motion/route_motion.dart';

PageRoute<T> BlurredRouter<T>({
  required WidgetBuilder builder,
  RouteSettings? settings,
  bool barrierDismiss = false,
  double barrierOpacity = 0.2,
  Duration? duration,
  Duration? reverseDuration,
  Curve enterCurve = Curves.easeOutCubic,
  Curve exitCurve = Curves.easeInCubic,
  bool fullscreenDialog = false,
}) {
  final double clampedOpacity =
      barrierOpacity.clamp(0.0, 1.0).toDouble();
  final Color? barrierColor = clampedOpacity == 0.0
      ? null
      : Colors.black.withOpacity(clampedOpacity);

  return AppPageRoute.build<T>(
    builder: builder,
    settings: settings,
    fullscreenDialog: fullscreenDialog,
    barrierDismissible: barrierDismiss,
    barrierColor: barrierColor,
    curve: enterCurve,
    popCurve: exitCurve,
    forwardDuration: duration ?? const Duration(milliseconds: 240),
    reverseDuration: reverseDuration ?? duration ?? const Duration(milliseconds: 180),
    motionPattern: AppMotionPattern.glide,
  );
}


