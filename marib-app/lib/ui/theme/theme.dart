import 'package:marib/utils/extensions/extensions.dart';
import 'package:flutter/material.dart';
import 'package:marib/utils/ui_utils.dart';
export 'extensions/shimmer_colors.dart';

///Light Theme Colors
///This color format is different, isn't it? .You can use hex colors here also but you have to remove '#' symbol and add 0xff instead.
const Color primaryColor_ = Color(0xFFF7F7F8);
// const Color primaryColor_ = Color(0xFFABABAB);
const Color secondaryColor_ = Color(0xFFFFFFFF);
// const Color secondaryColor_ = Color(0xFF525252);
const Color headingAccentLight = Color(0xFFA8D7E6);
const Color headingAccentDark = Color(0xFF4FA5BA);
const Color neutralStrokeLight = Color(0xFFE2E3E7);
const Color neutralStrokeDark = Color(0xFF2A2A2D);



// 0xffEB5924
const Color territoryColor_ = Color.fromARGB(255, 235, 89, 36);
const Color forthColor_ = Color.fromRGBO(250, 110, 83, 1);
const Color _backgroundColor = primaryColor_; //here you can change if you need
const Color textDarkColor = Color(0xFF000000);
Color widgetsBorderColorLight = const Color(0xffEEEEEE).withOpacity(0.6);
Color lightTextColor = textDarkColor.withOpacity(0.6);
Color senderChatColor = const Color.fromARGB(255, 233, 233, 233).darken(22);

///Dark Theme Colors
const Color primaryColorDark = Color(0xFF0E0E10);
Color secondaryColorDark = const Color(0xFF1E1E20);
const Color cardColorLight = secondaryColor_;
Color cardColorDark = secondaryColorDark.brighten(6);

const Color territoryColorDark = Color(0xffEB5924);
Color deactivateColorLight = const Color(0xff7F7F7F);
const Color deactivateColorDark = Color(0xFF3D3D3D);

const Color forthColorDark = Color(0xffEB5924);
Color backgroundColorDark = primaryColorDark; //here you can change if you need
const Color textColorDarkTheme = Color(0xffFDFDFD);
Color lightTextColorDarkTheme = const Color(0xffFDFDFD).withOpacity(0.3);
Color widgetsBorderColorDark = neutralStrokeDark;
//Color popUpColor = const Color(0xff02AD11);
Color darkSenderChatColor =
    const Color.fromARGB(255, 233, 233, 233).darken(100);

///Messages Color
const Color errorMessageColor =
    Color.fromARGB(255, 166, 4, 4); // Color(0xffeb5479)
const Color successMessageColor = Color(0xffEB5924);
const Color warningMessageColor = Color(0xFFC2AF6F);

//status button color
const Color pendingButtonColor = Color(0xffEB5924);
const Color soldOutButtonColor = Color(0xffFFBB33);
const Color deactivateButtonColor = Color(0xffFE0000);
const Color activateButtonColor = Color(0xffEB5924);

//Button text color
const Color buttonTextColor = Colors.white;

//Button text color
const Color ligttextColor = Colors.white;

///Advance
//Theme settings
extension ColorPrefs on ColorScheme {
  Color get primaryColor => _getColor(brightness,
      lightColor: primaryColor_, darkColor: primaryColorDark);

  Color get secondaryColor => _getColor(brightness,
      lightColor: secondaryColor_, darkColor: secondaryColorDark);

  Color get cardColor =>
      _getColor(brightness, lightColor: cardColorLight, darkColor: cardColorDark);


  Color get secondaryDetailsColor => _getColor(brightness,
      lightColor: secondaryColor_, darkColor: primaryColorDark);

  Color get territoryColor => _getColor(brightness,
      lightColor: territoryColor_, darkColor: territoryColorDark);


  Color get headingAccentColor => _getColor(brightness,
      lightColor: headingAccentLight, darkColor: headingAccentDark);



  Color get deactivateColor => _getColor(brightness,
      lightColor: deactivateColorLight, darkColor: deactivateColorDark);

  Color get forthColor =>
      _getColor(brightness, lightColor: forthColor_, darkColor: forthColorDark);

  Color get backgroundColor => _getColor(brightness,
      lightColor: _backgroundColor, darkColor: backgroundColorDark);

  Color get buttonColor => buttonTextColor;

  Color get textColor => _getColor(brightness,
      lightColor: textDarkColor, darkColor: textColorDarkTheme);

  Color get textColorDark => _getColor(brightness,
      lightColor: textDarkColor, darkColor: textColorDarkTheme);

  Color get textDefaultColor => _getColor(brightness,
      lightColor: textDarkColor, darkColor: textColorDarkTheme);

  Color get textLightColor => _getColor(brightness,
      lightColor: lightTextColor, darkColor: lightTextColorDarkTheme);

  Color get borderColor => _getColor(brightness,
      lightColor: neutralStrokeLight,
      darkColor: neutralStrokeDark);

  Color get neutralStrokeColor => _getColor(brightness,
      lightColor: neutralStrokeLight, darkColor: neutralStrokeDark);

  Color get chatSenderColor => _getColor(brightness,
      lightColor: senderChatColor, darkColor: darkSenderChatColor);

  Color get errorColor => _getColor(
        brightness,
        lightColor: errorMessageColor,
        darkColor: errorMessageColor,
      );

  Color get successColor => _getColor(
        brightness,
        lightColor: successMessageColor,
        darkColor: successMessageColor,
      );

  ///This will set text color white if background is dark if background is light it will be dark
  Color textAutoAdapt(Color backgroundColor) =>
      UiUtils.getAdaptiveTextColor(backgroundColor);

  Color get blackColor => Colors.black;
}

// 10pt: Smaller
// 12pt: Small
// 16pt: Large
// 18pt: Larger
// 24pt: Extra large
extension TextThemeForFont on TextTheme {
  Font get font => Font();
}

/// i made this to access font easily from theme like, Theme.of(context).textTheme.font.small
/// So what is difference here?? in Theme.of(context).textTheme.small and Theme.of(context).textTheme.font.small
/// We use separate class because There will be an execution on BuildContext in [Utils/Extensions/lib] folder so further explanation is there. you can check
class Font {
  ///10
  double get smaller => 10;

  ///12
  double get small => 12;

  ///14
  double get normal => 14;

  ///16
  double get large => 16;

  ///18
  double get larger => 18;

  ///24
  ///
  double get extraLarge => 24;

  ///28
  double get xxLarge => 28;
}

//This one is for check current theme and return data accordingly
Color _getColor(Brightness brightness,
    {required Color lightColor, required Color darkColor}) {
  if (Brightness.light == brightness) {
    return lightColor;
  } else {
    return darkColor;
  }
}
