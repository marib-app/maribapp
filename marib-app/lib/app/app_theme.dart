// ignore_for_file: deprecated_member_use

import 'package:marib/ui/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:marib/app/navigation/motion/motion_page_transitions_builder.dart';

enum AppTheme { dark, light }


final _baseLightColorScheme = ColorScheme.fromSeed(
  seedColor: territoryColor_,
  brightness: Brightness.light,
  error: errorMessageColor,
);

final _baseDarkColorScheme = ColorScheme.fromSeed(
  seedColor: territoryColorDark,
  brightness: Brightness.dark,
  error: errorMessageColor.withOpacity(0.7),
);

final appThemeData = {
  AppTheme.light: ThemeData(
    // scaffoldBackgroundColor: pageBackgroundColor,
    brightness: Brightness.light,
    //textTheme
    useMaterial3: false,


    scaffoldBackgroundColor: primaryColor_,
    cardColor: cardColorLight,
    appBarTheme: const AppBarTheme(
      backgroundColor: primaryColor_,
      elevation: 0,
      foregroundColor: textDarkColor,
      surfaceTintColor: Colors.transparent,
    ),

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
        return neutralStrokeLight;
      }),
    ),
    colorScheme: _baseLightColorScheme.copyWith(
      background: primaryColor_,
      surface: cardColorLight,
      primary: territoryColor_,
      secondary: headingAccentLight,
      tertiary: headingAccentLight,
      outline: neutralStrokeLight,
      onPrimary: Colors.white,
      onSecondary: textDarkColor,
      onTertiary: textDarkColor,
      onBackground: textDarkColor,
      onSurface: textDarkColor,
    ),


  ),
  AppTheme.dark: ThemeData(
    brightness: Brightness.dark,
    useMaterial3: false,


    scaffoldBackgroundColor: primaryColorDark,
    cardColor: cardColorDark,
    appBarTheme: const AppBarTheme(
      backgroundColor: primaryColorDark,
      elevation: 0,
      foregroundColor: textColorDarkTheme,
      surfaceTintColor: Colors.transparent,
    ),

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
    colorScheme: _baseDarkColorScheme.copyWith(
      background: primaryColorDark,
      surface: cardColorDark,
      primary: territoryColorDark,
      secondary: headingAccentDark,
      tertiary: headingAccentDark,
      outline: neutralStrokeDark,
      onPrimary: Colors.white,
      onSecondary: textColorDarkTheme,
      onTertiary: textColorDarkTheme,
      onBackground: textColorDarkTheme,
      onSurface: textColorDarkTheme,
    ),


    switchTheme: SwitchThemeData(
        thumbColor: const MaterialStatePropertyAll(territoryColor_),
        trackColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return territoryColor_.withOpacity(0.3);
          }
          return neutralStrokeDark;
        })),
  )
};
