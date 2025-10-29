import 'package:flutter/material.dart';

class AppScrollBehavior extends ScrollBehavior {
  const AppScrollBehavior();

  static const ScrollPhysics defaultPhysics = ClampingScrollPhysics(
    parent: AlwaysScrollableScrollPhysics(),
  );

  @override
  Widget buildOverscrollIndicator(
      BuildContext context,
      Widget child,
      ScrollableDetails details,
      ) {
    return StretchingOverscrollIndicator(
      axisDirection: details.direction,
      child: child,
    );
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return defaultPhysics;

  }
}