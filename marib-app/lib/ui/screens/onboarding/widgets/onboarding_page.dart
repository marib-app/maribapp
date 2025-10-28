import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:marib/utils/screen_scaler.dart';
import 'package:flutter/foundation.dart';

import '../models/onboarding_page_data.dart';

class OnboardingPageContent extends StatelessWidget {
  OnboardingPageContent({
    super.key,
    required CardPlanetData data,
    required ValueListenable<bool> heroActiveListenable,
  })  : hero = _buildHero(data, heroActiveListenable),
        textContent = _OnboardingTextContent(data: data);

  final Widget? hero;
  final Widget textContent;

  static Widget? _buildHero(
    CardPlanetData data,
    ValueListenable<bool> heroActiveListenable,
  ) {
    if (data.animationPath != null) {
      return _OnboardingLottieHero(
        animationPath: data.animationPath!,
        isActiveListenable: heroActiveListenable,
      );
    }
    if (data.image != null) {
      return _OnboardingImageHero(image: data.image!);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final double spacing = ScreenScaler.s(40);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (hero != null) hero!,
        SizedBox(height: spacing),
        textContent,
      ],
    );
  }
}

class _OnboardingLottieHero extends StatelessWidget {
  const _OnboardingLottieHero({
    required this.animationPath,
    required this.isActiveListenable,
  });

  final String animationPath;
  final ValueListenable<bool> isActiveListenable;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isActiveListenable,
      builder: (context, isActive, _) {
        return SizedBox(
          height: ScreenScaler.s(300),
          child: Lottie.asset(
            animationPath,
            fit: BoxFit.contain,
            animate: isActive,
          ),
        );
      },
    );
  }
}

class _OnboardingImageHero extends StatelessWidget {
  const _OnboardingImageHero({
    required this.image,
  });

  final ImageProvider<Object> image;

  @override
  Widget build(BuildContext context) {
    return Image(
      image: image,
      height: ScreenScaler.s(300),
      fit: BoxFit.contain,
    );
  }
}

class _OnboardingTextContent extends StatelessWidget {
  const _OnboardingTextContent({
    required this.data,
  });

  final CardPlanetData data;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        children: [
          Text(
            data.title,
            style: GoogleFonts.tajawal(
              fontSize: ScreenScaler.s(22),
              fontWeight: FontWeight.bold,
              color: data.titleColor,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: ScreenScaler.s(12)),
          Text(
            data.subtitle,
            style: GoogleFonts.tajawal(
              fontSize: ScreenScaler.s(16),
              height: 1.6,
              color: data.subtitleColor,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
