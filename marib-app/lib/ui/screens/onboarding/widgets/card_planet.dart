import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';

import '../models/card_planet_data.dart';

class CardPlanet extends StatelessWidget {
  final CardPlanetData data;
  final Map<String, LottieComposition> compositions;
  final bool shouldAnimate;
  final double progress;

  const CardPlanet({
    required this.data,
    required this.shouldAnimate,
    required this.compositions,
    required this.progress,
    super.key,
  });

  LottieComposition? _compositionFor(String? path) {
    if (path == null) return null;
    return compositions[path];
  }

  @override
  Widget build(BuildContext context) {
    final double clampedProgress = progress.clamp(-1.0, 1.0).toDouble();
    final double inverted = 1 - clampedProgress.abs();
    final double normalized = inverted.clamp(0.0, 1.0);
    final double easedOpacity = Curves.easeOut.transform(normalized);
    final double verticalOffset = 60.0 * clampedProgress;
    final double backgroundShift = 30.0 * clampedProgress;
    final titleColor = Color.lerp(
          data.titleColor.withOpacity(0.0),
          data.titleColor,
          easedOpacity,
        ) ??
        data.titleColor;
    final subtitleColor = Color.lerp(
          data.subtitleColor.withOpacity(0.0),
          data.subtitleColor,
          easedOpacity,
        ) ??
        data.subtitleColor;

    final gradientBlend = (easedOpacity * 0.7).clamp(0.0, 1.0);
    final blendedGradientColors = data.backgroundGradientColors
        .map(
          (color) =>
              Color.lerp(
                color.withOpacity(0.0),
                color,
                gradientBlend,
              ) ??
              color,
        )
        .toList(growable: false);

    return Stack(
      children: [
        if (blendedGradientColors.any((color) => color.opacity > 0.0))
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: blendedGradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
        if (data.backgroundAnimationPath != null)
          Transform.translate(
            offset: Offset(backgroundShift, 0),
            child: Opacity(
              opacity: 0.15 + 0.35 * easedOpacity,
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
            ),
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
                  child: Transform.translate(
                    offset: Offset(0, verticalOffset),
                    child: Opacity(
                      opacity: easedOpacity,
                      child: () {
                        final cached = _compositionFor(data.animationPath);
                        final double height =
                            MediaQuery.of(context).size.height * 0.45;
                        if (cached != null) {
                          return Lottie(
                            composition: cached,
                            height: height,
                            fit: BoxFit.contain,
                            animate: shouldAnimate,
                            repeat: shouldAnimate,
                          );
                        }
                        return Lottie.asset(
                          data.animationPath!,
                          height: height,
                          fit: BoxFit.contain,
                          // قم بإيقاف التشغيل الافتراضي إذا تريد تحكم خاص
                          animate: shouldAnimate,
                          repeat: shouldAnimate,
                        );
                      }(),
                    ),
                  ),
                ),
              if (data.image != null)
                Flexible(
                  flex: 20,
                  child: Transform.translate(
                    offset: Offset(0, verticalOffset),
                    child: Opacity(
                      opacity: easedOpacity,
                      child: Image(image: data.image!),
                    ),
                  ),
                ),
              const Spacer(flex: 2),
              Directionality(
                textDirection: TextDirection.rtl,
                child: Transform.translate(
                  offset: Offset(0, verticalOffset / 2),
                  child: Column(
                    children: [
                      Opacity(
                        opacity: easedOpacity,
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
                      Opacity(
                        opacity: easedOpacity,
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
              ),
              const Spacer(flex: 5),
            ],
          ),
        )
      ],
    );
  }
}
