import 'dart:math' as math;

/// One spring, integrated by hand so its velocity is readable.
///
/// Flutter's `SpringSimulation` would do the maths, but it has to be rebuilt
/// every time the target moves — which is every frame of a drag.
///
/// Shared by the bottom nav bar and the task screen's scope bar: the two
/// travelling indicators are meant to feel like the same object, so they run
/// off the same integrator rather than two copies of it that can drift apart.
class Spring {
  Spring({required this.stiffness, required this.damping, this.value = 0})
    : target = value;

  final double stiffness;
  final double damping;
  double value;
  double target;
  double velocity = 0;

  /// Springs are integrated in steps no longer than this, so a dropped frame
  /// cannot blow one up.
  static const double maxSubStep = 0.004;

  bool isAtRest(double epsilon) =>
      (value - target).abs() < epsilon && velocity.abs() < epsilon * 10;

  /// Drives the spring from outside, for as long as something else — a finger
  /// — is deciding where it should be.
  void hold(double position) {
    value = position;
    target = position;
    velocity = 0;
  }

  void snap() {
    value = target;
    velocity = 0;
  }

  void advance(double dt) {
    final int steps = math.max(1, (dt / maxSubStep).ceil());
    final double h = dt / steps;
    for (int step = 0; step < steps; step++) {
      velocity += (-stiffness * (value - target) - damping * velocity) * h;
      value += velocity * h;
    }
  }
}

/// Holds [value] back the further it runs, approaching but never passing
/// [limit] — the renderer's own `withResistance`, in one dimension.
double soften(double value, double limit) =>
    value * limit / (limit + value.abs());
