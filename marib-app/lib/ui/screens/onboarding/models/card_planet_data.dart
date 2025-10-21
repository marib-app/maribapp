import 'package:flutter/material.dart';

class CardPlanetData {
  final String title;
  final String subtitle;
  final ImageProvider? image;
  final List<Color> backgroundGradientColors;
  final Color titleColor;
  final Color subtitleColor;
  final String? backgroundAnimationPath;
  final String? animationPath;

  const CardPlanetData({
    required this.title,
    required this.subtitle,
    this.image,
    required this.backgroundGradientColors,
    required this.titleColor,
    required this.subtitleColor,
    this.backgroundAnimationPath,
    this.animationPath,
  });
}