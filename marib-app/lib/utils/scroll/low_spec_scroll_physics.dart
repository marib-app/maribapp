import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

/// Scroll physics tuned for low-spec devices.
///
/// The damping factor reduces the fling velocity which helps prevent
/// jank when large lists are scrolled quickly on hardware with limited
/// resources.
class LowSpecScrollPhysics extends ClampingScrollPhysics {
  const LowSpecScrollPhysics({super.parent});

  static const double _ballisticDamping = 0.82;

  @override
  LowSpecScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return LowSpecScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  Simulation? createBallisticSimulation(ScrollMetrics position, double velocity) {
    final double adjustedVelocity = velocity * _ballisticDamping;
    if (adjustedVelocity.abs() < 10) {
      return super.createBallisticSimulation(position, 0);
    }
    return super.createBallisticSimulation(position, adjustedVelocity);
  }
}