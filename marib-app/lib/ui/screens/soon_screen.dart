import 'package:flutter/material.dart';
import 'package:marib/ui/screens/widgets/animated_routes/blur_page_route.dart';

class SoonScreen extends StatelessWidget {
  const SoonScreen({super.key});

  static Route route(RouteSettings routeSettings) {
    return BlurredRouter(builder: (_) => const SoonScreen());
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SizedBox.shrink(),
    );
  }
}
