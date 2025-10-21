import 'package:flutter/material.dart';
import 'package:marib/data/model/metal_rate.dart';

enum MetalsFilter {
  all,
  gold,
  silver,
  other,
}

class MetalSection {
  const MetalSection({
    required this.filter,
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.accent,
    required this.rates,
    this.subtitle,
  });

  const MetalSection.empty()
      : filter = MetalsFilter.all,
        title = '',
        icon = Icons.circle,
        iconColor = Colors.transparent,
        accent = Colors.transparent,
        rates = const <MetalRate>[],
        subtitle = null;

  final MetalsFilter filter;
  final String title;
  final IconData icon;
  final Color iconColor;
  final Color accent;
  final List<MetalRate> rates;
  final String? subtitle;

  bool get exists => title.isNotEmpty;
  bool get hasRates => rates.isNotEmpty;
}