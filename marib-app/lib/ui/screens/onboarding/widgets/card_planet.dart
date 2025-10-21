import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';

import '../models/card_planet_data.dart';

class CardPlanet extends StatelessWidget {
  final CardPlanetData data;
  final Map<String, LottieComposition> compositions;
  final bool shouldAnimate;
  final double progress;
  final double contentProgress;

  const CardPlanet({
    required this.data,
    required this.shouldAnimate,
    required this.compositions,
    required this.progress,
    required this.contentProgress,
    super.key,
  });

  LottieComposition? _compositionFor(String? path) {
    if (path == null) return null;
    return compositions[path];
  }

  @override
  Widget build(BuildContext context) {
    final double clampedProgress = progress.clamp(-1.0, 1.0).toDouble();
    final double verticalOffset = 60.0 * clampedProgress;
    final double clampedContent = contentProgress.clamp(0.0, 1.0);
    final double backgroundShift = 30.0 * clampedProgress;
    double staggered(double value,
        {double begin = 0.0,
        double end = 1.0,
        Curve curve = Curves.easeInOut}) {
      if (begin >= end) return value >= end ? 1.0 : 0.0;
      final double normalized =
          ((value - begin) / (end - begin)).clamp(0.0, 1.0);
      return curve.transform(normalized);
    }

    final double titleProgress = staggered(
      clampedContent,
      begin: 0.0,
      end: 0.35,
      curve: Curves.easeOutCubic,
    );
    final double subtitleProgress = staggered(
      clampedContent,
      begin: 0.12,
      end: 0.55,
      curve: Curves.easeInOut,
    );
    final double secondaryProgress = staggered(
      clampedContent,
      begin: 0.35,
      end: 0.9,
      curve: Curves.easeInOut,
    );
    final double backgroundProgress = staggered(
      clampedContent,
      begin: 0.25,
      end: 1.0,
      curve: Curves.easeInOut,
    );

    final titleColor = Color.lerp(
          data.titleColor.withOpacity(0.0),
          data.titleColor,
          titleProgress,
        ) ??
        data.titleColor;
    final subtitleColor = Color.lerp(
          data.subtitleColor.withOpacity(0.0),
          data.subtitleColor,
          subtitleProgress,
        ) ??
        data.subtitleColor;

    final subtleOverlayColor = data.backgroundGradientColors.isEmpty
        ? null
        : Color.lerp(
            Colors.transparent,
            data.backgroundGradientColors.first.withOpacity(0.18),
            backgroundProgress,
          );

    Widget animatedEntry({
      required Widget child,
      required double progress,
      double vertical = 0,
      double initialOffset = 40,
      double minScale = 0.94,
      Curve curve = Curves.easeInOut,
      Duration duration = const Duration(milliseconds: 360),
    }) {
      return TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: progress),
        duration: duration,
        curve: curve,
        child: child,
        builder: (context, value, child) {
          final double translateY = vertical + (1 - value) * initialOffset;
          final double scale = lerpDouble(minScale, 1.0, value)!;
          return Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, translateY),
              child: Transform.scale(
                scale: scale,
                child: child,
              ),
            ),
          );
        },
      );
    }

    return Stack(
      children: [
        Positioned.fill(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
            color: subtleOverlayColor,
          ),
        ),
        if (data.backgroundAnimationPath != null)
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: backgroundProgress),
            duration: const Duration(milliseconds: 520),
            curve: Curves.easeInOut,
            child: () {
              final cached = _compositionFor(data.backgroundAnimationPath);
              if (cached != null) {
                return Lottie(
                  composition: cached,
                  fit: BoxFit.cover,
                  animate: shouldAnimate,
                  repeat: shouldAnimate,
                );
              }
              return Lottie.asset(
                data.backgroundAnimationPath!,
                fit: BoxFit.cover,
                animate: shouldAnimate,
                repeat: shouldAnimate,
              );
            }(),
            builder: (context, value, child) {
              final double opacity = (0.15 + 0.35 * value).clamp(0.0, 1.0);
              return Transform.translate(
                offset: Offset(backgroundShift * value, 0),
                child: Opacity(
                  opacity: opacity,
                  child: child,
                ),
              );
            },
          ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),
              if (data.animationPath != null)
                Flexible(
                  flex: 20,
                  child: animatedEntry(
                    progress: secondaryProgress,
                    vertical: verticalOffset,
                    initialOffset: 80,
                    minScale: 0.88,
                    curve: Curves.easeOutCubic,
                    duration: const Duration(milliseconds: 420),
                    child: () {
                      final cached = _compositionFor(data.animationPath);
                      final double height =
                          MediaQuery.of(context).size.height * 0.45;
                      if (cached != null) {
                        return Lottie(
                          composition: cached,
                          height: height,
                          fit: BoxFit.contain,
                          // قم بإيقاف التشغيل الافتراضي إذا تريد تحكم خاص
                          animate: shouldAnimate,
                          repeat: shouldAnimate,
                        );
                      }
                      return Lottie.asset(
                        data.animationPath!,
                        height: height,
                        fit: BoxFit.contain,
                        animate: shouldAnimate,
                        repeat: shouldAnimate,
                      );
                    }(),
                  ),
                ),
              if (data.image != null)
                Flexible(
                  flex: 20,
                  child: animatedEntry(
                    progress: secondaryProgress,
                    vertical: verticalOffset,
                    initialOffset: 70,
                    minScale: 0.92,
                    curve: Curves.easeOutCubic,
                    duration: const Duration(milliseconds: 420),
                    child: Image(image: data.image!),
                  ),
                ),
              const Spacer(flex: 2),
              Directionality(
                textDirection: TextDirection.rtl,
                child: Column(
                  children: [
                    animatedEntry(
                      progress: titleProgress,
                      vertical: verticalOffset / 2,
                      initialOffset: 30,
                      minScale: 0.94,
                      curve: Curves.easeInOut,
                      duration: const Duration(milliseconds: 320),
                      child: Text(
                        data.title,
                        style: GoogleFonts.tajawal(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: titleColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 12),
                    animatedEntry(
                      progress: subtitleProgress,
                      vertical: verticalOffset / 2,
                      initialOffset: 24,
                      minScale: 0.96,
                      curve: Curves.easeInOut,
                      duration: const Duration(milliseconds: 360),
                      child: Text(
                        data.subtitle,
                        style: GoogleFonts.tajawal(
                          fontSize: 16,
                          height: 1.6,
                          color: subtitleColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(flex: 5),
            ],
          ),
        )
      ],
    );
  }
}
