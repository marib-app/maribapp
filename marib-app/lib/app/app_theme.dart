// ignore_for_file: deprecated_member_use

import 'package:marib/ui/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:marib/app/navigation/motion/motion_page_transitions_builder.dart';

enum AppTheme { dark, light }

final appThemeData = {
  AppTheme.light: ThemeData(
    // scaffoldBackgroundColor: pageBackgroundColor,
    brightness: Brightness.light,
    //textTheme
    useMaterial3: false,

    pageTransitionsTheme: const PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{
        TargetPlatform.android: MotionPageTransitionsBuilder(),
        TargetPlatform.iOS: MotionPageTransitionsBuilder(),
        TargetPlatform.fuchsia: MotionPageTransitionsBuilder(),
        TargetPlatform.macOS: MotionPageTransitionsBuilder(),
        TargetPlatform.windows: MotionPageTransitionsBuilder(),
        TargetPlatform.linux: MotionPageTransitionsBuilder(),
      },
    ),

    fontFamily: "Manrope",
    textSelectionTheme: const TextSelectionThemeData(
      selectionColor: territoryColor_,
      cursorColor: territoryColor_,
      selectionHandleColor: territoryColor_,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: const MaterialStatePropertyAll(territoryColor_),
      trackColor: MaterialStateProperty.resolveWith((states) {
        if (states.contains(MaterialState.selected)) {
          return territoryColor_.withOpacity(0.3);
        }
        return primaryColorDark;
      }),
    ),
    colorScheme: ColorScheme.fromSeed(
        error: errorMessageColor, seedColor: territoryColor_,brightness:Brightness.light),
  ),
  AppTheme.dark: ThemeData(
    brightness: Brightness.dark,
    useMaterial3: false,

    pageTransitionsTheme: const PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{
        TargetPlatform.android: MotionPageTransitionsBuilder(),
        TargetPlatform.iOS: MotionPageTransitionsBuilder(),
        TargetPlatform.fuchsia: MotionPageTransitionsBuilder(),
        TargetPlatform.macOS: MotionPageTransitionsBuilder(),
        TargetPlatform.windows: MotionPageTransitionsBuilder(),
        TargetPlatform.linux: MotionPageTransitionsBuilder(),
      },
    ),

    fontFamily: "Manrope",
    textSelectionTheme: const TextSelectionThemeData(
      selectionHandleColor: territoryColorDark,
      selectionColor: territoryColorDark,
      cursorColor: territoryColorDark,
    ),
    colorScheme: ColorScheme.fromSeed(
        error: errorMessageColor.withOpacity(0.7),
        seedColor: territoryColorDark,brightness:Brightness.dark),
    switchTheme: SwitchThemeData(
        thumbColor: const MaterialStatePropertyAll(territoryColor_),
        trackColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return territoryColor_.withOpacity(0.3);
          }
          return primaryColor_.withOpacity(0.2);
        })),
  )
};
