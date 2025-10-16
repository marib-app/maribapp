import 'package:device_preview/device_preview.dart';
import 'package:marib/app/app.dart';
import 'package:marib/app/app_localization.dart';
import 'package:marib/app/app_theme.dart';
import 'package:marib/app/register_cubits.dart';
import 'package:marib/app/routes.dart';
import 'package:marib/data/cubits/system/app_theme_cubit.dart';
import 'package:marib/ui/screens/chat/chat_audio/globals.dart';
import 'package:marib/utils/constant.dart';
import 'package:marib/utils/hive_utils.dart';
import 'package:marib/utils/notification/notification_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:marib/data/cubits/system/language_cubit.dart';



/////////////
///V-1.0.0//
////////////


void main() => initApp();

class EntryPoint extends StatefulWidget {
  const EntryPoint({
    super.key,
  });

  @override
  EntryPointState createState() => EntryPointState();
}

class EntryPointState extends State<EntryPoint> {
  @override
  void initState() {
    super.initState();
    FirebaseMessaging.onBackgroundMessage(
        NotificationService.onBackgroundMessageHandler);
    //ChatMessageHandler.handle();
    ChatGlobals.init();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
        providers: RegisterCubits().providers,
        child: Builder(builder: (BuildContext context) {
          return const App();
        }));
  }
}

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  @override
  void initState() {
    context.read<LanguageCubit>().loadCurrentLanguage();


    AppTheme currentTheme = HiveUtils.getCurrentTheme();

    // ///Initialized notification services
    // LocalAwsomeNotification().init(context);
    ///////////// 
    // NotificationService.init(context);

    /// Initialized dynamic links for share items feature
    //DeepLinkManager.initDeepLinks();
    context.read<AppThemeCubit>().changeTheme(currentTheme);

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    //Continuously watching theme change
    AppTheme currentTheme = context.watch<AppThemeCubit>().state.appTheme;
    return BlocBuilder<LanguageCubit, LanguageState>(
      builder: (context, languageState) {
        return MaterialApp(
          initialRoute: Routes.splash,
          // App will start from here splash screen is first screen,
          navigatorKey: Constant.navigatorKey,
          //This navigator key is used for Navigate users through notification
          title: Constant.appName,
          debugShowCheckedModeBanner: false,
          onGenerateRoute: Routes.onGenerateRouted,
          theme: appThemeData[currentTheme],
          builder: (context, child) {
            TextDirection? direction;

            if (languageState is LanguageLoader) {
              if (languageState.language['rtl'] == true) {
                direction = TextDirection.rtl;
              } else {
                direction = TextDirection.ltr;
              }
            } else {
              direction = TextDirection.ltr;
            }
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(
                    1.0), //set text scale factor to 1 so that this will not resize app's text while user change their system settings text scale
              ),
              child: Directionality(
                textDirection: direction,
                //This will convert app direction according to language
                child: DevicePreview(
                  enabled: false,

                  /// Turn on this if you want to test the app in different screen sizes
                  builder: (context) {
                    return child!;
                  },
                ),
              ),
            ); /*MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(
                    1.0), //set text scale factor to 1 so that this will not resize app's text while user change their system settings text scale
              ),
              child: Directionality(
                textDirection: direction,
                //This will convert app direction according to language
                child: DevicePreview(
                  enabled: false,

                  /// Turn on this if you want to test the app in different screen sizes
                  builder: (context) {
                    return child!;
                  },
                ),
              ),
            );*/
          },
          localizationsDelegates: const [
            AppLocalization.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          locale: loadLocalLanguageIfFail(languageState),
        );
      },
    );
  }

  dynamic loadLocalLanguageIfFail(LanguageState state) {
    if ((state is LanguageLoader)) {
      return Locale(state.language['code']);
    } else if (state is LanguageLoadFail) {
      return const Locale("ar");
    }
  }
}

class GlobalScrollBehavior extends ScrollBehavior {
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics();
  }
}
