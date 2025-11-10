import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static ThemeData get light => FlexThemeData.light(
        colors: const FlexSchemeColor(
          primary: Color(0xFF1464A0),
          primaryContainer: Color(0xFF99CAFF),
          secondary: Color(0xFF3A7CA5),
          secondaryContainer: Color(0xFFCAE8FF),
          tertiary: Color(0xFF3AAFA9),
          tertiaryContainer: Color(0xFFCFEFEF),
          appBarColor: Color(0xFF0F4C75),
        ),
        fontFamily: GoogleFonts.manrope().fontFamily,
        useMaterial3: true,
      ).copyWith(
        visualDensity: VisualDensity.adaptivePlatformDensity,
      );

  static ThemeData get dark => FlexThemeData.dark(
        colors: const FlexSchemeColor(
          primary: Color(0xFF76B4FF),
          primaryContainer: Color(0xFF132742),
          secondary: Color(0xFF70C1B3),
          secondaryContainer: Color(0xFF103D3F),
          tertiary: Color(0xFF9DE2B3),
          tertiaryContainer: Color(0xFF1B402F),
          appBarColor: Color(0xFF041C32),
        ),
        fontFamily: GoogleFonts.manrope().fontFamily,
        surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
        blendLevel: 10,
        useMaterial3: true,
      );
}
