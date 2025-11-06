import 'package:flutter/material.dart';
import 'package:marib/app/navigation/app_page_route.dart';
import 'package:marib/app/navigation/motion/route_motion.dart';
import 'package:marib/app/app_scroll_behavior.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:marib/utils/extensions/extensions.dart';

class WifiCabinScreen extends StatefulWidget {
  const WifiCabinScreen({super.key});

  static Route route(RouteSettings settings) {
    return AppPageRoute.build(
      builder: (_) => const WifiCabinScreen(),
      settings: settings,
      maintainState: true,
      motionPattern: AppMotionPattern.glide,
    );
  }

  @override
  State<WifiCabinScreen> createState() => _WifiCabinScreenState();
}

class _WifiCabinScreenState extends State<WifiCabinScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: UiUtils.buildAppBar(
        context,
        showBackButton: true,
        title: 'wifiCabin'.translate(context),
      ),
      body: const CustomScrollView(
        physics: AppScrollBehavior.defaultPhysics,
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
