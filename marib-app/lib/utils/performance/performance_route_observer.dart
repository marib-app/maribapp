import 'package:flutter/widgets.dart';

import 'performance_monitor.dart';

class PerformanceRouteObserver extends NavigatorObserver {
  PerformanceRouteObserver();

  final PerformanceMonitor _monitor = PerformanceMonitor.instance;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _monitor.onRoutePushed(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _monitor.onRoutePopped(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _monitor.onRouteReplaced(newRoute, oldRoute);
  }
}