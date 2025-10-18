import 'dart:ui';
import 'package:flutter/material.dart';

/// BlurredRouter
/// انتقال احترافي هادئ مع فرق بسيط بين دخول وخروج:
/// - الدخول: Slide خفيف + Scale up + Fade in.
/// - الخروج: Scale down طفيف + Slide خفيف لاتّجاه مختلف + Fade out.
/// كما يطبّق ضبابية وتعتيم تدريجيين على الخلفية.
class BlurredRouter<T> extends PageRoute<T> {
  final WidgetBuilder builder;

  // خيارات الحركة العامة
  final AxisDirection? axisDirection;      // اتجاه الانزلاق عند الدخول (إن لزم)
  final Offset? entryOffset;               // يعلو axisDirection إن حُدِّد
  final Offset? exitOffset;                // انزلاق بسيط عند الخروج (افتراضي: نصف entryOffset)
  final Duration? duration;                // مدة الدخول
  final Duration? reverseDuration;         // مدة الخروج (تعلو duration إن حُدِّدت)

  // منحنيات مخصّصة للدخول/الخروج
  final Curve enterCurve;
  final Curve exitCurve;

  // Scale مخصّص للدخول/الخروج
  final double enterScaleBegin;            // 0.0 < x <= 1.0 (افتراضي 0.96)
  final double exitScaleEnd;               // 0.0 < x <= 1.0 (افتراضي 0.985)
  final Alignment scaleAlignment;

  // الخلفية/الإغلاق
  final bool barrierDismiss;               // يُلتقط داخل الشجرة (وليس ModalRoute)
  final double barrierOpacity;             // [0..1] تعتيم الخلفية

  // الضبابية
  final double blurSigmaX;                 // >= 0
  final double blurSigmaY;                 // >= 0

  BlurredRouter({
    required this.builder,
    this.axisDirection,
    this.entryOffset,
    this.exitOffset,
    this.duration,
    this.reverseDuration,
    bool? barrierDismiss,
    double? barrierOpacity,
    this.enterCurve = Curves.easeOutCubic,
    this.exitCurve = Curves.easeInCubic,
    this.enterScaleBegin = 0.96,
    this.exitScaleEnd = 0.985,
    this.scaleAlignment = Alignment.center,
    this.blurSigmaX = 12.0,
    this.blurSigmaY = 12.0,
    RouteSettings? settings,
  })  : barrierDismiss = barrierDismiss ?? false,
        barrierOpacity = ((barrierOpacity ?? 0.20).clamp(0.0, 1.0)).toDouble(),
        assert(enterScaleBegin > 0.0 && enterScaleBegin <= 1.0),
        assert(exitScaleEnd > 0.0 && exitScaleEnd <= 1.0),
        assert(blurSigmaX >= 0.0 && blurSigmaY >= 0.0),
        super(settings: settings, fullscreenDialog: false);

  // ـــــــــ ModalRoute overrides ـــــــــ

  @override
  bool get opaque => false;

  // نلتقط النقر عبر GestureDetector داخل الشجرة
  @override
  bool get barrierDismissible => false;

  @override
  Color? get barrierColor => Colors.transparent;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration =>
      duration ?? const Duration(milliseconds: 240);

  @override
  Duration get reverseTransitionDuration =>
      reverseDuration ?? duration ?? const Duration(milliseconds: 180);

  // ـــــــــ البناء ـــــــــ

  @override
  Widget buildPage(
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      ) {
    return builder(context);
  }

  @override
  Widget buildTransitions(
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      Widget child,
      ) {
    // هل نحن في حالة دفع (push) أم سحب (pop)؟
    final bool isPushing = animation.status != AnimationStatus.reverse;

    // نجعل التقدّم يسير دائمًا من 0→1 سواء دخول أو خروج
    final Animation<double> progress =
    isPushing ? animation : ReverseAnimation(animation);

    // منحنى مختلف للدخول/الخروج
    final CurvedAnimation eased = CurvedAnimation(
      parent: progress,
      curve: isPushing ? enterCurve : exitCurve,
    );

    // إعدادات الانزلاق
    final Offset baseEnterOffset =
        entryOffset ?? (axisDirection != null ? _offsetForDirection(axisDirection!) : Offset.zero);

    // افتراضي الخروج: نصف قيمة الدخول وبنفس الاتجاه (هادئ جدًا)
    final Offset baseExitOffset = exitOffset ?? baseEnterOffset * 0.5;

    final Offset slideBegin = isPushing ? baseEnterOffset : Offset.zero;
    final Offset slideEnd   = isPushing ? Offset.zero       : baseExitOffset;

    final Animation<Offset> slide = Tween<Offset>(
      begin: slideBegin,
      end: slideEnd,
    ).animate(eased);

    // Scale: دخول (0.96→1.0) / خروج (1.0→0.985)
    final double scaleBegin = isPushing ? enterScaleBegin : 1.0;
    final double scaleEnd   = isPushing ? 1.0            : exitScaleEnd;

    final Animation<double> scale = Tween<double>(
      begin: scaleBegin,
      end: scaleEnd,
    ).animate(eased);

    // Fade: دخول (0→1) / خروج (1→0)
    final double fadeBegin = isPushing ? 0.0 : 1.0;
    final double fadeEnd   = isPushing ? 1.0 : 0.0;

    final Animation<double> fade = Tween<double>(
      begin: fadeBegin,
      end: fadeEnd,
    ).animate(eased);

    // الخلفية (ضبابية + تعتيم):
    // عند الدخول: 0→1، عند الخروج: 1→0
    final Animation<double> backdropT =
    isPushing ? eased : ReverseAnimation(eased);

    final Widget backdrop = _AnimatedBackdrop(
      animation: backdropT,
      sigmaX: blurSigmaX,
      sigmaY: blurSigmaY,
      targetOpacity: barrierOpacity,
    );

    // التقاط الضغط على الخلفية فقط عند السماح بالإغلاق
    final Widget backgroundTapCatcher = Positioned.fill(
      child: IgnorePointer(
        ignoring: !barrierDismiss,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: barrierDismiss ? () => Navigator.of(context).maybePop() : null,
          child: const SizedBox.expand(),
        ),
      ),
    );

    final Widget transitioningChild = FadeTransition(
      opacity: fade,
      child: SlideTransition(
        position: slide,
        child: ScaleTransition(
          alignment: scaleAlignment,
          scale: scale,
          child: child,
        ),
      ),
    );

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        backdrop,
        backgroundTapCatcher,
        transitioningChild,
      ],
    );
  }

  // ـــــــــ Helpers ـــــــــ

  Offset _offsetForDirection(AxisDirection direction) {
    switch (direction) {
      case AxisDirection.up:
        return const Offset(0.0, -0.14);
      case AxisDirection.right:
        return const Offset(0.14, 0.0);
      case AxisDirection.down:
        return const Offset(0.0, 0.14);
      case AxisDirection.left:
        return const Offset(-0.14, 0.0);
    }
  }
}

/// خلفية ضبابية مع تعتيم يتدرّج بقيمة animation (0..1).
class _AnimatedBackdrop extends StatelessWidget {
  final Animation<double> animation;
  final double sigmaX;
  final double sigmaY;
  final double targetOpacity;

  const _AnimatedBackdrop({
    Key? key,
    required this.animation,
    required this.sigmaX,
    required this.sigmaY,
    required this.targetOpacity,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final double t = animation.value; // 0..1
        return RepaintBoundary(
          child: Stack(
            fit: StackFit.expand,
            children: [
              BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: sigmaX * t,
                  sigmaY: sigmaY * t,
                ),
                child: const SizedBox.expand(),
              ),
              ColoredBox(
                color: Colors.black.withOpacity(targetOpacity * t),
              ),
            ],
          ),
        );
      },
    );
  }
}
