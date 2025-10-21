import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';

import '../models/card_planet_data.dart';

class CardPlanet extends StatelessWidget {
  final CardPlanetData data;
  final Map<String, LottieComposition> compositions;
  final bool isActive;

  const CardPlanet({
    required this.data,
    required this.isActive,
    required this.compositions,
    super.key,
  });

  LottieComposition? _compositionFor(String? path) {
    if (path == null) return null;
    return compositions[path];
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: data.backgroundGradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        if (data.backgroundAnimationPath != null)
          Opacity(
            opacity: 0.2,
            child: () {
              final cached = _compositionFor(data.backgroundAnimationPath);
              if (cached != null) {
                return Lottie(
                  composition: cached,
                  fit: BoxFit.cover,
                  animate: isActive,
                  repeat: isActive,
                );
              }
              return Lottie.asset(
                data.backgroundAnimationPath!,
                fit: BoxFit.cover,
                animate: isActive,
                repeat: isActive,
              );
            }(),
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
                  child: AnimatedSlide(
                    duration: const Duration(milliseconds: 350),
                    curve: const Interval(0, 1, curve: Curves.easeOut),
                    offset: isActive ? Offset.zero : const Offset(0, 0.08),
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOut,
                      opacity: isActive ? 1 : 0,
                      child: () {
                        final cached = _compositionFor(data.animationPath);
                        if (cached != null) {
                          return Lottie(
                            composition: cached,
                            height: MediaQuery.of(context).size.height * 0.45,
                            fit: BoxFit.contain,
                            animate: isActive,
                            repeat: isActive,
                          );
                        }
                        return Lottie.asset(
                          data.animationPath!,
                          height: MediaQuery.of(context).size.height * 0.45,
                          fit: BoxFit.contain,
                          // قم بإيقاف التشغيل الافتراضي إذا تريد تحكم خاص
                          animate: isActive,
                          repeat: isActive,
                        );
                      }(),
                    ),
                  ),
                ),
              if (data.image != null)
                Flexible(
                  flex: 20,
                  child: AnimatedSlide(
                    duration: const Duration(milliseconds: 350),
                    curve: const Interval(0, 1, curve: Curves.easeOut),
                    offset: isActive ? Offset.zero : const Offset(0, 0.08),
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOut,
                      opacity: isActive ? 1 : 0,
                      child: Image(image: data.image!),
                    ),
                  ),
                ),
              const Spacer(flex: 2),
              Directionality(
                textDirection: TextDirection.rtl,
                child: Column(
                  children: [
                    AnimatedSlide(
                      duration: const Duration(milliseconds: 300),
                      curve: const Interval(0, 1, curve: Curves.easeOut),
                      offset: isActive ? Offset.zero : const Offset(0, 0.12),
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                        opacity: isActive ? 1 : 0,
                        child: Text(
                          data.title,
                          style: GoogleFonts.tajawal(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: data.titleColor,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    AnimatedSlide(
                      duration: const Duration(milliseconds: 350),
                      curve: const Interval(0.25, 1, curve: Curves.easeOut),
                      offset: isActive ? Offset.zero : const Offset(0, 0.12),
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 350),
                        curve: const Interval(0.25, 1, curve: Curves.easeOut),
                        opacity: isActive ? 1 : 0,
                        child: Text(
                          data.subtitle,
                          style: GoogleFonts.tajawal(
                            fontSize: 16,
                            height: 1.6,
                            color: data.subtitleColor,
                          ),
                          textAlign: TextAlign.center,
                        ),
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