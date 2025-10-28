import 'package:flutter/material.dart';

class CardPlanetData {
  const CardPlanetData({
    required this.title,
    required this.subtitle,
    required this.backgroundGradientColors,
    required this.titleColor,
    required this.subtitleColor,
    this.animationPath,
    this.image,
  })  : assert(
          backgroundGradientColors.length >= 2,
          'backgroundGradientColors must include at least two colors for gradient interpolation.',
        ),
        assert(
          animationPath != null || image != null,
          'Either animationPath or image must be provided.',
        );

  final String title;
  final String subtitle;
  final List<Color> backgroundGradientColors;
  final Color titleColor;
  final Color subtitleColor;
  final String? animationPath;
  final ImageProvider? image;
}