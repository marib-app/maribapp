import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:marib/utils/screen_scaler.dart';

import '../models/onboarding_page_data.dart';

class OnboardingPage extends StatelessWidget {
  const OnboardingPage({
    super.key,
    required this.data,
    required this.opacity,
    required this.textTranslateX,
    required this.imageTranslateY,
  });

  final CardPlanetData data;
  final double opacity;
  final double textTranslateX;
  final double imageTranslateY;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: ScreenScaler.s(24),
          vertical: ScreenScaler.s(60),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (data.animationPath != null)
              Transform.translate(
                offset: Offset(0, imageTranslateY),
                child: SizedBox(
                  height: ScreenScaler.s(300),
                  child: Lottie.asset(
                    data.animationPath!,
                    fit: BoxFit.contain,
                  ),
                ),
              )
            else if (data.image != null)
              Transform.translate(
                offset: Offset(0, imageTranslateY),
                child: Image(
                  image: data.image!,
                  height: ScreenScaler.s(300),
                  fit: BoxFit.contain,
                ),
              ),
            SizedBox(height: ScreenScaler.s(40)),
            Transform.translate(
              offset: Offset(textTranslateX, 0),
              child: Directionality(
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}