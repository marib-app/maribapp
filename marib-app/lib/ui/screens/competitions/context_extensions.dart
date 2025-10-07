import 'package:flutter/material.dart';

extension MaribContextExtension on BuildContext {
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  ColorScheme get colorScheme => Theme.of(this).colorScheme;

  TextTheme get textTheme => Theme.of(this).textTheme;
}
