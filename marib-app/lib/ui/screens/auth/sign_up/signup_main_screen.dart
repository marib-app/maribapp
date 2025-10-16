import 'package:flutter/material.dart';
import 'package:marib/ui/screens/auth/signup_flow/signup_flow_screen.dart';
import 'package:marib/ui/screens/widgets/animated_routes/blur_page_route.dart';







class SignUpMainScreen extends SignupFlowScreen {
  const SignUpMainScreen({super.key, super.arguments});

  static BlurredRouter route(RouteSettings routeSettings) {
    final args = routeSettings.arguments as Map<String, dynamic>?;
    return BlurredRouter(builder: (_) => SignUpMainScreen(arguments: args));
  }
}
